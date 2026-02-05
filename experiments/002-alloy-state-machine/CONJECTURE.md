# Conjecture: Alloy is better than TLA+ for cprr's state machine

## Hypothesis
Alloy's relational logic and built-in visualization provide faster iteration for bounded state spaces like cprr's 5-state machine, compared to TLA+'s temporal logic approach.

## Motivation
- cprr has a small, bounded state space (5 states, finite evidence counts)
- Guards are structural predicates, not temporal properties
- TLA+ is designed for distributed systems with unbounded concurrency
- Alloy Analyzer provides automatic counterexample visualization

## Falsification Criteria
- If Alloy cannot express cprr's invariants, the conjecture is refuted
- If TLA+ specification is significantly more concise, the conjecture is refuted
- If Alloy's bounded checking misses bugs that TLA+ would catch, the conjecture is refuted

## Prior Art
- TLA+ (Lamport): Temporal logic, model checking, distributed systems
- Alloy (Jackson): Relational logic, SAT solving, structural properties
- conjecture #4 (abandoned): Originally planned TLA+ verification

## Scope

### In Scope
- Alloy specification of cprr state machine (`cprr.als`)
- Guards as predicates
- Invariants as assertions
- Transition system modeling

### Out of Scope
- Performance benchmarking Alloy vs TLC
- Liveness properties (not needed for cprr)
- Integration with cprr binary
