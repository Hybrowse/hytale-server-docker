# Read-only diagnostics

Run diagnostics inside the server container:

```sh
docker compose exec hytale hytale-cli doctor
# Same checks, JSON output suitable for a support request:
docker compose exec -T hytale hytale-cli report > hytale-report.json
```

Replace `hytale` with your Compose service name. With Kubernetes, use
`kubectl exec <pod> -- hytale-cli doctor` (select the server container with `-c`
if necessary). `hytale-cli status` is an alias for `doctor`.

Diagnostics also work with console injection disabled. They never start Java,
run mods or the downloader, send console commands, change files, initiate login,
refresh tokens, or mint game sessions. By default, they make no network requests.
The existing container health check is unchanged.

## What is checked

- Image version (release builds), architecture, Java release metadata and ARM64 downloader emulator.
- Server JAR and assets ZIP structure, readable configuration and selected invalid or conflicting settings.
- Data, server, temporary and backup directory permissions; free space, inodes and estimated update space.
- Cgroup memory and CPU quotas, explicit heap limits and estimated native-memory headroom.
- Matching Java processes and the configured UDP port in the container's network namespace.
- Presence and permissions of persistent authentication and downloader credentials, explicit token expiry when readable, and broker configuration.
- Persistent authentication identity, update configuration, staging/transaction/lock remnants and required AOT files.
- Mod archive counts and ZIP structure, without running mod code or reporting mod names.

An archive directory check does not read every asset. For a full ZIP CRC check:

```sh
docker compose exec hytale hytale-cli doctor --verify-archives
```

This streams all archive entries without extracting them and can take several
minutes and substantial disk I/O. Neither mode proves that JAR and assets belong
to the same release, or that mods are compatible with the server.

Space and heap headroom recommendations are estimates. Capacity needs depend on
world size, players, mods and backup retention. A detected update lock or staging
directory can belong to an active update; check the server before removing it.

## Optional network checks

```sh
docker compose exec hytale hytale-cli doctor --network --timeout 15s
```

This sends credential-free HTTPS HEAD requests to the Hytale OAuth endpoint and
downloader archive, plus a GET to the configured broker's `/healthz` when enabled.
It follows no redirects, sends no bearer token, and does not download server files.
Broker URLs containing user information, a query or a fragment are skipped.
The total network budget defaults to 10 seconds (maximum 30), starting after local
checks. It does not bound local archive verification.

HTTP responses only establish transport reachability; broker health does not
establish that an account can mint sessions. Proxy settings from the environment
may be used by the HTTP client. Endpoint URLs and response bodies are not reported.

## Interpreting results

Each check has a stable ID, a status and, where useful, a suggested next step:

| Status | Meaning |
| --- | --- |
| `ok` | The specific local check passed. |
| `info` | An observation, not a readiness guarantee. |
| `warning` | A possible problem or a prerequisite that needs attention. |
| `error` | A detected local problem. |
| `unknown` | Cannot be established with this read-only inspection. |

The report summary is `error`, `warning` or `ok`, in that order of precedence.
`ok` means no local warning or error was found; unknown checks remain unknown.
Exit codes are **0** without errors, **1** with errors, or **2** for invalid options.
`--strict` also returns 1 for warnings. Unknown checks do not fail the command.

In particular:

- An `auth.enc` file does not prove that it can be decrypted or that a live server is authenticated.
- Token expiry checks do not validate signatures. An expired downloader access token does not imply that its refresh token is unusable.
- A UDP socket does not prove that it belongs to Hytale, that Docker published the port, or that a firewall/router allows players through.
- Java metadata describes the configured runtime, not necessarily a custom running JVM.

Use server logs and `hytale-cli auth status` for live authentication evidence.
Use a real Hytale client from another network to verify external connectivity.

## Sharing a report

`report` and `doctor --json` use the same allowlisted JSON schema (`schema_version: 1`).
They include fixed diagnostic messages, numeric observations and validated numeric
version strings. They do not copy logs, environment dumps, configuration values,
passwords, tokens, profile/account names, arbitrary paths, URLs, process arguments
or raw exception messages. Human-readable output follows the same rules.

The report still describes your deployment (for example memory limits and enabled
features). Review it before posting publicly. Keep logs and credentials separate.
New checks may be added; consumers should tolerate unknown check IDs and fields.

If the container cannot start, inspect the mounted data without its entrypoint:

```sh
docker compose run --rm --no-deps --entrypoint hytale-cli hytale doctor --json
```

This diagnoses a separate container. A missing Java process or UDP listener is
expected in that case, and it cannot inspect the stopped container's runtime.
The diagnostic itself does not write to the mounted data.
