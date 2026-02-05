# Conjecture: `cprr quickstart` helps agents understand the tool

## Hypothesis
We believe that adding a `cprr quickstart` command will reduce agent onboarding friction because it provides a guided, self-documenting introduction to the CPRR workflow.

## Motivation
- Agents currently need to read AGENTS.md, SKILL.md, and run multiple commands to understand the workflow
- A single `quickstart` command could demonstrate the full cycle (conjecture → proof → refutation → refinement)
- Self-documenting tools reduce context window usage and errors

## Falsification Criteria
- If agents still require external documentation after running `quickstart`, the conjecture is refuted
- If `quickstart` output exceeds 100 lines (too verbose for agent context), the conjecture is refuted
- If the command takes > 5 seconds to run, the conjecture is refuted (agents need fast feedback)

## Prior Art
- `cprr init --examples` provides sample data but no workflow guidance
- `bd quickstart` mentioned in CLAUDE.md but not implemented
- Many CLI tools have `--help` but few have interactive quickstart flows

## Scope

### In Scope
- `cprr quickstart` command that:
  - Shows the CPRR state machine
  - Creates a sample conjecture
  - Demonstrates `next` and `evidence` commands
  - Explains when to use each phase
- Output optimized for LLM agent consumption (concise, structured)

### Out of Scope
- Interactive prompts (agents can't handle them)
- Modifications to existing commands
- Changes to the underlying data model
