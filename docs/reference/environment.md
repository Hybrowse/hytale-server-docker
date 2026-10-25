# Environment variables

Find settings by task. Each reference lists defaults and accepted values; the guides show complete workflows.

| Group | Typical settings |
| --- | --- |
| [Downloads and startup updates](downloads.md) | Auto-download, credentials, patchline |
| [Authentication and broker](authentication.md) | Login, auth keys, broker, machine identity |
| [JSON configuration](configuration.md) | `HYTALE_CONFIG_*`, `HYTALE_CFG_*` |
| [Java and AOT](runtime.md) | Heap size, extra JVM arguments, AOT |
| [Mods and content downloads](mods.md) | CurseForge and pre-start downloads |
| [Console, backups and native updates](operations.md) | Console pipe, backup retention, update runner |
| [Server flags and paths](server.md) | Bind address, paths, validation and debugging |

Image behavior and game-server behavior are separate. For example `HYTALE_AUTO_UPDATE` controls the startup downloader, while `HYTALE_DISABLE_UPDATES` is read directly by Hytale.

Most guides use Compose snippets that extend the [quickstart](../image/quickstart.md). Quote environment values so YAML treats numbers and booleans as strings. Do not commit credentials to Compose or Helm values files.
