# Documentation

This repository maintains documentation in two layers:

- [`docs/image/README.md`](docs/image/README.md) — End-user documentation for the Docker image `hybrowse/hytale-server` (Docker Hub, primary) and `ghcr.io/hybrowse/hytale-server` (GHCR mirror) (usage, configuration, operations).
- [`docs/hytale/README.md`](docs/hytale/README.md) — Internal reference notes about the *Hytale dedicated server software* (derived from the official manual and related articles). Not intended as the primary end-user documentation for this Docker image.

## Hybrowse Server Stack

The Hytale Server Docker Image is part of the **Hybrowse Server Stack**:

- [Hybrowse/hytale-session-token-broker](https://github.com/Hybrowse/hytale-session-token-broker) — non-interactive server authentication for providers/fleets
- [Hybrowse/hyrouter](https://github.com/Hybrowse/hyrouter) — stateless QUIC entrypoint and referral router for routing players to backends

## Scope & sources

We aim to keep these docs practical and operations-focused.
For authoritative information, always refer to the official Hytale documentation:

- https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual

For legal/policy notes (unofficial status, no redistribution, and operator responsibilities), see the repository [`README.md`](../../README.md).
