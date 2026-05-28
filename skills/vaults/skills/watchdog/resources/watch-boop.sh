#!/usr/bin/env bash
# Watch boop.md. When modified, restart the vault-agent loop immediately.
BOOP="~/.geno-tools/geno-loops/vault/boop.md"
SESSION="t20-vault-agent"
PROMPT="/loop 15m You are the VAULT AGENT. Read VAULT/t20-vault-agent/main.md for current state and the improvement queue. Regenerate dashboard, manage email schedule, ship one vault improvement per iteration. Atomically write+commit each iteration."

echo "[boop-watcher] monitoring $BOOP"
LAST_MOD=$(stat -c %Y "$BOOP" 2>/dev/null || echo 0)

while true; do
    sleep 2
    CURRENT_MOD=$(stat -c %Y "$BOOP" 2>/dev/null || echo 0)
    if [ "$CURRENT_MOD" != "$LAST_MOD" ]; then
        echo "[boop] $(date +%I:%M%p) — waking vault-agent"
        
        # Kill existing claude in the session
        tmux send-keys -t "$SESSION" C-c 2>/dev/null
        sleep 2
        tmux send-keys -t "$SESSION" C-c 2>/dev/null
        sleep 2
        
        # Restart claude
        tmux send-keys -t "$SESSION" "claude --dangerously-skip-permissions" Enter 2>/dev/null
        sleep 12
        tmux send-keys -t "$SESSION" Enter 2>/dev/null
        sleep 3
        tmux send-keys -t "$SESSION" "$PROMPT" Enter 2>/dev/null
        sleep 2
        tmux send-keys -t "$SESSION" Enter 2>/dev/null
        
        echo "[boop] vault-agent restarted"
        LAST_MOD=$(stat -c %Y "$BOOP" 2>/dev/null || echo 0)
    fi
done
