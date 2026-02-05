# Conjecture: Vale is better than custom linters for experiment content

## Hypothesis
Vale's prose linting with custom vocabulary catches more style issues than bash grep checks, with less maintenance burden.

## Motivation
- Custom lint-experiments.sh checks structure only
- Content validation (## Hypothesis section, evidence format) is brittle with grep
- Vale provides:
  - Built-in style rules (Microsoft, Google, write-good)
  - Custom vocabularies for domain terms
  - Markdown/Org awareness
  - CI integration

## Falsification Criteria
- If Vale setup takes > 30 minutes, the hypothesis is weakened
- If Vale misses issues our custom script catches, the hypothesis is refuted
- If Vale configuration is more complex than our bash script, the hypothesis is refuted

## Prior Art
- lint-experiments.sh: Structure validation (directory names, required files)
- Vale: https://vale.sh/ - Prose linting for technical documentation
- markdownlint: Structural markdown checks

## Scope

### In Scope
- .vale.ini configuration
- Custom styles for CPRR terminology
- Integration with `make lint-style`

### Out of Scope
- Replacing structural checks in lint-experiments.sh
- Vale for non-experiment documentation (initially)
