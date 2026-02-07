#!/usr/bin/env bash
# CLI validation test script
# Runs in a temp directory to avoid trashing project .cprr/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CPRR="${CPRR:-$PROJECT_ROOT/cprr}"

# Ensure binary exists
if [[ ! -x "$CPRR" ]]; then
	echo "Error: cprr binary not found at $CPRR"
	echo "Run 'make build' first"
	exit 1
fi

PASS=0
FAIL=0

test_case() {
	local name="$1"
	local expected_exit="$2"
	shift 2
	local cmd="$*"

	if output=$($cmd 2>&1); then
		actual_exit=0
	else
		actual_exit=$?
	fi

	if [[ "$actual_exit" -eq "$expected_exit" ]]; then
		echo "PASS: $name"
		((PASS++)) || true
	else
		echo "FAIL: $name (expected exit $expected_exit, got $actual_exit)"
		echo "  cmd: $cmd"
		echo "  out: $output"
		((FAIL++)) || true
	fi
}

# Setup: use temp directory to avoid trashing project .cprr/
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT
cd "$TEST_DIR"

echo "Running CLI tests in: $TEST_DIR"
echo ""

# Global flags
test_case "help flag" 0 $CPRR --help
test_case "version flag" 0 $CPRR --version
test_case "no args shows help" 0 $CPRR

# Init (local by default, idempotent)
test_case "init default" 0 $CPRR init
test_case "init exists" 0 $CPRR init # idempotent: exits 0
test_case "init examples" 0 $CPRR init --examples
test_case "init force" 0 $CPRR init --force --examples

# Add
test_case "add no args" 1 $CPRR add
test_case "add title only" 0 $CPRR add "Test hypothesis"
test_case "add with hypothesis" 0 $CPRR add "Full test" --hypothesis "Expected outcome"

# List
test_case "list all" 0 $CPRR list
test_case "list filter" 0 $CPRR list --status open

# Show
test_case "show exists" 0 $CPRR show 1
test_case "show not found" 1 $CPRR show 999
test_case "show invalid" 1 $CPRR show abc

# Next
test_case "next with hypothesis" 0 $CPRR next 5
test_case "next no hypothesis" 1 $CPRR next 4
test_case "next force" 0 $CPRR next 4 --force

# Evidence
test_case "evidence add" 0 $CPRR evidence 5 "Test observation"
test_case "evidence no text" 1 $CPRR evidence 5

# Status
test_case "status set" 0 $CPRR status 4 abandoned
test_case "status invalid" 1 $CPRR status 4 invalid

# Delete
test_case "delete exists" 0 $CPRR delete 4
test_case "delete not found" 1 $CPRR delete 999

# Unknown command
test_case "unknown command" 1 $CPRR foobar
test_case "typo suggestion" 1 $CPRR lst

# Summary (temp dir cleaned up by trap)
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
