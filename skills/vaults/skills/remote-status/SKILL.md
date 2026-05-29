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
  version: "0.1.3"
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

### 1. Collect host candidates (always run this first)

Run both commands and merge the results:

```bash
# SSH config
grep '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '\*'
# Shell rc files
grep -hEo '\bssh [a-zA-Z0-9_-]+\b|\b(HOST|host|REMOTE|remote)=[a-zA-Z0-9_-]+\b' \
  ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile ~/.profile 2>/dev/null \
  | grep -oE '[a-zA-Z0-9_-]+$' | sort -u
```

Also read the saved config if it exists:

```bash
python3 -c "
import os, yaml
p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
c = yaml.safe_load(open(p)) if os.path.exists(p) else {}
print((c or {}).get('remote', {}).get('host', ''))
" 2>/dev/null
```

### 2. Ask the user — REQUIRED, always call AskUserQuestion here

**This step is mandatory. Do not skip it. Do not substitute plain-text output.**

If a host was already given in `$ARGUMENTS` (any non-flag token) OR the config printed a non-empty host, skip this step and use that host.

Otherwise call `AskUserQuestion` with exactly these two questions:

**Q1** — header `"Host"`, question `"Which host should I check?"`:
- One option per discovered candidate (label = hostname, description = where it was found)
- Plus an "Enter manually" option

**Q2** — header `"Save config"`, question `"Save this host as the default for future runs?"`:
- `"Yes — save as default"` (recommended): writes `~/.geno-tools/geno-loops/config/config.yaml`
- `"No — one-time only"`: just use it now, don't write anything

After the user answers:
- If "Yes — save as default": run:
  ```bash
  mkdir -p ~/.geno-tools/geno-loops/config && python3 -c "
  import os, yaml
  p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
  c = (yaml.safe_load(open(p)) if os.path.exists(p) else None) or {}
  c.setdefault('remote', {})['host'] = 'CHOSEN_HOST'
  yaml.dump(c, open(p, 'w'))
  "
  ```
  Say: "Saved `CHOSEN_HOST` as default remote host."

### 3. Count live Claude processes

```bash
ssh <host> "ps aux | grep '[c]laude --dangerously' | wc -l"
```

Report the count. If 0, note that no loops appear to be running.

**Do NOT use any tmux introspection commands** (`tmux list-sessions`,
`tmux capture-pane`, `tmux display-message`, etc.) — these crash the tmux
server on z2. The only safe tmux command is `tmux new-session` and
`tmux send-keys`.

### 4. List tmux sessions via process list

Since tmux introspection is unsafe, infer sessions from the process table:

```bash
ssh <host> "ps aux | grep '[t]mux' | grep -v grep"
```

Show the raw lines — they contain the session name in the command args.

### 5. Read most recent iteration per loop

```bash
ssh <host> "find ~/geno-vault -name '*iter*.md' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -40"
```

Group by loop (parent directory of the iteration file). For each loop, show:
- Loop name (directory basename)
- Most recent iteration filename
- Age (current time minus mtime)

Flag loops whose most recent iteration is older than 1 hour as **stale**.

If `--stale-only`, suppress loops updated within the last hour.

### 6. Show dashboard.md

```bash
ssh <host> "cat ~/geno-vault/dashboard.md 2>/dev/null || echo '(no dashboard.md found)'"
```

Print the full contents. If the file doesn't exist, note it and suggest running
`/geno-loops-vaults-agent` to generate it.

### 7. Summary line

End with a one-line summary:

```
<host> — <N> claude processes | <N> loops total | <N> stale (>1h) | <N> missing
```

## Don'ts

- Never use `tmux list-sessions`, `tmux capture-pane`, `tmux display-message`,
  or any other tmux introspection command — they crash the tmux server on z2.
- **Never stop and tell the user to re-run with a host argument** — always use
  `AskUserQuestion` to collect the host interactively when config is missing.
- Don't SSH more times than necessary — batch steps 2–4 into a single
  compound SSH call if possible.
- Don't show raw process table dumps unless the user asks for verbose output.
