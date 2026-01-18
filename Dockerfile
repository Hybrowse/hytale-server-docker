FROM eclipse-temurin:25-jre

RUN apt-get update \
  && apt-get install -y --no-install-recommends tini ca-certificates curl unzip jq \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -f hytale \
  && if ! id -u hytale >/dev/null 2>&1; then useradd -m -u 1000 -o -g hytale -s /usr/sbin/nologin hytale; fi \
  && touch /etc/machine-id \
  && chown hytale:hytale /etc/machine-id

RUN mkdir -p /data \
  && chown -R hytale:hytale /data

VOLUME ["/data"]
WORKDIR /data

COPY scripts/entrypoint.sh /usr/local/bin/hytale-entrypoint
COPY scripts/auto-download.sh /usr/local/bin/hytale-auto-download
COPY scripts/curseforge-mods.sh /usr/local/bin/hytale-curseforge-mods
COPY scripts/hytale-cli.sh /usr/local/bin/hytale-cli
RUN chmod 0755 /usr/local/bin/hytale-entrypoint /usr/local/bin/hytale-auto-download /usr/local/bin/hytale-curseforge-mods /usr/local/bin/hytale-cli

USER hytale

ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/hytale-entrypoint"]
