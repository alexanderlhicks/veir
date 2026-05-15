# Verification plan

The road to verified LLZK passes inside VEIR. Updated as pilots land
and as the underlying machinery evolves.

## Why this isn't a one-shot project

The intuitive "pick an LLZK transform pass and verify it" plan
collides with the current state of VEIR:

1. **Most LLZK transform passes operate over Struct/Function**
   (UnusedDeclarationElimination, EnforceNoOverwrite, PolyLowering,
   InlineStructs, ComputeConstrainToProduct, FuseProductLoops). Those
   dialects are Tier 3 — gated on regions (Phase F).
2. **The simpler passes operate over Felt/Bool/Constrain/Arith**
   (RedundantOperationElimination is CSE-style across these), which
   we *can* port soon. But CSE needs dominance, and
   `Veir/Dominance.lean` is axiomatized.
3. **No LLZK dialect has an interpreter** in
   `Veir/Interpreter/`. So `interpret ; pass = interpret`-style
   semantic equivalence is not currently achievable.

The remaining option is what `Veir/Passes/Combines/` already does
for RISCV: **algebraic identities over individual ops, decoupled from
control flow.** Mirroring that for Felt is the right first step.

## Pilot pipeline

### Pilot 1: `felt.add x 0 → x` (right identity)

**Status**: ✅ landed 2026-05-15.

**Mirror**: `Veir/Passes/Combines/Combine.lean` proves the same
identity for RISCV's `add`. The Felt version is a near-copy with
different types.

**Files to create**:

- `Veir/Passes/Felt/Combine.lean` — the rewriter
- `Veir/Passes/Felt/Proofs.lean` — the algebraic theorem
- `Test/Felt/right_identity.mlir` — lit test

**Theorem (sketch)**:

```lean
-- Over an abstract commutative ring with zero (Felt's underlying semantics)
theorem felt_add_zero (R : Type) [CommRing R] (x : R) : x + 0 = x := by
  simp
```

The pass file is structural; the theorem is one line of `simp`.
Acceptance criteria §B is met by:
- The theorem holds for any commutative ring (sound regardless of
  field choice).
- The rewriter file mirrors `Combines/Combine.lean` patterns,
  including `sorry`s in rewriter preconditions (consistent with
  current VEIR practice — see `harness/evaluation-criteria.md` §B.1).
- The lit test runs `veir-opt -p felt-combine` and FileChecks.

**Effort**: 1–2 days once Phase A ships. Mostly mechanical.

**Open design question**: do we model Felt semantics as
(a) an abstract `[CommRing R]` parameter (cheap, no commitment to a
specific field) or
(b) a concrete `ZMod p` instance (commits to one field) or
(c) build a small `Veir/Data/Felt/` module mirroring
`Veir/Data/LLVM/Int/`?

Recommendation: start with (a). The theorem is field-agnostic; we
don't need to pick a modulus until a pass actually depends on field
size.

---

### Pilot 2: `felt.const c1 + felt.const c2 → felt.const (c1+c2)` (constant fold)

**Status**: ✅ landed 2026-05-15.

**Mirror**: `Veir/Passes/InstCombine.lean` lines 42–45 do constant
folding for LLVM but without proofs. The verified version would prove:

```lean
theorem felt_const_fold (R : Type) [CommRing R] (c₁ c₂ : R) :
    (c₁ : R) + (c₂ : R) = (c₁ + c₂ : R) := by
  rfl
```

Trivially true; the work is on the pattern side (matching `const +
const` rather than `_ + const`). Pattern-rewriter side has `sorry`s
for preconditions (consistent with current state).

**Effort**: 1 day after Pilot 1.

---

### Pilot 3: `felt.sub x x → felt.const 0` (self-subtraction)

**Status**: ✅ landed 2026-05-15.

**Theorem**: `∀ x, x - x = 0` in `[Ring R]`. One-line proof.

**Effort**: 1 day.

The point of pilots 1–3 is **not** to prove deep LLZK semantics; it's
to **exercise the harness** — to confirm that

- the seven-file dialect-port recipe extends to a
  Veir/Passes/`<Dialect>`/ pair (rewriter + proofs)
- a passing port plus a one-line algebraic theorem clears the §B
  acceptance bar
- the lit-test integration works for pass invocation

Three pilots over Felt is enough to validate the workflow. Then the
real question opens up.

---

### Pilot 4 (stretch): `felt.add (felt.add x c1) c2 → felt.add x (c1+c2)` (associativity-driven canonicalization)

**Status**: ✅ landed 2026-05-15. The dominance-light reasoning the
spike worried about turned out to be subsumed by `getDefiningOp!` —
the inner add and its constant are visible from the outer add's
match, and we replace the outer add in place (no SSA reference-before-
def issue).

**Theorem**: `(x + c₁) + c₂ = x + (c₁ + c₂)` over a commutative ring.
Provable but the rewriter side requires looking at the defining op of
one of the operands (dominance-light reasoning).

**Open**: does this require dominance to be proven (not axiomatized)?
The matching itself is local but the *correctness* of replacing a use
when the def is in the same block doesn't strictly need dominance
beyond the local form. Worth a spike.

**Effort**: 2–3 days once a single-pass dominance reasoning pattern is
worked out.

---

### Beyond Felt: LLZK transform passes

The five candidates ranked by `Catalog LLZK passes` agent, ordered by
verifiability score:

| Pilot | LLZK pass | Score | Gating dialects | Gating verification infra |
|---|---|---|---|---|
| 5 | EnforceNoOverwrite | 1 | Function, Struct | Lattice-based dataflow (new in VEIR) |
| 6 | UnusedDeclarationElimination | 2 | Function, Struct | Symbol use-def graph |
| 7 | RedundantOperationElimination | 2 | Felt, Bool, Constrain, Function | **Dominance** (currently axiomatized) |
| 8 | RedundantReadAndWriteElimination | 3 | Struct, Array, Felt, Function | Memory-state machine |
| 9 | PolyLowering | 4 | Constrain, Felt, Array, Function | Polynomial-ring algebra, observational equivalence |

Pilots 5–9 are gated. Pilot 7 (CSE) is the most likely first
*real* LLZK pass to verify, but it requires dominance to be
actually proven (not axiomatized in `Veir/Dominance.lean`). That's a
project on its own.

Pilots 5/6 require Function and Struct dialects (Tier 3 / Phase G) —
a long way out.

## VEIR-side enablers (by priority)

These are the infrastructure additions that, if landed, would unlock
verified LLZK passes:

### Enabler A: real Felt semantics module (small)

A `Veir/Data/Felt/Basic.lean` and `Lemmas.lean` mirroring
`Veir/Data/LLVM/Int/Basic.lean`. Probably 50–100 LoC. Lets pilots
1–4 state their theorems against a concrete model and not against
`[CommRing R]`. **Optional** — start with the abstract form.

### Enabler B: replace axioms in `Veir/Dominance.lean`

9 axioms; the predicate `dominates` is undefined. Until this lands,
no verified pass can use dominance. Estimated: 1–3 weeks
depending on chosen formulation. Open question: does VEIR upstream
have a roadmap for this? (The file's header says "It currently only
contains axioms, and will be filled in with actual definitions and
proofs".)

### Enabler C: pattern-rewriter precondition discharge

The current `~179 sorry`s in `Veir/Passes/` are mostly precondition
discharges (`rewriter.replaceValue _ _ sorry sorry`). A focused
project to add helper lemmas (e.g., "in a pattern that matched op X,
the defining-op of operand 0 is in bounds") would eliminate most of
these. Estimated: 2–4 weeks, but cleans up a lot of debt.

### Enabler D: a single LLZK interpreter arm

If any LLZK pass is to be proved correct via interpreter equivalence,
some dialect needs interpreter coverage. Felt is the natural
candidate — `Veir/Interpreter/Basic.lean` has LLVM and RISCV arms;
adding Felt is a precedent-following exercise. Probably 1 week.

This is the path that opens up `interpret ; pass = interpret`
proofs.

### Enabler E: lattice-based dataflow framework

For Pilots 5/6 (and several LLZK analyses). Big — likely several
weeks of work to build a generic `SparseAnalysis`-equivalent in Lean
and prove its soundness.

---

## Pilot ↔ enabler dependency matrix

|   | A: Felt model | B: dominance | C: precond | D: interpreter | E: dataflow |
|---|---|---|---|---|---|
| Pilot 1 (right id) | optional | — | optional (rewriter side) | — | — |
| Pilot 2 (const fold) | optional | — | optional | — | — |
| Pilot 3 (self sub) | optional | — | optional | — | — |
| Pilot 4 (assoc canon) | optional | maybe | optional | — | — |
| Pilot 5 (NoOverwrite) | — | — | — | — | **required** |
| Pilot 6 (UnusedDecl) | — | — | — | — | **required** |
| Pilot 7 (CSE / RedundOp) | — | **required** | — | — | — |
| Pilot 8 (RedundRW) | — | partial | — | — | — |
| Pilot 9 (PolyLowering) | **required** | — | — | maybe | — |

Reading the matrix: **Pilots 1–4 are unblocked.** Pilots 5–9 each need
substantial infrastructure work.

---

## Measurement

Pilots count as verified when they meet §B in
`harness/evaluation-criteria.md`. The `harness/coverage.md`
§Verification machinery rows update as enablers land (e.g., when
Dominance moves from ⚠️ axiomatized to ✅).

A summary row appears in `plan.md` Status snapshot once Pilot 1
lands.

---

## Cross-references

- Existing verified passes in VEIR: `Veir/Passes/InstructionSelection/Proofs.lean`,
  `Veir/Passes/Combines/Proofs.lean`
- VEIR refinement framework: `Veir/Data/Refinement.lean`
- Rewriter scaffolding: `Veir/Rewriter/WfRewriter/`
- Pattern rewriter: `Veir/PatternRewriter/Basic.lean`
- LLZK pass list to choose from: `llzk-lib/lib/Transforms/*.cpp` and
  `llzk-lib/include/llzk/Transforms/LLZKTransformationPasses.td`
