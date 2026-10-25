# Java, memory and AOT

The official Hytale server requires Java 25.
This image uses **Adoptium / Eclipse Temurin 25**, with a minimum runtime version
of **25.0.5** (`eclipse-temurin:25-jre-noble`, pinned to a digest).
While the official Docker image is still on 25.0.4.1, the build installs the official
25.0.5 JRE archive for AMD64 or ARM64 and verifies its SHA-256 checksum.
Newer runtimes in the base image are kept. Use `java -version` inside the container
to check the installed runtime.

## Heap sizing

If `JVM_XMS` / `JVM_XMX` are not set, the JVM will pick defaults (based on available container memory).
This is usually fine for testing, but for predictable production operation you should set at least `JVM_XMX` to an explicit limit.
There are no universal best-practice values; monitor RAM/CPU usage for your player count and playstyle and experiment with different values.
If you see high CPU usage from garbage collection, that can be a symptom of memory pressure and an `JVM_XMX` value that is too low.
In that case, try increasing `JVM_XMX` (or reducing view distance / workload) and compare behavior.

You can optionally set `JVM_XMS` as well. Keeping `JVM_XMS` lower than `JVM_XMX` allows the heap to grow as needed.
Setting `JVM_XMS` equal to `JVM_XMX` can reduce heap resizing overhead but increases baseline memory usage.

```yaml
services:
  hytale:
    environment:
      JVM_XMS: "2G"
      JVM_XMX: "6G"
```

Leave memory outside the heap for threads, native libraries and filesystem cache. A 6G heap needs a container limit larger than 6G. [Doctor](diagnostics.md) checks explicit heap settings against detected cgroup limits.

## AOT cache

Hytale ships with a pre-trained AOT cache (`HytaleServer.aot`), but AOT caches require a compatible Java runtime.
If you see AOT cache errors during startup, generate a cache that matches the Java version/build inside the container.

AOT caches are also architecture-specific (e.g. `linux/amd64` vs `linux/arm64`).
If you switch the container platform (or move the `/data` volume between machines), delete and regenerate the cache.
If the cache is incompatible (for example shipped for a different architecture), `ENABLE_AOT=auto` should ignore it and continue startup.
For strict diagnostics, use `ENABLE_AOT=true` (fails fast). For normal operation, prefer `ENABLE_AOT=auto`.

- `ENABLE_AOT=auto` (default): enables AOT only when the cache file exists.
- `ENABLE_AOT=true`: requires the cache file to exist and fails fast otherwise.
- `ENABLE_AOT=false`: do not use AOT.
- `ENABLE_AOT=generate`: generates an AOT cache at `HYTALE_AOT_PATH`, then exits.

If you see Java warnings about restricted native access (e.g. Netty), you can set:

- `JVM_EXTRA_ARGS=--enable-native-access=ALL-UNNAMED`

## Machine identity

The Hytale server reads `/etc/machine-id` to generate a stable hardware UUID.
In Docker containers, this file is typically missing or read-only.
This image automatically generates a stable machine ID and persists it in `/data/.machine-id`.

The machine ID is used by the Hytale server to encrypt the `auth.enc` file (which stores authentication credentials from `/auth login device`).
This image replicates the standard Linux behavior where `/etc/machine-id` is readable by all processes.

You can override the auto-generated machine ID:

```yaml
services:
  hytale:
    environment:
      HYTALE_MACHINE_ID: "0123456789abcdef0123456789abcdef"
```

The value must be exactly 32 lowercase hexadecimal characters (no dashes).
