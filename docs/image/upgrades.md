# Upgrades

This document describes how to upgrade the `hybrowse/hytale-server` Docker image safely.

## General upgrade guidance

- Prefer pinning a specific image tag (for example `hybrowse/hytale-server:1.2.3`) instead of using `latest`.
- Always persist `/data` if you expect your server files, universe, mods, auth state, and backups to survive restarts.
- Consider taking an out-of-band backup (for example a snapshot of the `/data` volume) before upgrading.

## Graceful shutdown: recommended grace periods

The Hytale dedicated server typically stops and flushes state quickly.
Based on observed stop times of ~5–15 seconds, a small buffer is still recommended for predictable operations, especially when using mods.

- Docker Compose: `stop_grace_period: 60s`
- Kubernetes: `terminationGracePeriodSeconds: 60`

If your host is under heavy load, or you run large universes/modpacks, consider increasing this to `90` seconds.

## Docker Compose upgrade

Typical upgrade flow:

1. Ensure your `./data:/data` volume mount is persistent.
2. Stop the container (gracefully):

   - `docker compose down`

3. Pull the new image:

   - `docker compose pull`

4. Start again:

   - `docker compose up -d`

### Note: server file updates

There are two common models:

- If you use `HYTALE_AUTO_DOWNLOAD=true`:

  - With `HYTALE_AUTO_UPDATE=true` (default), the container checks for updates on each start and downloads new server files into `/data` when an update is available.
  - With `HYTALE_AUTO_UPDATE=false`, downloads happen only when files are missing.

- If you provision server files manually:

  - Replace `/data/server/HytaleServer.jar` and `/data/Assets.zip` out-of-band.
  - This project must not redistribute proprietary server files.

## Kubernetes upgrade

### Helm

- Prefer pinning the chart/app version and the image tag.
- Upgrade by changing the image tag and running `helm upgrade`.

Recommended termination grace period:

- `terminationGracePeriodSeconds: 60`

### Kustomize

- Change the image tag in your overlay and apply.

### Notes

- If you use a PVC for `/data`, upgrades should preserve world state and authentication as long as you keep the PVC.
- If you run with ephemeral `/data` (`emptyDir`), upgrades will naturally discard state on restart.

## Downgrades / rollbacks

Rolling back the image tag is possible, but rolling back server files and world state may not be safe.
If you need reliable rollbacks, use snapshots/backups of `/data` and restore those in addition to changing the image tag.


## In-game server updates

Opt in with:

```yaml
environment:
  HYTALE_NATIVE_UPDATES: "true"
  HYTALE_AUTO_UPDATE: "false"
  HYTALE_ENABLE_BACKUP: "true"
```

Remove `HYTALE_DISABLE_UPDATES=true` if previously set. `HYTALE_AUTO_DOWNLOAD=true`
can still provision missing files on first startup, but its startup update check
must be disabled so that two mechanisms do not update the same installation.

Send the normal Hytale update commands, checking the server logs between steps:

```bash
docker compose exec hytale hytale-cli send "/update check"
docker compose exec hytale hytale-cli send "/update download"
# Wait for the download to finish, then:
docker compose exec hytale hytale-cli send "/update apply --confirm"
```

Hytale performs its configured pre-update backups, shuts down with exit code 8,
and the image then verifies and installs the staged files before restarting Java.
A staged update is also applied at the next container start, matching the official
launcher workflow. A crash or a regular shutdown does not trigger an internal restart.
An update exit without staged files fails with a clear error instead of looping.

Use the standard `/data/server/HytaleServer.jar`, `/data/Assets.zip` and AOT paths.
The files and their directories must be writable; mount the `/data` volume rather
than individual read-only JAR/assets files. Only one update runner can hold the
volume lock at a time. No root privileges are required.

### What is replaced

A complete staged package must contain both the JAR and `Assets.zip`; partial
or JAR-only packages are rejected. Only those files, optional AOT input configuration
and the license directory are installed. Staged launcher scripts, configuration, mods and authentication
files are not executed or installed. World data and credentials stay in place.
The existing AOT cache is removed because it may not match the new server. Use
`ENABLE_AOT=auto` or `false` for unattended updates; strict mode needs a matching
cache to be generated again before the next start.

The image checks archive integrity and rejects staged links or special files.
It prepares the replacement files and records the previous binaries before
changing live files. A failed install restores the previous files. An interrupted
transaction is recovered before Java can start. Keep enough free disk space for
the staged package, prepared replacements and backups.

Previous binaries are retained at `/data/updater/image-backup/previous/`:
`jar`, `assets`, `aotconfig`, `aot` and `licenses` correspond to their managed paths.
Hytale's own `/data/updater/backup` is separate and is left untouched.
Once the new server has started, the image does not roll it back automatically:
world or config migrations may already have happened. A version rollback should
include a compatible world/config snapshot, as described above.

If validation fails, the live files stay unchanged. Inspect the log and staged
package, cancel the incomplete update with Hytale's `/update cancel` while native
update mode is disabled if necessary, then download it again. Do not delete
`image-transaction` while recovering an interrupted install.
