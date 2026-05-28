#!/usr/bin/env bash
# iter-restore.sh — start-of-iteration recovery helper.
#
# Run at the top of any vault-agent iteration to bring the working tree
# back in sync with HEAD after a watchdog rebuild or ad-hoc desync. The
# watchdog (`tools/watchdog.sh`, `*/5 * * * *`) restarts loops without
# touching the working tree, but the rsync sync-from-remote path can revert
# uncommitted edits and drop untracked files; this helper standardises
# the recovery sequence so iters don't re-derive it each time.
#
# What it does (in order):
#   1. cd to repo root
#   2. report current HEAD + git status
#   3. `git checkout HEAD -- .` to restore tracked files
#   4. `chmod +x tools/*.sh` so shell scripts stay executable
#   5. report what changed and what remains untracked/modified
#
# Usage:
#   tools/iter-restore.sh             # restore + report
#   tools/iter-restore.sh --check     # report only, no checkout
#   tools/iter-restore.sh --quiet     # restore, only print summary
#
# Exit codes:
#   0 — clean restore (or --check found nothing dirty)
#   1 — restore left untracked/modified state worth attention

set -euo pipefail

VAULT="${VAULT_DIR:-$HOME/geno-vault}"
MODE="restore"
QUIET=0

for arg in "$@"; do
    case "$arg" in
        --check) MODE="check" ;;
        --quiet) QUIET=1 ;;
        -h|--help)
            sed -n '2,22p' "$0"
            exit 0
            ;;
        *) echo "iter-restore: unknown arg: $arg" >&2; exit 2 ;;
    esac
done

cd "$VAULT"

HEAD_SHA=$(git rev-parse --short HEAD)
HEAD_MSG=$(git log -1 --pretty=%s)

if [ "$QUIET" -eq 0 ]; then
    echo "iter-restore: HEAD=$HEAD_SHA — $HEAD_MSG"
fi

if [ "$MODE" = "check" ]; then
    DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
    echo "iter-restore: --check, $DIRTY dirty path(s) (no changes made)"
    git status --short || true
    [ "$DIRTY" -eq 0 ] && exit 0 || exit 1
fi

# Restore tracked files to HEAD. Untracked files are preserved.
git checkout HEAD -- . 2>/dev/null || true

# Ensure shell helpers stay executable.
chmod +x tools/*.sh 2>/dev/null || true

REMAINING=$(git status --porcelain | wc -l | tr -d ' ')

if [ "$QUIET" -eq 0 ]; then
    if [ "$REMAINING" -eq 0 ]; then
        echo "iter-restore: clean (working tree matches HEAD)"
    else
        echo "iter-restore: $REMAINING path(s) still dirty after restore:"
        git status --short
    fi
fi

[ "$REMAINING" -eq 0 ]
