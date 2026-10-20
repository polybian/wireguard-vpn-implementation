# WireGuard VPN Lab — Remote-Access Network with Firewall + Internal DNS


> **Note on sources:** This lab recreates a deployment I administered in a professional role. Company names, hostnames, IP addresses, keys, and tenant identifiers have been sanitized or replaced with placeholders for confidentiality.

A production-style remote-access VPN build, mirroring a real distributed-workforce deployment:
a WireGuard hub serving roaming clients, hardened with host firewall rules and an
internal DNS zone for VPN clients.

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
                    │  │firewall │  │lab.local │  │
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
| `dns/dnsmasq.conf` | Internal DNS zone `lab.local` on the VPN interface |
| `docs/architecture.md` | Design decisions and topology |
| `docs/interview-answers.md` | "How did you build this?" — talking points for interviews |

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
## Validation

- WireGuard server + client configs: parsed with `wg-quick strip` (no errors).
- Shell scripts: `bash -n` clean; dnsmasq: `dnsmasq --test` OK.
- nftables ruleset uses standard documented syntax; the sandbox container lacks
  conntrack kernel support for offline `nft --check`, so it must be applied on
  a real host (`deploy-server.sh` runs `nft -f` and will surface any error).
- **To fully test the tunnel**, deploy on a real Linux host or cloud VM and run:
  `wg show` (handshake), `ping 10.8.0.1` from a client, and
  `dig @10.8.0.1 fileserver.lab.local`.
