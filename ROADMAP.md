# Roadmap
 
This roadmap focuses on delivering a **secure, fast, and easy-to-operate** Docker image for the official Hytale dedicated server.
 
## Guiding principles
 
- **Security**: least-privilege defaults, safe handling of credentials/tokens, no accidental binary redistribution
- **Performance**: sane JVM defaults, optional AOT cache usage, practical tuning guidance
- **Speed**: quick startup, repeatable upgrades, minimal friction
- **UX**: simple configuration, clear docs, helpful error messages
 
## Current capabilities (single-server)
 
- Run the Hytale server from a persistent data volume (e.g. `./data:/data`)
- Clear validation & error messages when server files / `Assets.zip` are missing
- Optional opt-in runtime download & extraction of server files and `Assets.zip` via the official Hytale Downloader CLI (where supported)
- Networking defaults:
  - UDP/QUIC on `5520/udp`
  - configurable bind address/port
- Environment-variable configuration mapping to common server flags:
  - assets path
  - auth mode (authenticated/offline)
  - disable Sentry flag
  - accept early plugins acknowledgement flag
  - backup flags (enable/dir/frequency)
  - JVM heap (Xms/Xmx) + extra JVM args
  - extra server args passthrough
- Run as **non-root** by default
- Documentation:
  - Compose quickstart
  - firewall/port-forwarding notes (UDP)
 
## Next (operator UX & reliability)

- Config file interpolation via environment variables (e.g. `CFG_*`), to generate/update config files at startup
- Troubleshooting commands and diagnostics output (versions, config paths, bind info)
- Configurable UID/GID for file permission alignment
- Graceful shutdown behavior with documented stop/grace period
- Basic healthcheck (process-level) with a documented way to disable it
- Better developer workflow and contributor ergonomics

## Later (hardening, observability & operational guidance)

- Hardening guidance (read-only root filesystem, capability dropping, seccomp/profile recommendations)
- Metrics integration guide (Prometheus exporter plugin usage)
- Operational recommendations:
  - log management/retention
  - capacity planning notes (view distance, heap sizing)
 
## Future ideas (TBD)

- Provider-grade features (hosting / fleets)
- Kubernetes Helm chart
- Optional mod/plugin installation automation (e.g. via CurseForge API)
