# Conjecture: Conjectures Should Be Project-Local by Default

## Hypothesis
Project-specific hypotheses (experiments/, .beads/) should live in `.cprr/` not `~/.cprr/` - global store causes sync issues and mixes unrelated projects.

## Motivation
When working across multiple projects, storing all conjectures in a global `~/.cprr/` directory creates several problems:
1. **Git tracking impossible**: Global storage cannot be version-controlled per-project
2. **Cross-project contamination**: Unrelated hypotheses get mixed together
3. **Sync conflicts**: Multiple agents or sessions could conflict on the same global file
4. **Context loss**: Conjectures lose their project context when stored globally

A local `.cprr/` directory addresses all these issues and aligns with the CPRR methodology's emphasis on experiment-driven development within repositories.

## Falsification Criteria
- If `cprr init` creates `~/.cprr/` by default, the conjecture is refuted.
- If there is no way to opt into local storage, the conjecture is refuted.
- If local store does not take precedence over global store in lookups, the conjecture is refuted.

## Prior Art
- The beads system (`.beads/`) uses project-local storage
- Git's `.git/` directory is local by design
- Modern tools like `.vscode/`, `.github/` favor local configuration

## Scope
- **IN SCOPE**: Default behavior of `cprr init`, store discovery order
- **OUT OF SCOPE**: Migration tooling, multi-project aggregation
