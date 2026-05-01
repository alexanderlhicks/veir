# LLZK Felt → VEIR port

Branch: `llzkfelt_test1`. Living plan; update after each phase.

## Goal

Round-trip MLIR generic-format text containing `felt.*` ops and `!felt.type` through
`veir-opt`, mirroring the existing `mod_arith` dialect in VEIR. No semantic
verification beyond operand/result/region shape checks (matches what other
dialects in VEIR do).

**Success criterion**: `uv run lit Test/Felt/identity.mlir` passes, full
`lake test && uv run lit Test/ -v` stays green.

## Scope

- 18 ops: `const`, `add`, `sub`, `mul`, `pow`, `div`, `uintdiv`, `sintdiv`,
  `umod`, `smod`, `neg`, `inv`, `bit_and`, `bit_or`, `bit_xor`, `bit_not`,
  `shl`, `shr`.
- One type: `!felt.type` and `!felt.type<"name">`.
- `felt.const`'s value stored as `IntegerAttr` (mod_arith precedent), not as a
  structured `FeltConstAttr`. Field name recovered from result type at print.

### Out of scope (deferred)

- Structured `#felt.const<...>` attribute (would need first per-dialect
  attribute parser in VEIR).
- `LLZK_FieldSpecAttr` (`field<name, prime>`).
- LLZK custom assembly format (`%0 = felt.add %a, %b`) — generic format only.
- `NotFieldNative`/`Commutative`/folder/canonicalizer behavior.
- LLZK semantic checks (`AllowConstraintAttr`, `AllowWitnessAttr`, etc.).

## Phases

Each phase ends with `lake build` clean; the failing test (Phase 0) gets less
red as we go.

- [x] **Phase 0 — Harness**
  - [x] Branch `llzkfelt_test1`
  - [x] Baseline captured (`baseline.txt`)
  - [x] `plan.md` (this file)
  - [x] `Test/Felt/identity.mlir` (failing forcing-function)
  - [x] Confirmed: full lit suite is **263/264 green**; only `Felt/identity.mlir`
        fails, because `felt.const` falls through to `builtin.unregistered`. This
        is the expected forcing-function failure.
- [ ] **Phase 1 — `Veir/IR/Attribute.lean`**
  - [ ] `structure FeltType` (mirrors `ModArithType`, optional `ByteArray` fieldName)
  - [ ] `Attribute.feltType` case
  - [ ] `Attribute.decEq` arm
  - [ ] `ToString FeltType`
  - [ ] `Attribute.toString` arm + `Attribute.isType` arm
  - [ ] `@[simp, grind =] isType_feltType` theorem
  - [ ] `Coe FeltType Attribute`, `Coe FeltType TypeAttr`
  - [ ] `lake build` clean
- [ ] **Phase 2 — `Veir/OpCode.lean`**
  - [ ] `@[opcodes] inductive Felt` with all 18 constructors
  - [ ] `lake build` clean; verify `OpCode.fromName "felt.const".toByteArray = .felt .const`
- [ ] **Phase 3 — Properties + per-dialect OpInfo**
  - [ ] `FeltConstProperties { value : IntegerAttr }` in `Veir/Properties.lean`
        (clone of `ModArithConstantProperties`)
  - [ ] `Veir/Dialects/Felt/OpInfo.lean` (clone of `Dialects/ModArith/OpInfo.lean`)
  - [ ] Wire in `Veir/GlobalOpInfo.lean` (import + `propertiesOf` + `fromAttrDict` + `toAttrDict`)
  - [ ] `lake build` clean
- [ ] **Phase 4 — `Veir/Verifier.lean`**
  - [ ] 18 arms (1 const, 14 binary, 3 unary). Mechanical clones of `mod_arith.add`/`mod_arith.constant`.
  - [ ] `lake build` clean
- [ ] **Phase 5 — `Veir/Parser/AttrParser.lean`**
  - [ ] `parseOptionalFeltType` — accepts `!felt.type` and `!felt.type<"name">`
  - [ ] Slot into `parseOptionalType` *before* the `parseOptionalDialectType` fallthrough
  - [ ] `lake build` clean
- [ ] **Phase 6 — Test**
  - [ ] `uv run lit Test/Felt/identity.mlir` passes
  - [ ] `uv run lit Test/ -v` (full suite) stays green
  - [ ] `lake test` (unit tests) stays green

## Open questions / spikes to confirm

- [ ] **Does extending the `Attribute` inductive require touching
      `IR/Fields.lean`, `GetSet.lean`, or `WellFormed.lean`?** Expectation: no.
      Those reason about IR structure (operations/blocks/regions), and
      attributes are opaque payloads. Will know after Phase 1 builds.
- [ ] **Does `parseOptionalAttribute` reach `IntegerAttr` cleanly when the
      result type is `!felt.type`?** Expectation: yes — the value is just an
      `IntegerAttr` and the type discrimination is on the *result* type. Will
      know when Phase 6 runs.
- [ ] **`@[opcodes]` lowercasing**: `Dialect.getName = name.toLower`, so
      `"Felt".toLower = "felt"`. Should be fine. Confirm in Phase 2.

## Decisions log

- **2026-05-01**: Use `IntegerAttr` for `felt.const`'s value, not a structured
  `FeltConstAttr`. Why: VEIR has no per-dialect attribute parser today
  (everything `#dialect.name<...>` falls through to `UnregisteredAttr`); adding
  the first one is real new infrastructure. Mirroring mod_arith's
  `IntegerAttr` precedent stays inside existing patterns. The cost is that
  printed output uses `<{"value" = 42 : i256}>` instead of LLZK's
  `<{"value" = #felt.const<42>}>`. Re-evaluate if/when porting Struct
  (which needs structured dialect attributes anyway for `<[5, @C, !felt.type]>`
  parameter lists).
- **2026-05-01**: Generic MLIR format only as the round-trip target. LLZK's
  custom assembly (`%0 = felt.add %a, %b`) is a separate phase, deferred.
- **2026-05-01**: First-run `lake build` flake (exit 143 from SIGTERM on
  `Rewriter/GetSet/{DetachOp,CreateOp}`) traced to elan toolchain-lock race
  at startup. Resolved on retry. Documented in `baseline.txt`. Not a code
  issue; flagging here so future flakes with the same signature can be
  immediately recognized.

## Iteration commands

```bash
# Build
lake build
# Felt-only test (forcing function)
uv run lit Test/Felt/identity.mlir -v
# Full suites
lake test
uv run lit Test/ -v
```

## Reference

- LLZK source: `llzk-lib/include/llzk/Dialect/Felt/IR/{Dialect,Types,Attrs,Ops}.td`
- VEIR analog: search for `mod_arith` / `ModArith` / `Mod_Arith`. Touched files:
  `Veir/IR/Attribute.lean`, `Veir/OpCode.lean`, `Veir/Properties.lean`,
  `Veir/Dialects/ModArith/OpInfo.lean`, `Veir/GlobalOpInfo.lean`,
  `Veir/Parser/AttrParser.lean`, `Veir/Verifier.lean`, `Test/ModArith/identity.mlir`.
