# CurseForge Mods

This image supports **automatic mod download and updates from CurseForge**.

You can configure mods via environment variables, and the container will install (and optionally update) mods on startup.

## Why this is useful

- Fully automated mod provisioning (no manual downloads)
- Automatic updates on container restart (optional)
- Managed mods are stored separately from any manually installed mods
- Idempotent installs via a local manifest on the `/data` volume

## Requirements

- A **CurseForge API key** (required)
- Internet access to `https://api.curseforge.com` and the CurseForge CDN

## Getting an API key

1. Go to [console.curseforge.com](https://console.curseforge.com/)
2. Create an API key
3. Copy your API key

**Important:** CurseForge API keys start with `$2a$10$`. If your key doesn't look like this, it may be incorrectly formatted.

### Docker Compose escaping

In Docker Compose YAML, dollar signs (`$`) must be escaped as `$$`. If you set the key directly in the YAML (not recommended), you need:

```yaml
HYTALE_CURSEFORGE_API_KEY: "$$2a$$10$$YourKeyHere..."
```

**Recommended:** Use a secret file instead to avoid escaping issues:

```yaml
HYTALE_CURSEFORGE_API_KEY_SRC: "/run/secrets/curseforge_api_key"
secrets:
  curseforge_api_key:
    file: ./secrets/curseforge_api_key.txt
```

The file should contain the API key as-is (with normal `$` signs, no escaping).

## Quickstart (Docker Compose)

```yaml
services:
  hytale:
    image: hybrowse/hytale-server:latest
    environment:
      HYTALE_AUTO_DOWNLOAD: "true"

      # Enable CurseForge mod management
      HYTALE_CURSEFORGE_MODS: |
        123456
        234567:3456789

      # Read the API key from a mounted secret file
      HYTALE_CURSEFORGE_API_KEY_SRC: "/run/secrets/curseforge_api_key"

    secrets:
      - curseforge_api_key

    ports:
      - "5520:5520/udp"
    volumes:
      - ./data:/data
    tty: true
    stdin_open: true
    restart: unless-stopped

secrets:
  curseforge_api_key:
    file: ./secrets/curseforge_api_key.txt
```

Notes:

- If `HYTALE_CURSEFORGE_MODS` is set and you did **not** explicitly set `HYTALE_MODS_PATH`, the image defaults it to `/data/server/mods-curseforge`.
- The default `mods/` folder of the Hytale server remains unaffected.

## Mod reference formats

`HYTALE_CURSEFORGE_MODS` supports a whitespace / newline separated list.

- `123456`
  - Install the latest file for CurseForge project with ID `123456` (can be found in the sidebar of the mod's page)
- `123456:3456789`
  - Install a specific file with ID `3456789` for CurseForge project with ID `123456`
- `123456@server`
  - Pick the latest file whose `fileName` or `displayName` contains `server` for CurseForge project with ID `123456`
- `@/path/to/mods.txt`
  - Load additional entries from a file inside the container

## Environment variables

| Variable | Default | Description |
|---|---:|---|
| `HYTALE_CURSEFORGE_MODS` | *(empty)* | Enables CurseForge mod management and lists mod references. |
| `HYTALE_CURSEFORGE_API_KEY` | *(empty)* | CurseForge API key (**secret**). Prefer `*_SRC` in production. |
| `HYTALE_CURSEFORGE_API_KEY_SRC` | *(empty)* | Path to a file containing the API key (Docker secrets recommended). |
| `HYTALE_CURSEFORGE_AUTO_UPDATE` | `true` | If `true`, checks for updates on startup (downloads only when needed). If `false`, keeps an already installed version. |
| `HYTALE_CURSEFORGE_RELEASE_CHANNEL` | `release` | Allowed channels: `release`, `beta`, `alpha`, `any`. |
| `HYTALE_CURSEFORGE_GAME_VERSION_FILTER` | *(empty)* | Filters `gameVersions[]` in the CurseForge API response. Leave empty to accept all versions. |
| `HYTALE_CURSEFORGE_CHECK_INTERVAL_SECONDS` | `0` | If `> 0`, skips remote checks when the last check was recent (reduces API usage on frequent restarts). |
| `HYTALE_CURSEFORGE_PRUNE` | `true` when mods path is not `/data/server/mods`, otherwise `false` | If `true`, removes previously installed CurseForge mods that are no longer listed in `HYTALE_CURSEFORGE_MODS`. |
| `HYTALE_CURSEFORGE_FAIL_ON_ERROR` | `false` | If `true`, fails container startup when any configured mod cannot be resolved/installed. |
| `HYTALE_CURSEFORGE_LOCK` | `true` | If `false`, disables the CurseForge install lock (power users). |
| `HYTALE_CURSEFORGE_HTTP_CACHE_URL` | *(empty)* | Optional HTTP cache gateway base URL used for both API requests and file downloads. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_API_URL` | *(empty)* | Optional HTTP cache gateway base URL used for CurseForge API requests only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |
| `HYTALE_CURSEFORGE_HTTP_CACHE_DOWNLOAD_URL` | *(empty)* | Optional HTTP cache gateway base URL used for mod file downloads only. Defaults to `HYTALE_CURSEFORGE_HTTP_CACHE_URL`. |
| `HYTALE_CURSEFORGE_DEBUG` | `false` | If `true`, prints additional diagnostics on API and download failures (does not print the API key). |

## Optional: HTTP cache gateway (for ephemeral servers)

If you start many short-lived servers without a persistent `/data` volume, you may want to reduce CurseForge API usage and avoid repeatedly downloading the same mod files.

You can point the container at an internal HTTP cache gateway (for example Varnish + Caddy):

```yaml
services:
  hytale:
    environment:
      HYTALE_CURSEFORGE_HTTP_CACHE_URL: "http://curseforge-cache:8080"
```

When these variables are set, the image routes both CurseForge API calls and file downloads through the cache gateway while preserving the original `Host` header.
This allows the gateway to forward requests to the correct upstream (`api.curseforge.com`, `edge.forgecdn.net`, ...).

## Behavior and data layout

### Mods directory

- Visible mods directory (passed as `--mods`):
  - `/data/server/mods-curseforge` (default when CurseForge is enabled)
  - Or whatever you set `HYTALE_MODS_PATH` to

The image installs each mod file and then creates a stable file in the visible directory:

- `cf-<modId>-<fileId>-<fileName>`

This avoids filename collisions and makes updates deterministic.

### State directory (manifest, downloads)

State is stored on the `/data` volume under:

- `/data/.hytale-curseforge-mods/`

Files:

- `manifest.json` stores the installed file IDs and last check timestamp

### Lock

To prevent concurrent installations into the same `/data` volume, the image uses a lock:

- `/data/.hytale-curseforge-mods-lock`

## Production strategies: dependency conflicts and version mismatches

CurseForge projects can have optional or required dependencies, and multiple mods may ship incompatible versions of shared libraries.
The image does not attempt to solve a dependency graph or resolve conflicts automatically.
In production, treat the mod list as a versioned input and use repeatable rollouts.

- **Pin exact file IDs for stability**
  - Prefer `modId:fileId` for all critical mods.
  - This avoids unexpected updates when containers restart.

- **Freeze updates during normal operation**
  - Set `HYTALE_CURSEFORGE_AUTO_UPDATE=false` to prevent silent drift.
  - If you want periodic updates, use a staging environment and promote the pinned file IDs into production.

- **Staged rollouts (canary) instead of updating everything at once**
  - Maintain the mod list in a single source of truth (for example a file you mount and reference via `@/path/to/mods.txt`).
  - Roll out changes to a single instance first, validate startup and gameplay, then expand to the full fleet.

- **Make dependencies explicit**
  - If a mod requires another CurseForge project, list the dependency explicitly in `HYTALE_CURSEFORGE_MODS`.
  - If you rely on keyword selection (`modId@keyword`), prefer migrating to `modId:fileId` once you have identified a known-good version.

- **Avoid cross-instance mismatches**
  - Ensure all instances use the same mod list and the same update policy.
  - If instances share a persistent `/data` volume, keep `HYTALE_CURSEFORGE_LOCK=true` to avoid concurrent installs.
  - If instances do not share `/data`, pinning file IDs is the most reliable way to keep versions aligned.

- **Operational troubleshooting (conflicts / crashes)**
  - If startup crashes after a mod update, temporarily pin the previously working file ID and restart.
  - Use `HYTALE_CURSEFORGE_FAIL_ON_ERROR=true` to prevent starting with a partially installed mod set.
  - If you suspect a specific mod conflict, bisect by removing half the mods, then narrow down until the problematic entry is found.

## Troubleshooting

- If the container logs warn about a missing API key:
  - set `HYTALE_CURSEFORGE_API_KEY` or `HYTALE_CURSEFORGE_API_KEY_SRC`
  - set `HYTALE_CURSEFORGE_FAIL_ON_ERROR=true` if you want missing/failed mods to block startup

- If a mod cannot be resolved:
  - verify the numeric project ID / file ID
  - try pinning a specific file via `modId:fileId`
  - if using `HYTALE_CURSEFORGE_GAME_VERSION_FILTER`, verify it matches the mod's file metadata
