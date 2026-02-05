# Refinement: Local-First Conjecture Storage

## What Landed
The implementation already exists in `main.go` and is correct:
- Lines 379-380: Default `useLocal := true`
- Lines 389-391: Explicit `--global` flag handling
- Line 145: Local store precedence in discovery
- Lines 400-414: Help text documenting the design

No code changes required - this experiment confirms existing behavior.

## What Changed During Refinement
No changes needed. The conjecture was testing an existing implementation, which was verified to be correct.

## Decision Record
See: docs/decisions/20260205-004-local-first-conjectures.md (to be created if needed)

## Hardening Level Achieved
- [x] L0: Working code (Proof phase)
- [x] L1: Example-based tests (Proof phase - manual verification)
- [ ] L2: Property-based tests (Not applicable - configuration behavior)
- [ ] L3: Runtime contracts
- [ ] L4: Formal verification

## Evidence Summary
Conjecture #12 was advanced to CONFIRMED with 5 pieces of evidence:
1. Implementation verified: cmdInit() defaults to useLocal=true
2. Help text confirms local default
3. Test: cprr init creates ./.cprr/conjectures.json
4. Global store requires explicit --global flag
5. Store discovery: local .cprr/ takes precedence over ~/.cprr/

## Conclusion
The CPRR tool correctly implements project-local conjecture storage by default, aligning with the CPRR methodology's emphasis on experiment-driven development within version-controlled repositories.
