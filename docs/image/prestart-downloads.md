# Download worlds and mods before startup

On startup, this image can optionally download additional content into the server data directories **before** starting the Java process.

Supported targets:

- `universe/` (world + player save data)
- `mods/`

The download list is a space/comma/newline-separated list of `http://` / `https://` URLs.
Each list item can also be a reference to a file by prefixing it with `@`.
The file is read line-by-line; empty lines and `# comments` are ignored.

Each URL is downloaded at most once per `/data` volume by default (a marker file is stored under `/data/.hytale-prestart-downloads/`).
To re-download, use the `*_FORCE=true` option.

Downloaded files:

- If the downloaded payload is a ZIP archive, it is extracted into the destination directory.
- Otherwise the payload is saved as a file in the destination directory.

Optional throttling:

- `*_LIMIT_RATE` maps to `curl --limit-rate` (for example `500k`, `2m`).

Security notes:

- The image does not log URL query strings and redacts URL userinfo (for example `https://user:pass@...`).
- Only `http(s)` is supported.

### Example (download a universe and mods)

```yaml
services:
  hytale:
    environment:
      HYTALE_UNIVERSE_DOWNLOAD_URLS: "https://example.com/my-universe.zip"
      HYTALE_UNIVERSE_DOWNLOAD_LIMIT_RATE: "5m"

      HYTALE_MODS_DOWNLOAD_URLS: "@/data/mods-urls.txt"
      HYTALE_MODS_DOWNLOAD_LIMIT_RATE: "2m"
```

Multiline example:

```yaml
services:
  hytale:
    environment:
      HYTALE_UNIVERSE_DOWNLOAD_URLS: |
        https://example.com/a.zip
        https://example.com/b.zip
      HYTALE_MODS_DOWNLOAD_URLS: |
        https://example.com/mod1.zip, https://example.com/mod2.zip
        https://example.com/mod3.zip
```

These are additions to your service definition, not standalone Compose files. Take an existing world offline and preserve a backup before forcing downloads into its data directory.
