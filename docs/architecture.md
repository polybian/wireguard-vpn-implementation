# Architecture & Design Decisions

## Topology

- **Server:** single WireGuard hub on `wg0`, address `10.8.0.1/24`, listening on UDP 51820.
- **Clients:** point-to-point `/32` addresses from the same /24 (`.2`, `.3`, …).
- **Crypto:** Curve25519 keypairs; each peer authenticates by public key. No
  passwords, no certificates to rotate: key rotation = swap one line.
- **DNS:** dnsmasq listens on `10.8.0.1:53`, authoritative for `corp.local`
  (e.g. `fileserver.corp.local → 10.8.0.10`), forwards everything else upstream.
- **Firewall (nftables):**
  - INPUT: allow UDP 51820 (WireGuard), allow loopback + established; drop rest.
  - FORWARD: allow `wg0 → wan` for internet egress; masquerade client source IPs.
  - Clients can reach each other only if explicitly allowed (default: isolated
    client subnets via per-peer `AllowedIPs`).

## Why WireGuard over OpenVPN/IPsec

- ~4k lines of code vs ~400k: smaller attack surface, easier to audit.
- Kernel-space: lower latency, simpler throughput story for remote users.
- Roaming: clients keep sessions across network changes (laptop lid
  close/open, phone switching Wi-Fi ↔ cellular), the exact pain point for a
  distributed workforce.

## Full-tunnel vs split-tunnel

Client template uses `AllowedIPs = 0.0.0.0/0` (full tunnel): all client
traffic, including DNS, goes through the VPN. For split-tunnel (only corporate
ranges through VPN), set `AllowedIPs = 10.8.0.0/24` instead.

## Hardening notes

- `PersistentKeepalive = 25` on clients behind NAT so the server can reach them.
- Server config sets `SaveConfig = false`; peers are managed via
  `scripts/add-client.sh` so the config file is the source of truth.
- In production, the server's private key lives with `0600` permissions and
  the host runs unattended-upgrades.
