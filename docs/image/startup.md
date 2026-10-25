# Startup order

The startup sequence is fixed and relevant when combining auto-download and token broker:

1. Validate required files (`/data/Assets.zip`, `/data/server/HytaleServer.jar`) and run auto-download/update if enabled.
2. Install/update CurseForge mods (if configured).
3. Run pre-start universe/mod downloads (if configured).
4. Ensure `/data/server/config.json` exists and apply `HYTALE_CONFIG_*` patches.
5. Apply `CFG_*` interpolation.
6. Run Session Token Broker (if enabled and tokens are not already set).
7. Start the Java server process.

This means: if an earlier step fails or blocks (for example downloader auth on first run), the Session Token Broker step is not reached yet.

8. On a fresh authenticated server, queue Hytale device login if automatic login is enabled.

See [authentication](authentication.md) for the separate downloader and server logins.
