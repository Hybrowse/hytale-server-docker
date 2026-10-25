# Console, backups and native updates

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_ENABLE_BACKUP` | `false` | If `true`, passes `--backup`. |
| `HYTALE_BACKUP_DIR` | `/data/backups` when backups are enabled | Passed as `--backup-dir`. Use a separate backup mount if required. |
| `HYTALE_BACKUP_FREQUENCY_MINUTES` | *server default (30)* | Passed as `--backup-frequency`. |
| `HYTALE_BACKUP_ARCHIVE_MAX_COUNT` | *(empty)* | Passed as `--backup-archive-max-count`. |
| `HYTALE_BACKUP_MAX_COUNT` | *server default* | Passed as `--backup-max-count`. |
| `HYTALE_NATIVE_UPDATES` | `false` | Apply Hytale-staged updates after exit code 8 and restart Java. Requires writable standard server paths and `HYTALE_AUTO_UPDATE=false` when auto-download is enabled. |
| `HYTALE_CONSOLE_PIPE` | `true` | If `true`, enables the console command pipe used by `hytale-cli`. If `false`, the server uses normal stdin and console/auth commands are disabled; read-only diagnostics still work. |
| `HYTALE_CONSOLE_FIFO` | `/tmp/hytale-console.fifo` | Path to the console FIFO inside the container (only used when `HYTALE_CONSOLE_PIPE=true`). |
| `HYTALE_DISABLE_UPDATES` | *(unset; read by Hytale)* | Disable Hytale's built-in updater. This is separate from this image's `HYTALE_AUTO_UPDATE`, which runs the downloader before startup. |

## Container health check

These settings affect the lightweight health check and Kubernetes probes, not `doctor`. A successful probe does not prove that OAuth login completed or a client can join.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_HEALTHCHECK_DISABLED` | `false` | Return success without checking anything. |
| `HYTALE_HEALTHCHECK_REQUIRE_FILES` | `true` | Require the configured JAR and assets files. |
| `HYTALE_HEALTHCHECK_REQUIRE_PROCESS` | `true` | Require a detected server process. |
| `HYTALE_HEALTHCHECK_SKIP_PORT` | `false` | Skip the UDP-listener check. |
| `HYTALE_HEALTHCHECK_PORT` | Port from `HYTALE_BIND` | Override the checked UDP port inside the container. |
