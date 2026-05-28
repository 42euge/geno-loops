#!/usr/bin/env bash
# Watchdog v5 — only touches loop sessions, never kills unrelated claude processes.
ulimit -n 65536
VAULT="${GENO_LOOPS_VAULT:-$HOME/.geno-tools/geno-loops/vault}"
REGISTRY="$VAULT/loops.yaml"
LOG="$VAULT/watchdog.log"

# Get session names and expected count from registry
SESSIONS=$(python3 -c "
import yaml
with open('$REGISTRY') as f:
    reg = yaml.safe_load(f)
for loop in reg['loops']:
    print(loop['session'])
" 2>/dev/null)

if [ -z "$SESSIONS" ]; then
    echo "$(date +%Y-%m-%dT%H:%M) WATCHDOG: could not read registry, aborting" >> "$LOG"
    exit 1
fi

EXPECTED=$(echo "$SESSIONS" | wc -l)

# Count only claude processes running inside known loop tmux sessions
RUNNING=0
DEAD_SESSIONS=""
while IFS= read -r session; do
    # Check if the tmux session exists and has a claude process
    if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -qx "$session"; then
        # Get the PID of the foreground process in that session's pane
        pane_pid=$(tmux list-panes -t "$session" -F "#{pane_pid}" 2>/dev/null | head -1)
        if [ -n "$pane_pid" ]; then
            # Check if any child of that pane is a claude process
            if pgrep -P "$pane_pid" -a 2>/dev/null | grep -q "claude\|node"; then
                RUNNING=$((RUNNING + 1))
            else
                DEAD_SESSIONS="$DEAD_SESSIONS $session"
            fi
        else
            DEAD_SESSIONS="$DEAD_SESSIONS $session"
        fi
    else
        DEAD_SESSIONS="$DEAD_SESSIONS $session"
    fi
done <<< "$SESSIONS"

if [ "$RUNNING" -ge "$EXPECTED" ]; then
    echo "$(date +%Y-%m-%dT%H:%M) OK: $RUNNING/$EXPECTED loop claudes running" >> "$LOG"
    exit 0
fi

echo "$(date +%Y-%m-%dT%H:%M) WATCHDOG: $RUNNING/$EXPECTED running, dead:$DEAD_SESSIONS" >> "$LOG"

# Restart only dead sessions — never touch sessions we don't own
python3 -c "
import yaml, subprocess, time, os, sys

registry = '$REGISTRY'
dead = '$DEAD_SESSIONS'.split()

with open(registry) as f:
    reg = yaml.safe_load(f)

loops_by_session = {loop['session']: loop for loop in reg['loops']}
email_rule = reg['email_rule']
steer_rule = reg['steer_rule']

for s in dead:
    if s not in loops_by_session:
        continue
    loop = loops_by_session[s]
    wd = loop['work_dir'].replace('~', os.path.expanduser('~'))

    # Kill only the claude inside this specific session (not all claudes)
    pane_pid = subprocess.run(
        ['tmux', 'list-panes', '-t', s, '-F', '#{pane_pid}'],
        capture_output=True, text=True
    ).stdout.strip()
    if pane_pid:
        subprocess.run(['pkill', '-P', pane_pid, '-f', 'claude'], capture_output=True)
        time.sleep(1)

    # Recreate session if it doesn't exist
    existing = subprocess.run(['tmux', 'list-sessions', '-F', '#{session_name}'],
                              capture_output=True, text=True).stdout.split()
    if s not in existing:
        subprocess.run(['tmux', 'new-session', '-d', '-s', s, '-c', wd], capture_output=True)

    # Start claude
    subprocess.run(['tmux', 'send-keys', '-t', s, 'claude --dangerously-skip-permissions', 'Enter'],
                   capture_output=True)

time.sleep(15)

for s in dead:
    if s not in loops_by_session:
        continue
    subprocess.run(['tmux', 'send-keys', '-t', s, '', 'Enter'], capture_output=True)

time.sleep(5)

for s in dead:
    if s not in loops_by_session:
        continue
    loop = loops_by_session[s]
    project = loop.get('project', s)
    interval = loop['interval']
    prompt = loop['prompt']
    steer = steer_rule.replace('{project}', project).replace('{session}', s)
    full = f'/loop {interval} {email_rule} {steer} --- {prompt}'
    subprocess.run(['tmux', 'send-keys', '-t', s, full, 'Enter'], capture_output=True)
    time.sleep(2)
    subprocess.run(['tmux', 'send-keys', '-t', s, '', 'Enter'], capture_output=True)
    time.sleep(1)
    print(f'restarted: {s}')
" >> "$LOG" 2>&1

echo "$(date +%Y-%m-%dT%H:%M) WATCHDOG: restart complete" >> "$LOG"
