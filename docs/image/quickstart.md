# Quickstart

## 1. Docker Compose

Hytale uses **QUIC over UDP** (not TCP). Publish `5520/udp`.

```yaml
services:
  hytale:
    image: hybrowse/hytale-server:latest
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
    ports:
      - "5520:5520/udp"
    volumes:
      - ./data:/data
    tty: true
    stdin_open: true
    restart: unless-stopped
```

```bash
docker compose up -d
```

> [!NOTE]
> On first run, the official downloader prints an authorization URL + device code in the logs.
> After you complete this once, credentials are stored and future runs are non-interactive.

## 2. Downloader authentication (first-time only)

Watch logs:

```bash
docker compose logs -f hytale
```

Open the URL in your browser and enter the device code. After completion, the download proceeds automatically.

On subsequent runs, this step is skipped (credentials are stored on the `/data` volume).

> [!TIP]
> For non-interactive setups, seed credentials via `HYTALE_DOWNLOADER_CREDENTIALS_SRC` (mounted secret), or pre-provision `Assets.zip` and `Server/` and set `HYTALE_AUTO_DOWNLOAD=false`.

> [!NOTE]
> **Apple Silicon (arm64):** The official downloader only supports `linux/amd64`.
> Add `platform: linux/amd64` to your Compose file (uses emulation), or provision files manually: [`server-files.md`](server-files.md)

> [!IMPORTANT]
> **After** the server starts, you must authenticate it before players can connect.
> If you skip this step, players will see: *"Server authentication unavailable - please try again later"*
>
> Provider/fleet option: if you use **the [Hytale Session Token Broker](https://github.com/Hybrowse/hytale-session-token-broker) by Hybrowse**, you can fetch `HYTALE_SERVER_SESSION_TOKEN` / `HYTALE_SERVER_IDENTITY_TOKEN` at container startup and skip the interactive `/auth` flow.
> See: [`configuration.md`](configuration.md#optional-session-token-broker-skip-auth)

## 3. Server authentication (required for player connections)

1. Attach to the server console:

   ```bash
   docker compose attach hytale
   ```

2. Enable encrypted persistence (so you don't need to re-authenticate after every restart):

   ```text
   /auth persistence Encrypted
   ```

3. Run:

   ```text
   /auth login device
   ```

4. Follow the URL + device code shown in the console.

5. If multiple profiles are shown, pick one:

   ```text
   /auth select <number>
   ```

6. Check status:

   ```text
   /auth status
   ```

Detach without stopping the server: `Ctrl-p` then `Ctrl-q`

See: [`troubleshooting.md`](troubleshooting.md)

## Done!

Players can now connect.

## Automation (optional)

If you want to run server console commands from scripts (for example before planned restarts), this image includes `hytale-cli`.

See: [`configuration.md`](configuration.md#send-console-commands-hytale-cli)

## Next steps

- [`configuration.md`](configuration.md) — environment variables, JVM tuning, backups
- [`curseforge-mods.md`](curseforge-mods.md) — automatic CurseForge mod download and updates
- [`troubleshooting.md`](troubleshooting.md) — common issues and fixes
- [`server-files.md`](server-files.md) — manual provisioning (if not using auto-download)
