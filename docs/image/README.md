# Docker Image Documentation

This section documents the Docker image:

- `hybrowse/hytale-server` (Docker Hub, primary)
- `ghcr.io/hybrowse/hytale-server` (GHCR mirror)

## Goals

- **Production-grade defaults** (security, stability, predictable behavior)
- **Great UX** (simple configuration, clear errors)
- **Fast operation** (support for AOT cache, sensible JVM tuning)

## Important note about server files

This project is intended to help *run* the official Hytale dedicated server in containers.
It should **not** be used to redistribute proprietary server binaries.

For legal/policy notes (unofficial status, no redistribution, and operator responsibilities), see the repository [`README.md`](../../README.md).

## Pages

- Start here: [`quickstart.md`](quickstart.md)
- Then: [`configuration.md`](configuration.md)
- Kubernetes: [`kubernetes.md`](kubernetes.md)
- Mods (CurseForge): [`curseforge-mods.md`](curseforge-mods.md)
- Common issues: [`troubleshooting.md`](troubleshooting.md)
- Ops: [`backups.md`](backups.md)
- Manual provisioning: [`server-files.md`](server-files.md)
- Development: [`development.md`](development.md)
- Upgrades: [`upgrades.md`](upgrades.md)
- Security hardening: [`security.md`](security.md)

## Advanced reference

The `docs/hytale/` section contains notes from the official documentation.
It is useful for advanced operators and providers, but the primary end-user docs for this image live in `docs/image/`.
