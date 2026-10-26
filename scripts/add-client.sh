#!/usr/bin/env bash
# add-client.sh - add a new client peer.
# Usage: sudo ./add-client.sh <name>
# Generates the client's keypair and a ready-to-import config, then appends the
# peer to the running server (no server restart needed).
set -euo pipefail

NAME="${1:?usage: add-client.sh <client-name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ_DIR="$(dirname "$SCRIPT_DIR")"
KEY_DIR="$PROJ_DIR/keys"
SERVER_PUB="$(cat "$KEY_DIR/server.pub")"
# Next free IP = count existing client keys + 1
NEXT_IP=$(( $(ls "$KEY_DIR"/client*.key 2>/dev/null | wc -l) + 1 ))
CLIENT_IP="10.8.0.${NEXT_IP}"

umask 077
wg genkey > "$KEY_DIR/client-$NAME.key"
wg pubkey < "$KEY_DIR/client-$NAME.key" > "$KEY_DIR/client-$NAME.pub"
CLIENT_PRIV="$(cat "$KEY_DIR/client-$NAME.key")"
CLIENT_PUB="$(cat "$KEY_DIR/client-$NAME.pub")"

# Client config (full tunnel; SERVER_ENDPOINT must be set to your public IP/DNS)
cat > "$PROJ_DIR/clients/$NAME.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/32
DNS = 10.8.0.1

[Peer]
PublicKey = $SERVER_PUB
Endpoint = ${SERVER_ENDPOINT:-vpn.example.com}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Add peer to the live server and persist it in the config
wg set wg0 peer "$CLIENT_PUB" allowed-ips "$CLIENT_IP/32"
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# $NAME
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
EOF

echo "Client '$NAME' ready: $CLIENT_IP - import clients/$NAME.conf on the device."
echo "Set SERVER_ENDPOINT env var to the server's public IP/DNS before adding real clients."
