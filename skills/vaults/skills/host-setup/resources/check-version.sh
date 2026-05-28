#!/usr/bin/env bash
# check-version.sh — verify local and remote have the same geno-loops version.
#
# Reads remote_host from ~/.geno-tools/geno-loops/config/config.yaml and compares
# the genotools.yaml version field on both machines.
#
# Exit 0: versions match.
# Exit 1: versions differ or remote is unreachable.

set -euo pipefail

CONFIG="${GENO_LOOPS_CONFIG:-$HOME/.geno-tools/geno-loops/config/config.yaml}"
REMOTE_HOST=$(awk '/^remote_host:/ {print $2}' "$CONFIG")

# Find local genotools.yaml — search from this script up to the repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_MANIFEST=$(find "$SCRIPT_DIR" -name "genotools.yaml" | head -1)
if [[ -z "$LOCAL_MANIFEST" ]]; then
  # Fall back to installed location
  LOCAL_MANIFEST="$HOME/.geno-tools/geno-loops/active/genotools.yaml"
fi

if [[ ! -f "$LOCAL_MANIFEST" ]]; then
  echo "check-version: cannot find local genotools.yaml" >&2
  exit 1
fi

LOCAL_VERSION=$(awk '/^version:/ {gsub(/"/, "", $2); print $2}' "$LOCAL_MANIFEST")

REMOTE_VERSION=$(ssh "$REMOTE_HOST" \
  "awk '/^version:/ {gsub(/\"/, \"\", \$2); print \$2}' ~/.geno-tools/geno-loops/active/genotools.yaml 2>/dev/null || echo MISSING")

if [[ "$REMOTE_VERSION" == "MISSING" ]]; then
  echo "check-version: geno-loops not installed on $REMOTE_HOST" >&2
  exit 1
fi

if [[ "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
  echo "check-version: OK — both on geno-loops v${LOCAL_VERSION}"
  exit 0
else
  echo "check-version: VERSION MISMATCH" >&2
  echo "  local:  v${LOCAL_VERSION}" >&2
  echo "  remote: v${REMOTE_VERSION} (on ${REMOTE_HOST})" >&2
  exit 1
fi
