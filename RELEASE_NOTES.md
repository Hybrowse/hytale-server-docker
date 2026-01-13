# Release Notes

## v0.1

### Overview

This is the first production-grade release of the **Hytale dedicated server Docker image**.

- Image (Docker Hub): `hybrowse/hytale-server`
- Mirror (GHCR): `ghcr.io/hybrowse/hytale-server`

### Highlights

- Runs as **non-root** by default.
- Clear startup validation and actionable error messages.
- Optional **auto-download** of official server files and `Assets.zip` via the official Hytale Downloader.
- Optional **auto-update** mode (runs the downloader on container start when enabled).
- Credentials and tokens are treated as **secrets**.

### Configuration defaults (important)

- Java runtime: **Eclipse Temurin 25 JRE**.
- `HYTALE_AUTH_MODE=authenticated` by default.
- Auto-download is **off by default**; enable explicitly with `HYTALE_AUTO_DOWNLOAD=true`.
- When `HYTALE_AUTO_DOWNLOAD=true`, auto-update is **on by default** (`HYTALE_AUTO_UPDATE=true`).
- AOT cache usage defaults to **best effort** (`ENABLE_AOT=auto`). A cache is used only when present and compatible.

### AOT (what it is)

This image can optionally use the JVM's Ahead-of-Time (AOT) cache mechanism to speed up startup.

- `ENABLE_AOT=auto` (default): if an AOT cache file exists and is compatible, it will be used; otherwise the JVM should ignore it and continue.
- `ENABLE_AOT=true`: strict diagnostics; startup fails if the cache is missing or incompatible.
- `ENABLE_AOT=false`: disable AOT.

### Authentication (operators)

There are two different authentication flows you may encounter:

#### 1) Downloader authentication (first start)

If you enable `HYTALE_AUTO_DOWNLOAD=true`, the official Hytale Downloader will print an authorization URL + device code in the container logs on first run.
Open that URL and complete the device-code flow once. Credentials are then stored on the `/data` volume.

#### 2) Server authentication (required for player connections)

In authenticated mode, the running server must obtain server session tokens before it can complete the authenticated handshake with clients.

Attach to the server console:

```bash
docker compose attach hytale
```

Then run:

```text
/auth login device
```

If multiple profiles are listed:

```text
/auth select <number>
```

For provider-grade automation, see `docs/hytale/server-provider-auth.md` (tokens via `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`).

### Known limitations

- Auto-download is currently supported on `linux/amd64` only (validated in CI). As of this release, the official downloader archive does not include a `linux/arm64` binary.
- AOT cache files are architecture-specific (`linux/amd64` vs `linux/arm64`) and must match the JVM build. In `ENABLE_AOT=auto` mode the JVM should ignore incompatible caches and continue; use `ENABLE_AOT=true` for strict diagnostics.

### Disclaimers

- This is an early release of the image. While core paths are tested, not every server CLI flag / environment variable combination has been validated yet.
- Expect frequent updates over the next days as both the upstream Hytale server and this Docker image evolve and real-world usage uncovers edge cases.
  Consider watching the repository for updates and/or join our Discord for update notifications: https://hybrowse.gg/discord
- Hytale (the game and server software) is Early Access. While we aim to keep this image production-grade, we cannot guarantee the server software (or this container) will be free of bugs.
  In the worst case, bugs may lead to data loss. Regular backups are strongly recommended (and should be treated as mandatory for production).

### Security notes

- Do not commit or publish any proprietary Hytale server binaries/assets.
- Treat these as secrets:
  - `/data/.hytale-downloader-credentials.json`
  - `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`

### Upgrade notes

- Keep `Assets.zip` and server files in sync when updating.
- Docker does not automatically pull newer images for `:latest`. Use:

```bash
docker compose pull
docker compose up -d
```

### Docs

- `docs/image/quickstart.md`
- `docs/image/troubleshooting.md`
- `docs/image/configuration.md`
- `docs/image/server-files.md`
- `docs/image/backups.md`
