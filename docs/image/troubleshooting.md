# Troubleshooting

Common issues and how to fix them.

> [!WARNING]
> This is the most common issue. If players can't connect, check this first.

## Server authentication error: "Server authentication unavailable"

**Symptom:** Players cannot connect; you see this in server logs:

```text
[SEVERE] [HandshakeHandler] Server session token not available - cannot request auth grant
[INFO] [Hytale] Disconnecting ... with the message: Server authentication unavailable - please try again later
```

**Cause:** The server is not authenticated. In `HYTALE_AUTH_MODE=authenticated` (the default), the server must complete a device-code login after startup before players can connect.

**Fix:**

For a fresh server, first check the logs for the automatically started device login. To start a new login with encrypted persistence:

```bash
docker compose exec hytale hytale-cli auth login
```

If several profiles are offered, use `hytale-cli auth select <name-or-number>`. For manual console access:

1. Attach to the server console:

```bash
docker compose attach hytale
```

2. Run:

```text
/auth login device
```

3. Follow the URL + device code shown in the console.

4. If multiple profiles are shown, pick one:

```text
/auth select <number>
```

5. Check status:

```text
/auth status
```

Detach without stopping the server:

- Press `Ctrl-p` then `Ctrl-q`

## Downloader authentication (first-time setup)

**Symptom:** Container logs show a URL + device code on first run.

**Cause:** The official Hytale Downloader uses OAuth device-code flow to authenticate before downloading server files.

**Fix:** Open the URL in your browser and enter the device code shown in the logs. After completion, the download will proceed.

Watch logs during first-time auth:

```bash
docker compose logs -f hytale
```

> [!NOTE]
> ARM64 images include emulation for the official downloader. Java and the game server remain native; no `platform: linux/amd64` override is needed.

## Expired downloader login (`invalid_grant`)

If auto-download stops with `oauth2: "invalid_grant"`, the saved downloader login
has expired or been revoked. This happens before the game server starts, so changing
`HYTALE_SESSION_TOKEN_BROKER_TIMEOUT_SECONDS` does not help.

For Docker Compose, sign in once using a temporary container:

```bash
docker compose stop hytale
docker compose run --rm --no-deps \
  -e HYTALE_AUTO_DOWNLOAD=true \
  -e HYTALE_AUTO_UPDATE=true \
  -e HYTALE_DOWNLOADER_RESET_CREDENTIALS=true \
  --entrypoint /usr/local/bin/hytale-auto-download hytale
docker compose up -d hytale
```

Follow the device-login URL in the temporary container's output. The regular
container then reuses the new login. Worlds, configuration and server authentication
are preserved. Keep the same volumes and `platform` as the regular service.

If `HYTALE_DOWNLOADER_CREDENTIALS_SRC` is set, obtain a fresh downloader login and
replace that mounted file instead. Otherwise the old login would be copied back on
every start. Resetting and seeding credentials together is rejected.

On other platforms, set `HYTALE_DOWNLOADER_RESET_CREDENTIALS=true` for one startup,
follow the login in the logs, then remove the setting before restarting again.

## Session Token Broker enabled, but no broker logs

**Symptom:** `HYTALE_SESSION_TOKEN_BROKER_ENABLED=true` is set, but startup logs show no broker activity.

**Cause:** The broker step runs later in startup. If an earlier phase fails or blocks, broker logs will not appear yet.
Common examples:

- Auto-download/update is still waiting on first-time downloader device auth.
- Auto-download failed before startup reached the broker step.
- Both `HYTALE_SERVER_SESSION_TOKEN` and `HYTALE_SERVER_IDENTITY_TOKEN` are already set (broker is skipped by design).

**Fix:**

- Check full container logs from startup (`docker compose logs -f hytale`), not only interactive attach output.
- For non-interactive startup, either:
  - seed `/data/.hytale-downloader-credentials.json` via `HYTALE_DOWNLOADER_CREDENTIALS_SRC`, or
  - pre-provision `/data/Assets.zip` and `/data/server/HytaleServer.jar` and set `HYTALE_AUTO_DOWNLOAD=false`.

## Auto-download on ARM64 (Apple Silicon)

Current ARM64 images run the official x86-64 downloader through a bundled emulator.
Java and the game server run natively. No privileged mode or host emulation setup
is required.

If you see the old error `Auto-download is not supported on arm64`, update the
image and recreate the container:

```bash
docker compose pull hytale
docker compose up -d hytale
```

Remove any `platform: linux/amd64` override from your Compose service to use the
native ARM64 image. Keep the existing `/data` volume so downloaded files, worlds
and credentials are preserved. Follow any downloader login prompt in the logs.

Manual provisioning remains available: [`server-files.md`](server-files.md).

## Permission denied errors on `/data`

**Symptom:**

```text
cp: cannot create regular file '/data/server/./HytaleServer.jar': Permission denied
```

**Cause:** The container runs as `uid=1000` (non-root) by default. If the host directory mounted to `/data` is owned by a different user, the container cannot write to it.

**Fix:** Make the host directory writable for uid 1000:

```bash
sudo chown -R 1000:1000 /path/to/your/data
```

Or, if you want to use a different uid, run the container with a matching user:

```yaml
services:
  hytale:
    user: "1001:1001"
```

> [!WARNING]
> Avoid running as root (`user: "0:0"`) in production.

## Read-only root filesystem

**Symptom:** When running with a read-only root filesystem (e.g., Kubernetes with `readOnlyRootFilesystem: true`):

```text
WARNING: Could not write to /etc/machine-id (read-only filesystem?)
WARNING: The Hytale server may fail with 'Failed to get Hardware UUID'.
```

**Cause:** The container needs to write a machine-id to `/etc/machine-id`. The Hytale server reads this file for hardware identification.

**Fix (Kubernetes):** Disable read-only root filesystem:

```yaml
securityContext:
  readOnlyRootFilesystem: false
```

The machine-id is persisted to `/data/.machine-id` for stability across restarts.

**Fix (Docker Compose):** Mount `/tmp` as tmpfs if needed:

```yaml
services:
  hytale:
    volumes:
      - /path/to/data:/data
    tmpfs:
      - /tmp
```

## Container exits immediately with "Missing server jar" or "Missing assets"

**Symptom:** Container exits with clear error messages about missing files.

**Cause:** The server files and `Assets.zip` are not present in `/data`.

**Fix:**

- Set `HYTALE_AUTO_DOWNLOAD=true` to let the container download them automatically.
- Or provision files manually: [`server-files.md`](server-files.md)

> [!TIP]
> AOT errors are usually harmless with `ENABLE_AOT=auto` (default). The server will continue without AOT.

## AOT cache errors on startup

**Symptom:** Java errors mentioning AOT cache incompatibility or "modules size has changed".

**Cause:** The AOT cache was generated for a different Java version or architecture.

**Fix:**

- Delete the existing cache (`./data/server/HytaleServer.aot`) and regenerate it, or
- Set `ENABLE_AOT=false` to disable AOT.

See: [`configuration.md`](configuration.md#aot-cache)

## High CPU usage from garbage collection

**Symptom:** Server uses a lot of CPU even with few players; GC logs show frequent collections.

**Cause:** The JVM heap is too small for the workload.

**Fix:** Increase `JVM_XMX`:

```yaml
services:
  hytale:
    environment:
      JVM_XMX: "6G"
```

Monitor and experiment with different values.

See: [`configuration.md`](configuration.md#jvm-heap-tuning)

## CurseForge mods: HTTP 403 when resolving download URL

**Symptom:** You see a warning like:

```text
WARNING: failed to install mod <modId>: failed to resolve download URL (CurseForge API returned HTTP 403 ...)
```

**Cause:** CurseForge returned HTTP 403 for the `download-url` endpoint. This often means the mod author has disabled third-party/API downloads for the project.

**Fix:**

- Remove the mod from `HYTALE_CURSEFORGE_MODS`.
- If the mod is essential, ask the author to enable API downloads or install the mod manually.

**Debug:** Set `HYTALE_CURSEFORGE_DEBUG=true` to print additional diagnostics on API failures.

## Related docs

- [`quickstart.md`](quickstart.md)
- [`configuration.md`](configuration.md)
- [`server-files.md`](server-files.md)
