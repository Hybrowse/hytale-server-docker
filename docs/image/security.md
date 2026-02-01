# Security

This document describes security hardening recommendations for running the `hybrowse/hytale-server` image.

## Guiding principles

- Run as **non-root** (this image uses UID `1000` by default).
- Treat authentication material as **secrets**.
- Prefer **least-privilege** runtime settings.
- Avoid changes that accidentally redistribute proprietary server assets.

For legal/policy notes (unofficial status, no redistribution, and operator responsibilities), see the repository [`README.md`](../../README.md).

## Secrets

Treat these as secrets and avoid placing them in plain text config repositories:

- `/data/.hytale-downloader-credentials.json`
- `HYTALE_SERVER_SESSION_TOKEN`
- `HYTALE_SERVER_IDENTITY_TOKEN`
- `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN`
- CurseForge API key (`HYTALE_CURSEFORGE_API_KEY`)

Recommendations:

- Prefer file-based secrets when possible (for example `*_SRC` style variables).
- In Docker Compose, use `secrets:` and mount them read-only.
- In Kubernetes, use `Secret` objects and mount them as files.

## Docker / Docker Compose hardening

### Recommended baseline

- Keep the container running as the default non-root user.
- Avoid `--privileged`.
- Do not add extra Linux capabilities unless you have a specific need.

### Read-only root filesystem (optional)

`read_only` / `readOnlyRootFilesystem` can cause issues with the official server's hardware UUID detection.
In particular, if the container cannot write `/etc/machine-id`, the server may fail with `Failed to get Hardware UUID`.

For this reason, a read-only root filesystem is **not recommended by default**.
If you still enable it, ensure you have a working machine-id strategy and writable mounts:

- Provide a writable `/tmp` (tmpfs) for temporary files.
- Ensure `/data` is writable (this image persists a stable machine-id under `/data`).

Example (Compose):

```yaml
services:
  hytale:
    read_only: true
    tmpfs:
      - /tmp
    volumes:
      - ./data:/data
```

### Drop privileges and prevent escalation

Example (Compose):

```yaml
services:
  hytale:
    security_opt:
      - no-new-privileges:true
```

If your runtime supports it, also consider:

- `cap_drop: ["ALL"]`

## Kubernetes hardening

### Pod security

Recommended settings:

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: ["ALL"]`

### Read-only root filesystem (optional)

`readOnlyRootFilesystem: true` is **not recommended by default** due to the machine-id / hardware UUID behavior described above.
If you enable it, you should typically also provide an `emptyDir` mount for `/tmp` and ensure `/data` remains writable.

### NetworkPolicy

If you deploy into a cluster with NetworkPolicies enforced, restrict:

- **Ingress** to UDP `5520`
- **Egress** to what you need

Notes:

- If you use `HYTALE_AUTO_DOWNLOAD=true`, the container must be able to reach the official Hytale downloader endpoints.
- If you use CurseForge mods, the container must be able to reach the CurseForge API and download endpoints.

### Resource limits

Set CPU/memory requests and limits to reduce noisy-neighbor effects and to make restarts/evictions more predictable.

### Termination behavior

The server is expected to stop cleanly on `SIGTERM`.
For recommended grace periods, see [`upgrades.md`](upgrades.md).
