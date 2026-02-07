#!/usr/bin/env bash
# deps.sh - Check required and optional dependencies
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

check_required() {
	local cmd="$1"
	local purpose="$2"
	if command -v "$cmd" &>/dev/null; then
		local version
		case "$cmd" in
		go) version=$(go version 2>&1 | head -1) ;;
		*) version=$("$cmd" --version 2>&1 | head -1 || echo "unknown") ;;
		esac
		echo -e "${GREEN}✓${NC} $cmd: $version"
		return 0
	else
		echo -e "${RED}✗${NC} $cmd: NOT FOUND (required for $purpose)"
		return 1
	fi
}

check_optional() {
	local cmd="$1"
	local purpose="$2"
	if command -v "$cmd" &>/dev/null; then
		local version
		case "$cmd" in
		go) version=$(go version 2>&1 | head -1) ;;
		tmux) version=$(tmux -V 2>&1 | head -1) ;;
		*) version=$("$cmd" --version 2>&1 | head -1 || echo "unknown") ;;
		esac
		echo -e "${GREEN}✓${NC} $cmd: $version"
	else
		echo -e "${YELLOW}○${NC} $cmd: not found (optional, for $purpose)"
	fi
}

echo "Checking dependencies..."
echo ""

echo "Required:"
MISSING=0
check_required "go" "building" || MISSING=1
check_required "git" "version control" || MISSING=1
check_required "gh" "GitHub operations" || MISSING=1
check_required "gmake" "build automation" || MISSING=1

echo ""
echo "Optional (linting):"
check_optional "shellcheck" "shell script linting"
check_optional "shfmt" "shell script formatting"
check_optional "staticcheck" "Go static analysis"
check_optional "golangci-lint" "Go linting"

echo ""
echo "Optional (dev tools):"
check_optional "emacs" "org-mode tangle/detangle"
check_optional "direnv" "environment management"
check_optional "tmux" "terminal multiplexing"
check_optional "asciinema" "terminal screencasts"
check_optional "bd" "beads issue tracking"

echo ""
echo "Optional (formal methods):"
check_optional "java" "TLA+ toolbox runtime"
check_optional "tlc" "TLA+ model checker"
check_optional "z3" "SMT solver"
check_optional "alloy" "Alloy analyzer"
check_optional "spin" "PROMELA model checker"
check_optional "coq" "Coq proof assistant"

echo ""

if [[ $MISSING -gt 0 ]]; then
	echo -e "${RED}Missing required dependencies.${NC}"
	echo ""
	echo "Install with:"
	echo "  brew install go git gh"
	echo "  # gmake is usually 'make' on Linux, 'gmake' on macOS/BSD"
	exit 1
fi

echo -e "${GREEN}All required dependencies found.${NC}"
