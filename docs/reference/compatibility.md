# Hytale compatibility

The documented server options were checked against the actual 0.7.4 server's `--help`.
If either removed environment option is enabled, the image stops before Java starts
and explains its replacement. Ignoring broken mods is an explicit recovery choice,
not the same operation as skipping validation. Schema exports need an output path
writable by UID 1000; use a directory under `/data`.

### Native server environment variables

Docker passes these directly to Hytale; no `EXTRA_SERVER_ARGS` mapping is needed:

| Variable | Purpose |
| --- | --- |
| `HYTALE_AUTH_KEY_FILE` | File containing the passphrase for Hytale's encrypted credential store. Mount it read-only and keep the same secret across restarts. |
| `HYTALE_AUTH_KEY` | Inline alternative to the key file. Treat it as a secret; prefer the file option. |
| `HYTALE_DISABLE_UPDATES` | Disable Hytale's built-in updater. This is separate from this image's `HYTALE_AUTO_UPDATE`, which runs the downloader before startup. |

The key variables apply to Hytale's own encrypted credential store, not to the
broker's storage or the downloader credentials. Both are already separate flows.
When managing updates through the image/downloader, set `HYTALE_DISABLE_UPDATES=true`.
To use Hytale's own `/update download` and `/update apply --confirm` flow, set
`HYTALE_NATIVE_UPDATES=true` and `HYTALE_AUTO_UPDATE=false`; do not set
`HYTALE_DISABLE_UPDATES=true`. See [`upgrades.md`](../image/upgrades.md#in-game-server-updates).

The server also reads `HYTALE_SERVER_OFFLINE_TOKEN` and `HYTALE_SERVER_AUDIENCE`.
These are advanced authentication inputs, not replacements for the documented
broker session/identity token flow. No image default is assigned to either.

### Upcoming Update 8 changes (pre-release)

[Update 8 pre-release notes](https://hytale.com/news/2026/10/pre-release-patch-notes-update-8)
announce quiche as the dedicated server default. Existing `HYTALE_TRANSPORT=QUIC`
selects the Netty fallback; leaving it empty preserves the server's own default.
Linux ARM64 falls back when a quiche native library is unavailable. This has not
been tested against a pre-release server here; the current 0.7.4 test uses Netty.

The notes also describe `SentryDsn` in `config.json`; the actual 0.7.4 config
schema already exposes this field. Supply it through `HYTALE_CONFIG_PATCH_JSON`
(or its `_SRC` file option), without another image variable.
`HYTALE_DISABLE_SENTRY=true` still disables reporting. The notes describe a
world-event save migration to `universe/resources/GlobalWorldEvents.json`; preserve
the entire `/data` volume and make a backup before upgrading or rolling back.

The [Update 7 notes](https://hytale.com/news/2026/10/modder-facing-patch-notes-update-7)
add a guard against writing into the launcher installation directory. The image's
writable paths are under `/data`, so it does not need to bypass that guard with
`--allow-install-dir`. The new `--bootstrap` flow is not integrated: the image's
normal file checks and downloader remain the supported installation flow.
