# Server files (manual provisioning)

> [!NOTE]
> **You usually don't need this page.** By default (`HYTALE_AUTO_DOWNLOAD=true`), the container downloads and provisions server files automatically.

Manual provisioning is needed if:

- You are on **Apple Silicon (arm64)** and don't want to use `platform: linux/amd64` emulation
- You want to pin a specific server version
- You prefer full control over file provisioning

---

This Docker image runs the official Hytale dedicated server binaries from a mounted volume.
This repository and image **do not** redistribute proprietary Hytale server binaries or assets.

You are responsible for obtaining the required files via official channels and for complying with the Hytale EULA, Terms of Service, and Server Operator Policies: https://hytale.com/server-policies

You must provide these files yourself:

- `Assets.zip`
- the `Server/` folder contents (at minimum `HytaleServer.jar`, plus additional runtime files)

## Option A: Official Hytale Downloader (recommended)

The official docs provide the downloader archive here:

- https://downloader.hytale.com/hytale-downloader.zip

Typical flow:

1. Download and extract the archive.
2. Run the downloader and store the game package zip:

   ```bash
   ./hytale-downloader -download-path game.zip
   ```

3. Extract required artifacts from `game.zip`:

   ```bash
   unzip -o game.zip 'Assets.zip'
   unzip -o game.zip 'Server/*' -d .
   ```

You should now have:

- `./Assets.zip`
- `./Server/` (folder)

## Option B: Copy from Hytale launcher installation

If you have the game installed via the launcher, the official manual documents a directory containing a `Server/` folder and `Assets.zip`.

Documented paths:

- **Windows:** `%appdata%\Hytale\install\release\package\game\latest`
- **Linux:** `$XDG_DATA_HOME/Hytale/install/release/package/game/latest`
- **macOS:** `~/Application Support/Hytale/install/release/package/game/latest`

Copy both artifacts (keep them as a matched set when updating):

- `Assets.zip`
- `Server/` (entire folder)

## Provide the files to the container

Expected volume layout:

- `./data/Assets.zip`
- `./data/server/` (contents of `Server/`)

Example:

```text
./data/
  Assets.zip
  server/
    HytaleServer.jar
    ...
```

If you extracted via Option A, you can provision like this:

```bash
mkdir -p ./data/server
cp -f ./Assets.zip ./data/Assets.zip
cp -a ./Server/. ./data/server/
```

Then start the container:

```bash
docker compose up -d
```

## Notes

- Keep `Assets.zip` and `Server/` in sync when updating.
- Avoid committing these files to source control.
