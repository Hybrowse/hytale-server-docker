# Start a server with Docker Compose

This guide starts one server, stores its data in a Docker volume and walks through both first-time logins. You need Docker with Compose and a Hytale account that can authorize a dedicated server.

## 1. Create the service

Save this complete example as `compose.yaml` in an empty directory:

```yaml
services:
  hytale:
    image: hybrowse/hytale-server:latest
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"
    ports:
      - "5520:5520/udp"
    volumes:
      - hytale-data:/data
    stop_grace_period: 120s
    restart: unless-stopped

volumes:
  hytale-data:
```

The named volume avoids host-directory ownership problems on first startup. To use a bind mount instead, follow [data and permissions](data.md). For production, replace `latest` with a specific [published image tag](https://github.com/Hybrowse/hytale-server-docker/releases).

Start the container and watch its logs:

```sh
docker compose up -d
docker compose logs -f hytale
```

On AMD64 and ARM64, use the native image. Do not add `platform: linux/amd64` on Apple Silicon. You do not need privileged mode, a terminal attachment or a local Java installation.

## 2. Authorize the downloader

Open the authorization URL printed in the logs and confirm the displayed code. The official downloader obtains the server files and assets. This can take several minutes and needs several gigabytes of free storage.

Downloader credentials are saved on `/data` and reused on later starts. They are independent of the server login in the next step.

If downloading stops with `invalid_grant`, use [downloader login recovery](troubleshooting.md#expired-downloader-login-invalid_grant). If you already have the official files, use [manual provisioning](server-files.md) instead.

## 3. Authorize the running server

After the download, Java starts and the image automatically requests Hytale's device login with encrypted persistence. Follow this **second** authorization URL in the logs.

If your account has several profiles, select one using the name or number Hytale displays:

```sh
docker compose exec hytale hytale-cli auth select ExamplePlayer
```

Request live authentication status, then read the result in the logs:

```sh
docker compose exec hytale hytale-cli auth status
docker compose logs --tail 50 hytale
```

Look for Hytale's authentication-success message. A running container or a healthy probe alone does not establish that players can join.

The login, selected profile and machine identity remain on the data volume. Do not delete the volume to resolve a downloader error. For manual login or automated fleets, see [authentication](authentication.md).

## 4. Connect

In Hytale Direct Connect, enter the Docker host's address and port `5520`. When the client runs on the same host, use `127.0.0.1:5520`. For another computer, use the host's reachable LAN or public address.

For internet access, forward **UDP 5520** to the Docker host and allow it in the host firewall. Forwarding TCP alone is insufficient. See [networking](networking.md) if local connections work but remote ones fail.

## 5. Stop and restart safely

```sh
docker compose stop hytale
docker compose up -d hytale
```

The same volume is reused, so normal restarts should not need a new login. `docker compose down` also retains the named volume; `docker compose down --volumes` deletes it and its server data.

## Next steps

- [Configure server name, player limit and JSON files](config-files.md).
- [Set memory limits and heap size](runtime.md).
- [Install CurseForge mods](curseforge-mods.md).
- [Choose an update method](upgrades.md).
- [Run Doctor](diagnostics.md) for read-only checks and support reports.
