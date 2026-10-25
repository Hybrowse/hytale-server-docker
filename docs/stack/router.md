# Hyrouter integration

Hyrouter accepts a Hytale connection and chooses a backend using routing rules and optional plugins. It sends a client referral, after which the player connects to the backend directly.

## What to configure

- Publish the router's UDP entrypoint for players.
- Give every selected backend an address and UDP port reachable by those players. A Docker-internal service name is usually not reachable by a remote game client.
- Authenticate each game server independently, using its own persisted login or the broker integration.
- Configure routing and any referral-validation plugin using the router's documentation.

The router does not forward gameplay traffic. Allowing traffic only to the router while hiding all backend addresses behind an unreachable private network does not provide a working referral setup.

## Diagnose a failed referral

First verify a direct client connection to the selected backend. If direct access works, inspect the router's selected target, advertised address, TLS/QUIC negotiation and referral logs. Test with the client version supported by your router release.

A successful `doctor` report on the backend does not test the router's handshake or prove that a remote client can follow a referral.

For full configuration, deployment and plugin options, use the [Hyrouter documentation](https://github.com/Hybrowse/hyrouter/blob/main/docs/README.md). This site documents how the server image fits into the stack; the router repository remains the source for its own settings.
