# Makefile for Vale linting experiment
# Tests conjecture: Vale is better than custom linters for PROSE QUALITY

VALE := vale
VALE_CONFIG := .vale.ini

.PHONY: all test test-good test-bad lint-quickstart compare clean help

all: test

# Run full test suite
test: test-good test-bad lint-quickstart
	@echo ""
	@echo "=== All Tests Complete ==="

# Test on well-written conjecture (should pass with positive suggestions only)
test-good:
	@echo "=== Testing good-conjecture.md ==="
	$(VALE) --config=$(VALE_CONFIG) tests/good-conjecture.md
	@echo ""

# Test on poorly-written conjecture (should catch issues)
test-bad:
	@echo "=== Testing bad-conjecture.md (expect suggestions) ==="
	$(VALE) --config=$(VALE_CONFIG) tests/bad-conjecture.md
	@echo ""

# Test on actual experiment files
lint-quickstart:
	@echo "=== Linting experiments/001-quickstart-command ==="
	$(VALE) --config=$(VALE_CONFIG) ../001-quickstart-command/CONJECTURE.md
	$(VALE) --config=$(VALE_CONFIG) ../001-quickstart-command/PROOF.md
	@echo ""

# Show comparison with bash script
compare:
	@echo "=== Comparison: Vale vs lint-experiments.sh ==="
	@echo ""
	@echo "lint-experiments.sh (62 lines) checks:"
	@echo "  [x] experiments/ directory exists"
	@echo "  [x] README.org index exists"
	@echo "  [x] Directory naming (NNN-description)"
	@echo "  [x] CONJECTURE.md exists"
	@echo ""
	@echo "Vale (this config) checks:"
	@echo "  [x] Passive voice (was implemented, were tested)"
	@echo "  [x] Hedging language (might work, maybe, sort of)"
	@echo "  [x] Falsification language present (refuted, disproved)"
	@echo "  [x] Custom vocabulary (CPRR domain terms)"
	@echo ""
	@echo "VERDICT: Complementary tools."
	@echo "  - lint-experiments.sh: STRUCTURE"
	@echo "  - Vale: PROSE QUALITY"

# Show current Vale config
show-config:
	$(VALE) ls-config

# Clean (no external packages synced in minimal config)
clean:
	@echo "No cleanup needed (write-good not synced)"

help:
	@echo "CPRR Vale Linting Experiment"
	@echo ""
	@echo "Targets:"
	@echo "  make test         - Run all tests"
	@echo "  make test-good    - Test on well-written example"
	@echo "  make test-bad     - Test on poorly-written example"
	@echo "  make compare      - Show Vale vs bash comparison"
	@echo "  make show-config  - Display Vale configuration"
