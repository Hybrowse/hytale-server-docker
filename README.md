# Hytale Server Docker Image

Run the official Hytale dedicated server with automatic downloads, persistent authentication, CurseForge mod management and optional Kubernetes deployment assets. Supports AMD64 and ARM64, with native Java on both.

**[Documentation](https://hybrowse.github.io/hytale-server-docker/)** | [Quickstart](https://hybrowse.github.io/hytale-server-docker/image/quickstart/) | [Troubleshooting](https://hybrowse.github.io/hytale-server-docker/image/troubleshooting/) | [Releases](https://github.com/Hybrowse/hytale-server-docker/releases) | [Discord](https://hybrowse.gg/discord)

## Start a server

Save as `compose.yaml`:

```yaml
services:
  hytale:
    image: hybrowse/hytale-server:latest
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
    ports:
      - "5520:5520/udp"
    volumes:
      - hytale-data:/data
    stop_grace_period: 120s
    restart: unless-stopped

volumes:
  hytale-data:
```

```sh
docker compose up -d
docker compose logs -f hytale
```

Follow **two separate authorization prompts** in the logs: first the downloader, then the running server. If Hytale offers several profiles, select one with `docker compose exec hytale hytale-cli auth select <name-or-number>`. Keep the data volume to reuse the login on later starts.

Players connect to the host on UDP port 5520. See the [full quickstart](https://hybrowse.github.io/hytale-server-docker/image/quickstart/) for login checks, networking and safe restarts. Production deployments should pin a [published image tag](https://github.com/Hybrowse/hytale-server-docker/releases).

## Images and guides

- [Docker Hub](https://hub.docker.com/r/hybrowse/hytale-server): `hybrowse/hytale-server`
- [GHCR mirror](https://github.com/Hybrowse/hytale-server-docker/pkgs/container/hytale-server): `ghcr.io/hybrowse/hytale-server`
- [Configuration](https://hybrowse.github.io/hytale-server-docker/image/configuration/), [environment variables](https://hybrowse.github.io/hytale-server-docker/reference/environment/), [Kubernetes](https://hybrowse.github.io/hytale-server-docker/image/kubernetes/), [mods](https://hybrowse.github.io/hytale-server-docker/image/curseforge-mods/), [updates](https://hybrowse.github.io/hytale-server-docker/image/upgrades/), [Doctor](https://hybrowse.github.io/hytale-server-docker/image/diagnostics/)

## Optional server stack

Use the [Session Token Broker](https://github.com/Hybrowse/hytale-session-token-broker) for centrally managed server authentication and [Hyrouter](https://github.com/Hybrowse/hyrouter) for client referrals to backends. Neither is required for a single server. See the [stack guide](https://hybrowse.github.io/hytale-server-docker/stack/).

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
