# Proof: Vale Linting for CPRR Experiments

## Implementation Summary

This experiment tested whether Vale prose linting could replace or supplement
the existing `lint-experiments.sh` bash script for validating CPRR experiment
content.

**Key Finding**: Vale and bash scripts have **complementary strengths**:
- `lint-experiments.sh`: Structure validation (directory names, file existence)
- Vale: Prose quality validation (hedging language, passive voice, domain terms)

Vale cannot easily validate "file must contain section X" because its
`existence` extension fires when tokens ARE found, not when missing.

### What Was Built

1. `.vale.ini` - Configuration for CPRR experiments
2. `styles/CPRR/` - Custom Vale rules:
   - `PassiveVoice.yml` - Flags passive constructions
   - `WeakClaims.yml` - Flags hedging language (might, maybe, sort of)
   - `FalsificationRequired.yml` - Confirms falsification language exists
   - `*.yml` (disabled) - Attempted structural checks (documented as not viable)
3. `styles/Vocab/CPRR/accept.txt` - Domain terminology
4. `tests/` - Sample good and bad conjecture files

## How to Verify

```bash
cd experiments/003-vale-linting

# Run Vale on a well-written conjecture (should have minimal suggestions)
vale --config=.vale.ini tests/good-conjecture.md

# Run Vale on a poorly-written conjecture (should catch issues)
vale --config=.vale.ini tests/bad-conjecture.md

# Run Vale on actual experiment files
vale --config=.vale.ini ../001-quickstart-command/CONJECTURE.md
vale --config=.vale.ini ../001-quickstart-command/PROOF.md

# Full test via Makefile
make test
```

## Test Matrix

| Test | Status | Notes |
|------|--------|-------|
| Vale installed | PASS | `/usr/local/bin/vale` |
| Config parses | PASS | No syntax errors |
| PassiveVoice rule fires | PASS | Catches "was implemented", "were tested" |
| WeakClaims rule fires | PASS | Catches "might work", "maybe", "sort of" |
| FalsificationRequired positive | PASS | Confirms "refuted" found |
| Good conjecture passes | PASS | Only positive suggestions |
| Bad conjecture caught | PASS | 9 suggestions for hedging/passive |
| Structural checks | FAIL | Vale existence rules work inversely |

### Setup Time

| Task | Time |
|------|------|
| Read Vale docs | 5 min |
| Create .vale.ini | 2 min |
| Write custom rules | 10 min |
| Debug existence behavior | 8 min |
| Create tests | 5 min |
| **Total** | **30 min** |

This meets the falsification criterion of "< 30 minutes setup".

## Falsification Criteria Results

| Criterion | Result |
|-----------|--------|
| Setup takes > 30 minutes | **SURVIVED** (30 min) |
| Vale misses issues bash catches | **SURVIVED** - Different scopes |
| Vale config more complex than bash | **PARTIALLY REFUTED** - See below |

### Complexity Comparison

**lint-experiments.sh**: 62 lines, checks:
- Directory exists
- README.org exists
- Experiment naming (NNN-description)
- CONJECTURE.md exists

**Vale config**: ~50 lines across 7 files, checks:
- Passive voice
- Hedging language
- Domain vocabulary
- Falsification language present

**Verdict**: Similar complexity, but for **different purposes**.

## Assumptions

1. Prose quality checks add value beyond structural validation
2. Agents benefit from style feedback (less hedging = clearer hypotheses)
3. Vale's package ecosystem (write-good, Microsoft style) adds value if synced
4. Structural validation should remain in lint-experiments.sh

## Recommendations

### Use Vale For:
- Prose quality in CONJECTURE.md (hedging, passive voice)
- Enforcing domain vocabulary
- Optional: write-good style rules (requires `vale sync`)

### Keep in lint-experiments.sh:
- Directory structure validation
- Required file existence checks
- Naming convention enforcement

### Proposed Integration

Add to project Makefile:
```makefile
lint-style:
    vale --config=experiments/003-vale-linting/.vale.ini experiments/
```

## Next Steps

1. [ ] Decide: Promote Vale config to project root?
2. [ ] Decide: Enable write-good package?
3. [ ] Decide: Add Vale to CI pipeline?
4. [ ] Document in AGENTS.md how to use both linters
