# Session Token Broker integration


If you run **the [Hytale Session Token Broker](https://github.com/Hybrowse/hytale-session-token-broker) by Hybrowse**, this image can fetch `session_token` and `identity_token` from it at container startup and pass them to the server process.

When both `HYTALE_SERVER_SESSION_TOKEN` and `HYTALE_SERVER_IDENTITY_TOKEN` are already set, the broker is skipped.

This is primarily intended for **providers / fleets / networks** that want non-interactive authentication without attaching to the server console.
The reference broker implementation by Hybrowse lives here: [Hytale Session Token Broker](https://github.com/Hybrowse/hytale-session-token-broker)

How credentials are used:

- The broker persists long-lived OAuth state (refresh token) and mints short-lived game session tokens on demand.
- This image only sees the short-lived `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN` at startup and passes them to the Java process through its environment, keeping them out of process arguments.

Security notes:

- Treat `HYTALE_SERVER_SESSION_TOKEN`, `HYTALE_SERVER_IDENTITY_TOKEN`, and `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN` as **secrets**.
- Prefer file-based secrets: set `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC` and mount it read-only.

Operational notes:

- If the container is in a crash/restart loop after the broker step (for example due to invalid config or broken plugins), you may mint tokens repeatedly.
  To reduce token minting in crash/restart loops, set `HYTALE_SESSION_TOKEN_BROKER_MIN_RETRY_INTERVAL_SECONDS`.
- If you run a large fleet, consider protecting the broker with an HTTP bearer token and applying startup jitter on your orchestration side to avoid many servers contacting the broker at once.

Minimal example (Docker Compose):

```yaml
services:
  hytale:
    environment:
      HYTALE_SESSION_TOKEN_BROKER_ENABLED: "true"
      HYTALE_SESSION_TOKEN_BROKER_URL: "http://broker:8080"
      HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS: "10"
```

With HTTP bearer token (recommended as file-based secret):

```yaml
services:
  hytale:
    secrets:
      - broker_bearer
    environment:
      HYTALE_SESSION_TOKEN_BROKER_ENABLED: "true"
      HYTALE_SESSION_TOKEN_BROKER_URL: "http://broker:8080"
      HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC: "/run/secrets/broker_bearer"

secrets:
  broker_bearer:
    file: ./secrets/broker_bearer_token
```

## What the broker does not replace

The game-server image still needs its JAR and assets before requesting broker tokens. Keep downloader credentials separate. The Compose snippets above assume that a broker is already running and reachable as `broker`; they do not deploy or authenticate one.

Follow the [broker setup guide](https://github.com/Hybrowse/hytale-session-token-broker#readme) to deploy it and preserve its own data directory. Do not expose its API publicly without access controls. For native updates, use a direct server OAuth login or keep the startup downloader update model. See [updates](../image/upgrades.md).
