# Refutation Attempts: Local-First Conjecture Storage

## Edge Cases Tested
| Case                            | Result   | Notes                                          |
|---------------------------------|----------|------------------------------------------------|
| Empty directory init            | SURVIVED | Creates .cprr/ correctly                       |
| Init in home directory          | SURVIVED | Still creates local .cprr/ not ~/.cprr/        |
| Global flag override            | SURVIVED | --global explicitly creates ~/.cprr/           |
| Both stores exist               | SURVIVED | Local takes precedence (main.go:145)           |
| Read-only directory             | N/A      | Would fail gracefully (not tested)             |

## Code Review
Examined `main.go` lines 378-430 for the `cmdInit()` function:
- Line 379-380: `useLocal := true` - correct default
- Line 389-391: `--global` flag processing - correct opt-in
- Line 407: Help text marks global as "not recommended"

## Integration Testing
The `.cprr/` directory integrates correctly with:
- Git version control (can be tracked in repo)
- The beads system (`.beads/` uses same local-first pattern)
- Multi-worktree setups (each worktree gets its own store)

## Verdict
- [x] SURVIVED - proceed to Refinement

The implementation correctly defaults to local storage. The design:
1. Matches user expectations from similar tools (.git/, .beads/)
2. Enables version control of conjectures
3. Provides explicit --global escape hatch for edge cases
4. Documents the recommendation clearly in help text
