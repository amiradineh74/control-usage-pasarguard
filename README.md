# Control Usage PasarGuard

Unofficial installation helper for the **PasarGuard UserConnTracker patch for Xray-core**.

> The patch is developed by the PasarGuard team, not this repository. This project helps deploy their prebuilt Xray binaries and revert the change if needed. It is not an official Xray-core release or a complete traffic-quota/billing solution.

## What problem does it address?

When the central management panel removes a user through the Xray gRPC API, previously established sessions may remain connected and continue transferring data. PasarGuard proposed an Xray-core change to track and close those connections when a user is removed.

- [Original upstream proposal: Xray-core PR #5844](https://github.com/XTLS/Xray-core/pull/5844)
- [Patch source branch](https://github.com/ImMohammad20000/Xray-core/tree/UserConnTracker)

The upstream PR was **open and unmerged when this README was written (October 2026)**. Check it again before using a third-party build.

## Where should it be installed?

**On each PasarGuard node running Xray**, not just on the central panel. The panel sends gRPC requests, but the Xray process that maintains user sessions runs on the node.

If you have Germany and Turkey nodes, apply and test the patch **one node at a time**, to avoid interrupting both locations at once.

## Supported environment and prerequisites

- PasarGuard node with the `pg-node` management command
- `/opt/pg-node/.env` on the node host
- The custom executable location `/var/lib/pg-node/xray-core/xray` supported by your node
- Linux `amd64` or `arm64`; provided archives were reportedly built for **Alpine Linux**
- root access and common tools: curl, unzip, sha256sum, python3
- An up-to-date backup and maintenance window

The binaries should be compatible with the **runtime inside the node container**, not just the host's CPU architecture. Verify that the host directory is mounted into the node container before restarting.

## Files

| File | Purpose |
|---|---|
| `install.sh` | Selects architecture, downloads the relevant ZIP, verifies checksum, creates a backup, installs Xray and configures `XRAY_EXECUTABLE_PATH` |
| `rollback.sh` | Restores the previous environment and optional custom Xray executable |
| `binaries/xray-amd64.zip` | Third-party Alpine/amd64 Xray build (must be added separately) |
| `binaries/xray-arm64.zip` | Third-party Alpine/arm64 Xray build (must be added separately) |

**The binaries are not included until explicitly uploaded. Running the installer before that will fail safely.**

## Uploaded archive SHA-256 hashes

These match the two ZIP files originally provided for this project; they verify download integrity **only**, not publisher authenticity:

```text
711d850deb8b71b7e2dbe9ae7dc8fdf266a6c26065d25e8fdd25a86a9271bcbb  binaries/xray-amd64.zip
271ded5626b854b3ea4da1ded4ce062a392f4e5381581d67ee39de325fe150db  binaries/xray-arm64.zip
```

Ensure the files originate from the PasarGuard team, review their provenance, and check redistribution rights before placing them in a **public** repository.

## Installation

First upload both original ZIPs into `binaries/` in this repository. Review the script and understand what it will change.

On **each PasarGuard node**, use:

```bash
curl -fsSL https://raw.githubusercontent.com/amiradineh74/control-usage-pasarguard/main/install.sh -o /root/control-usage-install.sh
bash /root/control-usage-install.sh
```

The installer performs the following steps:

1. Detects `amd64` or `arm64`.
2. Downloads the selected ZIP over HTTPS.
3. Verifies its pinned SHA-256 hash and that it contains a single expected ELF executable.
4. Backs up `/opt/pg-node/.env` and any existing custom executable under `/var/lib/pg-node/xray-core/backups/`.
5. Installs the executable at `/var/lib/pg-node/xray-core/xray`.
6. Sets `XRAY_EXECUTABLE_PATH=/var/lib/pg-node/xray-core/xray` in the node env.

The installer **does not restart the node**. Review the changes and, during a maintenance window, run:

```bash
pg-node restart
```

Verify that Xray starts, clients can reconnect, and a controlled **test user** with an active session is disconnected when removed through gRPC. Successful startup alone does not verify the behavior of the patch.

## Rolling back

On the same node, if there is a problem:

```bash
curl -fsSL https://raw.githubusercontent.com/amiradineh74/control-usage-pasarguard/main/rollback.sh -o /root/control-usage-rollback.sh
bash /root/control-usage-rollback.sh
pg-node restart
```

The rollback uses the latest backup created by the installer. Backed-up environment files may contain credentials: never commit or publicly share them.

## Limitations

- The scripts install prebuilt binaries; they **do not compile or modify Xray source**.
- This does not patch Paqet, the central management panel, or third-party proxies.
- Binary builds may become outdated or incompatible with subsequent node versions.
- Always test in staging if possible, monitor real user traffic and have an alternate working node available.
- Do not claim this installer is authored or endorsed by the PasarGuard team.

## Credits

Patch author: **PasarGuard team** — see [XTLS/Xray-core#5844](https://github.com/XTLS/Xray-core/pull/5844). This repo packages an independent helper to install third-party builds. No redistribution license for third-party ZIP files is asserted here.
