-- cprr State Machine in Alloy
-- Conjecture-Proposition-Refutation-Resolution

abstract sig Status {}
one sig Open, Testing, Confirmed, Refuted, Abandoned extends Status {}

sig Evidence {}

sig Conjecture {
    var status: one Status,
    var hypothesis: lone String,
    var evidence: set Evidence
}

-- String placeholder (Alloy doesn't have native strings)
sig String {}

-- Initial state: all conjectures start Open, no hypothesis, no evidence
pred init {
    all c: Conjecture | c.status = Open
    all c: Conjecture | no c.hypothesis
    all c: Conjecture | no c.evidence
}

-- Guard: hypothesis required for Open -> Testing
pred canAdvanceToTesting[c: Conjecture] {
    c.status = Open
    some c.hypothesis
}

-- Guard: 2+ evidence for Testing -> Confirmed
pred canConfirm[c: Conjecture] {
    c.status = Testing
    some c.hypothesis
    #c.evidence >= 2
}

-- Guard: 1+ evidence for Testing -> Refuted
pred canRefute[c: Conjecture] {
    c.status = Testing
    #c.evidence >= 1
}

-- Abandon is always allowed (escape hatch)
pred canAbandon[c: Conjecture] {
    c.status != Abandoned
}

-- Transitions
pred advanceToTesting[c: Conjecture] {
    canAdvanceToTesting[c]
    c.status' = Testing
    c.hypothesis' = c.hypothesis
    c.evidence' = c.evidence
    -- frame: other conjectures unchanged
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

pred confirm[c: Conjecture] {
    canConfirm[c]
    c.status' = Confirmed
    c.hypothesis' = c.hypothesis
    c.evidence' = c.evidence
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

pred refute[c: Conjecture] {
    canRefute[c]
    c.status' = Refuted
    c.hypothesis' = c.hypothesis
    c.evidence' = c.evidence
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

pred abandon[c: Conjecture] {
    canAbandon[c]
    c.status' = Abandoned
    c.hypothesis' = c.hypothesis
    c.evidence' = c.evidence
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

pred setHypothesis[c: Conjecture, h: String] {
    c.status = Open
    no c.hypothesis
    c.hypothesis' = h
    c.status' = c.status
    c.evidence' = c.evidence
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

pred addEvidence[c: Conjecture, e: Evidence] {
    c.status = Testing
    e not in c.evidence
    c.evidence' = c.evidence + e
    c.status' = c.status
    c.hypothesis' = c.hypothesis
    all other: Conjecture - c |
        other.status' = other.status and
        other.hypothesis' = other.hypothesis and
        other.evidence' = other.evidence
}

-- System transition: one of the above happens
pred step {
    (some c: Conjecture | advanceToTesting[c]) or
    (some c: Conjecture | confirm[c]) or
    (some c: Conjecture | refute[c]) or
    (some c: Conjecture | abandon[c]) or
    (some c: Conjecture, h: String | setHypothesis[c, h]) or
    (some c: Conjecture, e: Evidence | addEvidence[c, e])
}

pred stutter {
    all c: Conjecture |
        c.status' = c.status and
        c.hypothesis' = c.hypothesis and
        c.evidence' = c.evidence
}

fact traces {
    init
    always (step or stutter)
}

-- INVARIANTS

-- Confirmed conjectures must have hypothesis and 2+ evidence
assert confirmedRequiresEvidence {
    always all c: Conjecture |
        c.status = Confirmed implies (some c.hypothesis and #c.evidence >= 2)
}

-- Refuted conjectures must have evidence
assert refutedRequiresEvidence {
    always all c: Conjecture |
        c.status = Refuted implies #c.evidence >= 1
}

-- Terminal states are stable
assert terminalStatesStable {
    always all c: Conjecture |
        (c.status = Confirmed or c.status = Refuted or c.status = Abandoned)
        implies c.status' = c.status
}

-- Abandoned is always reachable (liveness-ish property)
assert abandonAlwaysReachable {
    all c: Conjecture | c.status != Abandoned implies canAbandon[c]
}

-- Check invariants
check confirmedRequiresEvidence for 3 but 10 steps
check refutedRequiresEvidence for 3 but 10 steps
check terminalStatesStable for 3 but 10 steps
check abandonAlwaysReachable for 3 but 10 steps

-- Visualize example traces
run happyPath {
    some c: Conjecture | eventually c.status = Confirmed
} for 1 Conjecture, 3 Evidence, 2 String, 10 steps

run refutationPath {
    some c: Conjecture | eventually c.status = Refuted
} for 1 Conjecture, 2 Evidence, 1 String, 10 steps
