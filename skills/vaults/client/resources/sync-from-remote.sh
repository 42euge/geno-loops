#!/usr/bin/env bash
# Pull changes FROM remote host → local every 5 seconds.
# Run alongside sync-to-remote.sh for bidirectional sync.

CONFIG="${GENO_LOOPS_CONFIG:-$HOME/.geno-tools/geno-loops/config/config.yaml}"
REMOTE_HOST=$(awk '/^remote_host:/ {print $2}' "$CONFIG")
VAULT_DIR=$(awk '/^vault_dir:/ {print $2}' "$CONFIG" | sed "s|~|$HOME|")

LOCAL="${VAULT_DIR}/"
REMOTE="${REMOTE_HOST}:${VAULT_DIR}/"

echo "[vault-pull] $REMOTE → $LOCAL (every 5s)"
echo "[vault-pull] Ctrl-C to stop"

while true; do
    rsync -az \
        --exclude='.git' \
        --exclude='.obsidian' \
        --exclude='node_modules' \
        --exclude='tools/sync-to-remote.sh' \
        --exclude='tools/sync-from-remote.sh' \
        "$REMOTE" "$LOCAL" 2>/dev/null
    sleep 5
done
