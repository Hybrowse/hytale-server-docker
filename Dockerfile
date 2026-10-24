FROM eclipse-temurin:25-jre-noble@sha256:3f2223fe04b750aa5a8179e29b5c9a1ddf7665fc9bb08bfe11ad01d143bc13a5

ARG TARGETARCH

RUN apt-get update \
  && apt-get install -y --no-install-recommends tini ca-certificates curl unzip jq zlib1g \
  && if [ "${TARGETARCH:-$(dpkg --print-architecture)}" = arm64 ]; then \
       apt-get install -y --no-install-recommends qemu-user-static; \
       find /usr/bin -maxdepth 1 -name 'qemu-*-static' ! -name qemu-x86_64-static -delete; \
     fi \
  && rm -rf /var/lib/apt/lists/*

# The October security release is available before the official Docker images.
# Keep newer base runtimes when the upstream image catches up.
RUN set -eu; \
  current="$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java.version = //p')"; \
  if dpkg --compare-versions "${current}" ge 25.0.5; then exit 0; fi; \
  case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
    amd64) arch=x64; checksum=6fac98f0c8202efc3135a9e9e42aa61963ec42d1c5cbb40caf231e7b14a24ef6 ;; \
    arm64) arch=aarch64; checksum=963931723891302ebb2687178532c3d793d71e2577cd058061c7efb396140a86 ;; \
    *) echo "Unsupported Java runtime architecture" >&2; exit 1 ;; \
  esac; \
  curl -fsSL "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jre_${arch}_linux_hotspot_25.0.5_8.tar.gz" -o /tmp/temurin-jre.tar.gz; \
  printf '%s  %s\n' "${checksum}" /tmp/temurin-jre.tar.gz | sha256sum -c -; \
  runtime_dir="$(mktemp -d)"; \
  tar -xzf /tmp/temurin-jre.tar.gz -C "${runtime_dir}" --strip-components=1; \
  chmod 0755 "${runtime_dir}"; \
  rm -rf "${JAVA_HOME}"; \
  mv "${runtime_dir}" "${JAVA_HOME}"; \
  rm /tmp/temurin-jre.tar.gz; \
  java -version

RUN groupadd -f hytale \
  && if ! id -u hytale >/dev/null 2>&1; then useradd -m -u 1000 -o -g hytale -s /usr/sbin/nologin hytale; fi \
  && mkdir -p /data \
  && chown -R hytale:hytale /data \
  && rm -f /etc/machine-id \
  && ln -s /data/.machine-id /etc/machine-id

VOLUME ["/data"]
WORKDIR /data

COPY scripts/entrypoint.sh /usr/local/bin/hytale-entrypoint
COPY scripts/cfg-interpolate.sh /usr/local/bin/hytale-cfg-interpolate
COPY scripts/config-patch.sh /usr/local/bin/hytale-config-patch
COPY scripts/auto-download.sh /usr/local/bin/hytale-auto-download
COPY scripts/curseforge-mods.sh /usr/local/bin/hytale-curseforge-mods
COPY scripts/prestart-downloads.sh /usr/local/bin/hytale-prestart-downloads
COPY scripts/session-token-broker.sh /usr/local/bin/hytale-session-token-broker
COPY scripts/hytale-cli.sh /usr/local/bin/hytale-cli
COPY scripts/healthcheck.sh /usr/local/bin/hytale-healthcheck
RUN chmod 0755 /usr/local/bin/hytale-entrypoint /usr/local/bin/hytale-cfg-interpolate /usr/local/bin/hytale-config-patch /usr/local/bin/hytale-auto-download /usr/local/bin/hytale-curseforge-mods /usr/local/bin/hytale-prestart-downloads /usr/local/bin/hytale-session-token-broker /usr/local/bin/hytale-cli /usr/local/bin/hytale-healthcheck

RUN mkdir -p /usr/share/hytale
COPY defaults/server-config.json /usr/share/hytale/default-config.json

RUN mkdir -p /usr/share/licenses/hybrowse-hytale-server
COPY LICENSE LICENSE-APACHE-2.0 NOTICE LICENSING.md COMMERCIAL_LICENSE.md TRADEMARKS.md /usr/share/licenses/hybrowse-hytale-server/

USER hytale

HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 CMD ["/usr/local/bin/hytale-healthcheck"]

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/hytale-entrypoint"]
