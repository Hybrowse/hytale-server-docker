[![Discord](https://img.shields.io/discord/1459154799407665397?label=Join%20Discord)](https://hybrowse.gg/discord)
[![Docker Pulls](https://img.shields.io/docker/pulls/hybrowse/hytale-server)](https://hub.docker.com/r/hybrowse/hytale-server)

# Hytale Server Docker Image
 
**🐳 Production-ready Docker image for dedicated Hytale servers.**

Automatic CurseForge mod management, auto-download with smart update detection, easy configuration, built-in backup support, and quick troubleshooting.

Brought to you by [Hybrowse](https://hybrowse.gg) and the developer of [setupmc.com](https://setupmc.com).

## Image

- **Image (Docker Hub)**: [`hybrowse/hytale-server`](https://hub.docker.com/r/hybrowse/hytale-server)
- **Mirror (GHCR)**: [`ghcr.io/hybrowse/hytale-server`](https://ghcr.io/hybrowse/hytale-server)

## Community

Join the **Hybrowse Discord Server** to get help and stay up to date: https://hybrowse.gg/discord

## Quickstart

```yaml
services:
  hytale:
    image: hybrowse/hytale-server:latest
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
    ports:
      - "5520:5520/udp"
    volumes:
      - ./data:/data
    tty: true
    stdin_open: true
    restart: unless-stopped
```

```bash
docker compose up -d
```

> [!IMPORTANT]
> **Two authentication steps required:**
>
> 1. **Downloader auth** (first run): follow the URL + device code in the logs to download server files
> 2. **Server auth** (after startup): attach to the console (`docker compose attach hytale`), then run `/auth persistence Encrypted` followed by `/auth login device`

Full guide: [`docs/image/quickstart.md`](docs/image/quickstart.md)

Troubleshooting: [`docs/image/troubleshooting.md`](docs/image/troubleshooting.md)

Automation: you can send server console commands from scripts via `hytale-cli`:

```bash
docker exec hytale hytale-cli send "/say Server is running!"
```

See: [`docs/image/configuration.md`](docs/image/configuration.md#send-console-commands-hytale-cli)

## Documentation

- [`docs/image/quickstart.md`](docs/image/quickstart.md) — start here
- [`docs/image/configuration.md`](docs/image/configuration.md) — environment variables, JVM tuning
- [`docs/image/curseforge-mods.md`](docs/image/curseforge-mods.md) — automatic CurseForge mod download and updates
- [`docs/image/troubleshooting.md`](docs/image/troubleshooting.md) — common issues
- [`docs/image/backups.md`](docs/image/backups.md) — backup configuration
- [`docs/image/server-files.md`](docs/image/server-files.md) — manual provisioning (arm64, etc.)

## Why this image

- **Security-first defaults** (least privilege; credentials/tokens treated as secrets)
- **Operator UX** (clear startup validation and actionable errors)
- **Performance-aware** (sane JVM defaults; optional AOT cache usage)
- **Predictable operations** (documented data layout and upgrade guidance)

## Java

Hytale requires **Java 25**.
This image uses **Adoptium / Eclipse Temurin 25**.

## Planned features

See [`ROADMAP.md`](ROADMAP.md) for details. Highlights:

- **Planned next**: graceful shutdown guidance, basic healthcheck (with a way to disable), diagnostics helpers, observability guidance, provider-grade patterns
 
## Documentation
 
- [`docs/image/`](docs/image/): Image usage & configuration
- [`docs/hytale/`](docs/hytale/): internal notes (not end-user image docs)
 
## Contributing & Security
 
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)

## Local verification

You can build and run basic container-level validation tests locally:

```bash
task verify
```

Install Task:

- https://taskfile.dev/
 
## License
 
See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
