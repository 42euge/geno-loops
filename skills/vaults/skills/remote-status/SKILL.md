---
name: geno-loops-vaults-remote-status
description: >-
  Show what loops and Claude sessions are currently running on a remote host —
  live process count, tmux session list, most recent iteration per loop, and
  dashboard.md summary. Use when user says /geno-loops-vaults-remote-status or
  asks "what's running on my remote".
argument-hint: "[<host>] [--stale-only]"
allowed-tools: "Bash(*) Read(*)"
license: MIT
metadata:
  author: 42euge
  version: "0.2.0"
---

# geno-loops-vaults-remote-status — Remote Session Status

Show what's live on a remote host: Claude process count, tmux sessions, most
recent iteration timestamp per loop, and the vault dashboard summary.

## When to invoke

- User says `/geno-loops-vaults-remote-status`
- User asks "what's running on my remote", "what loops are alive", "check the remote"
- User wants to know if a loop died or stalled on a remote workstation

## Input

Optional positional `<host>` (e.g. `z2`, `user@hostname`). If omitted, read
`host` from `~/.geno-tools/geno-loops/config/config.yaml`. Pass `--stale-only`
to suppress healthy sessions and show only stale/missing/dead entries.

## Workflow

### 1. Check for a pre-configured host

If `$ARGUMENTS` contains a non-flag token (anything other than `--stale-only`), use it as the host and jump to step 3.

Otherwise run:
```bash
python3 -c "
import os, yaml
p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
c = yaml.safe_load(open(p)) if os.path.exists(p) else {}
print((c or {}).get('remote', {}).get('host', ''))
" 2>/dev/null
```
If it prints a non-empty host, use it and jump to step 3.

### 2. Init prompt — REQUIRED when no host is configured

**This step is mandatory. Call `AskUserQuestion` — do not output plain text and wait.**

First collect host candidates:
```bash
{ grep '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '\*';
  grep -hEo '\bssh [a-zA-Z0-9_-]+\b|\b(HOST|host|REMOTE|remote)=[a-zA-Z0-9_-]+\b' \
    ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile ~/.profile 2>/dev/null \
    | grep -oE '[a-zA-Z0-9_-]+$'; } | sort -u
```

Call `AskUserQuestion` with **three questions in the same call** (AskUserQuestion supports up to 4):

**Q1** — header `"Setup"`, question `"No remote host configured. What would you like to do?"`:
- `"Run init — set up config directory and save default host"` (recommended) — runs the init flow: creates `~/.geno-tools/geno-loops/config/` and writes `config.yaml` so future runs skip this prompt
- `"One-time — just check now, skip init"` — don't create anything, use the chosen host for this run only

**Q2** — header `"Host"`, question `"Which host?"`:

Run this single command and read the output — it produces the ranked, deduplicated host list:
```bash
python3 - <<'EOF'
import subprocess, os, re
from pathlib import Path

# Collect SSH config hosts
ssh_hosts = subprocess.getoutput("grep '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '[*?]'").splitlines()
# Collect rc file hosts  
rc_hosts = subprocess.getoutput(
  r"grep -hEo '\bssh [a-zA-Z0-9_-]+\b|\b(HOST|host|REMOTE|remote)=[a-zA-Z0-9_-]+\b' "
  r"~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile ~/.profile 2>/dev/null "
  r"| grep -oE '[a-zA-Z0-9_-]+$'"
).splitlines()

# Merge, deduplicate, filter noise
all_hosts = list(dict.fromkeys(ssh_hosts + rc_hosts))
all_hosts = [h for h in all_hosts if not h.startswith('-') and '.' not in h and len(h) > 1]
# Prefer short aliases: if a short name (<=6 chars, no internal dots) and a longer
# name share the same suffix, keep only the short one (e.g. keep "z2", drop "host-z2")
short = [h for h in all_hosts if len(h) <= 6 and '-' not in h]
all_hosts = [h for h in all_hosts if h in short or not any(h.endswith(s) for s in short if s != h)]

# Score by references in ~/code/ and CLAUDE.md
scores = {}
for h in all_hosts:
    try:
        n = int(subprocess.getoutput(f"grep -rl '{h}' ~/code/ ~/.claude/CLAUDE.md 2>/dev/null | wc -l").strip())
    except:
        n = 0
    scores[h] = n

ranked = sorted(all_hosts, key=lambda h: scores[h], reverse=True)
for i, h in enumerate(ranked):
    tag = " (best guess)" if i == 0 and scores[h] > 0 else ""
    print(f"{h}{tag}|{scores[h]} refs in ~/code/ and CLAUDE.md")
EOF
```

Each output line is `<label>|<description>`. The **first line** becomes option 1 in Q2 — its label already contains `(best guess)`. Pass all lines directly as options, then append `Enter manually|type a hostname or user@host` as the last option.

Do not reorder or relabel the output. Use it verbatim.

**Q3** — header `"Search more"`, question `"Search for additional hosts?"`:
- `"No — use list above"` (recommended)
- `"Yes — scan shell history"` — run `grep -h 'ssh ' ~/.bash_history ~/.zsh_history 2>/dev/null | grep -oE 'ssh [a-zA-Z0-9_@.-]+' | awk '{print $2}' | sort -u` and add any new unique hosts to Q2's list before proceeding
- `"Yes — scan recent git remotes"` — run `git -C ~ remote -v 2>/dev/null | grep -oE '@[a-zA-Z0-9_.-]+' | tr -d '@' | sort -u`

After the user answers:

- If Q3 = scan option: run the corresponding command, merge new hosts into the candidate list, then re-ask Q2 with the expanded list.
- If Q1 = **"Run init"**: run:
  ```bash
  mkdir -p ~/.geno-tools/geno-loops/config && python3 -c "
  import os, yaml
  p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
  c = (yaml.safe_load(open(p)) if os.path.exists(p) else None) or {}
  c.setdefault('remote', {})['host'] = 'CHOSEN_HOST'
  yaml.dump(c, open(p, 'w'))
  "
  ```
  Say: "Init complete — created `~/.geno-tools/geno-loops/config/config.yaml` with `CHOSEN_HOST` as default. Future runs will skip this prompt."
- If Q1 = **"One-time — just check now, skip init"**: proceed without writing config.

Use the host from Q2 for the rest of the workflow.

### 3. Detect if already running ON the target host

Before SSHing, check whether the current machine IS the target:

```bash
LOCAL_HOSTNAME=$(uname -n 2>/dev/null)
SSH_CONNECTION_SET="${SSH_CONNECTION:-}"
```

If `$LOCAL_HOSTNAME` matches `<host>` (exact or prefix), OR `$SSH_CONNECTION` is set (meaning this session itself came in over SSH), skip all `ssh <host>` calls and read files directly instead:

```bash
# Local fast-path — read directly
ps aux | grep '[c]laude --dangerously' | wc -l
ps aux | grep '[t]mux' | grep -v grep
find ~/geno-vault -name '*iter*.md' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -40
cat ~/geno-vault/dashboard.md 2>/dev/null || echo "(no dashboard.md found)"
```

Otherwise proceed with SSH in steps 4–7.

### 4. Count live Claude processes

```bash
ssh <host> "ps aux | grep '[c]laude --dangerously' | wc -l"
```

Report the count. If 0, note that no loops appear to be running.

**Do NOT use any tmux introspection commands** (`tmux list-sessions`,
`tmux capture-pane`, `tmux display-message`, etc.) — these can crash the tmux
server. The only safe tmux command is `tmux new-session` and `tmux send-keys`.

### 5. List tmux sessions via process list

Since tmux introspection is unsafe, infer sessions from the process table:

```bash
ssh <host> "ps aux | grep '[t]mux' | grep -v grep"
```

Show the raw lines — they contain the session name in the command args.

### 6. Read most recent iteration per loop

```bash
ssh <host> "find ~/geno-vault -name '*iter*.md' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -40"
```

Group by loop (parent directory of the iteration file). For each loop, show:
- Loop name (directory basename)
- Most recent iteration filename
- Age (current time minus mtime)

Flag loops whose most recent iteration is older than 1 hour as **stale**.

If `--stale-only`, suppress loops updated within the last hour.

### 7. Show dashboard.md

```bash
ssh <host> "cat ~/geno-vault/dashboard.md 2>/dev/null || echo '(no dashboard.md found)'"
```

Print the full contents. If the file doesn't exist, note it and suggest running
`/geno-loops-vaults-agent` to generate it.

### 8. Summary line

End with a one-line summary:

```
<host> — <N> claude processes | <N> loops total | <N> stale (>1h) | <N> missing
```

## Don'ts

- Never use `tmux list-sessions`, `tmux capture-pane`, `tmux display-message`,
  or any other tmux introspection command — these can crash the tmux server on some hosts.
- **Never stop and tell the user to re-run with a host argument** — always use
  `AskUserQuestion` to collect the host interactively when config is missing.
- Don't SSH more times than necessary — batch steps 2–4 into a single
  compound SSH call if possible.
- Don't show raw process table dumps unless the user asks for verbose output.
