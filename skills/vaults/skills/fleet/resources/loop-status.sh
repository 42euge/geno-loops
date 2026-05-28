#!/usr/bin/env bash
# loop-status.sh — emit fleet-liveness rows.
#
# For each project (each non-empty steer/<Project>/ folder), report:
#   project   age_min   last_seen_pt12   latest_note   status_emoji
#
# Status thresholds (minutes since latest outbox note):
#   <  20   🟢 active
#   < 120   🟡 stale
#   >=120   🔴 dead

set -euo pipefail

cd "$(dirname "$0")/.."

now=$(date +%s)

# Walk every project that has a steer/ entry — that's our authoritative fleet list.
for sd in steer/*/; do
    proj=$(basename "$sd")
    [[ "$proj" == "vault-keeper" ]] && continue   # vault-agent itself, not a loop

    out_dir="outbox/$proj"
    if [[ ! -d "$out_dir" ]]; then
        printf "%s\t-\t-\t(no outbox dir)\t⚪\n" "$proj"
        continue
    fi

    # Latest regular file (not tmp/dotfile)
    latest=$(find "$out_dir" -maxdepth 1 -type f ! -name '.*' ! -name '*.tmp.*' -printf '%T@ %f\n' 2>/dev/null \
             | sort -rn | head -1)
    if [[ -z "$latest" ]]; then
        printf "%s\t-\t-\t(no notes yet)\t⚪\n" "$proj"
        continue
    fi

    mtime=${latest%% *}
    fname=${latest#* }
    mtime=${mtime%.*}                         # drop subsecond
    age_min=$(( (now - mtime) / 60 ))
    pt12=$(date -d "@$mtime" "+%-I:%M %p")

    if   [[ $age_min -lt  20 ]]; then emoji="🟢"
    elif [[ $age_min -lt 120 ]]; then emoji="🟡"
    else                              emoji="🔴"
    fi

    printf "%s\t%d\t%s\t%s\t%s\n" "$proj" "$age_min" "$pt12" "$fname" "$emoji"
done
