# Authentication

The downloader login, server login and optional broker have different jobs.

| Login | Purpose | Stored state |
| --- | --- | --- |
| Downloader | Obtain server files and assets | `/data/.hytale-downloader-credentials.json` |
| Server | Authenticate the running server for player connections | `/data/server/auth.enc`, configuration, identity/key |
| Broker (optional) | Supply short-lived server tokens for automated deployments | Long-lived state stays with the broker |

Completing the downloader login does not authenticate the running server.

## Sign in to the server

In `HYTALE_AUTH_MODE=authenticated` mode, the server must be authenticated after startup before players can connect.
This is separate from the downloader OAuth flow used for auto-download.

On a fresh server, `HYTALE_AUTO_AUTH=true` (default) queues Hytale's own
`/auth persistence Encrypted` and `/auth login device` commands. Follow the device
login link in the logs. If several profiles are offered, run
`hytale-cli auth select <name-or-number>` and check the result in the server logs.

Stored credentials and broker/supplied tokens bypass this first-start action.
Set `HYTALE_AUTO_AUTH=false` for manual login. Automatic login requires
`HYTALE_CONSOLE_PIPE=true`; validation, schema export, help and offline runs skip it.
`hytale-cli auth login` starts another persistent device login when needed.

See:

- [`quickstart.md`](quickstart.md)

Advanced (providers / fleets):

- [Broker integration](../stack/broker.md) (tokens via `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`)



## Preserve authentication across restarts

Keep the complete `/data` volume, including `.machine-id`, `server/auth.enc`, `server/config.json` and any `server/auth.key`. If you supply `HYTALE_AUTH_KEY_FILE`, keep that Secret too. Do not reset server credentials to fix an expired downloader login.

## Providers and fleets

See [broker integration](../stack/broker.md). Broker sessions do not authorize native game-update downloads.

## If login fails

Use [Doctor](diagnostics.md) for local checks and [troubleshooting](troubleshooting.md) for specific symptoms. `hytale-cli auth status` writes the live status to the server logs; it is separate from the read-only `hytale-cli status` alias.
