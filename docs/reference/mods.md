# Mods and content downloads

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_MODS_PATH` | *(empty)* | Passed as `--mods`. If `HYTALE_CURSEFORGE_MODS` is set and you did not explicitly set `HYTALE_MODS_PATH`, it defaults to `/data/server/mods-curseforge`. |
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
| `HYTALE_CURSEFORGE_MODS` | *(empty)* | Space/newline-separated list of mod references (enables CurseForge mod management). |
| `HYTALE_CURSEFORGE_API_KEY` | *(empty)* | CurseForge API key (**secret**). Prefer `*_SRC` in production. |
| `HYTALE_CURSEFORGE_API_KEY_SRC` | *(empty)* | Path to a file containing the API key (Docker secrets recommended). |
| `HYTALE_CURSEFORGE_AUTO_UPDATE` | `true` | If `true`, checks for updates on startup (downloads only when needed). If `false`, keeps an already installed version. |
| `HYTALE_CURSEFORGE_RELEASE_CHANNEL` | `release` | Allowed channels: `release`, `beta`, `alpha`, `any`. |
| `HYTALE_CURSEFORGE_GAME_VERSION_FILTER` | *(empty)* | Filters `gameVersions[]` in the CurseForge API response. Leave empty to accept all versions. |
| `HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS` | `0` | If `> 0`, skips remote checks when the last check was recent (reduces API usage on frequent restarts). |
| `HYTALE_CURSEFORGE_PRUNE` | `true` when mods path is not `/data/server/mods`, otherwise `false` | If `true`, removes previously installed CurseForge mods that are no longer listed in `HYTALE_CURSEFORGE_MODS`. |
| `HYTALE_CURSEFORGE_FAIL_ON_ERROR` | `false` | If `true`, fails container startup when any configured mod cannot be resolved/installed. |
| `HYTALE_CURSEFORGE_LOCK` | `true` | If `false`, disables the CurseForge install lock (power users). |
| `HYTALE_CURSEFORGE_HTTP_CACHE_URL` | *(empty)* | Optional HTTP cache gateway base URL used for both API requests and file downloads. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_API_URL` | *(empty)* | Optional HTTP cache gateway base URL used for CurseForge API requests only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL` | *(empty)* | Optional HTTP cache gateway base URL used for mod file downloads only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |
| `HYTALE_CURSEFORGE_DEBUG` | `false` | If `true`, prints additional diagnostics on API and download failures (does not print the API key). |
