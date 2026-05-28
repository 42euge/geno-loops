#!/usr/bin/env bash
# Continuously sync local vault → remote host every 3 seconds.
# Changes you make in Obsidian appear on the remote host almost instantly.

CONFIG="${GENO_LOOPS_CONFIG:-$HOME/.geno-tools/geno-loops/config/config.yaml}"
REMOTE_HOST=$(awk '/^remote_host:/ {print $2}' "$CONFIG")
VAULT_DIR=$(awk '/^vault_dir:/ {print $2}' "$CONFIG" | sed "s|~|$HOME|")

LOCAL="${VAULT_DIR}/"
REMOTE="${REMOTE_HOST}:${VAULT_DIR}/"

echo "[vault-sync] $LOCAL → $REMOTE (every 3s)"
echo "[vault-sync] Ctrl-C to stop"

while true; do
    rsync -az --delete \
        --exclude='.git' \
        --exclude='.obsidian' \
        --exclude='node_modules' \
        "$LOCAL" "$REMOTE" 2>/dev/null
    sleep 3
done
