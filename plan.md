# VEIR ↔ LLZK port: master roadmap

Living document. Updated after every port, every verified pass, every infra
investigation. Cross-references the `harness/` directory for protocols and
the per-component working state.

The original Felt-port-specific plan that lived here through 2026-05-02 is
preserved in `LLZK_PORT_RETRO.md`. The reusable lessons from it are folded
into `harness/porting-notes.md`.

## Mission

1. **Port LLZK dialects** into VEIR so that LLZK MLIR can round-trip
   through `veir-opt` as typed VEIR IR (not `UnregisteredAttr` blobs).
2. **Produce verified examples** of LLZK passes in VEIR, leveraging
   VEIR's `WellFormed`-preservation and data-refinement scaffolding.
3. **Maintain a coverage review** (`harness/coverage.md`) so caveats and
   limitations are surfaced for any downstream consumer of this fork.

The harness is itself a deliverable: every doc under `harness/` is meant
to be maintained as work progresses, not written once.

## Status snapshot

| Component | State | Pointer |
|---|---|---|
| Felt dialect (18 ops, `!felt.type`) | ✅ ported (round-trip, generic format) | `LLZK_PORT_RETRO.md`, `Test/LLZK/Felt/identity.mlir` |
| String dialect (`string.new`, `!string.type`) | ✅ ported (round-trip, generic format) | `Test/LLZK/String/identity.mlir` |
| Include dialect (`include.from`) | ✅ ported (typed, with typed-path negative test) | `Test/LLZK/Include/{identity,invalid}.mlir` |
| RAM dialect (`ram.load`, `ram.store`) | ✅ ported (typed) | `Test/LLZK/RAM/{identity,invalid}.mlir` |
| Cast dialect (`cast.tofelt`, `cast.toindex`) | ✅ ported (typed) | `Test/LLZK/Cast/{identity,invalid}.mlir` |
| Bool dialect basic (and/or/xor/not/assert) | ⚠️ partial (bool.cmp deferred) | `Test/LLZK/Bool/{identity,invalid}.mlir` |
| Constrain dialect (eq only) | ⚠️ partial (constrain.in deferred) | `Test/LLZK/Constrain/{identity,invalid}.mlir` |
| `index` type | ✅ added inline as infra during A.4 | `Veir/IR/Attribute.lean` |
| Per-dialect attribute parser | ❌ none in VEIR (workaround: `IntegerAttr`) | `harness/coverage.md` §Attributes |
| Symbol references (`@name`) | ❌ no `SymbolRefAttr` case in `Attribute` | `harness/coverage.md` §Symbols |
| `AffineMapAttr` | ❌ unrepresented | `harness/coverage.md` §AffineMap |
| Variadic-of-variadic operands | ❌ unrepresented | `harness/coverage.md` §Ops |
| Regions (multi-block, terminators) | ❌ no `Region` in verified IR | `harness/coverage.md` §Structural |
| Dominance | ⚠️ axiomatized only (`Veir/Dominance.lean`) | `harness/coverage.md` §Verification |
| WellFormed preservation across rewrites | ✅ proven | `Veir/Rewriter/WellFormed/` |
| Data refinement framework | ⚠️ exists, only RISCV instruction-selection uses it | `Veir/Data/Refinement.lean` |
| `interpret ; pass = interpret` | ❌ no framework | `harness/verification-plan.md` |
| LLZK pass verification examples | ❌ none yet | `harness/verification-plan.md` |

## Phased roadmap

Phases are sized by **risk and infrastructure**, not by dialect count.
Each phase has a build gate (`lake build` clean, full lit suite green) and
ends with `harness/coverage.md` updated.

### Phase A — Tier 1 dialect batch (≈2–3 weeks)

Goal: prove the dialect-port recipe (`harness/dialect-port-checklist.md`)
generalizes. No new VEIR infrastructure beyond what Felt established.

In dependency order:

- [x] **A.1 Include** — symbol *producer*; uses upstream `FlatSymbolRefAttr` (PR #533). Includes a typed-path negative test (defense against Gotcha 2, made worse by upstream PR #569).
- [x] **A.2 String** — single op, single param-less type.
- [x] **A.3 Cast** — Felt + index types (both in place).
- [x] **A.4 RAM** — Felt-dependent, plus `index` type infra.
- [x] **A.5 Bool (basic)** — 5 of 6 ops ported; `bool.cmp` deferred to Phase D.4.
- [x] **A.6 Constrain (eq only)** — `constrain.eq` ported; `constrain.in` deferred to Phase D.3 (Array types).

*Build/lit counts at each phase: see git log / `baseline.txt` §tier-1-complete.*

Acceptance: each dialect has a `Test/<Dialect>/identity.mlir`, full lit
suite green, build clean, `harness/coverage.md` row updated.

### Phase B — Symbol-table architecture spike  **[RETIRED 2026-05-15]**

Originally a 1-week design phase for symbol-table semantics. Assessed
and retired after Tier 1 + the upstream merge revealed:

1. **Flat `@name` parsing landed upstream** (PR #533, `FlatSymbolRefAttr`).
   Include consumes it directly; no spike needed.
2. **Tier 2 (Global, POD, Array) needs nothing beyond flat refs** — the
   one symbol-using site, `!array.type<5,@N x !felt.type>`, takes a single
   flat ref inside a parametric type.
3. **Tier 3 (Function, Polymorphic, Struct) does need nested `@A::@B`
   plus SymbolTable semantics**, but those are *gated on Phase F (regions)*.
   The two design decisions should be made together, not in isolation.

The original framing is preserved in `harness/symbol-table-spike.md`
(marked deferred) and the remaining open questions are folded into
Phase F's design scope.

### Phase C — Attribute & operand infrastructure (≈2 weeks)

Lands the per-dialect attribute and operand machinery needed by
Tier 2. (Originally included a `SymbolRefAttr` parser; that's now
delivered by upstream.)

- [ ] **C.1** `AffineMapAttr` in `Attribute.lean` + parser (black-box: store the textual form, no semantic interpretation yet)
- [ ] **C.2** Variadic-of-variadic operand handling in `OpCode`/`Verifier`
- [ ] **C.3** Enum-attribute story finalized (either a per-dialect parser pattern, or keep the `IntegerAttr` workaround documented)

Acceptance: one consumer dialect for each piece of infra lands as a
follow-on commit on the same branch.

### Phase D — Tier 2 dialects (≈1–2 weeks)

- [ ] **D.1 Global** — uses upstream `FlatSymbolRefAttr` (no new infra)
- [ ] **D.2 POD** — uses C.2 + C.3
- [ ] **D.3 Array** (types + non-symbol ops) — uses C.2 + C.3
- [ ] **D.4 Bool full** — adds `bool.cmp` (uses C.4 if enum parser; else stays on `IntegerAttr`)

### Phase E — Verification pilot 1: Felt local rewrite (≈2 weeks)

First verified LLZK-touching pass, deliberately scoped small.

- [ ] **E.1** Pattern: `felt.add x (felt.const 0) → x`. Mirror
      `Veir/Passes/Combines/Combine.lean` (which proves the same identity
      for RISCV addi).
- [ ] **E.2** Proof: state and prove the algebraic identity in
      `Veir/Passes/Felt/Proofs.lean`. Felt has no interpreter yet so the
      theorem is structural (matches Combines/Proofs.lean style) or
      data-level once a `Veir/Data/Felt/` semantic model lands.
- [ ] **E.3** Decide whether to add a minimal `Veir/Data/Felt/` semantics
      module (a finite field is abstract; use a `variable` field
      parameter and treat semantics over an arbitrary commutative
      ring with appropriate operations).
- [ ] **E.4** Lit test that runs the pass and FileChecks the output.

Acceptance: build green, lit green, zero new `sorry` in the new files.

### Phase F — Region infrastructure + symbol-table design (≈3–6 weeks)

Major architectural addition to VEIR's verified IR. Gates Function,
Polymorphic, Struct, Array (with symbol-bearing dims used inside
regions), and almost all LLZK transform passes.

Includes the design questions that were originally Phase B (now
retired) because they're tightly coupled to region semantics:

- [ ] **F.1** Design note: structural region representation (block
      ownership, terminator op verification, IsolatedFromAbove
      semantics, region-as-symbol-table-scope). Includes the
      former Phase B questions:
  - [ ] nested `SymbolRefAttr` (`@A::@B`) parsing + storage
  - [ ] `SymbolTable` trait on parent ops; child-lookup semantics
  - [ ] `SymbolUserOpInterface` resolution at use sites
  - [ ] whether `WellFormed` includes symbol integrity, or symbol
        resolution stays an unverified pass-level concern (recommended
        hybrid path from `harness/symbol-table-spike.md` still applies)
- [ ] **F.2** Implementation in `Veir/IR/`.
- [ ] **F.3** Update `Veir/Rewriter/` for region-aware rewrites.
- [ ] **F.4** Re-prove WellFormed preservation.
- [ ] **F.5** Prototype `Function.def` (a Symbol producer with a
      region body) as the first concrete consumer of both pieces.

This is its own project; the design note should land before
committing to a schedule.

### Phase G — Tier 3 dialects (gated by F)

- [ ] **G.1 Function** — `function.def`, `function.return`, `function.call`
- [ ] **G.2 Polymorphic** — `poly.template`, type variables, `LLZKSymbolTable` trait
- [ ] **G.3 Struct** — `struct.def`, parametric `!struct.type<@A<[...]>>`, member symbols, nested functions

### Phase H — Verification pilot 2 onward

Pilots in increasing difficulty (sourced from LLZK transforms by
verifiability score; see `harness/verification-plan.md`):

- [ ] **H.1 EnforceNoOverwrite checker** (LLZK trivial-1, but needs G.3
      to run on real Struct ops — Felt-only variant could land earlier)
- [ ] **H.2 UnusedDeclarationElimination** (DCE, needs G.1 + G.3)
- [ ] **H.3 RedundantOperationElimination** (CSE-style, needs dominance
      properly implemented — `Veir/Dominance.lean` is axiomatized today)

### Out-of-band: SMT dialect

Orthogonal to the rest. Port only when there's a concrete use case;
treat as a separate project.

## Living-document protocol

Three rules:

1. **Coverage updates are non-optional.** Any commit that adds support
   for an LLZK feature, or that discovers a new gap, updates
   `harness/coverage.md` in the same commit.
2. **Phase boundaries are commit boundaries.** Each phase ends with a
   green build, a green test suite, a coverage update, and a
   checkpointing tag per `harness/checkpoint-protocol.md`.
3. **Porting notes accumulate.** Anything surprising encountered during
   a port goes into `harness/porting-notes.md` in the same commit, so
   the next porter benefits. Don't wait for a retro.

## Cross-references

| Topic | Doc |
|---|---|
| Per-dialect work | `harness/dialect-port-checklist.md` |
| "Is this port/pass done?" | `harness/evaluation-criteria.md` |
| Commit/branch/tag conventions | `harness/checkpoint-protocol.md` |
| Durable porting gotchas (the two from Felt + new ones) | `harness/porting-notes.md` |
| Verification pilot designs | `harness/verification-plan.md` |
| LLZK feature ↔ VEIR support | `harness/coverage.md` |
| Felt port history | `LLZK_PORT_RETRO.md` |

## Iteration commands (unchanged from Felt)

```bash
lake build                       # 207/207 currently
lake test                        # UnitTest target
uv run lit Test/ -v              # 264/264 currently
uv run lit Test/<Dialect>/identity.mlir -v
```
