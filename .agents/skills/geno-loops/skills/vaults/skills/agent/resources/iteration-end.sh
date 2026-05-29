#!/usr/bin/env bash
# iteration-end.sh — run at the END of every vault-agent iteration.
#
# Stages and commits all changes as the vault-agent author so the next
# iteration's steering detector can correctly identify human-vs-agent edits.
#
# Usage:
#   ./tools/iteration-end.sh "iter-NNN: short summary"

set -euo pipefail

cd "$(dirname "$0")/.."

MSG="${1:-vault-agent: routine iteration}"

git add -A

# If nothing to commit, no-op cleanly
if git diff --cached --quiet; then
    echo "iteration-end: no changes to commit"
    exit 0
fi

# Author the commit explicitly so detect-steering.sh can find it.
GIT_AUTHOR_NAME="vault-agent" \
GIT_AUTHOR_EMAIL="vault-agent@local" \
GIT_COMMITTER_NAME="vault-agent" \
GIT_COMMITTER_EMAIL="vault-agent@local" \
git commit -m "$MSG" --quiet

NEW_SHA=$(git rev-parse --short HEAD)
echo "iteration-end: committed $NEW_SHA — $MSG"
