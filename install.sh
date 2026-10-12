#!/usr/bin/env bash
set -Eeuo pipefail

REPO="amiradineh74/control-usage-pasarguard"
ENV_FILE="/opt/pg-node/.env"
DEST="/var/lib/pg-node/xray-core"
TARGET="$DEST/xray"

fail(){ echo "[ERROR] $*" >&2; exit 1; }
[[ "$EUID" == 0 ]] || fail "Run as root"
[[ -f "$ENV_FILE" ]] || fail "Missing node config: $ENV_FILE"
command -v pg-node >/dev/null || fail "pg-node not found; run on a PasarGuard node"
for cmd in curl unzip sha256sum python3 od; do command -v "$cmd" >/dev/null || fail "Missing utility: $cmd"; done

case "$(uname -m)" in
  x86_64|amd64)
    ARCH=amd64
    CHECKSUM=711d850deb8b71b7e2dbe9ae7dc8fdf266a6c26065d25e8fdd25a86a9271bcbb
    ELF_MACHINE=3e00
    ;;
  aarch64|arm64)
    ARCH=arm64
    CHECKSUM=271ded5626b854b3ea4da1ded4ce062a392f4e5381581d67ee39de325fe150db
    ELF_MACHINE=b700
    ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac

ARCHIVE_URL="https://raw.githubusercontent.com/$REPO/main/binaries/xray-$ARCH.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "[1/5] Downloading third-party Xray build for $ARCH"
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 "$ARCHIVE_URL" -o "$TMP/xray.zip"
echo "$CHECKSUM  $TMP/xray.zip" | sha256sum -c - || fail "Archive hash mismatch"

echo "[2/5] Validating archive content and ELF architecture"
FILES="$(unzip -Z -1 "$TMP/xray.zip")"
[[ "$FILES" == "xray-$ARCH" ]] || fail "Unexpected contents in ZIP"
unzip -p "$TMP/xray.zip" "xray-$ARCH" > "$TMP/xray"
[[ -s "$TMP/xray" ]] || fail "Empty executable"
[[ "$(od -An -tx1 -N4 "$TMP/xray" | tr -d ' \n')" == "7f454c46" ]] || fail "Not ELF"
[[ "$(od -An -tx1 -j18 -N2 "$TMP/xray" | tr -d ' \n')" == "$ELF_MACHINE" ]] || fail "Wrong ELF machine"

echo "[3/5] Backing up existing node configuration"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
BACKUP="$DEST/backups/$STAMP"
mkdir -p "$BACKUP"
cp -p "$ENV_FILE" "$BACKUP/node.env"
if [[ -e "$TARGET" ]]; then cp -p "$TARGET" "$BACKUP/xray"; fi

echo "[4/5] Installing patched binary"
install -m 0755 "$TMP/xray" "$DEST/xray.new"
mv -f "$DEST/xray.new" "$TARGET"

echo "[5/5] Setting XRAY_EXECUTABLE_PATH"
python3 - "$ENV_FILE" "$TARGET" <<'PY'
import os, re, sys, tempfile
from pathlib import Path
p = Path(sys.argv[1]); target = sys.argv[2]
original = p.read_text()
# Replace commented or uncommented occurrences, retaining unrelated variables.
cleaned = re.sub(r'(?m)^[ \t]*#?[ \t]*XRAY_EXECUTABLE_PATH[ \t]*=.*(?:\n|$)', '', original)
cleaned = cleaned.rstrip('\n') + f'\nXRAY_EXECUTABLE_PATH={target}\n'
fd, name = tempfile.mkstemp(prefix='.pg-env-', dir=p.parent)
try:
    os.fchmod(fd, p.stat().st_mode & 0o777)
    with os.fdopen(fd, 'w') as output:
        output.write(cleaned)
    os.chown(name, p.stat().st_uid, p.stat().st_gid)
    os.replace(name, p)
finally:
    if os.path.exists(name): os.unlink(name)
PY

printf '%s\n' "$BACKUP" > "$DEST/last-backup-path"
chmod 600 "$DEST/last-backup-path"
echo "[OK] Binary installed; previous config saved to $BACKUP"
echo "Node NOT restarted. Inspect the env and verify runtime compatibility first."
echo "To activate during maintenance: pg-node restart"
