# Configuration

## Java runtime

The official Hytale server requires Java 25.
This image uses **Adoptium / Eclipse Temurin 25** (`eclipse-temurin:25-jre`).

## Auto-download (recommended)

If `HYTALE_AUTO_DOWNLOAD=true` and `Assets.zip` / `HytaleServer.jar` are missing, the container will:

- download the official Hytale Downloader from `https://downloader.hytale.com/`
- run it using the OAuth device-code flow
- store downloader credentials on the `/data` volume
- extract `Assets.zip` to `/data/Assets.zip`
- extract `Server/` contents to `/data/server/`

When `HYTALE_AUTO_DOWNLOAD=true`, the container will check for updates on each start by comparing the remote version against the locally stored version (in `.hytale-version`).
Downloads only happen when an update is available. Set `HYTALE_AUTO_UPDATE=false` to disable update checks entirely and only download when files are missing.

Credentials are stored as:

- `/data/.hytale-downloader-credentials.json`

If that file already exists (for example from a previous run), downloads become non-interactive.

If you want fully non-interactive automation, see: [Non-interactive auto-download (seed credentials)](#non-interactive-auto-download-seed-credentials)

For safety, `HYTALE_DOWNLOADER_URL` is restricted to `https://downloader.hytale.com/`.

Current limitation:

- Auto-download is supported on `linux/amd64` only, because the official downloader archive currently does not include a `linux/arm64` binary.
- On `linux/arm64`, you must provide the server files and `Assets.zip` manually.

On arm64 hosts (for example Apple Silicon), you can also run the container as `linux/amd64` (Compose: `platform: linux/amd64`).

## Server authentication (required for player connections)

In `HYTALE_AUTH_MODE=authenticated` mode, the server must be authenticated **after startup** before players can connect.
This is separate from the downloader OAuth flow used for auto-download.

See:

- [`quickstart.md`](quickstart.md)

Advanced (providers / fleets):

- [`../hytale/server-provider-auth.md`](../hytale/server-provider-auth.md) (tokens via `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`)

## Environment variables

| Variable | Default | Description |
|---|---:|---|
| `HYTALE_SERVER_JAR` | `/data/server/HytaleServer.jar` | Path to `HytaleServer.jar` inside the container. |
| `HYTALE_ASSETS_PATH` | `/data/Assets.zip` | Path to `Assets.zip` inside the container. |
| `HYTALE_AOT_PATH` | `/data/server/HytaleServer.aot` | Path to the AOT cache file. |
| `HYTALE_BIND` | `0.0.0.0:5520` | Bind address for QUIC/UDP. |
| `HYTALE_AUTH_MODE` | `authenticated` | Authentication mode (`authenticated` or `offline`). |
| `HYTALE_DISABLE_SENTRY` | `false` | If `true`, passes `--disable-sentry`. |
| `HYTALE_ACCEPT_EARLY_PLUGINS` | `false` | If `true`, passes `--accept-early-plugins` (acknowledges unsupported early plugins). |
| `HYTALE_ENABLE_BACKUP` | `false` | If `true`, passes `--backup`. |
| `HYTALE_BACKUP_DIR` | *(empty)* | Passed as `--backup-dir`. |
| `HYTALE_BACKUP_FREQUENCY_MINUTES` | `30` | Passed as `--backup-frequency`. |
| `HYTALE_BACKUP_MAX_COUNT` | `5` | Passed as `--backup-max-count`. |
| `HYTALE_SERVER_SESSION_TOKEN` | *(empty)* | Passed as `--session-token` (**secret**). |
| `HYTALE_SERVER_IDENTITY_TOKEN` | *(empty)* | Passed as `--identity-token` (**secret**). |
| `HYTALE_AUTO_DOWNLOAD` | `false` | If `true`, downloads server files and `Assets.zip` via the official Hytale Downloader when missing. |
| `HYTALE_AUTO_UPDATE` | `true` | If `true`, checks for updates on each start (compares remote version vs local). Only downloads when an update is available. |
| `HYTALE_VERSION_FILE` | `/data/.hytale-version` | File where the installed server version is stored (used for update checks). |
| `HYTALE_DOWNLOADER_URL` | `https://downloader.hytale.com/hytale-downloader.zip` | Official downloader URL (must start with `https://downloader.hytale.com/`). |
| `HYTALE_DOWNLOADER_DIR` | `/data/.hytale-downloader` | Directory where the image stores the downloader binary. |
| `HYTALE_DOWNLOADER_PATCHLINE` | *(empty)* | Optional downloader patchline (e.g. `pre-release`). |
| `HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK` | `false` | If `true`, passes `-skip-update-check` to reduce network/variability during automation. |
| `HYTALE_DOWNLOADER_CREDENTIALS_SRC` | *(empty)* | Optional path to a mounted credentials file to seed `/data/.hytale-downloader-credentials.json`. |
| `HYTALE_GAME_ZIP_PATH` | `/data/game.zip` | Where the downloader stores the downloaded game package zip. |
| `HYTALE_KEEP_GAME_ZIP` | `false` | If `true`, keep the downloaded game zip after extraction. |
| `HYTALE_DOWNLOAD_LOCK` | `true` | If `false`, disables the download lock (power users). Keeping the lock enabled prevents concurrent downloads into the same `/data` volume. |
| `JVM_XMS` | *(empty)* | Passed as `-Xms...` (initial heap). |
| `JVM_XMX` | *(empty)* | Passed as `-Xmx...` (max heap). |
| `JVM_EXTRA_ARGS` | *(empty)* | Extra JVM args appended to the `java` command. |
| `ENABLE_AOT` | `auto` | `auto\|true\|false\|generate` (controls `-XX:AOTCache=...`). |
| `EXTRA_SERVER_ARGS` | *(empty)* | Extra server args appended at the end. |
| `HYTALE_ALLOW_OP` | `true` | If `true`, enables the `/op` command. |
| `HYTALE_BARE` | `false` | If `true`, passes `--bare`. |
| `HYTALE_BOOT_COMMAND` | *(empty)* | Passed as `--boot-command`. |
| `HYTALE_DISABLE_ASSET_COMPARE` | `false` | If `true`, passes `--disable-asset-compare`. |
| `HYTALE_DISABLE_CPB_BUILD` | `false` | If `true`, passes `--disable-cpb-build`. |
| `HYTALE_DISABLE_FILE_WATCHER` | `false` | If `true`, passes `--disable-file-watcher`. |
| `HYTALE_EARLY_PLUGINS_PATH` | *(empty)* | Passed as `--early-plugins`. |
| `HYTALE_EVENT_DEBUG` | `false` | If `true`, passes `--event-debug`. |
| `HYTALE_FORCE_NETWORK_FLUSH` | `true` | If `true`, passes `--force-network-flush`. |
| `HYTALE_GENERATE_SCHEMA` | `false` | If `true`, passes `--generate-schema`. |
| `HYTALE_LOG` | *(empty)* | Passed as `--log`. |
| `HYTALE_MODS_PATH` | *(empty)* | Passed as `--mods`. |
| `HYTALE_OWNER_NAME` | *(empty)* | Passed as `--owner-name`. |
| `HYTALE_OWNER_UUID` | *(empty)* | Passed as `--owner-uuid`. |
| `HYTALE_PREFAB_CACHE_PATH` | *(empty)* | Passed as `--prefab-cache`. |
| `HYTALE_SHUTDOWN_AFTER_VALIDATE` | `false` | If `true`, passes `--shutdown-after-validate`. |
| `HYTALE_SINGLEPLAYER` | `false` | If `true`, passes `--singleplayer`. |
| `HYTALE_TRANSPORT` | *(empty)* | Passed as `--transport`. |
| `HYTALE_UNIVERSE_PATH` | *(empty)* | Passed as `--universe`. |
| `HYTALE_VALIDATE_ASSETS` | `false` | If `true`, passes `--validate-assets`. |
| `HYTALE_VALIDATE_PREFABS` | *(empty)* | If set to `true`, passes `--validate-prefabs`. Otherwise passes `--validate-prefabs <value>`. |
| `HYTALE_VALIDATE_WORLD_GEN` | `false` | If `true`, passes `--validate-world-gen`. |
| `HYTALE_WORLD_GEN_PATH` | *(empty)* | Passed as `--world-gen`. |

## Examples

### Change bind address / port

```yaml
services:
  hytale:
    environment:
      HYTALE_BIND: "0.0.0.0:5520"
```

### Disable Sentry

The official documentation recommends disabling Sentry during active plugin development so that your errors are not reported to the Hytale team.

```yaml
services:
  hytale:
    environment:
      HYTALE_DISABLE_SENTRY: "true"
```

### Accept early plugins (unsupported)

If you want to acknowledge that loading early plugins is unsupported and may cause stability issues:

```yaml
services:
  hytale:
    environment:
      HYTALE_ACCEPT_EARLY_PLUGINS: "true"
```

### JVM heap tuning

If `JVM_XMS` / `JVM_XMX` are not set, the JVM will pick defaults (based on available container memory).
This is usually fine for testing, but for predictable production operation you should set at least `JVM_XMX` to an explicit limit.
There are no universal best-practice values; monitor RAM/CPU usage for your player count and playstyle and experiment with different values.
If you see high CPU usage from garbage collection, that can be a symptom of memory pressure and an `JVM_XMX` value that is too low.
In that case, try increasing `JVM_XMX` (or reducing view distance / workload) and compare behavior.

You can optionally set `JVM_XMS` as well. Keeping `JVM_XMS` lower than `JVM_XMX` allows the heap to grow as needed.
Setting `JVM_XMS` equal to `JVM_XMX` can reduce heap resizing overhead but increases baseline memory usage.

```yaml
services:
  hytale:
    environment:
      JVM_XMS: "2G"
      JVM_XMX: "6G"
```

### AOT cache

Hytale ships with a pre-trained AOT cache (`HytaleServer.aot`), but AOT caches require a compatible Java runtime.
If you see AOT cache errors during startup, generate a cache that matches the Java version/build inside the container.

AOT caches are also architecture-specific (e.g. `linux/amd64` vs `linux/arm64`).
If you switch the container platform (or move the `/data` volume between machines), delete and regenerate the cache.
If the cache is incompatible (for example shipped for a different architecture), `ENABLE_AOT=auto` should ignore it and continue startup.
For strict diagnostics, use `ENABLE_AOT=true` (fails fast). For normal operation, prefer `ENABLE_AOT=auto`.

- `ENABLE_AOT=auto` (default): enables AOT only when the cache file exists.
- `ENABLE_AOT=true`: requires the cache file to exist and fails fast otherwise.
- `ENABLE_AOT=false`: do not use AOT.
- `ENABLE_AOT=generate`: generates an AOT cache at `HYTALE_AOT_PATH`, then exits.

If you see Java warnings about restricted native access (e.g. Netty), you can set:

- `JVM_EXTRA_ARGS=--enable-native-access=ALL-UNNAMED`

If you see a stacktrace about failing to read a hardware UUID during Sentry init, you can set:

- `HYTALE_DISABLE_SENTRY=true`

### Non-interactive auto-download (seed credentials)

If you already have `.hytale-downloader-credentials.json`, you can mount it read-only and seed it:

```yaml
services:
  hytale:
    secrets:
      - hytale_downloader_credentials
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
      HYTALE_DOWNLOADER_CREDENTIALS_SRC: "/run/secrets/hytale_downloader_credentials"

secrets:
  hytale_downloader_credentials:
    file: ./secrets/.hytale-downloader-credentials.json
```

## Related docs

- [`server-files.md`](server-files.md)
- [`backups.md`](backups.md)
