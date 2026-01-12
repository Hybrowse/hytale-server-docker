 # Hytale Server Docker Image — by [Hybrowse](https://hybrowse.gg)
 
 Production-ready Docker image for dedicated Hytale servers.
 
 - **Image**: `ghcr.io/hybrowse/hytale-server`
 - **Repo**: `Hybrowse/hytale-server-docker`

 ## Community

 - **Discord**: https://hybrowse.gg/discord
 
 ## Quickstart (Docker Compose)
 
 Hytale uses **QUIC over UDP** (not TCP). Publish `5520/udp`.
 
 ```yaml
 services:
   hytale:
     image: ghcr.io/hybrowse/hytale-server:latest
     ports:
       - "5520:5520/udp"
     volumes:
       - ./data:/data
     restart: unless-stopped
 ```
 
 Start:
 
 ```bash
 docker compose up -d
 ```
 
 ## First-time authentication
 
 In the server console:
 
 ```text
 /auth login device
 ```

 ## Why this image

 - **Security-first defaults** (least privilege; credentials/tokens treated as secrets)
 - **Operator UX** (clear startup validation and actionable errors)
 - **Performance-aware** (sane JVM defaults; optional AOT cache usage)
 - **Predictable operations** (documented data layout and upgrade guidance)

 ## Planned features

 See [`ROADMAP.md`](ROADMAP.md) for details. Highlights:

 - **MVP**: non-root runtime, startup validation, minimal healthcheck, clear docs
 - **Operations**: safer upgrades, backup guidance, better logging ergonomics
 - **Observability**: metrics hooks / exporter guidance
 - **Provider-grade**: non-interactive auth flows and fleet patterns
 
 ## Documentation
 
 - [`docs/hytale/`](docs/hytale/): Notes from the official Hytale Server Manual
 - [`docs/image/`](docs/image/): Image usage & configuration
 
 ## Contributing & Security
 
 - [`CONTRIBUTING.md`](CONTRIBUTING.md)
 - [`SECURITY.md`](SECURITY.md)
 
 ## License
 
 See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
