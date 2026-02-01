FROM eclipse-temurin:25-jre

RUN apt-get update \
  && apt-get install -y --no-install-recommends tini ca-certificates curl unzip jq \
  && rm -rf /var/lib/apt/lists/*

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
COPY scripts/auto-download.sh /usr/local/bin/hytale-auto-download
COPY scripts/curseforge-mods.sh /usr/local/bin/hytale-curseforge-mods
COPY scripts/prestart-downloads.sh /usr/local/bin/hytale-prestart-downloads
COPY scripts/session-token-broker.sh /usr/local/bin/hytale-session-token-broker
COPY scripts/hytale-cli.sh /usr/local/bin/hytale-cli
COPY scripts/healthcheck.sh /usr/local/bin/hytale-healthcheck
RUN chmod 0755 /usr/local/bin/hytale-entrypoint /usr/local/bin/hytale-cfg-interpolate /usr/local/bin/hytale-auto-download /usr/local/bin/hytale-curseforge-mods /usr/local/bin/hytale-prestart-downloads /usr/local/bin/hytale-session-token-broker /usr/local/bin/hytale-cli /usr/local/bin/hytale-healthcheck

RUN mkdir -p /usr/share/licenses/hybrowse-hytale-server
COPY LICENSE LICENSE-APACHE-2.0 NOTICE LICENSING.md COMMERCIAL_LICENSE.md TRADEMARKS.md /usr/share/licenses/hybrowse-hytale-server/

USER hytale

HEALTHCHECK --interval=30s --timeout=5s --start-period=10m --retries=3 CMD ["/usr/local/bin/hytale-healthcheck"]

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/hytale-entrypoint"]
