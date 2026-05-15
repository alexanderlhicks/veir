# Per-dialect port checklist

Reusable checklist for porting one LLZK dialect into VEIR. Copy this
template into a working note when starting a new port; do not modify
this file unless improving the template itself.

The structure mirrors the seven-file recipe established by the Felt
port. See `harness/porting-notes.md` for the durable gotchas, and
`LLZK_PORT_RETRO.md` for the original empirical write-up.

---

## Pre-flight (10 minutes)

- [ ] Branch from `main`: `git checkout -b llzk<dialect>_<n>` (`n` = attempt counter)
- [ ] Capture baseline:
  - [ ] `lake build 2>&1 | tail -5` — confirm clean
  - [ ] `uv run lit Test/ -v 2>&1 | tail -3` — confirm full green
  - [ ] `lake test 2>&1 | tail -3` — confirm UnitTest passes
- [ ] Read the LLZK source:
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/Dialect.td`
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/Ops.td`
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/Types.td` (if present)
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/Attrs.td` (if present)
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/Enums.td` (if present)
  - [ ] `llzk-lib/include/llzk/Dialect/<X>/IR/OpInterfaces.td` (if present)
- [ ] Confirm against `harness/coverage.md`: does this dialect require
      any infrastructure VEIR doesn't yet have? If yes, stop and read
      the relevant Phase C/F work plan in `plan.md`.

## Phase 0 — Failing forcing function (5 min)

- [ ] `mkdir -p Test/<Dialect>/`
- [ ] Write `Test/<Dialect>/identity.mlir`: generic-form MLIR exercising
      every op and type the port will support. Begin and end with a
      `// RUN: veir-opt %s | filecheck %s` and matching `// CHECK:` lines.
- [ ] `uv run lit Test/<Dialect>/identity.mlir -v` — confirms it fails
      (forcing-function check: most ops will be `builtin.unregistered`).

## Phase 1 — Type case in `Attribute.lean` (15 min)

*Skip if the dialect declares no new types.*

For each new type:

- [ ] In `Veir/IR/Attribute.lean`:
  - [ ] Add `structure XxxType where ... deriving Inhabited, Repr, DecidableEq, Hashable`
  - [ ] Add `| xxxType (type : XxxType)` constructor to the `Attribute` inductive
  - [ ] Add a `case xxxType.xxxType =>` arm in the `Attribute.decEq` mutual block
  - [ ] `instance : ToString XxxType where toString type := ...` (string body)
  - [ ] `.xxxType type => ToString.toString type` arm in `Attribute.toString`
  - [ ] `.xxxType _ => true` (or `false`) arm in `Attribute.isType`
  - [ ] If it is a type: `theorem isType_xxxType (type : XxxType) : (Attribute.xxxType type).isType = true := by rfl` with `@[simp, grind =]`
  - [ ] `instance : Coe XxxType Attribute where coe := .xxxType`
  - [ ] If a type: `instance : Coe XxxType TypeAttr where coe type := ⟨.xxxType type, by rfl⟩`
- [ ] `lake build` — expect clean. If not, the build error is in this file (no other file references the new type yet).

## Phase 2 — OpCode + verifier + properties placeholder (20 min)

*(Subsumes what the original Felt port called Phase 4 — verifier arms.
The exhaustive-match coupling described in `porting-notes.md` Gotcha 1
forces these to land in a single commit.)*

- [ ] In `Veir/OpCode.lean`:
  - [ ] Add `@[opcodes] inductive Xxx where | op1 | op2 | ... deriving Inhabited, Repr, Hashable, DecidableEq`
  - [ ] Verify capitalization: `@[opcodes]` lowercases the dialect name (`Xxx → "xxx"`). Op-constructor names are taken as-is.
- [ ] Build will fail in two places. Fix both **in the same commit**:
  - [ ] **`Veir/Verifier.lean`**: add per-op arms to `verifyLocalInvariants`. Group ops sharing a shape (Comb-style: `| .xxx .op1 | .xxx .op2 | ... => do ...`).
  - [ ] **`Veir/GlobalOpInfo.lean`**: add `case xxx => all_goals exact (Except.ok ())` placeholder in `Properties.fromAttrDict`.
- [ ] `lake build` — clean.

⚠️ **Phase 2 cannot be split.** Adding the opcode inductive without the
verifier and properties placeholder leaves two exhaustive matches
incomplete and the build red. See `harness/porting-notes.md` Gotcha 1.

## Phase 3 — Properties wiring (20 min, skip if no op carries attributes)

There are two cases:

### Phase 3.A — No op in this dialect carries attributes

(Cast, RAM, Constrain.eq, Datapath, etc. — also any dialect whose only
attributes are inferred from operand types.)

- [ ] **Skip the per-dialect `Properties.lean` / `OpInfo.lean` files.** They
      would be empty / map everything to `Unit`. Instead, the central
      `propertiesOf`'s `_ => Unit` arm in `Veir/GlobalOpInfo.lean` handles
      this dialect; the Phase-2 placeholder
      `case xxx => all_goals exact (Except.ok ())` in
      `Properties.fromAttrDict` is the final state, not a placeholder.
- [ ] No change to `Properties.toAttrDict` needed; the wildcard `| _ =>
      Std.HashMap.emptyWithCapacity 0` at the bottom catches it.
- [ ] `lake build` — clean.

### Phase 3.B — One or more ops carry attributes

(Felt has `.const`, String has `.new`, Include has `.from`, Bool has
`.assert` — all need this branch.)

- [ ] Create `Veir/Dialects/LLZK/<Dialect>/Properties.lean`:
  - [ ] `structure Xxx<Op>Properties where ... deriving Inhabited, Repr, Hashable, DecidableEq`
  - [ ] `Xxx<Op>Properties.fromAttrDict` with explicit type checks per field
        (use `Option StringAttr` for optional fields — see
        `BoolAssertProperties` for the pattern with `Option`)
- [ ] Create `Veir/Dialects/LLZK/<Dialect>/OpInfo.lean`:
  - [ ] `def Xxx.propertiesOf (op : Xxx) : Type := match op with | .op1 => Xxx<Op1>Properties | _ => Unit`
  - [ ] `instance : HasDialectOpInfo Xxx where propertiesOf := Xxx.propertiesOf`
- [ ] In `Veir/GlobalOpInfo.lean`:
  - [ ] `public import Veir.Dialects.LLZK.<Dialect>.OpInfo`
  - [ ] Add arm to `propertiesOf : OpCode → Type`: `| .xxx op => Xxx.propertiesOf op`
  - [ ] Upgrade the Phase 2 placeholder in `Properties.fromAttrDict` to
        proper per-op dispatch (use the `«keyword»` French-quote escape
        if a constructor name is a Lean keyword — `.from`, `.include`,
        etc. — see Include's wiring)
  - [ ] Add per-op arms in `Properties.toAttrDict` (the wildcard at the
        bottom only handles 0-attr ops; property-bearing ops need explicit
        `| .xxx .op => insert ...`)
- [ ] `lake build` — clean.

## Phase 5 — Typed parser (15 min, **mandatory** if Phase 1 ran)

⚠️ **Mandatory**: skipping this leaves the typed `Attribute` case as
dead code; the parser falls through to `UnregisteredAttr` and the
forcing test still passes. See `harness/porting-notes.md` Gotcha 2.

- [ ] In `Veir/Parser/AttrParser.lean`:
  - [ ] Add `parseOptionalXxxType` mirroring the closest existing parser
        - `parseOptionalFeltType` — optional `<...>` body
        - `parseOptionalModArithType` — mandatory `<...>` body
        - LLVM-ptr-style — no body at all
  - [ ] Slot it into `parseOptionalType` **before** `parseOptionalDialectType`
- [ ] `lake build` — clean.

## Phase 6 — Verify (5 min)

- [ ] `uv run lit Test/<Dialect>/identity.mlir -v` — green
- [ ] `uv run lit Test/ -v` — full lit suite, count matches baseline+1
- [ ] `lake test` — UnitTest clean

## Phase 7 — Coverage and notes (10 min)

- [ ] Update `harness/coverage.md`:
  - [ ] Change the dialect's row to ✅ or ⚠️ (with caveat link)
  - [ ] Update type rows
  - [ ] Update any attribute rows affected by workarounds (e.g., enum-as-`IntegerAttr`)
- [ ] If anything surprised you, add a note to `harness/porting-notes.md`
  in the same commit (don't wait for a retro)
- [ ] If a new VEIR-side limitation surfaced, file it as a row in
  `harness/coverage.md` §Known cross-cutting limitations

## Phase 8 — Commit and merge

Follow `harness/checkpoint-protocol.md`:

- [ ] Commit logically (one phase per commit is the Felt-era default)
- [ ] Open a PR back to main; ensure `harness/coverage.md` shows the
      delta in the diff
- [ ] After merge, tag `port-<dialect>-v1` (see checkpoint protocol)

---

## Sub-table: fill out for this port

Copy and fill when starting:

```
Dialect:          <name>
Branch:           llzk<dialect>_<n>
Started:          YYYY-MM-DD
LLZK TD LoC:      <wc -l of all relevant .td files combined>
Ops to support:   <comma-separated list>
Types to support: <list or "none">
Deferred:         <ops/features deferred and why>
New infra used:   <none / SymbolRefAttr / AffineMapAttr / ...>
Coverage rows:    <which rows in coverage.md are affected>
Open questions:   <list>
Time budget:      <e.g. 90 min, plus build wait>
Actual time:      <fill in at end>
```

---

## Aborting and restarting

If the port reveals an unexpected infrastructure dependency (e.g., the
dialect uses `SymbolRefAttr` and that isn't ported), the right move
is:

1. Stop. Do not invent a workaround under time pressure.
2. Write the discovery in `harness/coverage.md` under the relevant
   feature row (downgrade if needed).
3. Note the discovery in `harness/porting-notes.md`.
4. Either:
   - Pause this dialect, port the missing infrastructure on a separate
     branch (`infra/<name>`), and come back, **or**
   - Reduce scope: defer the ops that need the missing infra, ship
     the rest as ⚠️ Partial.

Both choices are legitimate. The wrong choice is to ship hidden
workarounds that aren't documented.
