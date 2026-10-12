#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$EUID" == 0 ]] || { echo "Run as root" >&2; exit 1; }
DEST="/var/lib/pg-node/xray-core"
LAST="$DEST/last-backup-path"
[[ -f "$LAST" ]] || { echo "No installer backup recorded." >&2; exit 1; }
BACKUP="$(cat "$LAST")"
case "$BACKUP" in "$DEST"/backups/*) ;; *) echo "Invalid backup path" >&2; exit 1;; esac
[[ -f "$BACKUP/node.env" ]] || { echo "Missing backed-up env file" >&2; exit 1; }
cp -p "$BACKUP/node.env" /opt/pg-node/.env
if [[ -f "$BACKUP/xray" ]]; then
  cp -p "$BACKUP/xray" "$DEST/xray"
else
  rm -f "$DEST/xray"
fi
echo "[OK] Previous config and executable restored."
echo "Node NOT restarted. To apply during maintenance: pg-node restart"
