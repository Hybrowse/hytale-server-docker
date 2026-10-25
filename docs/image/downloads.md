# Downloads and credentials

If `HYTALE_AUTO_DOWNLOAD=true` and `Assets.zip` / `HytaleServer.jar` are missing, the container will:

- download the official Hytale Downloader from `https://downloader.hytale.com/`
- run it using the OAuth device-code flow
- store downloader credentials on the `/data` volume
- extract `Assets.zip` to `/data/Assets.zip`
- extract `Server/` contents to `/data/server/`

When `HYTALE_AUTO_DOWNLOAD=true`, the container will check for updates on each start by comparing the remote version against the locally stored version (in `.hytale-version`).
Downloads only happen when an update is available. Set `HYTALE_AUTO_UPDATE=false` to disable update checks entirely and only download when files are missing.

Credentials are stored as:

- `/data/.hytale-downloader-credentials.json`

If that file already exists (for example from a previous run), downloads become non-interactive.

To replace an expired or revoked login, set `HYTALE_DOWNLOADER_RESET_CREDENTIALS=true`
for one startup and complete the device login shown in the logs. Remove the setting
once signed in: leaving it enabled clears the downloader login on every startup.
This only resets downloader credentials; server authentication, worlds and configuration
are preserved. It cannot be combined with `HYTALE_DOWNLOADER_CREDENTIALS_SRC`;
replace the mounted credentials instead. See [recovery steps](troubleshooting.md#expired-downloader-login-invalid_grant).

For non-interactive operations (providers/fleets), use one of these patterns:

- Seed downloader credentials via `HYTALE_DOWNLOADER_CREDENTIALS_SRC` (recommended if you keep `HYTALE_AUTO_DOWNLOAD=true`).
- Provision `Assets.zip` and `Server/` out-of-band (for example with an init container) and run with `HYTALE_AUTO_DOWNLOAD=false`.

If you want fully non-interactive automation, see: [Non-interactive auto-download (seed credentials)](#seed-an-existing-downloader-login)

For safety, `HYTALE_DOWNLOADER_URL` is restricted to `https://downloader.hytale.com/`.

Auto-download works on both `linux/amd64` and `linux/arm64`. The official
archive currently provides an x86-64 downloader only. On ARM64, the image runs
that helper through QEMU user-mode emulation, including its version checks.
Java and the Hytale server remain native ARM64. No privileged mode or host
binfmt registration is required. AMD64 images do not install the emulator.
Manual provisioning remains available; see [`server-files.md`](server-files.md).

## Seed an existing downloader login


If you already have `.hytale-downloader-credentials.json`, you can mount it read-only and seed it:

```yaml
services:
  hytale:
    secrets:
      - hytale_downloader_credentials
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
      HYTALE_DOWNLOADER_CREDENTIALS_SRC: "/run/secrets/hytale_downloader_credentials"

secrets:
  hytale_downloader_credentials:
    file: ./secrets/.hytale-downloader-credentials.json
```
