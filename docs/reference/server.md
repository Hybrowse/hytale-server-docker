# Server flags and paths

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_SERVER_JAR` | `/data/server/HytaleServer.jar` | Path to `HytaleServer.jar` inside the container. |
| `HYTALE_ASSETS_PATH` | `/data/Assets.zip` | Path to `Assets.zip` inside the container. |
| `HYTALE_BIND` | `0.0.0.0:5520` | Bind address for QUIC/UDP. |
| `HYTALE_DISABLE_SENTRY` | `false` | If `true`, passes `--disable-sentry`. |
| `HYTALE_ACCEPT_EARLY_PLUGINS` | `false` | If `true`, passes `--accept-early-plugins` (acknowledges unsupported early plugins). |
| `EXTRA_SERVER_ARGS` | *(empty)* | Extra server args appended at the end. |
| `HYTALE_ALLOW_OP` | `false` | If `true`, enables the `/op self` command. |
| `HYTALE_BARE` | `false` | If `true`, passes `--bare`. |
| `HYTALE_BOOT_COMMAND` | *(empty)* | Passed as `--boot-command`. |
| `HYTALE_CLIENT_PID` | *(empty)* | Passed as `--client-pid` (advanced/debug use cases). |
| `HYTALE_DISABLE_ASSET_COMPARE` | `false` | If `true`, passes `--disable-asset-compare`. |
| `HYTALE_DISABLE_CPB_BUILD` | `false` | If `true`, passes `--disable-cpb-build`. |
| `HYTALE_DISABLE_FILE_WATCHER` | `false` | If `true`, passes `--disable-file-watcher`. |
| `HYTALE_EARLY_PLUGINS_PATH` | *(empty)* | Passed as `--early-plugins`. |
| `HYTALE_EVENT_DEBUG` | `false` | If `true`, passes `--event-debug`. |
| `HYTALE_FORCE_NETWORK_FLUSH` | *(unset)* | If `true`, passes `--force-network-flush`. |
| `HYTALE_GENERATE_SCHEMA` | `false` | Removed in Hytale 0.7.4. Use one of the schema output paths below. |
| `HYTALE_GENERATE_ASSET_SCHEMA_PATH` | *(empty)* | Export asset JSON schemas to this directory and exit. |
| `HYTALE_GENERATE_CONFIG_SCHEMA_PATH` | *(empty)* | Export config JSON schemas to this directory and exit. |
| `HYTALE_IGNORE_BROKEN_MODS` | `false` | Attempt startup despite broken mods (`--ignore-broken-mods`). |
| `HYTALE_VERIFY_WORLDS` | `false` | Verify all worlds, then exit (`--verify-worlds`). |
| `HYTALE_RECOVERY_MODE` | *(empty)* | With world verification: `FROM_BACKUP_OR_REGENERATE` or `REGENERATE`. Back up the volume first; recovery can replace broken chunks. |
| `HYTALE_LOG` | *(empty)* | Passed as `--log`. |
| `HYTALE_MIGRATE_WORLDS` | *(empty)* | Passed as `--migrate-worlds`. |
| `HYTALE_MIGRATIONS` | *(empty)* | Passed as `--migrations`. |
| `HYTALE_OWNER_NAME` | *(empty)* | Passed as `--owner-name`. |
| `HYTALE_OWNER_UUID` | *(empty)* | Passed as `--owner-uuid`. |
| `HYTALE_PREFAB_CACHE_PATH` | *(empty)* | Passed as `--prefab-cache`. |
| `HYTALE_SHUTDOWN_AFTER_VALIDATE` | `false` | If `true`, passes `--shutdown-after-validate`. |
| `HYTALE_SINGLEPLAYER` | `false` | If `true`, passes `--singleplayer`. |
| `HYTALE_SKIP_MOD_VALIDATION` | `false` | Removed in Hytale 0.7.4. Explicitly choose `HYTALE_IGNORE_BROKEN_MODS=true` if you want to attempt startup with broken mods. |
| `HYTALE_TRANSPORT` | *(empty)* | Passed as `--transport`. |
| `HYTALE_UNIVERSE_PATH` | *(empty)* | Passed as `--universe`. |
| `HYTALE_VALIDATE_ASSETS` | `false` | If `true`, passes `--validate-assets`. |
| `HYTALE_VALIDATE_PREFABS` | *(empty)* | If set to `true`, passes `--validate-prefabs`. Otherwise passes `--validate-prefabs <value>`. |
| `HYTALE_VALIDATE_WORLD_GEN` | `false` | If `true`, passes `--validate-world-gen`. |
| `HYTALE_WORLD_GEN_PATH` | *(empty)* | Passed as `--world-gen`. |
