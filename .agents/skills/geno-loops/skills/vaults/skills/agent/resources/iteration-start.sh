#!/usr/bin/env bash
# iteration-start.sh — run at the START of every vault-agent iteration.
#
# Prints (to stdout):
#   - Current PT time (12hr) and UTC
#   - Next loop tick + countdown
#   - Steering detection: any human edits since last vault commit
#
# The vault agent reads this output, treats any STEERING blocks as user
# instructions, and folds them into the iteration's plan.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "================================================================"
echo "  VAULT-AGENT ITERATION START"
echo "  Now:        $(./tools/time-helpers.sh pt12)   ($(./tools/time-helpers.sh utc24))"
echo "  Next tick:  $(./tools/time-helpers.sh next15)   (~$(./tools/time-helpers.sh countdown))"
echo "================================================================"
echo

./tools/detect-steering.sh
