#!/usr/bin/env bash
# email-window.sh — single source of truth for the loop email window.
#
# Window: 06:00 to 18:30 Pacific Time (America/Los_Angeles), every day.
#
# Usage:
#   tools/email-window.sh            # exit 0 inside window, 1 outside
#   tools/email-window.sh --print    # print "INSIDE" or "OUTSIDE: <reason>"
#   tools/email-window.sh --json     # {"inside": bool, "now_pt": "...",
#                                    #  "window": "06:00-18:30 PT",
#                                    #  "next_open_pt": "..."}
#
# Loops should call this before send_email. Centralizing here means
# changes to the email policy land in one place instead of in 19
# copy-pasted prompt strings.

set -euo pipefail

now_minutes=$(TZ=America/Los_Angeles date '+%-H * 60 + %-M' | bc)
inside=0
[ "$now_minutes" -ge 360 ] && [ "$now_minutes" -le 1110 ] && inside=1
# 360  = 06:00
# 1110 = 18:30

next_open_pt=""
if [ "$inside" -eq 0 ]; then
    if [ "$now_minutes" -lt 360 ]; then
        # Before 06:00 today
        next_open_pt=$(TZ=America/Los_Angeles date '+%Y-%m-%d 06:00 PT')
    else
        # After 18:30 today -> 06:00 tomorrow
        next_open_pt=$(TZ=America/Los_Angeles date -d 'tomorrow 06:00' '+%Y-%m-%d 06:00 PT')
    fi
fi

mode="${1:-exit}"
case "$mode" in
    --print)
        if [ "$inside" -eq 1 ]; then
            echo "INSIDE: $(TZ=America/Los_Angeles date '+%Y-%m-%d %H:%M PT') is in 06:00-18:30 PT"
        else
            now_pt=$(TZ=America/Los_Angeles date '+%Y-%m-%d %H:%M PT')
            echo "OUTSIDE: ${now_pt} is not in 06:00-18:30 PT (next open: ${next_open_pt})"
        fi
        ;;
    --json)
        now_pt=$(TZ=America/Los_Angeles date '+%Y-%m-%d %H:%M PT')
        if [ "$inside" -eq 1 ]; then
            printf '{"inside": true, "now_pt": "%s", "window": "06:00-18:30 PT"}\n' "$now_pt"
        else
            printf '{"inside": false, "now_pt": "%s", "window": "06:00-18:30 PT", "next_open_pt": "%s"}\n' \
                "$now_pt" "$next_open_pt"
        fi
        ;;
    --since-window-start)
        # Seconds since the current window's 06:00 PT (only meaningful when inside).
        if [ "$inside" -eq 1 ]; then
            start=$(TZ=America/Los_Angeles date -d 'today 06:00' '+%s')
            now=$(date '+%s')
            echo $((now - start))
        else
            echo 0
        fi
        ;;
    exit)
        [ "$inside" -eq 1 ] && exit 0 || exit 1
        ;;
    *)
        echo "usage: $0 [--print|--json|--since-window-start]" >&2
        exit 2
        ;;
esac

[ "$mode" != "exit" ] && [ "$inside" -eq 0 ] && exit 1
exit 0
