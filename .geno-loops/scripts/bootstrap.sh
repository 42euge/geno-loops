#!/usr/bin/env bash
# Bootstrap script for geno-loops skillset installation.
# Called by geno-tools during `npx skills add geno-loops`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "geno-loops bootstrap: nothing to provision"
