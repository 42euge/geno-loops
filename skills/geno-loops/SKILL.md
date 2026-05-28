---
name: geno-loops
description: >-
  Execution loop engines — turbocharge (spec-driven convergence), cruise
  (plan-driven sequential), boost (pomodoro focus), drift (question-driven
  exploration), ignition (cold-start bootstrap), autopilot (background
  monitoring), supercharge (long-running autonomous sessions), dynamic
  (adaptive self-paced), lemans (endurance), lemans-restart (kill/restart).
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
| geno-loops-engines-cruise | /geno-loops-engines-cruise | Plan-driven sequential — execute steps one at a time |
| geno-loops-engines-boost | /geno-loops-engines-boost | Pomodoro focus — time-boxed blocks with reflection |
| geno-loops-engines-drift | /geno-loops-engines-drift | Question-driven exploration — prioritized Q queue |
| geno-loops-engines-ignition | /geno-loops-engines-ignition | Cold-start bootstrap — turn goal into blueprint |
| geno-loops-engines-autopilot | /geno-loops-engines-autopilot | Background monitoring — watch CI/tests/lint/git |
| geno-loops-engines-supercharge | /geno-loops-engines-supercharge | Long-running autonomous sessions — 8-24h multi-cycle runs |
| geno-loops-engines-dynamic | /geno-loops-engines-dynamic | Adaptive self-paced — EMA-steps interval toward iteration duration + buffer |
| geno-loops-engines-lemans | /geno-loops-engines-lemans | Endurance — long-haul iteration-on-worktree, one small verified change per lap |
| geno-loops-engines-lemans-restart | /geno-loops-engines-lemans-restart | Kill and restart all Le Mans loops from the registry |
</content>
</invoke>