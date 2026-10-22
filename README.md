# WireGuard VPN Implementation — Remote-Access Network with Firewall + Internal DNS

I'm the main IT contact for a distributed team, so remote access has to just work.
This is the setup I'd build for that: a WireGuard hub for roaming clients, locked
down with host firewall rules, plus an internal DNS zone for VPN users. Keys, IPs,
and hostnames are placeholders.

**What this demonstrates:** WireGuard crypto-key routing, peer key management,
Linux firewall (nftables) design, NAT/masquerade for client internet access,
split/full-tunnel routing, internal DNS (dnsmasq), and end-to-end validation of
the full path: handshake → routing → DNS → internet egress.

```
                    ┌─────────────────────────────┐
                    │      VPN SERVER (wg0)       │
                    │   10.8.0.1/24  UDP 51820    │
                    │  ┌─────────┐  ┌──────────┐  │
                    │  │nftables │  │ dnsmasq  │  │
                    │  │firewall │  │corp.local│  │
                    │  └─────────┘  └──────────┘  │
                    └──────────────┬──────────────┘
                                   │ WireGuard
            ┌──────────────────────┼──────────────────────┐
            ▼                      ▼                      ▼
   ┌────────────────┐    ┌────────────────┐    ┌────────────────┐
   │ client-laptop  │    │ client-phone   │    │ client-server  │
   │  10.8.0.2/32   │    │  10.8.0.3/32   │    │  10.8.0.4/32   │
   └────────────────┘    └────────────────┘    └────────────────┘
```

## Repo layout

| Path | Purpose |
|---|---|
| `scripts/generate-keys.sh` | Creates Curve25519 keypairs for server + clients (run once) |
| `scripts/deploy-server.sh` | Brings up `wg0`, applies nftables firewall, starts dnsmasq |
| `scripts/add-client.sh` | Generates a new client keypair + config and appends the peer to the server |
| `server/wg0.conf.example` | Server config template (placeholders, no real keys) |
| `clients/client-template.conf.example` | Client config template |
| `firewall/nftables.conf` | Host firewall: allow 51820/udp, forward + masquerade, drop rest |
| `dns/dnsmasq.conf` | Internal DNS zone `corp.local` on the VPN interface |
| `docs/architecture.md` | Design decisions and topology |

## Quick start

```bash
# 1. Generate keys (private keys stay on disk, never committed)
./scripts/generate-keys.sh

# 2. Deploy the server (needs root)
sudo ./scripts/deploy-server.sh

# 3. Add a client
sudo ./scripts/add-client.sh alice
# -> writes clients/alice.conf — import it on the device
```

## Security notes

- Private keys are **never committed** (see `.gitignore`). Only `.example`
  templates with placeholders live in this repo.
- `wg0` accepts only authenticated peers; the host firewall drops everything
  inbound except UDP 51820 and established connections.
## Testing it

- Server and client configs pass `wg-quick strip` with no errors.
- Shell scripts pass `bash -n`, and the dnsmasq config passes `dnsmasq --test`.
- The nftables ruleset uses standard syntax and is checked when it's applied:
  `deploy-server.sh` runs `nft -f` and stops on any error.
- To test the tunnel end to end on a Linux host or cloud VM: check the
  handshake with `wg show`, `ping 10.8.0.1` from a client, and resolve an
  internal name with `dig @10.8.0.1 fileserver.corp.local`.
