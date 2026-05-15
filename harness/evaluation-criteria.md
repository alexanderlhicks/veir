# Evaluation criteria

"Done" definitions for dialect ports, verification pilots, and
infrastructure additions. Used as PR review checklists and as
acceptance criteria when closing a phase in `plan.md`.

The same criteria apply whether the work is by an internal contributor
or an external one — these are the bars to clear before claiming
something is complete.

---

## §A. Dialect port — "Done"

A dialect port is **Done** when all of the following hold:

### A.1 Build and tests

- [ ] `lake build` clean (target count matches or exceeds prior +N for
      any new files added)
- [ ] `lake test` clean (UnitTest target green)
- [ ] `uv run lit Test/ -v` count = previous total + 1 (the new
      `Test/<Dialect>/identity.mlir`)
- [ ] No new `sorry` introduced in any new file (the `Veir/Passes/`
      legacy `sorry` count of ~179 is allowed; new files must be
      `sorry`-free)
- [ ] No new `axiom` introduced anywhere in `Veir/`

### A.2 Round-trip coverage

- [ ] `Test/<Dialect>/identity.mlir` exercises **every** op the port
      claims to support, with at least one representative form of each
      type
- [ ] For each type with optional parameters, both the bare and the
      parameterized form are exercised
- [ ] FileCheck assertions verify both the op invocation and the type
      annotations on results

### A.3 Typed representation (not just textual)

This is the criterion that defends against Gotcha 2 (silent
`UnregisteredAttr` round-trip).

- [ ] If a new type was added to `Attribute` (Phase 1 of the
      checklist), then a corresponding `parseOptionalXxxType` exists
      and is wired into `parseOptionalType` (Phase 5)
- [ ] **Either**:
  - (a) a Lean-level unit test in `UnitTest/` constructs the
        attribute programmatically, parses a text round-trip, and
        asserts the resulting `Attribute` case matches; **or**
  - (b) a code comment in the PR description explicitly attests that
        the parser was tested and the typed case is reachable
- [ ] Programmatic pattern-match on the typed case compiles in at
      least one usage site (e.g., `def isFeltType : Attribute → Bool := fun | .feltType _ => true | _ => false` builds)

### A.4 Coverage and notes

- [ ] `harness/coverage.md` rows updated to ✅ or ⚠️ with caveat links
- [ ] Any new caveat (e.g., a trait that wasn't encoded) appears as a
      row in the relevant section
- [ ] If anything surprising arose during the port,
      `harness/porting-notes.md` has a new section in the same commit
- [ ] If a new VEIR-side limitation was discovered, it's filed under
      §Known cross-cutting limitations

### A.5 Quality bars

- [ ] No copy-pasted comments referencing the donor dialect (e.g., no
      `mod_arith` mentions inside Felt files)
- [ ] No `TODO` for the dialect being shipped; outstanding work goes
      into `plan.md` as a future phase, not as a comment
- [ ] Commit history is logical (one phase per commit is the default;
      Phase 2's atomic three-file landing is the exception)
- [ ] No formatter regressions: `clang-format` is not relevant here;
      Lean style follows existing files (no per-file style changes)

---

## §B. Verification pilot — "Done"

A verified pass pilot is **Done** when all of the following hold:

### B.1 Build, tests, and proof health

- [ ] `lake build` clean
- [ ] `lake test` clean
- [ ] `uv run lit Test/ -v` passes; new lit test exercises the pass
- [ ] **Zero `sorry` in any new file.** The theorem and its support
      lemmas are fully proved. The pass-implementation file may still
      use `sorry` for rewriter preconditions (consistent with current
      VEIR practice), but the *proof* file must be clean.
- [ ] **Zero new `axiom`** anywhere

### B.2 Theorem statement

- [ ] The proof file states a **clear, named theorem** capturing what
      the pass guarantees. Examples of acceptable statements:
  - *Algebraic identity*: `theorem felt_add_zero (x : Felt) : x + 0 = x`
  - *Refinement*: `isRefinedBy (sourceOp ...) (targetOp ...)` per
    `Veir/Data/Refinement.lean`
  - *Preservation*: `WellFormed ctx → WellFormed (pass ctx)` (this
    one is free from the rewriter scaffolding, so it's not a useful
    bar on its own — needs to be paired with one of the above)
- [ ] The theorem statement references the actual operations the pass
      rewrites (not a placeholder)

### B.3 Pass integration

- [ ] The pass is registered with the pass pipeline (so `veir-opt -p
      <name>` invokes it)
- [ ] A lit test (`Test/<Dialect>/<pass>.mlir`) runs the pass and
      FileChecks the output

### B.4 Documentation

- [ ] `harness/verification-plan.md` lists the pilot as completed and
      links the theorem
- [ ] `harness/coverage.md` §Verification machinery is updated if the
      pilot pushed any capability from ⚠️ to ✅
- [ ] If the proof revealed a missing VEIR-side capability that was
      worked around with axioms in `Veir/Dominance.lean` (or
      elsewhere), the workaround is documented

### B.5 Realism

- [ ] The pilot is **not vacuous**: it operates on at least one real
      LLZK construct and is *enabled* by default in some pass
      pipeline, or has a documented use case
- [ ] The theorem statement is **not circular**: it doesn't define
      semantics in terms of itself; it relates the rewritten IR to an
      independent semantic model (an algebraic identity over a field
      type, an interpreter trace, or a refinement relation)

---

## §C. Infrastructure addition — "Done"

For phases that add VEIR-side machinery (Phase B symbol-table design,
Phase C `SymbolRefAttr`/`AffineMapAttr`/variadic-of-variadic, Phase F
regions):

### C.1 Design doc

- [ ] A short design note exists in `harness/` covering: what was
      added, what alternatives were considered, what's *not* supported
      yet, and the migration path for the rejected alternatives
- [ ] The design note is referenced from `plan.md` in the matching
      phase

### C.2 Build and proof health

- [ ] `lake build` clean
- [ ] Existing `WellFormed` proofs continue to hold (if the
      infrastructure touches `Veir/IR/` or `Veir/Rewriter/`)
- [ ] No new `sorry` in `Veir/IR/` or `Veir/Rewriter/`
- [ ] Any new `axiom` is justified in the design doc (with a TODO to
      remove it)

### C.3 Consumer

- [ ] At least one consumer dialect uses the new infrastructure in a
      follow-on commit on the same branch (closes the
      Phase-1-only-typed-case-dead-code class of failure for
      infrastructure too)

### C.4 Coverage and notes

- [ ] `harness/coverage.md` rows updated (typically pulling several
      ❌ rows to ✅)
- [ ] `harness/porting-notes.md` updated with any new gotcha or
      pattern that emerged

---

## §D. Cross-cutting bars

These apply to all changes:

- [ ] The PR/commit description names the relevant `plan.md` phase
      and links it
- [ ] No regression in test counts (`lit Test/` total never
      decreases)
- [ ] No regression in `harness/coverage.md` status (downgrading a
      row requires explicit explanation per §Maintenance protocol)
- [ ] No formatting/whitespace-only changes mixed with substantive
      changes (separate commits if both are needed)

---

## §E. Anti-patterns (auto-fail)

A change is **not** done if any of the following applies:

1. **Hidden workarounds.** "Stored as `IntegerAttr` because we don't
   have structured attributes" must appear in `coverage.md`, not only
   as a code comment.
2. **Dead typed paths.** Adding an `Attribute` case without wiring it
   into `parseOptionalType` (Gotcha 2). The forcing-function test
   passing is *not* sufficient.
3. **Silent coverage drift.** Changing what an op accepts without
   updating the test that documents it.
4. **`sorry` flooding.** Adding many `sorry`s to a *new* proof file
   to make it appear complete. The existing `~179` in
   `Veir/Passes/` are legacy; new proof files must be clean.
5. **`axiom` inflation.** Adding an axiom to make a proof go through
   without a corresponding design note explaining why and how it'll
   be removed.
6. **README claims that outrun the code.** Adding "LLZK Felt
   verified" or similar to the README feature matrix without B-grade
   acceptance criteria met.

---

## §F. Review template (for PR descriptions)

```markdown
### What

<one-paragraph summary>

### Plan reference

Phase: <e.g. A.3 — Cast dialect port>
Coverage rows affected: <list>

### Acceptance criteria

- [ ] §A.1 Build and tests
- [ ] §A.2 Round-trip coverage
- [ ] §A.3 Typed representation
- [ ] §A.4 Coverage and notes
- [ ] §A.5 Quality bars

### Notes

- New gotchas discovered: <yes/no, link to porting-notes.md if yes>
- New VEIR-side limitations discovered: <yes/no>
- Deferred from this port: <list>
```
