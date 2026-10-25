[![Discord](https://img.shields.io/discord/1459154799407665397?label=Join%20Discord)](https://hybrowse.gg/discord)
[![Docker Pulls](https://img.shields.io/docker/pulls/hybrowse/hytale-server)](https://hub.docker.com/r/hybrowse/hytale-server)

# Hytale Server Docker Image
 
**🐳 Production-ready Docker image for dedicated Hytale servers.**

Automatic CurseForge mod management, auto-download with smart update detection, Helm chart, CLI, easy configuration, and quick troubleshooting.

## Hybrowse Server Stack
 
This image is part of the **Hybrowse Server Stack** — production-grade building blocks for running Hytale at scale:
 
- **Non-interactive server authentication** via [Hybrowse/hytale-session-token-broker](https://github.com/Hybrowse/hytale-session-token-broker) (mints short-lived `session_token` / `identity_token` at startup to skip the interactive `/auth` flow)
- **Stateless QUIC entrypoint + referral routing** via [Hybrowse/hyrouter](https://github.com/Hybrowse/hyrouter)

Brought to you by [Hybrowse](https://github.com/Hybrowse) and the developer of [setupmc.com](https://setupmc.com).

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
> 2. **Server auth** (first startup): follow the second URL + device code in the logs. The image starts Hytale's device login and encrypted credential storage automatically.
>
> If your account has several profiles, choose one from the log with `docker compose exec hytale hytale-cli auth select <name-or-number>`. The login and profile are reused on later starts. Set `HYTALE_AUTO_AUTH=false` to manage login yourself.
>
> Optional (advanced / providers): if you run **the [Hytale Session Token Broker](https://github.com/Hybrowse/hytale-session-token-broker) by Hybrowse**, you can fetch session/identity tokens at container startup and skip the interactive `/auth` flow. See: [`docs/image/configuration.md`](docs/image/configuration.md)

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
- [`docs/image/kubernetes.md`](docs/image/kubernetes.md) — Helm chart, Kustomize overlays, and Kubernetes deployment notes
- [`docs/image/curseforge-mods.md`](docs/image/curseforge-mods.md) — automatic CurseForge mod download and updates
- [`docs/image/diagnostics.md`](docs/image/diagnostics.md) — read-only checks and support reports
- [`docs/image/troubleshooting.md`](docs/image/troubleshooting.md) — common issues
- [`docs/image/backups.md`](docs/image/backups.md) — backup configuration
- [`docs/image/server-files.md`](docs/image/server-files.md) — manual provisioning of server files
- [`docs/image/upgrades.md`](docs/image/upgrades.md) — upgrade guidance
- [`docs/image/security.md`](docs/image/security.md) — security hardening

## Why this image

- **Security-first defaults** (least privilege; credentials/tokens treated as secrets)
- **Operator UX** (clear startup validation and actionable errors)
- **Performance-aware** (sane JVM defaults; optional AOT cache usage)
- **Predictable operations** (documented data layout and upgrade guidance)

## Java

Hytale requires **Java 25**.
This image uses **Adoptium / Eclipse Temurin 25**.
 
## Documentation
 
- [`docs/image/`](docs/image/): Image usage & configuration
- [`docs/hytale/`](docs/hytale/): internal notes (not end-user image docs)
 
## Contributing & Security
 
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`LICENSING.md`](LICENSING.md)
- [`SECURITY.md`](SECURITY.md)

## Local verification

You can build and run basic container-level validation tests locally:

```bash
task verify
```

Install Task:

- https://taskfile.dev/
 
## Legal and policy notes

This is an **unofficial** community project and is not affiliated with or endorsed by Hypixel Studios Canada Inc.

This repository and image do not redistribute proprietary Hytale game/server files.
Server operators are responsible for complying with the Hytale EULA, Terms of Service, and Server Operator Policies (including monetization and branding rules): https://hytale.com/server-policies

## License
 
Current repository license (releases after v0.4.0): [`LICENSE`](LICENSE)

Non-binding summary (see [`LICENSE`](LICENSE) for the full, binding terms):
 
- Free production use is permitted for self-operated communities that are not a managed service, within the license’s free-use thresholds (currently: Peak CCU <= 250 and Peak Game Server Count <= 10).
- Managed-service/hosting usage requires a commercial agreement.

Apache-2.0 license text for releases v0.4.0 and older: [`LICENSE-APACHE-2.0`](LICENSE-APACHE-2.0)

See also: [`NOTICE`](NOTICE).

For an overview (including commercial agreements and trademarks), see:

- [`LICENSING.md`](LICENSING.md)
- [`COMMERCIAL_LICENSE.md`](COMMERCIAL_LICENSE.md)
- [`TRADEMARKS.md`](TRADEMARKS.md)
