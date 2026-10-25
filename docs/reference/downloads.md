# Downloads and startup updates

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
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
| `HYTALE_DOWNLOADER_RESET_CREDENTIALS` | `false` | Reset only downloader credentials for one login. Remove after use; cannot be combined with `HYTALE_DOWNLOADER_CREDENTIALS_SRC`. |
