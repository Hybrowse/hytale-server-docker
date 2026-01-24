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

In `HYTALE_AUTH_MODE=authenticated` mode, the server must be authenticated after startup before players can connect.
This is separate from the downloader OAuth flow used for auto-download.

To persist authentication across server restarts, run `/auth persistence Encrypted` before `/auth login device`.
Without this, you will need to re-authenticate after every container restart.

See:

- [`quickstart.md`](quickstart.md)

Advanced (providers / fleets):

- [`../hytale/server-provider-auth.md`](../hytale/server-provider-auth.md) (tokens via `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN`)

## Mods

This image supports **automatic mod download and updates from CurseForge**.

See: [`curseforge-mods.md`](curseforge-mods.md)

## Pre-start downloads (universe / mods)

On startup, this image can optionally download additional content into the server data directories **before** starting the Java process.

Supported targets:

- `universe/` (world + player save data)
- `mods/`

The download list is a space/comma/newline-separated list of `http://` / `https://` URLs.
Each list item can also be a reference to a file by prefixing it with `@`.
The file is read line-by-line; empty lines and `# comments` are ignored.

Each URL is downloaded at most once per `/data` volume by default (a marker file is stored under `/data/.hytale-prestart-downloads/`).
To re-download, use the `*_FORCE=true` option.

Downloaded files:

- If the downloaded payload is a ZIP archive, it is extracted into the destination directory.
- Otherwise the payload is saved as a file in the destination directory.

Optional throttling:

- `*_LIMIT_RATE` maps to `curl --limit-rate` (for example `500k`, `2m`).

Security notes:

- The image does not log URL query strings and redacts URL userinfo (for example `https://user:pass@...`).
- Only `http(s)` is supported.

### Example (download a universe and mods)

```yaml
services:
  hytale:
    environment:
      HYTALE_UNIVERSE_DOWNLOAD_URLS: "https://example.com/my-universe.zip"
      HYTALE_UNIVERSE_DOWNLOAD_LIMIT_RATE: "5m"

      HYTALE_MODS_DOWNLOAD_URLS: "@/data/mods-urls.txt"
      HYTALE_MODS_DOWNLOAD_LIMIT_RATE: "2m"
```

Multiline example:

```yaml
services:
  hytale:
    environment:
      HYTALE_UNIVERSE_DOWNLOAD_URLS: |
        https://example.com/a.zip
        https://example.com/b.zip
      HYTALE_MODS_DOWNLOAD_URLS: |
        https://example.com/mod1.zip, https://example.com/mod2.zip
        https://example.com/mod3.zip
```

## Config file interpolation (CFG_*)

On startup, this image can replace placeholders in JSON config files using environment variables.

Processed files:

- `/data/server/config.json`
- all `*.json` files under `/data/server/mods/`
- all `*.json` files under `HYTALE_MODS_PATH` (if set)

Interpolation runs **after** CurseForge mod installation (if enabled) and **before** the server process is started.

### Placeholders

The entrypoint searches JSON string values for references to variables prefixed with `CFG_`.
You can use:

- `${CFG_FOO}`
- `$CFG_FOO`

### Typing rules (important)

There are two modes:

- If a JSON string value is **exactly** a placeholder, for example:

  - `"${CFG_MAX_PLAYERS}"`

  then the value is replaced with a **typed JSON value** when possible.
  The environment variable is interpreted as JSON via `jq fromjson`.
  Examples:

  - `CFG_MAX_PLAYERS=20` becomes `20`
  - `CFG_PUBLIC=true` becomes `true`
  - `CFG_NAME='"My Server"'` becomes `"My Server"`
  - `CFG_OBJ='{"a":1}'` becomes `{ "a": 1 }`

  If parsing as JSON fails, the value is used as a normal string.

- If the placeholder appears **inside a larger string**, for example:

  - `"Welcome to ${CFG_SERVER_NAME}!"`

  then the variable value is substituted as plain text.

### Enable/disable

- Enabled by default.
- To disable interpolation entirely, set:

  - `HYTALE_CFG_INTERPOLATION=false`

### Scope / performance / safety controls

To reduce startup time and avoid applying interpolation to plugin-generated data files, you can scope interpolation.

Modes:

- `HYTALE_CFG_INTERPOLATION_MODE=server-only` (default)

  - Only interpolates `/data/server/config.json`

- `HYTALE_CFG_INTERPOLATION_MODE=all`

  - Always interpolates `/data/server/config.json`
  - Also interpolates JSON files under `/data/server/mods/` and `HYTALE_MODS_PATH`

- `HYTALE_CFG_INTERPOLATION_MODE=explicit`

  - Always interpolates `/data/server/config.json`
  - Additionally interpolates only the paths listed in `HYTALE_CFG_INTERPOLATION_PATHS`

`HYTALE_CFG_INTERPOLATION_PATHS` accepts space-separated paths. Each entry can be:

- a file (relative to `/data/server/` or an absolute path)
- a directory (all `*.json` files beneath it will be processed)

Optional limits:

- `HYTALE_CFG_INTERPOLATION_MAX_BYTES` (empty by default)

  - If set to a number, skips JSON files larger than this size.

- `HYTALE_CFG_INTERPOLATION_EXCLUDE_PATHS` (empty by default)

  - Space-separated shell glob patterns matched against the full file path.
  - If a file matches, it is skipped.

Security note:

- `CFG_*` can be used for secrets if plugins only support secrets via config files.
- To reduce risk of accidental substitution into large/untrusted plugin-generated files (or files that might be exposed to players), prefer `server-only` or `explicit`.

### Example

```yaml
services:
  hytale:
    environment:
      CFG_SERVER_NAME: "My Server"
      CFG_MAX_PLAYERS: "20"
```

In JSON:

```json
{
  "name": "${CFG_SERVER_NAME}",
  "maxPlayers": "${CFG_MAX_PLAYERS}"
}
```

## Environment variables

| Variable | Default | Description |
|---|---:|---|
| `HYTALE_CFG_INTERPOLATION` | `true` | If `false`, disables `CFG_*` placeholder interpolation in JSON config files at startup. |
| `HYTALE_CFG_INTERPOLATION_MODE` | `server-only` | Scope for interpolation: `all`, `server-only`, or `explicit`. |
| `HYTALE_CFG_INTERPOLATION_PATHS` | *(empty)* | When `HYTALE_CFG_INTERPOLATION_MODE=explicit`: additional paths (files/dirs) to process. Relative paths are resolved against `/data/server/`. |
| `HYTALE_CFG_INTERPOLATION_EXCLUDE_PATHS` | *(empty)* | Space-separated shell glob patterns (matched against full file paths) to skip during interpolation. |
| `HYTALE_CFG_INTERPOLATION_MAX_BYTES` | *(empty)* | If set: skip JSON files larger than this size (bytes). |
| `HYTALE_MACHINE_ID` | *(empty)* | 32-character hex string for the container's machine ID (hardware UUID workaround). Auto-generated and persisted if not set. |
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
| `HYTALE_CONSOLE_PIPE` | `true` | If `true`, enables the console command pipe used by `hytale-cli`. If `false`, the server uses normal stdin and `hytale-cli` is disabled. |
| `HYTALE_CONSOLE_FIFO` | `/tmp/hytale-console.fifo` | Path to the console FIFO inside the container (only used when `HYTALE_CONSOLE_PIPE=true`). |
| `HYTALE_VERSION_FILE` | `/data/.hytale-version` | File where the installed server version is stored (used for update checks). |
| `HYTALE_DOWNLOADER_URL` | `https://downloader.hytale.com/hytale-downloader.zip` | Official downloader URL (must start with `https://downloader.hytale.com/`). |
| `HYTALE_DOWNLOADER_DIR` | `/data/.hytale-downloader` | Directory where the image stores the downloader binary. |
| `HYTALE_DOWNLOADER_PATCHLINE` | *(empty)* | Optional downloader patchline (e.g. `pre-release`). |
| `HYTALE_DOWNLOADER_SKIP_UPDATE_CHECK` | `false` | If `true`, passes `-skip-update-check` to reduce network/variability during automation. |
| `HYTALE_DOWNLOADER_CREDENTIALS_SRC` | *(empty)* | Optional path to a mounted credentials file to seed `/data/.hytale-downloader-credentials.json`. |
| `HYTALE_GAME_ZIP_PATH` | `/data/game.zip` | Where the downloader stores the downloaded game package zip. |
| `HYTALE_KEEP_GAME_ZIP` | `false` | If `true`, keep the downloaded game zip after extraction. |
| `HYTALE_DOWNLOAD_LOCK` | `true` | If `false`, disables the download lock (power users). Keeping the lock enabled prevents concurrent downloads into the same `/data` volume. |
| `TZ` | *(empty)* | Optional timezone name (for example `Europe/Berlin`). If set, passed to the JVM as `-Duser.timezone=...`. |
| `JVM_XMS` | *(empty)* | Passed as `-Xms...` (initial heap). |
| `JVM_XMX` | *(empty)* | Passed as `-Xmx...` (max heap). |
| `HYTALE_JAVA_TERMINAL_PROPS` | `true` | If `true`, sets terminal-related JVM properties (`-Dterminal.jline=...`, `-Dterminal.ansi=...`). |
| `JVM_TERMINAL_JLINE` | `false` | Used when `HYTALE_JAVA_TERMINAL_PROPS=true`: passed as `-Dterminal.jline=...`. |
| `JVM_TERMINAL_ANSI` | `true` | Used when `HYTALE_JAVA_TERMINAL_PROPS=true`: passed as `-Dterminal.ansi=...`. |
| `JVM_EXTRA_ARGS` | *(empty)* | Extra JVM args appended to the `java` command. |
| `ENABLE_AOT` | `auto` | `auto\|true\|false\|generate` (controls `-XX:AOTCache=...`). |
| `EXTRA_SERVER_ARGS` | *(empty)* | Extra server args appended at the end. |
| `HYTALE_ALLOW_OP` | `false` | If `true`, enables the `/op self` command. |
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
| `HYTALE_MODS_PATH` | *(empty)* | Passed as `--mods`. If `HYTALE_CURSEFORGE_MODS` is set and you did not explicitly set `HYTALE_MODS_PATH`, it defaults to `/data/server/mods-curseforge`. |
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
| `HYTALE_UNIVERSE_DOWNLOAD_URLS` | *(empty)* | Space/comma/newline-separated list of universe download URLs (or `@/path/to/list.txt`) to fetch before server start. |
| `HYTALE_UNIVERSE_DOWNLOAD_PATH` | *(empty)* | Destination directory for universe downloads. Defaults to `HYTALE_UNIVERSE_PATH` if set, otherwise `/data/server/universe`. |
| `HYTALE_UNIVERSE_DOWNLOAD_LIMIT_RATE` | *(empty)* | Bandwidth limit passed to `curl --limit-rate` (e.g. `500k`, `2m`). |
| `HYTALE_UNIVERSE_DOWNLOAD_FORCE` | `false` | If `true`, downloads even if a previous run already downloaded the same URL. |
| `HYTALE_UNIVERSE_DOWNLOAD_FAIL_ON_ERROR` | `true` | If `true`, fails container startup when any universe download fails. |
| `HYTALE_MODS_DOWNLOAD_URLS` | *(empty)* | Space/comma/newline-separated list of mod download URLs (or `@/path/to/list.txt`) to fetch before server start. |
| `HYTALE_MODS_DOWNLOAD_PATH` | *(empty)* | Destination directory for mods downloads. Defaults to `HYTALE_MODS_PATH` if set, otherwise `/data/server/mods`. |
| `HYTALE_MODS_DOWNLOAD_LIMIT_RATE` | *(empty)* | Bandwidth limit passed to `curl --limit-rate` (e.g. `500k`, `2m`). |
| `HYTALE_MODS_DOWNLOAD_FORCE` | `false` | If `true`, downloads even if a previous run already downloaded the same URL. |
| `HYTALE_MODS_DOWNLOAD_FAIL_ON_ERROR` | `true` | If `true`, fails container startup when any mods download fails. |

### CurseForge mod management

| Variable | Default | Description |
|---|---:|---|
| `HYTALE_CURSEFORGE_MODS` | *(empty)* | Space/newline-separated list of mod references (enables CurseForge mod management). |
| `HYTALE_CURSEFORGE_API_KEY` | *(empty)* | CurseForge API key (**secret**). Prefer `*_SRC` in production. |
| `HYTALE_CURSEFORGE_API_KEY_SRC` | *(empty)* | Path to a file containing the API key (Docker secrets recommended). |
| `HYTALE_CURSEFORGE_AUTO_UPDATE` | `true` | If `true`, checks for updates on startup (downloads only when needed). If `false`, keeps an already installed version. |
| `HYTALE_CURSEFORGE_RELEASE_CHANNEL` | `release` | Allowed channels: `release`, `beta`, `alpha`, `any`. |
| `HYTALE_CURSEFORGE_GAME_VERSION_FILTER` | *(empty)* | Filters `gameVersions[]` in the CurseForge API response. Leave empty to accept all versions. |
| `HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS` | `0` | If `> 0`, skips remote checks when the last check was recent (reduces API usage on frequent restarts). |
| `HYTALE_CURSEFORGE_PRUNE` | `false` | If `true`, removes previously installed CurseForge mods that are no longer listed in `HYTALE_CURSEFORGE_MODS`. |
| `HYTALE_CURSEFORGE_FAIL_ON_ERROR` | `false` | If `true`, fails container startup when any configured mod cannot be resolved/installed. |
| `HYTALE_CURSEFORGE_LOCK` | `true` | If `false`, disables the CurseForge install lock (power users). |
| `HYTALE_CURSEFORGE_HTTP_CACHE_URL` | *(empty)* | Optional HTTP cache gateway base URL used for both API requests and file downloads. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_API_URL` | *(empty)* | Optional HTTP cache gateway base URL used for CurseForge API requests only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL` | *(empty)* | Optional HTTP cache gateway base URL used for mod file downloads only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |

See: [`curseforge-mods.md`](curseforge-mods.md)

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

### Send console commands (hytale-cli)

This image includes a small helper called `hytale-cli` that can be used to send commands to the server console from a script (for example before a planned restart).

If you want to disable this feature, set `HYTALE_CONSOLE_PIPE=false`.

From your host:

```bash
docker exec hytale hytale-cli send "/auth status"
```

Multiple commands (one per line):

```bash
printf '%s\n' "/auth status" "/auth persistence Encrypted" | docker exec -i hytale hytale-cli send
```

Advanced: the console FIFO path inside the container can be overridden via `HYTALE_CONSOLE_FIFO`.

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

### Hardware UUID workaround

The Hytale server reads `/etc/machine-id` to generate a stable hardware UUID.
In Docker containers, this file is typically missing or read-only.
This image automatically generates a stable machine ID and persists it in `/data/.machine-id`.

The machine ID is used by the Hytale server to encrypt the `auth.enc` file (which stores authentication credentials from `/auth login device`).
This image replicates the standard Linux behavior where `/etc/machine-id` is readable by all processes.

You can override the auto-generated machine ID:

```yaml
services:
  hytale:
    environment:
      HYTALE_MACHINE_ID: "0123456789abcdef0123456789abcdef"
```

The value must be exactly 32 lowercase hexadecimal characters (no dashes).

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
