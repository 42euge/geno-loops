#!/usr/bin/env bash
# time-helpers.sh — common time formatters for the vault.
#
#   pt12      — current PT in 12hr (e.g. "9:39 PM")
#   utc24     — current UTC iso (e.g. "2026-05-27T04:39Z")
#   next15    — next */15 cron tick in 12hr PT (e.g. "9:45 PM")
#   countdown — minutes until the next */15 tick (e.g. "6 min")

set -euo pipefail

pt12()    { date "+%-I:%M %p %Z"; }
utc24()   { date -u "+%Y-%m-%dT%H:%MZ"; }

next15() {
    local mm
    mm=$(date +%M)
    local rem=$((15 - (10#$mm % 15)))
    [[ $rem -eq 0 ]] && rem=15
    date -d "+${rem} minutes" "+%-I:%M %p %Z"
}

countdown() {
    local mm
    mm=$(date +%M)
    local rem=$((15 - (10#$mm % 15)))
    [[ $rem -eq 0 ]] && rem=15
    echo "${rem} min"
}

case "${1:-}" in
    pt12)      pt12 ;;
    utc24)     utc24 ;;
    next15)    next15 ;;
    countdown) countdown ;;
    *)
        echo "Usage: $0 {pt12|utc24|next15|countdown}" >&2
        exit 1
        ;;
esac
