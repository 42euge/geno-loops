---
name: geno-loops
description: >-
  Execution loop patterns — turbocharge (spec-driven convergence), cruise
  (plan-driven sequential), boost (pomodoro focus), drift (question-driven
  exploration), ignition (cold-start bootstrap), autopilot (background monitoring),
  supercharge (long-running autonomous sessions), dynamic (adaptive self-paced).
  Use when user says /geno-loops.
license: MIT
metadata:
  author: 42euge
  version: "0.1.0"
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

Execution loop patterns for autonomous and semi-autonomous agent work.

| Skill | Slash command | Pattern |
|-------|---------------|---------|
| geno-loops-turbocharge | /geno-loops-turbocharge | Spec-driven convergence — iterate until all criteria pass |
| geno-loops-cruise | /geno-loops-cruise | Plan-driven sequential — execute steps one at a time |
| geno-loops-boost | /geno-loops-boost | Pomodoro focus — time-boxed blocks with reflection |
| geno-loops-drift | /geno-loops-drift | Question-driven exploration — prioritized Q queue |
| geno-loops-ignition | /geno-loops-ignition | Cold-start bootstrap — turn goal into blueprint |
| geno-loops-autopilot | /geno-loops-autopilot | Background monitoring — watch CI/tests/lint/git |
| geno-loops-supercharge | /geno-loops-supercharge | Long-running autonomous sessions — 8-24h multi-cycle runs |
| geno-loops-dynamic | /geno-loops-dynamic (alias /gl-dyn) | Adaptive self-paced — starts at 10min, EMA-steps interval toward iteration duration + buffer |
| geno-loops-lemans | /geno-loops-lemans (alias /gl-lemans) | Endurance — long-haul iteration-on-worktree, one small verified change per lap, ff-merged with log + reports |
