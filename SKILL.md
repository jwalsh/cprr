# cprr: Hypothesis Tracking Skill

## Overview

cprr (Conjecture-Proposition-Refutation-Resolution) provides a rigorous methodology for tracking hypotheses through a state machine with guard conditions. Use this skill when you need to validate assumptions, run experiments, or maintain audit trails of what was tried.

## When to Use This Skill

- Validating technical assumptions before implementation
- A/B testing or experiment tracking
- Technical debt tracking (assumptions that may become debt)
- Documenting decisions with evidence
- Multi-agent debate synthesis

## Core Workflow

```
open → testing → confirmed
                ↘ refuted
     any state → abandoned (escape hatch)
```

### Guards (Preconditions)

| Transition | Requirement |
|------------|-------------|
| open → testing | Hypothesis must be set |
| testing → confirmed | At least 2 evidence pieces |
| testing → refuted | At least 1 evidence piece |
| * → abandoned | Always allowed |

## Commands

### Create a Conjecture
```bash
cprr add "Title of conjecture" --hypothesis "Falsifiable prediction" -t tag1,tag2
```

### Advance State
```bash
cprr next <id>           # Advance to next state (checks guards)
cprr next <id> --dry-run # Preview without changing
```

### Add Evidence
```bash
cprr evidence <id> "Description of observation or data"
```

### View Status
```bash
cprr list                    # All conjectures
cprr list --status testing   # Filter by state
cprr show <id>               # Full details
```

### Direct Status Change
```bash
cprr status <id> abandoned   # Escape hatch (always allowed)
cprr status <id> refuted     # Requires evidence
```

## Evidence Standards

| Level | Description | Example |
|-------|-------------|---------|
| Anecdotal | Single observation | "Seemed faster" |
| Measured | Quantified observation | "p99: 180ms" |
| Statistical | Significance tested | "p=0.03, n=10000" |
| Replicated | Multiple trials | "3 runs, consistent" |

## Best Practices

1. **Be specific** - "Caching improves latency" → "Redis cache reduces p99 by 50%"
2. **Be falsifiable** - Predictions that can be proven wrong
3. **Set boundaries** - Time, scope, metrics
4. **Gather evidence before concluding** - Guards enforce this
5. **Abandon cleanly** - When circumstances change, use abandoned state

## Example Session

```bash
# Initialize (if not done)
cprr init --examples

# Create hypothesis
cprr add "Microservices reduce deployment time" \
    --hypothesis "Independent deploys cut release cycle from 2 weeks to 2 days"

# Advance to testing
cprr next 1

# Gather evidence
cprr evidence 1 "Baseline: 14 days average release cycle, n=12 releases"
cprr evidence 1 "Post-migration: 3 days average, n=8 releases, p<0.01"

# Confirm (requires 2+ evidence)
cprr next 1
```

## Integration with Other Tools

- **beads (bd)**: Track issues/tasks that arise from conjectures
- **TLA+**: Formal verification of state machine properties
- **git notes**: Attach conjecture IDs to commits

## Philosophy

Based on Karl Popper's epistemology: knowledge advances through bold conjectures and systematic attempts at refutation. The guard system prevents premature conclusions and creates an audit trail of validated (or invalidated) assumptions.
