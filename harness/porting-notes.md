# Durable porting notes

Append-only log of lessons that apply across dialect ports. Seeded
from `LLZK_PORT_RETRO.md` (the Felt-specific retrospective); add to it
in the same commit that discovers a new gotcha.

Format: each note has a date, a short title, the discovery, and a
"how to apply" paragraph. Notes are sorted by date, newest at the top.

---

## 2026-05-02 — VEIR dialect surface is closed-world

**Discovery (Felt port)**: VEIR's dialect surface is centralized through
a single closed `Attribute` inductive plus a per-dialect property
record system. Each new dialect type is a new case on the inductive;
each property-bearing op gets a record in `Veir/Properties.lean` and an
entry in a `Veir/Dialects/<X>/OpInfo.lean` file.

**How to apply**: When porting a dialect, expect to touch exactly seven
files (the recipe is in `harness/dialect-port-checklist.md`). The
verified IR data structure (`Veir/IR/Fields.lean`, `GetSet.lean`,
`WellFormed.lean`) is **untouched** by a dialect addition — attributes
are truly opaque payloads to the verified core. This is excellent news
for porting: those 9.4K LoC of proofs never need re-doing for a
dialect addition.

`Veir/Printer.lean` is also untouched. Printing goes through generic
MLIR format and relies on `Attribute.toString`; as long as a `ToString`
instance for new types exists, printing is automatic.

---

## 2026-05-15 — Gotcha 3: `Symbol`-trait ops still need `@name` parsing

**Discovery (Phase A.1 attempt)**: The retro / dialect-catalog
classified `Include` as "Tier 1, no infra needed" because
`include.from` is a *symbol producer*, not a user — so no
`SymbolRefAttr` (and no symbol-table lookup) is required.

In practice this is wrong. MLIR's generic format for an op with the
`Symbol` trait still emits the `sym_name` attribute as `@aliasName`,
not `"aliasName"` — i.e. the printer specializes for Symbol-trait ops.
VEIR's `AttrParser` doesn't handle the `@` lexeme as an attribute
form at all, so parsing fails before we get to anything semantic.

**How to apply**: any LLZK op declaring the `Symbol` trait (Include,
Function.def, Struct.def, Poly.template, Global.def) requires at least
a minimal *flat* `@name` attribute parser, even if no other op
references the symbol. This is much smaller than full
`SymbolRefAttr` / symbol-table semantics (no nested lookup, no
resolution, no integrity check) — it's "parse and store a name path".

**Re-ordering implication**: Phase A.1 (Include) has been deferred
out of Phase A and into Phase B/C, where the minimal symbol parser
lands. Phase A continues with String, Cast, RAM, Bool, Constrain.

**Upstream-fix candidate**: a flat-symbol `Attribute` case (akin to
`StringAttr` but tagged) and the corresponding `parseOptionalSymbolRef`,
without any IR-level resolution. Keeps the Phase B design open.

---

## 2026-05-02 — Gotcha 1: exhaustive-match coupling across files

**Discovery (Felt port)**: `Veir/Verifier.lean`'s
`verifyLocalInvariants` is a fully-exhaustive `match opCode`.
`Veir/GlobalOpInfo.lean`'s `Properties.fromAttrDict` is a
fully-exhaustive `cases opCode` (Lean tactic). Adding a new
`OpCode.felt` constructor causes **both** to fail at build time:

```
error: Veir/Verifier.lean: Missing cases:
(OpCode.felt Felt.const) ... (18 missing arms)

error: Veir/GlobalOpInfo.lean: unsolved goals
case felt
attrDict : Std.HashMap ByteArray Attribute
op : Felt
⊢ Except String (propertiesOf (OpCode.felt op))
```

**How to apply**: Phase 2 of any dialect port (the opcode inductive)
is **not** a standalone unit of work. It's coupled to the verifier
arms (Phase 4) and to the properties dispatch (Phase 3 placeholder) at
build-time. Land all three in one commit. The
`harness/dialect-port-checklist.md` Phase 2 step is explicit about
this.

**Upstream-fix candidate**: add `_ => pure ()` wildcards to both
exhaustive matches. Trades static exhaustiveness for dialect-extension
modularity. Open question for VEIR upstream — they may prefer the
current behavior because it forces every op to be considered.

---

## 2026-05-02 — Gotcha 2: silent textual round-trip via `UnregisteredAttr`

**Discovery (Felt port)**: `AttrParser.parseOptionalDialectType` (L213)
is a fallthrough that captures any `!dialect.name` or
`!dialect.name<body>` it doesn't recognize as `UnregisteredAttr` whose
`value` is the raw textual slice. `UnregisteredAttr.toString` echoes
`value` verbatim. So **any unknown LLZK dialect type appears to
round-trip textually with zero parser support.**

What this means in practice: after Phase 3 of the Felt port, the
forcing-function test passed at 264/264. Phase 5 (the typed parser
branch) was strictly unnecessary for that test. The IR was internally
storing every `!felt.type<"bn254">` as
`Attribute.unregisteredAttr "!felt.type<\"bn254\">"`, *not* as
`Attribute.feltType { fieldName := some "bn254".toByteArray }`. The
Phase 1 typed case was effectively dead code until Phase 5 landed.

**How to apply**: Any port that adds a new typed `Attribute` case must
add the corresponding `parseOptionalXxx` and slot it into
`parseOptionalType` before `parseOptionalDialectType`. Or, equivalently,
a Lean-level unit test that constructs the typed case programmatically
and asserts it's reached after a textual round-trip. The
`harness/evaluation-criteria.md` §A.3 makes this an explicit acceptance
criterion.

**Upstream-fix candidate**: move `parseOptionalDialectType` behind a
"strict" mode that throws on unknown dialect types.

---

## 2026-05-02 — `@[opcodes]` lowercases the dialect name

**Discovery (Felt port)**: The `#generate_op_codes` macro picks up
`@[opcodes] inductive Xxx` and synthesizes the dialect arm of `OpCode`,
plus `OpCode.fromName` and `OpCode.name`. It **lowercases the inductive
name** (`Felt → "felt"`); op constructors are taken as-is (so `bit_and`
stays `bit_and`).

**How to apply**: When naming the inductive (`inductive Bool`,
`inductive Constrain`, etc.), the corresponding MLIR dialect name will
be lowercase. If LLZK's dialect name has underscores or mixed case
(`Mod_Arith` for `mod_arith`), match that pattern.

---

## 2026-05-02 — `IntegerAttr` is the workaround for missing structured attrs

**Discovery (Felt port)**: VEIR has no per-dialect attribute parser
today. Every `#dialect.name<...>` falls through to `UnregisteredAttr`.
Adding the first one is real new infrastructure.

LLZK's `#felt.const<value>` carries both an `APInt` and the field type.
VEIR's port stores `felt.const`'s value as `IntegerAttr` instead,
mirroring VEIR's existing `arith.constant` / `mod_arith.constant`
precedent. The cost: printed output uses `<{"value" = 42 : i256}>`
instead of LLZK's `<{"value" = #felt.const<42>}>`.

**How to apply**: For any LLZK structured attribute, the first
question is "can I use `IntegerAttr` (or another built-in) instead?".
The answer is *yes* for simple enums (predicates, kinds) and *no* for
parametric attribute lists (`<[5, @C, !felt.type, #map]>` for Struct).
The workaround must be recorded in `harness/coverage.md` (§Attributes).

**Re-evaluate when**: the next port has parameter lists or genuine
multi-field attributes — likely Polymorphic or Struct.

---

## 2026-05-02 — First-run `lake build` flake (elan toolchain-lock)

**Discovery (Felt port)**: First `lake build` after a fresh clone
failed with exit 143 (SIGTERM) on
`Veir.Rewriter.GetSet.{DetachOp,CreateOp}`. Traced to elan
toolchain-lock race at startup — another process held
`nightly-2026-04-29.lock`. Not OOM, not a real Lean error. Retry was
clean.

**How to apply**: On a first build after a fresh clone or toolchain
bump, if exit 143 hits `Rewriter/GetSet/*`, retry once. Don't
investigate as a real failure. Recorded in `baseline.txt` and
`harness/checkpoint-protocol.md` §9.

---

## Templated note (for future entries)

```
## YYYY-MM-DD — <short title>

**Discovery (<context: which dialect port, which infra spike>)**:
<one-paragraph description of what surprised you>

**How to apply**: <one paragraph describing how a future porter
benefits from this knowledge>

**Upstream-fix candidate** (optional): <if there's a code-side fix
that would prevent the gotcha from recurring>
```
