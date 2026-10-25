# Data and permissions

Keep the entire `/data` volume between container replacements. Reusing only the world directory loses other state needed for a predictable restart.

| Path | Purpose |
| --- | --- |
| `/data/Assets.zip` | Official assets, matched to the server release |
| `/data/server/HytaleServer.jar` | Official server binary |
| `/data/server/universe/` | Default world and player data |
| `/data/server/config.json` | Server settings and saved profile configuration |
| `/data/server/mods/` | Default mod directory |
| `/data/server/mods-curseforge/` | Default additional directory for managed CurseForge mods |
| `/data/server/auth.enc` | Encrypted server login |
| `/data/server/auth.key` | Auth key when Hytale creates or uses one; treat as a secret |
| `/data/.machine-id` | Persistent machine identity |
| `/data/.hytale-downloader-credentials.json` | Separate downloader login; treat as a secret |
| `/data/updater/` | Native-update staging, transactions and previous binaries |
| `/data/backups/` | Default backup destination when built-in backups are enabled |

Custom path settings can change some locations. See the [variable reference](../reference/environment.md).

## Named volume or bind mount

The [quickstart](quickstart.md) uses a named volume. Docker manages its host location and initial ownership. A bind mount makes files visible in a host directory:

```yaml
services:
  hytale:
    volumes:
      - ./data:/data
```

This is a replacement for the quickstart's volume mount, not an additional mount at the same path. The image runs as UID/GID `1000:1000` by default. On Linux, create the host directory with ownership that lets that user write:

```sh
mkdir -p ./data
sudo chown 1000:1000 ./data
```

For an existing directory, inspect ownership before making recursive changes. Do not solve a permission error by deleting the data directory or running the game server as root.

## Capacity and temporary files

Allow room for assets, worlds, mods, backups and update copies. Native updates can temporarily need several copies of the game files. The Kubernetes examples use 20Gi for a basic claim and 40Gi for native updates; neither is a workload guarantee.

Keep `/tmp` writable. Large extraction jobs can consume substantial temporary storage; a RAM-backed temporary filesystem counts against container memory. Kubernetes defaults use disk-backed temporary storage.

## One writer per world

Never start two game-server processes against the same world volume. A second process can damage state even if the storage permits multiple mounts. For manual maintenance, stop the old process and wait for it to exit before using a replacement container or recovery Job.

See [Kubernetes operations](kubernetes-operations.md) for PVC and rollout considerations and [security](security.md) for Secret handling.
