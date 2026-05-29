# geno-loops — Execution Loop Engines

`geno-loops` provides a library of execution loop engines for autonomous and semi-autonomous agent work. Each engine is a different strategy for sustained progress.

## Skills

| Skill | Slash command | Pattern | Best for |
|-------|---------------|---------|----------|
| geno-loops | /geno-loops | Umbrella | Entry point — routes to the right engine |
| geno-loops-engines-turbocharge | /geno-loops-engines-turbocharge | Spec-driven convergence | TDD, contract-first, migrations with known targets |
| geno-loops-engines-cruise | /geno-loops-engines-cruise | Plan-driven sequential | Checklists, runbooks, multi-step refactors |
| geno-loops-engines-boost | /geno-loops-engines-boost | Pomodoro focus | Time-boxed deep work with periodic reflection |
| geno-loops-engines-drift | /geno-loops-engines-drift | Question-driven exploration | Research, investigation, discovery |
| geno-loops-engines-ignition | /geno-loops-engines-ignition | Cold-start bootstrap | Turning a vague goal into a concrete blueprint |
| geno-loops-engines-autopilot | /geno-loops-engines-autopilot | Background monitoring | Watching CI, tests, lint, git for changes |
| geno-loops-engines-supercharge | /geno-loops-engines-supercharge | Long-running autonomous | 8–24h multi-cycle runs |
| geno-loops-engines-dynamic | /geno-loops-engines-dynamic | Adaptive self-paced | Recurring tasks with variable runtime |
| geno-loops-tracks-lemans | /geno-loops-tracks-lemans | Endurance | Long-haul worktree work, one small verified change per lap |
| geno-loops-tracks-lemans-restart | /geno-loops-tracks-lemans-restart | Kill/restart | Kill and restart all Le Mans loops from the registry |
| geno-loops-vaults-remote-status | /geno-loops-vaults-remote-status | Remote status | Live claude procs, tmux sessions, iteration recency, dashboard on a remote host |
| geno-loops-config-init | /geno-loops-config-init | Config init | Interactive setup of ~/.geno-tools/geno-loops/config/config.yaml |

## Repo structure

```
geno-loops/
├── GENO.md                          ← this file (source of truth)
├── AGENTS.md                        ← full copy of GENO.md
├── CLAUDE.md                        ← full copy of GENO.md
├── GEMINI.md                        ← full copy of GENO.md
├── LICENSE
├── genotools.yaml
├── skills.sh.json
├── SKILL.md -> skills/geno-loops/SKILL.md
├── .geno-loops/                     ← installer assets for this repo
│   ├── scripts/bootstrap.sh
│   ├── hooks/hooks.json
│   └── config/defaults.yaml
└── skills/
    ├── geno-loops/SKILL.md          ← umbrella skill
    ├── engines/                     ← strategy loops (name: geno-loops-engines-*)
    │   ├── turbocharge/SKILL.md
    │   ├── cruise/SKILL.md
    │   ├── boost/SKILL.md
    │   ├── drift/SKILL.md
    │   ├── ignition/SKILL.md
    │   ├── autopilot/SKILL.md
    │   ├── supercharge/SKILL.md
    │   └── dynamic/SKILL.md
    └── tracks/                   ← long-haul lap loops (name: geno-loops-tracks-*)
        └── lemans/
            ├── SKILL.md
            └── restart/SKILL.md  ← kill/restart all Le Mans loops
```

## Conventions

### Skill naming — two sub-skillsets

Skills follow the `{skillset}-{sub-skillset}-{skill}` three-segment pattern. Two sub-skillsets exist:

- **`engines`** — strategy loops (`geno-loops-engines-{name}`). Live in `skills/engines/{name}/`.
- **`tracks`** — long-haul lap loops (`geno-loops-tracks-{name}`). Live in `skills/tracks/{name}/`.

The leaf directory name is the short skill name (e.g. `turbocharge`, `lemans`). The fully-qualified name is in the `name:` frontmatter of each SKILL.md.

The umbrella skill (`geno-loops`) is the only one-segment name — it routes to the right sub-skillset.

### Adding a new engine

1. Create `skills/engines/{name}/SKILL.md` with `name: geno-loops-engines-{name}` in frontmatter.
2. Add it to the umbrella SKILL.md table in `skills/geno-loops/SKILL.md`.
3. Add it to `skills.sh.json` under the `"Engines"` grouping.
4. Update the skills table in this file (GENO.md).
5. Copy GENO.md → AGENTS.md, CLAUDE.md, GEMINI.md (see Agent instruction files below).
6. Bump the patch version in `genotools.yaml` and `skills/geno-loops/SKILL.md`.

### Adding a new track loop

Same steps, but use `skills/tracks/{name}/`, `name: geno-loops-tracks-{name}`, and the `"Tracks"` grouping in `skills.sh.json`.

### Command prefix aliasing

The full slash command for each engine is `/geno-loops-engines-{name}`. Short aliases (e.g. `/gl-dyn`, `/lemans`) may be registered via `geno-tools` config but are not part of the canonical skill name. The canonical name is always three segments.

### Versioning

`genotools.yaml` and the umbrella `skills/geno-loops/SKILL.md` frontmatter carry the version. Bump rules:
- **patch** — add/fix an engine, update docs
- **minor** — change the engines interface (spec schema, flags, output format)
- **major** — breaking change that requires callers to update

### Agent instruction files

`AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` are **full copies** of `GENO.md` — not pointers (`@./GENO.md`). After every edit to `GENO.md`, run:

```bash
cp GENO.md AGENTS.md && cp GENO.md CLAUDE.md && cp GENO.md GEMINI.md
```

Rationale: pointer files are fragile across agent runtimes and editor integrations. Full copies ensure every agent sees the same instructions regardless of runtime.

## History

Previously these skills lived in `geno-dev` as `geno-dev-loops-*`. They were extracted into their own skillset because loops are a cross-cutting pattern used by many skillsets, not just dev workflows.
