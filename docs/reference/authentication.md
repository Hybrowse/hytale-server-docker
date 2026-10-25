# Authentication and broker

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_MACHINE_ID` | *(empty)* | 32-character hex string for the container's machine ID (hardware UUID workaround). Auto-generated and persisted if not set. |
| `HYTALE_AUTH_MODE` | `authenticated` | Authentication mode (`authenticated` or `offline`). |
| `HYTALE_AUTO_AUTH` | `true` | Start persistent device login on a fresh authenticated server. Existing credentials, broker tokens and non-game modes are skipped. |
| `HYTALE_SERVER_SESSION_TOKEN` | *(empty)* | Read by Hytale from the environment (**secret**). |
| `HYTALE_SERVER_IDENTITY_TOKEN` | *(empty)* | Read by Hytale from the environment (**secret**). |
| `HYTALE_SESSION_TOKEN_BROKER_ENABLED` | `false` | If `true`, fetches server session/identity tokens from the Session Token Broker before starting the server. |
| `HYTALE_SESSION_TOKEN_BROKER_URL` | *(empty)* | Base URL for the broker (e.g. `http://broker:8080`). |
| `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN` | *(empty)* | Optional HTTP bearer token for the broker API (**secret**). |
| `HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC` | *(empty)* | Optional path to a file containing the broker bearer token (Docker/Kubernetes secrets recommended). |
| `HYTALE_SESSION_TOKEN_BROKER_ACCOUNT` | *(empty)* | Optional broker account name for minting (sent as `account`). |
| `HYTALE_SESSION_TOKEN_BROKER_PROFILE_UUIDS` | *(empty)* | Optional pool of profile UUIDs (comma/space-separated) for fallback (sent as `profile_uuids`). |
| `HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS` | `10` | Request timeout for the broker HTTP call. |
| `HYTALE_SESSION_TOKEN_BROKER_FAIL_ON_ERROR` | `true` | If `true`, fails container startup when the broker request fails. If `false`, continues without broker tokens. |
| `HYTALE_SESSION_TOKEN_BROKER_MIN_RETRY_INTERVAL_SECONDS` | *(empty)* | If set: minimum time between successful broker token fetches. Prevents token minting spam on restart loops by waiting before minting again. |
| `HYTALE_AUTH_KEY_FILE` | *(unset; read by Hytale)* | File containing the passphrase for Hytale's encrypted credential store. Mount it read-only and keep the same secret across restarts. |
| `HYTALE_AUTH_KEY` | *(unset; read by Hytale)* | Inline alternative to the key file. Treat it as a secret; prefer the file option. |
