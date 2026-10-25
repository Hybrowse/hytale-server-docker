# Configure server and mod JSON files

Use `HYTALE_CONFIG_*` for common server settings. Use `CFG_*` when a JSON file already contains placeholders. Both run before Java starts.

## Server config patching (`HYTALE_CONFIG_*`)

On startup, this image ensures `/data/server/config.json` exists:

- If missing, it is created from a bundled default template.
- Then optional `HYTALE_CONFIG_*` overrides are applied.
- If the template is unavailable, the image does not pre-create `config.json`; the server creates it on first start.
  In that case, `HYTALE_CONFIG_*` overrides are skipped for that startup.

This works for both first start and existing servers and does not require `${CFG_*}` placeholders.

Convenience overrides:

- `HYTALE_CONFIG_SERVER_NAME`
- `HYTALE_CONFIG_MOTD`
- `HYTALE_CONFIG_PASSWORD` (**secret**)
- `HYTALE_CONFIG_MAX_PLAYERS`
- `HYTALE_CONFIG_MAX_VIEW_RADIUS`
- `HYTALE_CONFIG_DEFAULT_WORLD`
- `HYTALE_CONFIG_DEFAULT_GAME_MODE`

Advanced overrides:

- `HYTALE_CONFIG_PATCH_JSON` (must be a JSON object)
- `HYTALE_CONFIG_PATCH_JSON_SRC` (path to a file containing a JSON object)

`HYTALE_CONFIG_PATCH_JSON` and `HYTALE_CONFIG_PATCH_JSON_SRC` are mutually exclusive.

Patch behavior:

- Existing keys not mentioned in overrides are preserved.
- Nested objects are merged recursively.
- Convenience variables override conflicting keys from `HYTALE_CONFIG_PATCH_JSON`.
- Invalid JSON or invalid numeric values fail startup early (no partial writes).

Example:

```yaml
services:
  hytale:
    environment:
      HYTALE_CONFIG_SERVER_NAME: "My Server"
      HYTALE_CONFIG_MOTD: "Welcome"
      HYTALE_CONFIG_MAX_PLAYERS: "50"
      HYTALE_CONFIG_PATCH_JSON: '{"Defaults":{"World":"creative-island"}}'
```

## Config file interpolation (CFG_*)

On startup, this image can replace placeholders in JSON config files using environment variables.

By default, only `/data/server/config.json` is processed. With `HYTALE_CFG_INTERPOLATION_MODE=all`, JSON files under `/data/server/mods/` and `HYTALE_MODS_PATH` are processed too. Use `explicit` mode to choose additional paths.

Interpolation runs **after** CurseForge mod installation (if enabled) and **before** the server process is started.

### Placeholders

The entrypoint searches JSON string values for references to variables prefixed with `CFG_`.
You can use:

- `${CFG_FOO}`
- `$CFG_FOO`

### Typing rules (important)

There are two modes:

- If a JSON string value is **exactly** a placeholder, for example:

    - `"${CFG_MAX_PLAYERS}"`

  then the value is replaced with a **typed JSON value** when possible.
  The environment variable is interpreted as JSON via `jq fromjson`.
  Examples:

    - `CFG_MAX_PLAYERS=20` becomes `20`
    - `CFG_PUBLIC=true` becomes `true`
    - `CFG_NAME='"My Server"'` becomes `"My Server"`
    - `CFG_OBJ='{"a":1}'` becomes `{ "a": 1 }`

  If parsing as JSON fails, the value is used as a normal string.

- If the placeholder appears **inside a larger string**, for example:

    - `"Welcome to ${CFG_SERVER_NAME}!"`

  then the variable value is substituted as plain text.

### Enable/disable

- Enabled by default.
- To disable interpolation entirely, set:

    - `HYTALE_CFG_INTERPOLATION=false`

### Scope / performance / safety controls

To reduce startup time and avoid applying interpolation to plugin-generated data files, you can scope interpolation.

Modes:

- `HYTALE_CFG_INTERPOLATION_MODE=server-only` (default)

    - Only interpolates `/data/server/config.json`

- `HYTALE_CFG_INTERPOLATION_MODE=all`

    - Always interpolates `/data/server/config.json`
    - Also interpolates JSON files under `/data/server/mods/` and `HYTALE_MODS_PATH`

- `HYTALE_CFG_INTERPOLATION_MODE=explicit`

    - Always interpolates `/data/server/config.json`
    - Additionally interpolates only the paths listed in `HYTALE_CFG_INTERPOLATION_PATHS`

`HYTALE_CFG_INTERPOLATION_PATHS` accepts space-separated paths. Each entry can be:

- a file (relative to `/data/server/` or an absolute path)
- a directory (all `*.json` files beneath it will be processed)

Optional limits:

- `HYTALE_CFG_INTERPOLATION_MAX_BYTES` (empty by default)

    - If set to a number, skips JSON files larger than this size.

- `HYTALE_CFG_INTERPOLATION_EXCLUDE_PATHS` (empty by default)

    - Space-separated shell glob patterns matched against the full file path.
    - If a file matches, it is skipped.

Security note:

- `CFG_*` can be used for secrets if plugins only support secrets via config files.
- To reduce risk of accidental substitution into large/untrusted plugin-generated files (or files that might be exposed to players), prefer `server-only` or `explicit`.

### Example

```yaml
services:
  hytale:
    environment:
      CFG_SERVER_NAME: "My Server"
      CFG_MAX_PLAYERS: "20"
```

In JSON:

```json
{
  "name": "${CFG_SERVER_NAME}",
  "maxPlayers": "${CFG_MAX_PLAYERS}"
}
```
