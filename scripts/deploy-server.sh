#!/usr/bin/env bash
# deploy-server.sh — bring up the WireGuard server with firewall + internal DNS.
# Run as root on a Linux host. Assumes keys already generated (generate-keys.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
KEY_DIR="$PROJ_DIR/keys"
WG_ADDR="10.8.0.1/24"
WG_PORT="51820"
WAN_IF="$(ip route show default | awk '{print $5; exit}')"

[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
[[ -f "$KEY_DIR/server.key" ]] || { echo "missing server key — run generate-keys.sh first"; exit 1; }

# Enable IPv4 forwarding (persist across reboots)
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -w net.ipv4.ip_forward=1

# Build the real server config from the template
SERVER_PRIV="$(cat "$KEY_DIR/server.key")"
CLIENT1_PUB="$(cat "$KEY_DIR/client1.pub")"
CLIENT2_PUB="$(cat "$KEY_DIR/client2.pub")"
sed -e "s|__SERVER_PRIVATE_KEY__|$SERVER_PRIV|" \
    -e "s|__CLIENT1_PUBLIC_KEY__|$CLIENT1_PUB|" \
    -e "s|__CLIENT2_PUBLIC_KEY__|$CLIENT2_PUB|" \
    "$PROJ_DIR/server/wg0.conf.example" > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Firewall
sed "s|__WAN_IF__|$WAN_IF|g" "$PROJ_DIR/firewall/nftables.conf" > /etc/nftables.conf
nft -f /etc/nftables.conf

# Internal DNS
cp "$PROJ_DIR/dns/dnsmasq.conf" /etc/dnsmasq.d/wireguard-lab.conf
systemctl restart dnsmasq

# WireGuard up
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0
systemctl enable wg-quick@wg0

echo "WireGuard server is up on ${WG_ADDR} (UDP ${WG_PORT}, WAN iface ${WAN_IF})"
wg show
