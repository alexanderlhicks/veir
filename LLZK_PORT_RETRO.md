# LLZK Felt → VEIR port: retrospective

Companion to `plan.md`. Written 2026-05-02 after the Felt dialect landed
on `llzkfelt_test1`. Scope: durable lessons for the next LLZK dialect port,
plus concrete scaling estimates.

If you are about to port a second LLZK dialect into VEIR, read this first.

## TL;DR

- Felt landed in 5 commits, ~145 source LoC across 6 files plus one new
  22-line `Veir/Dialects/Felt/OpInfo.lean`. `lake build` 207/207, lit
  264/264 (up from 263/264 baseline), `lake test` clean.
- Two surprises that aren't in the existing docs:
  1. **Adding a single `OpCode` constructor breaks two exhaustive matches
     in unrelated files** (`Veir/Verifier.lean` and
     `Veir/GlobalOpInfo.lean`'s `Properties.fromAttrDict`). Both must be
     patched in the same commit or `lake build` fails. Plan accordingly.
  2. **`parseOptionalDialectType` silently round-trips unknown dialect
     types as `UnregisteredAttr`.** Textual round-trip tests can pass
     without the typed parser branch ever being wired up. You will
     not notice from a FileCheck test alone. Add the typed parser anyway
     unless you have a specific reason not to.
- One precedent set, one not set:
  - **Set**: a dialect type with an optional `<...>` body
    (`parseOptionalFeltType`). Useful for future LLZK types that have
    optional parameters.
  - **Not set**: per-dialect *attribute* parsers. VEIR still has no
    structured `#dialect.name<body>` parser; everything falls through to
    `UnregisteredAttr`. The Felt port deliberately sidestepped this by
    storing `felt.const`'s value as `IntegerAttr` instead of LLZK's native
    `FeltConstAttr`. Worth budgeting for whenever the next port needs
    structured dialect attributes (Struct, Polymorphic, anything with
    `<[5, @C, !felt.type, #map]>` parameter lists).

## Scope of the port

What shipped:
- 18 felt ops: `const`, `add`, `sub`, `mul`, `pow`, `div`, `uintdiv`,
  `sintdiv`, `umod`, `smod`, `neg`, `inv`, `bit_and`, `bit_or`, `bit_xor`,
  `bit_not`, `shl`, `shr`.
- One type: `!felt.type` and `!felt.type<"name">`.
- Round-trip end-to-end as typed VEIR values (not `UnregisteredAttr`
  blobs).

What did *not* ship, and why:
- **`#felt.const<value>` structured attribute**. LLZK encodes
  `felt.const`'s value as a typed `FeltConstAttr` carrying both an `APInt`
  and the field type. VEIR has no per-dialect attribute parser today
  (every `#dialect.name<...>` falls through to `UnregisteredAttr`). Adding
  the first one would be real new infrastructure. We mirrored mod_arith's
  `IntegerAttr` precedent instead, so `felt.const`'s value prints as
  `<{"value" = 42 : i256}>` rather than `<{"value" = #felt.const<42>}>`.
  The IR-level information is preserved; the textual form is
  VEIR-flavored. Re-evaluate when the next port genuinely needs structured
  attribute parsing (Struct will, for `!struct.type<@A<[5,@C,!felt.type,#map]>>`).
- **LLZK custom assembly format** (`%0 = felt.add %a, %b`). Generic format
  only (`"felt.add"(%a, %b) : (...) -> ...`). This is a separate piece of
  work in `Veir/Parser/MlirParser.lean`. Defer until there's a use case.
- **`LLZK_FieldSpecAttr`** (`field<name, prime>`), trait semantics
  (`NotFieldNative`, `Commutative`), folder/canonicalizer behavior, the
  LLZK semantic checks (`AllowConstraintAttr`, `AllowWitnessAttr`). All
  out of scope for "round-trip the IR." Most are in scope for "validate
  the IR" — different effort entirely.

## How VEIR dialects work (architecture map)

Important context that wasn't documented anywhere I found in-repo. The
short version: VEIR's dialect surface is *closed-world* and centralized
through a single inductive plus a per-dialect property record system.

### Touchpoints when adding a dialect

For a port like Felt — opcodes plus a single new type plus one
property-bearing op — the changes land in **seven** files. Listed in
build-dependency order:

1. **`Veir/IR/Attribute.lean`** — `Attribute` is a single closed
   inductive covering both MLIR attributes *and* types (built-in and
   per-dialect). Each new dialect type is a new case. Mechanical, but
   touches multiple structures: the `inductive`, the `Attribute.decEq`
   mutual block, `ToString`, `Attribute.toString`, `Attribute.isType`, an
   `isType_X` `@[simp, grind =]` theorem, and two `Coe` instances (to
   `Attribute` and to `TypeAttr`). For Felt, +31 LoC.
2. **`Veir/OpCode.lean`** — `@[opcodes] inductive Felt`. The
   `#generate_op_codes` macro picks it up automatically and synthesises
   the dialect arm of `OpCode`, plus `OpCode.fromName` and `OpCode.name`.
   The macro lowercases the inductive name (`Felt → "felt"`); op
   constructors are taken as-is (so `bit_and` stays `bit_and`). +22 LoC.
3. **`Veir/Verifier.lean`** — exhaustive `match opCode` per-op shape
   checks (operand/result/region/successor counts). New OpCode → new
   arms required. Use Comb's grouped-pattern style for ops that share a
   shape. +34 LoC for Felt's 18 ops.
4. **`Veir/Properties.lean`** — `XxxProperties` records for ops that
   carry attributes. Each has a `fromAttrDict` that pulls fields out of
   a parsed property dict. For Felt, only `FeltConstProperties` is
   needed. +17 LoC.
5. **`Veir/Dialects/Felt/OpInfo.lean`** — new file. Defines
   `Felt.propertiesOf : Felt → Type` (mapping each op to its property
   record or `Unit`) and the `HasDialectOpInfo Felt` instance. +22 LoC.
6. **`Veir/GlobalOpInfo.lean`** — three glue points:
   - `import Veir.Dialects.Felt.OpInfo`
   - new arm in `propertiesOf : OpCode → Type`:
     `| .felt op => Felt.propertiesOf op`
   - new arm in `Properties.fromAttrDict` (exhaustive `cases opCode`):
     `case felt op => cases op; case const => exact (FeltConstProperties.fromAttrDict attrDict); all_goals exact (Except.ok ())`
   - new arm in `Properties.toAttrDict` (has a wildcard, but property-
     bearing ops need explicit arms):
     `| .felt .const => insert "value"...`
   +8 LoC for Felt.
7. **`Veir/Parser/AttrParser.lean`** — `parseOptionalFeltType` plus a
   single line slotting it into `parseOptionalType` *before* the
   `parseOptionalDialectType` fallthrough. +22 LoC.

### What you *don't* touch

The verified IR data structure (`Veir/IR/Fields.lean`,
`Veir/IR/GetSet.lean`, `Veir/IR/WellFormed.lean`) is entirely untouched
by a dialect addition. Confirmed empirically: extending the `Attribute`
inductive with a new case builds clean without touching any of those
files. **Attributes are truly opaque payloads to the verified data
structure.** This is excellent news for the rest of the LLZK port —
those three files are 9.4K LoC of verified proofs that we never have to
re-prove for a dialect addition.

`Veir/Printer.lean` is also untouched. Printing goes through the generic
MLIR format and relies on `Attribute.toString` for types/attrs. As long
as you add the `ToString` instance for new types, printing is automatic.

## The two gotchas in detail

### Gotcha 1: exhaustive-match coupling across files

`Veir/Verifier.lean`'s `verifyLocalInvariants` is a fully-exhaustive
`match opCode`. `Veir/GlobalOpInfo.lean`'s `Properties.fromAttrDict` is
a fully-exhaustive `cases opCode` (Lean tactic). Adding a new
`OpCode.felt` constructor causes both to fail at build time:

```
error: Veir/Verifier.lean:18:2: Missing cases:
(OpCode.felt Felt.const)
(OpCode.felt Felt.add)
... (18 missing arms)

error: Veir/GlobalOpInfo.lean:48:43: unsolved goals
case felt
attrDict : Std.HashMap ByteArray Attribute
op✝ : Felt
⊢ Except String (propertiesOf (OpCode.felt op✝))
```

Implication: **Phase 2 of the original plan ("just add the inductive,
build, then move on") doesn't exist as a standalone unit of work.** The
inductive is coupled to the verifier arms (Phase 4) and to the
properties dispatch (Phase 3) at build-time. This collapses the ordering:

- Theoretical phases: 1 → 2 → 3 → 4 → 5 → 6
- Actual phases: 1 → (2+4+sliver-of-3) → 3-rest → 5 → 6

For the next dialect: budget Phase 2 as a meta-phase that includes the
verifier arms and a placeholder in `fromAttrDict`. Only after that's
green can you do the per-op properties wiring.

A simple upstream fix that would decouple this: add a `_ => pure ()`
wildcard at the bottom of `verifyLocalInvariants`, and a wildcard arm
in `fromAttrDict`. This trades exhaustiveness checking for
modularity — probably worth it for the dialect-extension story. Not
done in this port (kept the existing pattern); flag for future work.

### Gotcha 2: silent textual round-trip via `UnregisteredAttr`

`AttrParser.parseOptionalDialectType` (line 213) is a fallthrough that
captures any `!dialect.name` or `!dialect.name<body>` it doesn't recognise
as `UnregisteredAttr` whose `value` is the raw textual slice. `UnregisteredAttr.toString`
echoes `value` verbatim. So **any unknown LLZK dialect type appears to
"round-trip" textually with zero parser support**.

What this means in practice: after Phase 3 of the Felt port, the
forcing-function test passed at 264/264. Phase 5 (the typed parser
branch) was strictly unnecessary for that test. The IR was internally
storing every `!felt.type<"bn254">` as
`Attribute.unregisteredAttr "!felt.type<\"bn254\">"`, *not* as
`Attribute.feltType { fieldName := some "bn254".toByteArray }`. The
Phase 1 typed `feltType` case was effectively dead code until Phase 5
landed.

This is a real footgun. A future port could:
- Add the dialect type as a structured `Attribute` case (Phase 1 work).
- Skip the parser branch (no Phase 5).
- Pass FileCheck tests.
- Ship a port that *appears* complete but where the Phase 1 typed case
  is unreachable from any real code path.

Mitigation: any port that adds a new typed `Attribute` case must also
add the corresponding `parseOptionalXxx` function and slot it into
`parseOptionalType` before `parseOptionalDialectType`. Or, equivalently,
a unit test that constructs a value programmatically and checks the
right `Attribute` case is reached after parsing.

Stretch: VEIR upstream could move `parseOptionalDialectType` behind a
"strict" mode where unknown dialects throw rather than capturing. Not
done in this port.

## Scaling estimates for the remaining LLZK dialects

Rough sizing based on what we just learned. "Effort" is multiplicative
relative to Felt (=1×). "Blocked on" lists infrastructure we don't have.

| Dialect | TD LoC | Effort | Blocked on | Notes |
|---|---|---|---|---|
| Constrain (no `emit.in`) | ~75 | 0.5× | — | Skip `emit.in` until Array. `emit.eq` is a 2-operand 0-result terminator-free op. Smallest dialect that exercises ops with no results. |
| Bool (no `cmp`) | ~120 | 0.7× | — | 4 logical i1→i1 ops. Skip `bool.cmp` (depends on Felt + custom predicate enum), keep `bool.assert`. |
| Bool full | 171 | 1× | enum attribute parsing | `bool.cmp` needs `LLZK_CmpPredicateAttr` (an enum). Either store as `IntegerAttr` (mod_arith trick) or add the first per-dialect attribute parser. |
| Cast | 75 | 1× | — | Trivial scalar conversions; should mostly mirror Felt patterns. |
| String | 80 | 1× | — | Adds `!string.type` (no params) and a couple of ops. Small. |
| Include | 70 | 1.5× | symbol references | `include.import` takes a `SymbolRefAttr` (`@module_name`). VEIR has no `SymbolRefAttr`. First port that requires symbol-table infrastructure. |
| Global | 110 | 2× | symbols + attribute parsing | `global.def` is a symbol; `global.read`/`write` resolve symbols. Needs the symbol-table layer. |
| RAM | 70 | ? | typed RAM type | Small TD but uses things we haven't seen yet. Read carefully. |
| Array | 410 | 5–8× | symbols + AffineMap + attribute parsing + variadic-of-variadic operands | Parametric dimensions (`!array.type<5,@N,#map x !felt.type>`) need three things VEIR doesn't have. The biggest single jump in infrastructure. |
| Function | 490 | 10×+ | symbols + AffineMap + variadic-of-variadic + region traits | `function.def` (symbol, `IsolatedFromAbove`, `AffineScope`, `FunctionOpInterface`), `function.call` with `mapOpGroupSizes`. Several net-new VEIR concepts. |
| Polymorphic | 360 | 10×+ | symbols + AffineMap + type variables + IsolatedFromAbove + region traits | Templates. Adds an ML-style generic system on top. |
| Struct | 385 | 10×+ | everything Function/Polymorphic plus member symbols | The boss fight. `struct.def`, `struct.member`, parametric `!struct.type<@A<[...]>>`, member offsets via affine maps. |
| SMT | 1203 | n/a | enum attrs | Sizeable but mostly separate from the rest of LLZK. Probably skip until needed. |

The cliff is clear: **everything up to and including String/Cast is
≤1.5× Felt.** That's a productive chunk. **Everything from Include
onward is blocked on infrastructure VEIR currently lacks** —
specifically `SymbolRefAttr` + symbol tables, then `AffineMap`/
`AffineMapAttr`, then variadic-of-variadic operands.

Suggested next step: do **Constrain (without `emit.in`) + Bool (without
`cmp`) + Cast + String** as a batch. That's four dialects, probably
~600 LoC total, exercises the dialect-extension path repeatedly without
introducing new infrastructure. After that, the next milestone is
deciding whether to invest in symbol-table infrastructure (gates
Include, Global, and everything else).

## Recipe for the next dialect (concrete playbook)

If the dialect adds one new type, one new property-bearing op, and N
purely-shape ops:

1. **Branch + harness** (10 min):
   - `git checkout -b llzk<dialect>_test`
   - Copy `Test/Felt/identity.mlir` to `Test/<Dialect>/identity.mlir`,
     rewrite for the new dialect's ops/types.
   - Update `plan.md` if you want a phased view, but for a small port
     you can probably skip this.

2. **Phase 1 — type case in `Attribute.lean`** (15 min):
   - Add `structure XxxType where ... deriving ...`
   - Add `| xxxType (type : XxxType)` to the `Attribute` inductive.
   - Add a `case xxxType.xxxType` arm to the `Attribute.decEq` mutual.
   - `instance : ToString XxxType where toString type := ...`
   - Add a `.xxxType type => ToString.toString type` arm to
     `Attribute.toString`.
   - `instance : Coe XxxType Attribute where coe := .xxxType`.
   - Add `.xxxType _ => true` (or false) to `Attribute.isType`.
   - If type, add `theorem isType_xxxType type : (xxxType type).isType = true := by rfl`
     with `@[simp, grind =]`.
   - If type, add `instance : Coe XxxType TypeAttr where coe type := ⟨.xxxType type, by rfl⟩`.
   - `lake build` — should pass.

3. **Phase 2 — opcode + verifier + placeholder properties** (20 min):
   - Add `@[opcodes] inductive Xxx where | op1 | op2 | ... deriving Inhabited, Repr, Hashable, DecidableEq` in `Veir/OpCode.lean`.
   - Build will fail in two places. Fix both:
     - Add per-op shape arms in `Veir/Verifier.lean` between MOD_ARITH
       and RISCV (or wherever the order makes sense). Use Comb's
       `| .xxx .op1 | .xxx .op2 | ... => do ...` grouping.
     - Add `case xxx => all_goals exact (Except.ok ())` in
       `Veir/GlobalOpInfo.lean`'s `Properties.fromAttrDict`.
   - `lake build` clean.

4. **Phase 3 — properties wiring** (20 min, only if any op carries attrs):
   - Add `XxxYyyProperties` structure(s) in `Veir/Properties.lean` plus
     their `fromAttrDict`.
   - Create `Veir/Dialects/Xxx/OpInfo.lean` with `Xxx.propertiesOf` and
     the `HasDialectOpInfo Xxx` instance.
   - In `Veir/GlobalOpInfo.lean`:
     - Add `public import Veir.Dialects.Xxx.OpInfo`.
     - Add `| .xxx op => Xxx.propertiesOf op` to `propertiesOf`.
     - Replace the placeholder in `Properties.fromAttrDict` with proper
       per-op dispatch.
     - Add per-op arms in `Properties.toAttrDict`.
   - `lake build` clean.

5. **Phase 5 — typed parser** (15 min, mandatory if Phase 1 ran):
   - Add `parseOptionalXxxType` to `Veir/Parser/AttrParser.lean`
     mirroring `parseOptionalFeltType` (which has the optional `<...>`
     pattern, mod_arith has the mandatory `<...>` pattern, llvm.ptr has
     no body).
   - Slot it into `parseOptionalType` *before* `parseOptionalDialectType`.
   - `lake build` clean.

6. **Phase 6 — verify** (5 min):
   - `uv run lit Test/<Dialect>/identity.mlir -v` — green.
   - `uv run lit Test/` — full suite, watch for regressions.
   - `lake test` — unit tests.

7. **Commit** in logical chunks (Phases 1, 2, 3, 5 each as separate
   commits keeps the history clear).

Total wall-clock estimate for a Felt-shaped dialect: ~90 min hands-on,
plus build wait time.

## Concrete follow-ups

These came out of the Felt port and would help the next ones:

- [ ] **Add wildcard arms to the two exhaustive matches.** Either `_ => pure ()`
      in `Veir.Verifier`'s `verifyLocalInvariants` (defaulting to no shape
      check), and a wildcard in `Properties.fromAttrDict`. Trades static
      exhaustiveness for dialect-extension modularity. Discussion needed
      with VEIR upstream — they may prefer the current behavior because
      it forces every op to be considered.
- [ ] **Make the `parseOptionalDialectType` fallthrough opt-in.** A
      "strict" mode that throws on unknown dialect types would catch
      Gotcha 2 at parse time.
- [ ] **First per-dialect attribute parser**. The right place to do
      this is when porting Bool's `bool.cmp` (which needs a comparison
      predicate enum) or Struct/Polymorphic (which need parametric
      attribute lists). Establish the pattern with whichever comes
      first.
- [ ] **Symbol-table layer**. Required for Include, Global, Function,
      Struct, Polymorphic. Big enough to deserve its own design doc.
      Start by sketching what `SymbolRefAttr` and `SymbolTable` look
      like as additions to `Attribute` and `IRContext`.
- [ ] **AffineMap representation**. Required for Array, Function,
      Polymorphic, Struct. Could either be a black-box `AffineMapAttr`
      that holds the textual form (cheap, gives round-trip but no
      semantics) or a real structured type (expensive, gives semantic
      access). Recommend the black-box approach until a pass actually
      needs to interpret the maps.
- [ ] **Structured `FeltConstAttr`**. Replace the `IntegerAttr`-trick
      with a proper `Attribute.feltConstAttr` case. Requires the first
      per-dialect attribute parser. Defer until that infrastructure
      lands for another reason.

## Files touched on this branch

```
Veir/IR/Attribute.lean              +31  (Phase 1)
Veir/OpCode.lean                    +22  (Phase 2)
Veir/Verifier.lean                  +34  (Phase 2/4)
Veir/Properties.lean                +17  (Phase 3)
Veir/Dialects/Felt/OpInfo.lean      +22  (Phase 3, new file)
Veir/GlobalOpInfo.lean              +10  (Phase 2 placeholder + Phase 3)
Veir/Parser/AttrParser.lean         +22  (Phase 5)
Test/Felt/identity.mlir             +52  (Phase 0)
plan.md                             ~75  (live during the port)
baseline.txt                        +29  (Phase 0)
```

Total: 6 source files modified, 1 source file created, plus 3 docs
files. Source-LoC: ~167. Within the 250–400 LoC plan estimate.

## What didn't happen (worth flagging)

- We didn't write any unit tests at the Lean level (`UnitTest/`). The
  FileCheck round-trip test was the forcing function. A unit test that
  programmatically constructs an `Attribute.feltType` and checks the
  parser produces it would explicitly guard against Gotcha 2.
- We didn't add semantic verification beyond shape checks. LLZK's
  `NotFieldNative` / `Commutative` / `AllowConstraintAttr` /
  `AllowWitnessAttr` / `WitnessGen` / `ConstraintGen` traits are not
  encoded. That's a different project.
- We didn't try to round-trip LLZK's *custom* assembly format. Strictly
  generic MLIR text only.
- We didn't touch the Interpreter (`VeirInterpret.lean`). Felt ops would
  need interpreter arms if you want to execute felt programs in VEIR's
  interpreter.
- We didn't update the README's feature matrix (the table at the top of
  `README.md` listing what's complete/verified). Worth adding a row for
  "LLZK Felt dialect" if this is going to be a public direction.
