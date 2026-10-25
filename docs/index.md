# Hytale Server on Docker

Run a Hytale dedicated server with automatic downloads, persistent login, mod management and tools for diagnosing problems. Start with one Docker Compose service; add Kubernetes, a token broker or a referral router when you need them.

## Start here

| I want to... | Go to |
| --- | --- |
| Start my first server | [Docker Compose quickstart](image/quickstart.md) |
| Deploy to Kubernetes | [Helm and Kustomize](image/kubernetes.md) |
| Change a setting | [Configuration](image/configuration.md) or [environment variables](reference/environment.md) |
| Install mods | [CurseForge mods](image/curseforge-mods.md) |
| Find out why something is failing | [Doctor](image/diagnostics.md) and [troubleshooting](image/troubleshooting.md) |
| Run several servers | [Hybrowse server stack](stack/index.md) |

## Before you start

- The image supports AMD64 and ARM64. Java runs natively on both. On ARM64, only the official downloader uses the bundled emulator.
- Hytale uses UDP. Publish `5520/udp` and allow the chosen port through your firewall.
- Persist the complete `/data` volume to keep worlds, mods, configuration and login state.
- First startup has **two separate authorizations**: one to download the files and one to authenticate the running server. Both prompts appear in the logs.

## Images and documentation versions

Use `hybrowse/hytale-server` from [Docker Hub](https://hub.docker.com/r/hybrowse/hytale-server) or its [GHCR mirror](https://github.com/Hybrowse/hytale-server-docker/pkgs/container/hytale-server). Pin a published image tag for deployments you want to reproduce.

These docs follow the repository's `main` branch. For changes in a specific image version, see the [release notes](https://github.com/Hybrowse/hytale-server-docker/releases).

## Get help

Use [troubleshooting](image/troubleshooting.md) first. For support, include your image version, deployment method and an allowlisted [diagnostic report](image/diagnostics.md#sharing-a-report) when available. Review anything you share publicly and keep login credentials private.

Ask in [Discord](https://hybrowse.gg/discord) or open a [GitHub issue](https://github.com/Hybrowse/hytale-server-docker/issues). For Hytale's own server behavior, refer to the [official server manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual).

This is an unofficial community project. The image does not contain proprietary game files. See the repository's [license and policy notes](https://github.com/Hybrowse/hytale-server-docker#legal-and-policy-notes).
