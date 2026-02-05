# Analysis: Should cprr Use Bead Semantics?

**Conjecture #13**: cprr should use bead semantics for branch-style isolation

**Date**: 2026-02-05
**Analyst**: Agent on feat/CPRR-a58-bead-semantics branch
**Verdict**: REFUTED

## Executive Summary

After analyzing the beads (bd) tool's architecture and comparing it with cprr's design goals, the conjecture that cprr needs "bead semantics for branch-style isolation" is **refuted**. Git worktrees already provide sufficient isolation for cprr's use case, and adopting beads' sophisticated features would add complexity without proportionate benefit.

## What Are "Bead Semantics"?

Based on analysis of the beads tool (github.com/steveyegge/beads), "bead semantics" refers to:

### 1. Hash-Based Issue IDs
- Issues get unique hash-based IDs (e.g., `bd-a1b2c3`)
- Prevents ID collisions when multiple agents create issues in parallel
- Different branches can create issues without coordination

### 2. Shared SQLite Database with JSONL Sync
- `.beads/beads.db` - SQLite database for fast local queries
- `.beads/issues.jsonl` - JSONL file for git tracking and sync
- Two-way sync: DB exports to JSONL, JSONL imports to DB
- Merge drivers handle JSONL conflicts intelligently

### 3. Worktree-Aware Database Discovery
- All git worktrees share the same `.beads/` directory in the main repository
- Database discovery searches main repo first, then worktree
- SQLite locking prevents corruption during concurrent access

### 4. Daemon Mode with Branch-Safe Commit Routing
- Background daemon handles auto-commit/push
- Sync-branch feature: commits go to dedicated metadata branch (e.g., `beads-sync`)
- Prevents issue commits from polluting feature branch history

## What Problem Does cprr Solve?

cprr is a **conjecture tracker** for the CPRR methodology:
- Tracks hypotheses through states: open -> testing -> confirmed/refuted
- Enforces guards (e.g., "2+ evidence required to confirm")
- Simple JSON store: `.cprr/conjectures.json`
- Local-first: prefers `.cprr/` in pwd over `~/.cprr/`

## Why cprr Does NOT Need Bead Semantics

### 1. Different Scale of Concurrency

**Beads Problem**: Multiple agents (potentially dozens) working on the SAME repository, creating/updating issues concurrently. Hash IDs prevent collision; daemon prevents commit spam.

**cprr Problem**: Typically one agent per worktree tracks hypotheses for that feature branch. Worktrees already isolate `.cprr/` copies.

### 2. Git Worktrees Already Provide Isolation

```
repo/
├── .cprr/conjectures.json          # Main branch conjectures
├── worktrees/
│   ├── CPRR-a58/
│   │   └── .cprr/conjectures.json  # This branch's conjectures (copy)
│   └── CPRR-ddd/
│       └── .cprr/conjectures.json  # Different branch's conjectures
```

Each worktree has its own `.cprr/` - conjectures are branch-isolated by default.

### 3. JSON vs SQLite+JSONL Complexity

| Feature | cprr (JSON) | beads (SQLite+JSONL) |
|---------|-------------|----------------------|
| Storage | Single JSON file | SQLite DB + JSONL |
| Queries | Load all, filter | SQL queries |
| Sync | Git commit | Daemon + sync branch |
| Merge | JSON diff (rare) | JSONL merge driver |
| Complexity | Low | High |

cprr's simple JSON is sufficient for its scale (dozens of conjectures per project).

### 4. Experiments Directory Provides Content Isolation

The CPRR methodology uses `experiments/NNN-name/` directories for actual work:
- Each experiment is a self-contained directory
- Experiments follow git branch lifecycle
- `.cprr/` just tracks metadata about experiments

The content isolation is already in experiments/, not in `.cprr/`.

### 5. Ephemeral Hypothesis Tracking

The conjecture states: "enables ephemeral hypothesis tracking without polluting the main project"

**Reality**: cprr already supports this:
- Work in a worktree on a feature branch
- Add conjectures to that branch's `.cprr/`
- Merge branch -> conjectures merge with it
- Delete branch -> conjectures deleted with it

This IS branch-style isolation, just using git's native mechanisms.

## What Would Adopting Bead Semantics Cost?

1. **SQLite dependency** - Currently cprr is a single Go binary with no deps
2. **Daemon complexity** - Background process management, port conflicts
3. **Sync branch management** - Protected branches, worktree lifecycle
4. **Hash ID migration** - Breaking change for existing stores
5. **Merge driver installation** - .gitattributes, git config

## When WOULD cprr Need Bead Semantics?

If cprr's use case evolved to:
- Multiple agents creating conjectures in parallel on SAME branch
- Cross-project conjecture aggregation (multi-repo hydration)
- Real-time conjecture updates across machines

These are NOT the current requirements.

## Conclusion

**Refuted**: cprr should NOT adopt bead semantics because:

1. Git worktrees already provide branch-style isolation
2. cprr's single-agent-per-worktree model doesn't need hash IDs
3. Simple JSON is sufficient for cprr's scale
4. Adopting beads' features would increase complexity 10x
5. The "ephemeral tracking" goal is already achieved via git branches

**Recommendation**: Keep cprr simple. If concurrent multi-agent access becomes a real requirement, revisit this conjecture with specific use cases.

## References

- beads tool: https://github.com/steveyegge/beads
- beads WORKTREES.md: worktree-aware database discovery
- beads GIT_INTEGRATION.md: merge driver and sync branch
- cprr main.go:140-162: loadStore() local-first detection
- cprr AGENTS.md: CPRR methodology and experiment structure
