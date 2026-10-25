# Networking and player connections

Hytale uses QUIC over UDP. The default listen address is `0.0.0.0:5520` inside the container.

## Change the public port

To expose UDP 15520 on the Docker host while leaving the server's internal port unchanged:

```yaml
services:
  hytale:
    ports:
      - "15520:5520/udp"
```

Players connect to the host on port `15520`. `HYTALE_BIND` controls the address inside the container, not Docker's published host port. Usually it should remain `0.0.0.0:5520`; binding to `127.0.0.1` inside the container prevents normal outside connections.

## Check the connection in order

1. Confirm server login succeeded in the logs. Downloader authorization alone is insufficient.
2. Try a direct connection from the Docker host using the published port.
3. Try the host's LAN address from another computer.
4. For internet access, check the router's UDP forwarding, host firewall and any provider firewall/security group.
5. Test from another network to avoid relying on router NAT-loopback behavior.

A socket or successful transport probe is not a complete Hytale login test. [Doctor](diagnostics.md) deliberately reports external connectivity as unknown.

## Kubernetes

A `ClusterIP` Service is internal. Expose UDP with a compatible LoadBalancer or NodePort and configure the surrounding network accordingly. See [Kubernetes setup](kubernetes.md#exposing-the-udp-port).

## Hyrouter

Hyrouter refers players to a backend; it does not tunnel gameplay traffic. The client must reach both the router and the selected backend. See [router integration](../stack/router.md).
