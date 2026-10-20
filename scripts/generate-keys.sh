#!/usr/bin/env bash
# generate-keys.sh — create WireGuard keypairs for the server and first clients.
# Idempotent: refuses to overwrite existing keys. Keys land in keys/ (gitignored).
set -euo pipefail

KEY_DIR="$(dirname "$0")/../keys"
mkdir -p "$KEY_DIR"
umask 077

gen() {
  local name="$1"
  if [[ -f "$KEY_DIR/$name.key" ]]; then
    echo "exists, skipping: $name"
    return
  fi
  wg genkey > "$KEY_DIR/$name.key"
  wg pubkey < "$KEY_DIR/$name.key" > "$KEY_DIR/$name.pub"
  echo "generated: $name"
}

gen server
gen client1
gen client2
echo "Keys in $KEY_DIR (do NOT commit this directory)."
