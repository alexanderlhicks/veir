# Symbol-table architecture spike

**Status**: 🚧 open. Plan phase B (gates Tier 2 / Phase C+D).

This is a placeholder + framing doc. The actual design work is the
next concrete action item; this document records the question, the
inputs to consider, and what the output should look like.

---

## The question

Can VEIR's existing verified `Operation`/`IRContext` structure encode
MLIR-style `SymbolTable` semantics, or does it need a new structural
layer in `Veir/IR/`?

In MLIR terms, we need:

1. **`Symbol` trait** — an op declares a name (its parent
   `SymbolTable` knows the op by that name).
2. **`SymbolTable` trait** — an op contains a region whose top-level
   ops form a symbol table; lookup by name is `O(1)`-ish.
3. **`SymbolRefAttr`** — an attribute that holds a path to a symbol,
   either flat (`@name`) or nested (`@outer::@inner`).
4. **`SymbolUserOpInterface`** — an op that references a symbol via a
   `SymbolRefAttr`; resolution happens at use sites.

LLZK adds:

5. **`LLZKSymbolTable`** — a custom trait on `struct.def` and
   `poly.template` that nests symbols (members, parameters) inside.

## Why it matters

These features gate:

- Tier 2 dialects: **Global, Array** (symbol-bearing dimensions)
- Tier 3 dialects: **Function, Polymorphic, Struct**
- Several LLZK verified-pass pilots that depend on symbol resolution

Without a design, "just add `SymbolRefAttr` to `Attribute`" reaches a
limit: the attribute can hold the textual path, but no part of VEIR
will resolve it. That's fine for round-trip but not for any pass
that traverses uses to defs.

## Two extremes (sketched)

### Extreme 1: attribute-only

Add `SymbolRefAttr` as an `Attribute` case. Don't change anything
else in `Veir/IR/`. Symbol resolution is a *pass-level* concern: any
pass that needs to follow a `SymbolRefAttr` walks the IR itself to
find the matching `Symbol`-trait op.

**Pros**: zero changes to `Veir/IR/` and the verified core. Smallest
possible footprint.

**Cons**: every symbol-using pass re-implements lookup. No invariant
that `@name` resolves to *something* — broken references are caught
only at consumer time. Verification proofs that depend on symbol
resolution have to thread the lookup through the proof state.

### Extreme 2: first-class symbol tables

Add a `SymbolTable` field to `IRContext` (or to `Operation`) that
maps `(scope, name) → OperationPtr`. Maintained by the rewriter
(insert/remove update the table). Verified well-formedness includes
"every `SymbolRefAttr` resolves to an op in scope".

**Pros**: symbol lookup is `O(1)`. Well-formedness includes symbol
integrity. Verified passes can take "symbol resolution is total" as a
given.

**Cons**: substantial change to `Veir/IR/{Fields, GetSet, WellFormed}.lean`
— exactly the 9.4K LoC the Felt port boasted about not touching. New
rewriter primitives (`createSymbolOp`, `eraseSymbolOp`) and re-proofs
of WellFormed preservation. Could be a multi-week project.

### Hybrid (likely the right answer)

Add `SymbolRefAttr` as an `Attribute` case **plus** an
*unverified* lookup helper (`IRContext.resolveSymbol :
SymbolRefAttr → Option OperationPtr`) that walks the IR. Mark it
`@[expose]`/non-verified. Verified passes that depend on symbol
resolution either:

- Avoid it (most pilots don't need it)
- State their theorem assuming a `resolves` predicate as a hypothesis
- Eventually upgrade to Extreme 2 when proof obligations warrant it

This is the "make the cheap thing work; defer the expensive thing
until forced" route. Aligns with VEIR's current dominance treatment
(axiomatized today, with the file header noting that it'll be filled
in later).

## Inputs to read before deciding

1. `Veir/IR/Basic.lean` — the `Operation` and `IRContext` structures
2. `Veir/IR/Fields.lean` — what fields exist on operations
3. `Veir/IR/WellFormed.lean` — what invariants are currently encoded
4. `Veir/IR/GetSet.lean` — get/set lemma pattern that any new field
   would have to follow
5. `Veir/Rewriter/WellFormed/Operation.lean` — what proofs would need
   to be extended if a `SymbolTable` becomes part of `WellFormed`
6. MLIR upstream: `mlir/lib/IR/SymbolTable.cpp` — for what semantics
   we'd be mimicking (lookup, walk, replace-all-uses-of-symbol)

## What "done" looks like

This spike concludes with:

- A short design note (this file, expanded) documenting:
  - Which of the three approaches was chosen, and why
  - What changes land in `Veir/IR/` (if any)
  - What changes land in `Veir/Rewriter/` (if any)
  - The migration path from the chosen approach to a more verified
    one (so we don't paint ourselves into a corner)
- A working prototype implementation on a `spike/symbol-table-arch`
  branch (per `harness/checkpoint-protocol.md` §1)
- One concrete consumer: either upgrading `Include` (already ported,
  declares a symbol) to make use of the new machinery, or
  prototyping `Global.read` (which uses a `SymbolRefAttr`)
- `harness/coverage.md` §Symbols and §Verification machinery rows
  updated

## Recommendation (default, can be revised after reading)

Go with **Hybrid**. Specifically:

1. Add `SymbolRefAttr` to `Attribute` as a flat-or-nested name path
   (a `List ByteArray` plus an optional leading `@`)
2. Add `parseOptionalSymbolRefAttr` to `Veir/Parser/AttrParser.lean`
3. Add an unverified `IRContext.resolveSymbol` walker, marked as such
4. Document in `coverage.md` that symbol *integrity* is not part of
   `WellFormed` and `resolveSymbol` may return `none` even on
   "valid" IR

This unblocks Global, Array-with-symbol-dims, and round-trip-only
support for Function/Struct, without paying the cost of extending
WellFormed proofs.

Upgrade path: when a verified pass actually needs "symbol references
always resolve", that pass either:
- discharges the resolution obligation locally, or
- motivates extending `WellFormed` to include symbol integrity

## Not in scope for this spike

- `LLZKSymbolTable` (the custom LLZK trait on `struct.def`,
  `poly.template`) — Tier 3 problem, revisit in Phase G design
- Multi-module symbol resolution (cross-file imports via `include`)
  — solve when it bites
- `replaceAllSymbolUses` (rename all references to a renamed symbol)
  — not currently needed; defer
