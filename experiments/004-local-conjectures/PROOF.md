# Proof: Local-First Conjecture Storage

## Implementation Summary
The `cprr` tool implements local-first conjecture storage with the following design:

1. **Default to local**: `cmdInit()` sets `useLocal := true` at line 379-380
2. **Explicit opt-in for global**: The `--global` flag must be explicitly provided
3. **Local precedence**: Store discovery checks `.cprr/` before `~/.cprr/`

## How to Verify

```bash
# Test 1: Default init creates local store
mkdir /tmp/test-local && cd /tmp/test-local
cprr init
ls -la .cprr/  # Should exist with conjectures.json

# Test 2: Help shows local is default
cprr init --help
# Should show: "Default: project-local store in ./.cprr (recommended for git tracking)"

# Test 3: Global requires explicit flag
cprr init --global  # Creates ~/.cprr/ (not recommended)
```

## Test Matrix
| Test                        | Status | Notes                                     |
|-----------------------------|--------|-------------------------------------------|
| init defaults to .cprr/     | PASS   | useLocal := true                          |
| --global creates ~/.cprr/   | PASS   | Explicit opt-in required                  |
| Local takes precedence      | PASS   | main.go:145 checks local first            |
| Help text documents default | PASS   | "recommended for git tracking"            |
| --local flag works          | PASS   | Explicit but redundant (already default)  |

## Assumptions
- Users will run `cprr init` from project root directories
- Projects will have a working directory where `.cprr/` can be created
- Users with legacy `~/.cprr/` can migrate via `cprr doctor --migrate`
