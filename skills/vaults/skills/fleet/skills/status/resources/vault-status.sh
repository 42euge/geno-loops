#!/usr/bin/env bash
# vault-status.sh — fleet summary for the new layout.
#
# Reads loops.yaml session list. For each session, finds its latest
# iter note in either the canonical root-flat path
# (~/geno-vault/<session>/iterations/) or the legacy project-grouped
# path (~/geno-vault/<project>/<session>/iterations/), reports age,
# layout used, and whether the filename matches the canonical schema
# YYYY-MM-DDTHHMM-iter-NNN.md.
#
# Usage:
#   tools/vault-status.sh              # all sessions
#   tools/vault-status.sh --stale-only # only stale (>1h) or missing
#   tools/vault-status.sh --tsv        # tab-separated, machine-readable
#
# Exit 0 healthy, 1 if anything stale, missing, or schema-violating.

set -euo pipefail
CONFIG="${GENO_LOOPS_CONFIG:-$HOME/.geno-tools/geno-loops/config/config.yaml}"
VAULT="$(awk '/^vault_dir:/ {print $2}' "$CONFIG" | sed "s|~|$HOME|")"
cd "$VAULT"

stale_only=0
tsv=0
for arg in "$@"; do
  case "$arg" in
    --stale-only) stale_only=1 ;;
    --tsv)        tsv=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

mapfile -t pairs < <(awk '
  /^[[:space:]]*-[[:space:]]+session:[[:space:]]/ {
    sub(/^[[:space:]]*-[[:space:]]+session:[[:space:]]*/, "")
    s=$0
  }
  /^[[:space:]]+project:[[:space:]]/ {
    sub(/^[[:space:]]+project:[[:space:]]*/, "")
    print s "\t" $0
  }
' loops.yaml | sort -u)

now_epoch=$(date +%s)
schema_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{4}-iter-[0-9]+\.md$'

stale_count=0
missing_count=0
violation_count=0

if [ "$tsv" -eq 0 ]; then
  printf '%-22s %-15s %-19s %6s  %-10s %s\n' \
    "SESSION" "PROJECT" "LAST ITER (LOCAL)" "AGE" "LAYOUT" "SCHEMA"
  printf '%s\n' "----------------------------------------------------------------------------------------------"
fi

for pair in "${pairs[@]}"; do
  session="${pair%%$'\t'*}"
  project="${pair##*$'\t'}"

  iter_dir=""
  layout="-"
  if [ -d "$session/iterations" ]; then
    iter_dir="$session/iterations"
    layout="root"
  elif [ -d "$project/$session/iterations" ]; then
    iter_dir="$project/$session/iterations"
    layout="project"
  fi

  if [ -z "$iter_dir" ]; then
    missing_count=$((missing_count + 1))
    if [ "$tsv" -eq 1 ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$session" "$project" "" "" "missing" ""
    else
      printf '%-22s %-15s %-19s %6s  %-10s %s\n' \
        "$session" "$project" "-" "n/a" "missing" "-"
    fi
    continue
  fi

  latest=$(ls -1 "$iter_dir" 2>/dev/null | sort | tail -1 || true)
  if [ -z "$latest" ]; then
    missing_count=$((missing_count + 1))
    if [ "$tsv" -eq 1 ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$session" "$project" "" "" "$layout" "empty"
    else
      printf '%-22s %-15s %-19s %6s  %-10s %s\n' \
        "$session" "$project" "(empty)" "n/a" "$layout" "-"
    fi
    continue
  fi

  schema_ok="ok"
  if ! [[ "$latest" =~ $schema_re ]]; then
    schema_ok="VIOLATION"
    violation_count=$((violation_count + 1))
  fi

  ts="${latest%-iter-*}"
  date_part="${ts%T*}"
  hhmm="${ts#*T}"
  iso_local="${date_part}T${hhmm:0:2}:${hhmm:2:2}:00"
  if iter_epoch=$(TZ=America/Los_Angeles date -d "$iso_local" +%s 2>/dev/null); then
    age_sec=$((now_epoch - iter_epoch))
  else
    age_sec=-1
  fi

  if [ "$age_sec" -lt 0 ]; then age_str="?"
  elif [ "$age_sec" -lt 60 ]; then age_str="${age_sec}s"
  elif [ "$age_sec" -lt 3600 ]; then age_str="$((age_sec / 60))m"
  elif [ "$age_sec" -lt 86400 ]; then age_str="$((age_sec / 3600))h"
  else age_str="$((age_sec / 86400))d"
  fi

  is_stale=0
  [ "$age_sec" -ge 3600 ] && is_stale=1
  [ "$age_sec" -lt 0 ] && is_stale=1
  [ "$is_stale" -eq 1 ] && stale_count=$((stale_count + 1))

  if [ "$stale_only" -eq 1 ] && [ "$is_stale" -eq 0 ] && [ "$schema_ok" = "ok" ]; then
    continue
  fi

  if [ "$tsv" -eq 1 ]; then
    printf '%s\t%s\t%s %s\t%s\t%s\t%s\n' \
      "$session" "$project" "$date_part" "${hhmm:0:2}:${hhmm:2:2}" \
      "$age_str" "$layout" "$schema_ok"
  else
    printf '%-22s %-15s %-19s %6s  %-10s %s\n' \
      "$session" "$project" "${date_part} ${hhmm:0:2}:${hhmm:2:2}" \
      "$age_str" "$layout" "$schema_ok"
  fi
done

if [ "$tsv" -eq 0 ]; then
  echo
  echo "stale (>1h): $stale_count   missing: $missing_count   schema violations: $violation_count"
fi

if [ "$stale_count" -gt 0 ] || [ "$missing_count" -gt 0 ] || [ "$violation_count" -gt 0 ]; then
  exit 1
fi
exit 0
