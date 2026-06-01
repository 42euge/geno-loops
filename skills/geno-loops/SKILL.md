---
name: geno-loops
description: >-
  Execution loop engines and track loops — turbocharge (spec-driven
  convergence), supercharge (long-running autonomous sessions), lemans
  (endurance laps), lemans-restart (kill/restart track loops).
  Use when user says /geno-loops.
allowed-tools: "Bash(*) Read(*) Edit(*) Write(*)"
license: MIT
metadata:
  author: 42euge
  version: "0.2.0"
---

# geno-loops

## Spec required

Every loop in this skill family expects a `--spec <path>` flag (or a first
positional argument) pointing to a `.genospecs.yaml` file authored via
`geno-specs`. The schema is defined in
`geno-specs/.specs/loops/loop-spec-schema.md`. At the end of every
iteration the loop MUST invoke the spec's `report_command` and surface
`report_path` to the user. If no spec is provided (or the path does not
resolve to a readable `.genospecs.yaml`), the loop MUST print

> Run /geno-specs-init first to author one

and stop without doing any work.

## Overview

Execution loop engines for autonomous and semi-autonomous agent work. Each
engine is a different strategy for sustained progress. Skills follow the
`{skillset}-{sub-skillset}-{skill}` pattern: `geno-loops-engines-{name}`.

| Skill | Slash command | Pattern |
|-------|---------------|---------|
| geno-loops-engines-turbocharge | /geno-loops-engines-turbocharge | Spec-driven convergence — iterate until all criteria pass |
| geno-loops-engines-supercharge | /geno-loops-engines-supercharge | Long-running autonomous sessions — 8-24h multi-cycle runs |
| geno-loops-tracks-lemans | /geno-loops-tracks-lemans | Endurance — long-haul iteration-on-worktree, one small verified change per lap |
| geno-loops-tracks-lemans-restart | /geno-loops-tracks-lemans-restart | Kill and restart all Le Mans loops from the registry |
</content>
</invoke>