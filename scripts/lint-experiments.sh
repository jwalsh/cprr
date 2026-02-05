#!/usr/bin/env bash
# lint-experiments.sh — Validate experiment directory structure
# Content/style validation delegated to Vale (make lint-style)
set -euo pipefail

EXPERIMENTS_DIR="${1:-experiments}"
ERRORS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error() { echo -e "${RED}ERROR${NC}: $1"; ((ERRORS++)); }
ok() { echo -e "${GREEN}OK${NC}: $1"; }

echo "Validating experiment structure in ${EXPERIMENTS_DIR}/"
echo "======================================================="

# Check experiments directory exists
if [ ! -d "$EXPERIMENTS_DIR" ]; then
    error "Experiments directory not found: $EXPERIMENTS_DIR"
    exit 1
fi

# Check for README.org index
if [ ! -f "$EXPERIMENTS_DIR/README.org" ]; then
    error "Missing experiments/README.org index"
else
    ok "experiments/README.org exists"
fi

# Validate each experiment directory structure
for exp_dir in "$EXPERIMENTS_DIR"/[0-9]*/; do
    [ -d "$exp_dir" ] || continue

    exp_name=$(basename "$exp_dir")

    # Check naming convention (NNN-description)
    if ! [[ "$exp_name" =~ ^[0-9]{3}- ]]; then
        error "$exp_name: Invalid naming (should be NNN-description)"
        continue
    fi

    # Required: CONJECTURE.md
    if [ ! -f "$exp_dir/CONJECTURE.md" ]; then
        error "$exp_name: Missing CONJECTURE.md"
    else
        ok "$exp_name: structure valid"
    fi
done

echo ""
echo "======================================================="
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}$ERRORS structural errors${NC}"
    echo "Run 'make lint-style' for content validation (Vale)"
    exit 1
else
    echo -e "${GREEN}All experiment directories valid${NC}"
    exit 0
fi
