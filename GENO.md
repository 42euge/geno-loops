# geno-loops — Execution Loop Patterns

`geno-loops` provides a library of execution loop patterns for autonomous and semi-autonomous agent work. Each loop is a different strategy for sustained progress.

## Skills

| Skill | Pattern | Best for |
|-------|---------|----------|
| geno-loops-turbocharge | Spec-driven convergence | TDD, contract-first, migrations with known targets |
| geno-loops-cruise | Plan-driven sequential | Checklists, runbooks, multi-step refactors |
| geno-loops-boost | Pomodoro focus | Time-boxed deep work with periodic reflection |
| geno-loops-drift | Question-driven exploration | Research, investigation, discovery |
| geno-loops-ignition | Cold-start bootstrap | Turning a vague goal into a concrete blueprint |
| geno-loops-autopilot | Background monitoring | Watching CI, tests, lint, git for changes |

## Repo structure

```
geno-loops/
├── GENO.md
├── SKILL.md -> skills/geno-loops/SKILL.md
├── genotools.yaml
└── skills/
    ├── geno-loops/SKILL.md
    ├── geno-loops-turbocharge/SKILL.md
    ├── geno-loops-cruise/SKILL.md
    ├── geno-loops-boost/SKILL.md
    ├── geno-loops-drift/SKILL.md
    ├── geno-loops-ignition/SKILL.md
    └── geno-loops-autopilot/SKILL.md
```

Previously these skills lived in `geno-dev` as `geno-dev-loops-*`. They were extracted into their own skillset because loops are a cross-cutting pattern used by many skillsets, not just dev workflows.
