# Console commands and diagnostics

Run `hytale-cli` inside the server container with `docker compose exec hytale`. Kubernetes users can use `kubectl exec <pod> -c hytale-server --` instead.

| Command | What it does |
| --- | --- |
| `hytale-cli auth login` | Queue encrypted persistence and a server device login |
| `hytale-cli auth select <name-or-number>` | Select a profile offered by Hytale |
| `hytale-cli auth status` | Send an auth-status request; read the result in server logs |
| `hytale-cli send <command>` | Send a command to the live console |
| `hytale-cli doctor` | Read-only local diagnostic checks |
| `hytale-cli status` | Same checks as `doctor`, not live auth status |
| `hytale-cli report` | Allowlisted JSON diagnostic report |

## Send a command

```sh
docker compose exec hytale hytale-cli send "/say Server restart in five minutes"
```

Console commands require a running server and the default `HYTALE_CONSOLE_PIPE=true`. They queue commands rather than returning the server's response; read the logs afterward.

Send multiple commands from standard input:

```sh
printf '%s\n' '/auth status' '/say Maintenance complete' | docker compose exec -T hytale hytale-cli send
```

Setting `HYTALE_CONSOLE_PIPE=false` disables console injection and automatic first-start login. Read-only diagnostics still work. The FIFO path can be changed with `HYTALE_CONSOLE_FIFO`; normally the default `/tmp/hytale-console.fifo` is sufficient.

## Collect a support report

```sh
docker compose exec -T hytale hytale-cli report > hytale-report.json
```

The redirection writes the file on your host. See [Doctor](diagnostics.md) for privacy, flags, exit codes and the distinction between local checks and live server readiness.
