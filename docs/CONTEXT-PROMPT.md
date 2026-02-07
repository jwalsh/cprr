# CPRR Research Prototype - Context Prompt

Use this document to brief an LLM for metaplanning research and development on the cprr project.

---

## Project Identity

**Name:** cprr (Conjecture-Proposition-Refutation-Resolution)
**Type:** CLI tool + methodology for hypothesis-driven development
**Language:** Go (zero dependencies, single binary)
**Repository:** https://github.com/jwalsh/cprr
**Philosophy:** Popperian falsificationism applied to software development

---

## Core Concept

cprr enforces rigor in technical decision-making through a state machine with guards:

```
open ──[hypothesis]──▶ testing ──[2+ evidence]──▶ confirmed
                            │
                            └──[1+ evidence]──▶ refuted

Any state ──▶ abandoned (escape hatch)
```

**Guards prevent premature conclusions:**
- Cannot advance to `testing` without a hypothesis
- Cannot `confirm` without 2+ pieces of evidence
- Cannot `refute` without 1+ piece of evidence
- `abandoned` always available (circumstances change)

---

## Current Implementation State

### Codebase
- `main.go`: ~1440 lines, complete CLI implementation
- State machine with 5 states, guard system
- Commands: init, add, list, show, next, evidence, status, delete, quickstart, doctor

### Conjectures Tracked
- 19 confirmed hypotheses
- 7 in testing
- 28 total conjectures documented

### Experiments
- `001-quickstart-command/` - CONFIRMED
- `002-alloy-state-machine/` - CONFIRMED (formal verification with Alloy)
- `003-vale-linting/` - In progress

### Open Issues (Beads)
- CPRR-lqz: Refinery pattern for merge conflicts
- CPRR-b6t: Branches prevent duplicate experiment numbers
- CPRR-ddd: Vale linting for experiment content
- CPRR-a58: Bead semantics for isolation
- CPRR-s83: Project-local conjectures by default

---

## Key Design Decisions (Confirmed)

1. **Local-first storage** - `.cprr/` in project dir takes precedence over `~/.cprr`
2. **Idempotent operations** - `init` and `quickstart` are safe to re-run
3. **Alloy over TLA+** - Relational logic better for small bounded state machines
4. **Git worktrees for parallel work** - `worktrees/` gitignored, branches shared via origin
5. **Experiment structure** - `experiments/NNN-name/` with CONJECTURE.md, PROOF.md

---

## Integration Points

### Tools
- `cprr` - Hypothesis tracking CLI
- `bd` (beads) - Issue/task tracking
- `gh` - GitHub CLI for PRs, gists
- `gmake` - Build system with fallthrough to scripts/

### Workflow
```bash
# Daily workflow
cprr list                    # See hypothesis status
bd list --status open        # See open tasks
gmake worktrees ARGS=sync    # See parallel work
gmake overview-gist          # Create status snapshot
```

---

## Architecture Patterns

### State Machine as Data
```go
var transitions = []Transition{
    {From: StatusOpen, To: StatusTesting, Guards: []Guard{...}},
    {From: StatusTesting, To: StatusConfirmed, Guards: []Guard{...}},
}
```

### Guard Functions
```go
type Guard struct {
    Name    string
    Check   func(*Conjecture) bool
    Message string
}
```

### Store Resolution
1. Check `.cprr/conjectures.json` in pwd
2. Fall back to `~/.cprr/conjectures.json`
3. Local takes precedence (no merge)

---

## Research Directions (Untested Hypotheses)

### Multi-Agent Collaboration
- Refinery pattern for conflict-free concurrent updates
- Bead semantics for branch-style isolation
- Automatic experiment number deconfliction

### Formal Methods
- Alloy specification exists (`experiments/002-alloy-state-machine/cprr.als`)
- TLA+ abandoned in favor of Alloy
- Could add property-based testing

### Developer Experience
- Vale linting for experiment documentation
- AGENTS.md integration for AI coding assistants
- SKILL.md for agent-skills packaging

### Scaling
- Performance with 1000+ conjectures
- Cross-repository conjecture tracking
- Team-wide hypothesis dashboards

---

## File Structure

```
cprr/
├── main.go                  # CLI implementation
├── go.mod                   # Zero dependencies
├── Makefile                 # Build system
├── .cprr/                   # Local conjecture store (in git)
├── .beads/                  # Issue tracking (in git)
├── experiments/             # Hypothesis experiments
│   ├── README.org           # Index
│   ├── 001-quickstart-command/
│   ├── 002-alloy-state-machine/
│   └── 003-vale-linting/
├── worktrees/               # Parallel work (gitignored)
├── scripts/                 # Helper scripts
│   ├── worktrees.sh
│   └── overview-gist.sh
├── docs/                    # Documentation
│   ├── CLI-TESTING.org
│   ├── STATE-MACHINE.org
│   └── CONTEXT-PROMPT.md    # This file
├── AGENTS.md                # AI agent instructions
├── SKILL.md                 # Agent skills definition
├── README.org               # User documentation
└── CONTRIBUTING.org         # Developer guide
```

---

## Prompting an LLM for Research Planning

### Setup Context
```
You are planning research for cprr, a hypothesis-tracking CLI.
Current state: 19 confirmed conjectures, 7 in testing, 7 open issues.
The tool is functional but has unexplored research directions.
```

### Planning Questions

1. **What hypotheses should be tested next?**
   - Review open issues (CPRR-lqz, CPRR-b6t, etc.)
   - Consider the "testing" conjectures (#1, #2, #9-13)

2. **What experiments would validate the methodology?**
   - Apply cprr to a real project
   - Measure decision quality improvement
   - Track "negative knowledge" (refuted hypotheses)

3. **What integrations would increase adoption?**
   - IDE plugins (VS Code, Emacs)
   - CI/CD integration (fail build on unvalidated assumptions)
   - Team dashboards

4. **What formal properties should be verified?**
   - Safety: confirmed always has evidence
   - Liveness: abandoned always reachable
   - No orphan states

### Output Format
Ask the LLM to produce:
- Numbered experiments with CONJECTURE.md structure
- Falsification criteria for each
- Priority ordering based on impact/effort
- Dependencies between experiments

---

## Quick Reference Commands

```bash
# Project status
cprr list
bd list --status open
gmake worktrees ARGS=sync

# Create hypothesis
cprr add "Title" --hypothesis "Prediction" -t tag1,tag2

# Advance state
cprr next <id>         # Checks guards
cprr evidence <id> "observation"

# Health check
cprr doctor

# Summary gist
gmake overview-gist
```

---

## Session Continuation

To continue this research in a new session:

1. Clone repo: `git clone https://github.com/jwalsh/cprr && cd cprr`
2. Build: `gmake build`
3. Read this file: `cat docs/CONTEXT-PROMPT.md`
4. Check state: `cprr list && bd list --status open`
5. Pick a conjecture or issue to work on

The methodology is self-documenting - all decisions are tracked as conjectures.
