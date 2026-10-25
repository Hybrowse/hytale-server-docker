# Java and AOT

Defaults are image defaults unless marked as server defaults. Empty/unset values are not passed unless described otherwise.

| Variable | Default | Description |
| --- | --- | --- |
| `HYTALE_AOT_PATH` | `/data/server/HytaleServer.aot` | Path to the AOT cache file. |
| `TZ` | *(empty)* | Optional timezone name (for example `Europe/Berlin`). If set, passed to the JVM as `-Duser.timezone=...`. |
| `JVM_XMS` | *(empty)* | Passed as `-Xms...` (initial heap). |
| `JVM_XMX` | *(empty)* | Passed as `-Xmx...` (max heap). |
| `HYTALE_JAVA_TERMINAL_PROPS` | `true` | If `true`, sets terminal-related JVM properties (`-Dterminal.jline=...`, `-Dterminal.ansi=...`). |
| `JVM_TERMINAL_JLINE` | `false` | Used when `HYTALE_JAVA_TERMINAL_PROPS=true`: passed as `-Dterminal.jline=...`. |
| `JVM_TERMINAL_ANSI` | `true` | Used when `HYTALE_JAVA_TERMINAL_PROPS=true`: passed as `-Dterminal.ansi=...`. |
| `JVM_EXTRA_ARGS` | *(empty)* | Extra JVM args appended to the `java` command. |
| `ENABLE_AOT` | `auto` | `auto\|true\|false\|generate` (controls `-XX:AOTCache=...`). |
