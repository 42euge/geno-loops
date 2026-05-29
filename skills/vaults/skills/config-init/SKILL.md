---
name: geno-loops-config-init
description: >-
  Initialize geno-loops runtime config — creates ~/.geno-tools/geno-loops/config/
  and writes config.yaml from an interactive prompt. Use when user says
  /geno-loops-config-init or when no config exists at first run.
argument-hint: "[--force]"
allowed-tools: "Bash(*) Read(*) Write(*)"
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
---

# geno-loops-config-init — Runtime Config Setup

Initialize the geno-loops runtime config at `~/.geno-tools/geno-loops/config/config.yaml`.
This config is read by all vault skills (`remote-status`, `client`, etc.) to locate the
remote host and vault path.

## When to invoke

- User says `/geno-loops-config-init`
- A vault skill reports "no config found" or prompts for init
- First-time setup on a new machine

## Input

Optional `--force` flag — overwrite an existing config without asking.

## Workflow

### 1. Check for existing config

```bash
python3 -c "
import os, yaml
p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
if os.path.exists(p):
    c = yaml.safe_load(open(p)) or {}
    print('EXISTS')
    print(yaml.dump(c, default_flow_style=False))
else:
    print('MISSING')
" 2>/dev/null
```

If the output starts with `EXISTS` **and** `--force` was NOT passed:

- Show the current values to the user.
- Call `AskUserQuestion` with:
  - header `"Config exists"`, question `"Config already exists. Overwrite?"`:
    - `"Yes, overwrite"` — continue to step 2
    - `"No, keep existing"` — stop and say "Keeping existing config. No changes made."

If output is `MISSING` or `--force` was passed, proceed directly to step 2.

### 2. Collect candidate remote hosts

```bash
{ grep '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '\*';
  grep -hEo '\bssh [a-zA-Z0-9_-]+\b|\b(HOST|host|REMOTE|remote)=[a-zA-Z0-9_-]+\b' \
    ~/.bashrc ~/.zshrc ~/.bash_profile ~/.zprofile ~/.profile 2>/dev/null \
    | grep -oE '[a-zA-Z0-9_-]+$'; } | sort -u
```

Save the list. Rank candidates: prefer hosts whose name appears in `~/code/` directory
names, `CLAUDE.md`, or recent git remotes — put the best match **first** and mark it
`"(best guess)"`.

### 3. Prompt for host and vault path

Call `AskUserQuestion` with **two questions in the same call**:

**Q1** — header `"Remote host"`, question `"Which host runs your geno-vault loops?"`:
- One option per discovered candidate (best guess first, marked `"(best guess)"`)
- Last option: `"Enter manually"`

**Q2** — header `"Vault path"`, question `"Where is your geno-vault on the remote?"`:
- `"~/geno-vault (default)"`
- `"Enter custom path"`

If the user selects `"Enter manually"` for Q1, ask for the hostname as a follow-up.
If the user selects `"Enter custom path"` for Q2, ask for the full path as a follow-up.

### 4. Write config

```bash
mkdir -p ~/.geno-tools/geno-loops/config
python3 -c "
import os, yaml
p = os.path.expanduser('~/.geno-tools/geno-loops/config/config.yaml')
c = (yaml.safe_load(open(p)) if os.path.exists(p) else None) or {}
c['remote'] = {'host': 'CHOSEN_HOST', 'vault_path': 'CHOSEN_VAULT_PATH'}
yaml.dump(c, open(p, 'w'), default_flow_style=False)
"
```

Replace `CHOSEN_HOST` and `CHOSEN_VAULT_PATH` with the values collected in step 3.

### 5. Confirm

Read back the written file and display it:

```bash
cat ~/.geno-tools/geno-loops/config/config.yaml
```

Say: "Config written to `~/.geno-tools/geno-loops/config/config.yaml`." then show the
YAML content.

Suggest next steps:
- Run `/geno-loops-vaults-remote-status` to verify the host is reachable and loops are alive.
- Run `/geno-loops-vaults-client` if you also need to set up local Obsidian sync.

## Don'ts

- Never overwrite an existing config without either `--force` or explicit user confirmation.
- Don't require `python3-yaml` — it ships with most Python 3 installs; if missing, fall back
  to writing the YAML manually with `Bash` heredoc.
- Don't expose SSH credentials or private keys in output.
