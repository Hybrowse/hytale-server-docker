# JSON configuration

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_CFG_INTERPOLATION` | `true` | If `false`, disables `CFG_*` placeholder interpolation in JSON config files at startup. |
| `HYTALE_CFG_INTERPOLATION_MODE` | `server-only` | Scope for interpolation: `all`, `server-only`, or `explicit`. |
| `HYTALE_CFG_INTERPOLATION_PATHS` | *(empty)* | When `HYTALE_CFG_INTERPOLATION_MODE=explicit`: additional paths (files/dirs) to process. Relative paths are resolved against `/data/server/`. |
| `HYTALE_CFG_INTERPOLATION_EXCLUDE_PATHS` | *(empty)* | Space-separated shell glob patterns (matched against full file paths) to skip during interpolation. |
| `HYTALE_CFG_INTERPOLATION_MAX_BYTES` | *(empty)* | If set: skip JSON files larger than this size (bytes). |
| `HYTALE_CONFIG_PATH` | `/data/server/config.json` | Path to the server config JSON file that is created/patched at startup. |
| `HYTALE_DEFAULT_CONFIG_PATH` | `/usr/share/hytale/default-config.json` | Source template path used when `HYTALE_CONFIG_PATH` does not exist yet. |
| `HYTALE_CONFIG_SERVER_NAME` | *(unset)* | Sets `ServerName` in `config.json` (applied at every startup). |
| `HYTALE_CONFIG_MOTD` | *(unset)* | Sets `MOTD` in `config.json` (applied at every startup). |
| `HYTALE_CONFIG_PASSWORD` | *(unset)* | Sets `Password` in `config.json` (applied at every startup, **secret**). |
| `HYTALE_CONFIG_MAX_PLAYERS` | *(unset)* | Sets `MaxPlayers` (integer) in `config.json`. |
| `HYTALE_CONFIG_MAX_VIEW_RADIUS` | *(unset)* | Sets `MaxViewRadius` (integer) in `config.json`. |
| `HYTALE_CONFIG_DEFAULT_WORLD` | *(unset)* | Sets `Defaults.World` in `config.json`. |
| `HYTALE_CONFIG_DEFAULT_GAME_MODE` | *(unset)* | Sets `Defaults.GameMode` in `config.json`. |
| `HYTALE_CONFIG_PATCH_JSON` | *(unset)* | JSON object merged into `config.json` before convenience variables are applied. |
| `HYTALE_CONFIG_PATCH_JSON_SRC` | *(unset)* | Path to a file containing a JSON object merged into `config.json`. |
