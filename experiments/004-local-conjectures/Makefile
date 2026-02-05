# Makefile for experiment 004-local-conjectures
# Tests the conjecture that cprr init defaults to local .cprr/ storage

.PHONY: test clean

test:
	@echo "Testing local-first conjecture storage..."
	@mkdir -p /tmp/cprr-test-$$$$
	@cd /tmp/cprr-test-$$$$ && ../../cprr init 2>&1 | grep -q "\.cprr" && echo "PASS: init creates local store"
	@cd /tmp/cprr-test-$$$$ && test -f .cprr/conjectures.json && echo "PASS: conjectures.json exists in .cprr/"
	@rm -rf /tmp/cprr-test-$$$$
	@echo "All tests passed."

clean:
	@rm -rf /tmp/cprr-test-*
