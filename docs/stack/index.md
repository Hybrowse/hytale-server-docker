# Hybrowse server stack

A single server only needs the [game-server image](../image/quickstart.md). The broker and router address different needs and can be added independently.

| Component | Use it when | Owns |
| --- | --- | --- |
| Hytale server image | You want to run the game server | Worlds, mods, configuration, game files and server login |
| [Session Token Broker](broker.md) | Servers need centrally managed, non-interactive authentication | Long-lived OAuth state and short-lived session minting |
| [Hyrouter](router.md) | Players should be referred to a selected backend | Routing rules and referral decisions |

## Connection and authentication flow

1. A game server obtains its files through the downloader or manual provisioning.
2. It authenticates directly with Hytale, or obtains short-lived session/identity tokens from a broker at startup.
3. A client connects directly to a game server, or first visits Hyrouter and receives a backend referral.
4. After referral, the client connects to that backend itself.

The broker does not download game files. Hyrouter does not replace the game server's authentication or relay gameplay packets. Keep each component's credentials, persistence and network exposure separate.

See [startup order](../image/startup.md) when a configured component appears not to be called.
