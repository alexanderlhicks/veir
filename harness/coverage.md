# LLZK ↔ VEIR coverage and gap review

**This document is mandatory reading for anyone consuming this VEIR fork
as an LLZK implementation.** It tracks every LLZK feature with its
current support status in VEIR, the caveat that applies if support is
partial, and the workaround in use.

Updated on every dialect port, every infrastructure addition, and
whenever a new gap is encountered during porting. See `plan.md` §Living
document for the protocol.

**Legend**

- ✅ **Supported** — round-trips and is typed as a first-class VEIR `Attribute`/`OpCode`/structure
- ⚠️ **Partial** — works for a defined subset; caveat below; downstream consumers must be aware
- 🟡 **Round-trip only** — survives parser→printer textually via `UnregisteredAttr` or similar fallback, but is not typed; programmatic pattern-matching does NOT see the feature
- ❌ **Unsupported** — no parser, no representation
- 🚧 **In progress** — has an open work item

---

## §Dialects

| LLZK dialect | Status | Caveats |
|---|---|---|
| `felt` | ✅ Supported | `felt.const` value stored as `IntegerAttr`, not structured `#felt.const<v>`. Printed form is `<{"value" = 42 : i256}>`, not LLZK's `<{"value" = #felt.const<42>}>`. Trait semantics (`NotFieldNative`, `Commutative`, `AllowConstraintAttr`, `AllowWitnessAttr`) **not encoded**. Folder/canonicalizer **not implemented**. Custom assembly format (`%0 = felt.add %a, %b`) **not supported** — generic format only. |
| `include` | ❌ Unsupported | Planned Phase A.1 (Tier 1). |
| `string` | ✅ Supported | Round-trips through `veir-opt`. One op (`string.new`), one type (`!string.type`). Custom assembly format (`%0 = string.new "x"`) **not supported** — generic form only. `Pure`, `ConstantLike`, `hasFolder` traits **not encoded**. |
| `cast` | ❌ Unsupported | Planned Phase A.3. Depends on Felt. `InferTypeOpInterface` semantics will not be encoded. |
| `ram` | ❌ Unsupported | Planned Phase A.4. Memory-effect traits (`MemRead`, `MemWrite`) **will not be encoded** — round-trip only. |
| `bool` | ❌ Unsupported | Planned Phase A.5 (basic 5 ops) + Phase D.4 (`bool.cmp`). |
| `constrain` (no `emit.in`) | ❌ Unsupported | Planned Phase A.6. `emit.in` requires `Array` types (containment check) — deferred to post-Phase D. `ConstraintOpInterface` will be a marker only, no semantic checks. |
| `global` | ❌ Unsupported | Planned Phase D.1. Blocked on `SymbolRefAttr` infrastructure (Phase C). |
| `pod` | ❌ Unsupported | Planned Phase D.2. Blocked on `AffineMapAttr` + variadic-of-variadic (Phase C). |
| `array` | ❌ Unsupported | Planned Phase D.3. Types + non-symbol ops first; symbol-bearing dimension forms gated on Phase F. `ShapedTypeInterface` and `PromotableMemOpInterface` will not be encoded. |
| `function` | ❌ Unsupported | Planned Phase G.1. Blocked on regions (Phase F), `SymbolRefAttr` (Phase C), `FunctionOpInterface`. |
| `polymorphic` | ❌ Unsupported | Planned Phase G.2. Blocked on regions, type variables, `LLZKSymbolTable` trait. |
| `struct` | ❌ Unsupported | Planned Phase G.3. The boss fight: regions + symbols + parametric types + member symbols + nested function. |
| `smt` | ❌ Unsupported | Orthogonal. Port-when-needed. |

---

## §Types

| LLZK type | Status | Caveats |
|---|---|---|
| `!felt.type` | ✅ | — |
| `!felt.type<"name">` | ✅ | Field-spec name is preserved as a `ByteArray` on `FeltType`. **No field-modulus semantics.** Distinct field names compare distinct in `Attribute.decEq`; that's the only place the name participates. |
| `!string.type` | ✅ | First parameterless dialect type ported. |
| `!array.type<dims x elem>` | ❌ | Planned D.3. Symbol-bearing dim forms `!array.type<5,@N x !felt.type>` blocked on Phase F. Affine-map dim forms `!array.type<#map x !felt.type>` blocked on Phase C.2. |
| `!struct.type<@A>` | ❌ | Planned G.3. |
| `!struct.type<@A<[5, @C, !felt.type, #map]>>` | ❌ | Mixed-kind parameter list — needs all of: integer literal, symbol ref, type, affine map. |
| `!poly.tvar<@T>` | ❌ | Planned G.2. |
| `!pod.type<[@field: !felt.type, ...]>` | ❌ | Planned D.2. Named-record attribute-list parameter. |
| SMT types (`!smt.bv<N>`, `!smt.int`, `!smt.array<K,V>`, …) | ❌ | Orthogonal. |

---

## §Attributes

| LLZK attribute | Status | Caveats |
|---|---|---|
| `#felt.const<value>` (structured) | ❌ | **Workaround in use:** `felt.const`'s value is stored as `IntegerAttr` instead. Mirrors VEIR's `arith.constant` precedent. Lossy w.r.t. the textual form (prints differently) but preserves the IR-level value. |
| `#field<name, prime>` (`LLZK_FieldSpecAttr`) | ❌ | Field modulus not encoded anywhere. Bigger semantic gap than the textual one. |
| `#bool.cmp<eq|ne|lt|le|gt|ge>` (enum) | ❌ | Bool `cmp` predicate. Planned C.4. Workaround if deferred: store as `IntegerAttr` (0..5). |
| `SymbolRefAttr` (`@name`, `@outer::inner`) | ❌ | Planned C.1. **No per-dialect attribute parser exists in VEIR today.** Unknown `#dialect.name<...>` falls through to `UnregisteredAttr` whose `value` is the raw textual slice. |
| `AffineMapAttr` (`affine_map<(i,j) -> (i+j)>`) | ❌ | Planned C.2. Black-box (textual) representation recommended initially. |
| `DenseI32ArrayAttr` | ✅ (`DenseArrayAttr`) | — |
| `StrArrayAttr` | ❌ | Used by POD field names. Phase D.2. |
| `AllowConstraintAttr`, `AllowWitnessAttr`, `WitnessGen`, `ConstraintGen` traits | ❌ | These are *traits*, not attributes per se. **No trait encoding in VEIR today.** Felt ops carry no information about whether they're constraint-legal or witness-legal. |

---

## §Symbols and symbol tables

| Feature | Status | Caveats |
|---|---|---|
| `SymbolRefAttr` as an `Attribute` case | ❌ | Phase C.1. |
| `Symbol` trait (op declares a name) | ❌ | Phase B (design). |
| `SymbolUserOpInterface` (op resolves a symbol) | ❌ | Phase B (design). |
| `SymbolTable` trait (parent op contains symbols) | ❌ | Phase B (design). May require structural extension to verified IR. |
| `LLZKSymbolTable` (custom LLZK variant) | ❌ | Phase G (Polymorphic, Struct). |
| Nested symbol lookup (`@A::@B`) | ❌ | Phase C.1 parser; semantic resolution gated on Phase B design. |

---

## §Affine maps

| Feature | Status | Caveats |
|---|---|---|
| `AffineMapAttr` round-trip | ❌ | Phase C.2 (planned black-box). |
| Affine-map semantic interpretation (compute dim/symbol arity, evaluate map) | ❌ | Out of scope for initial port. Required only if a pass needs to interpret the maps. |
| Variadic-of-variadic operands with `mapOpGroupSizes` | ❌ | Phase C.3. Used by `array.new`, `pod.new`. |

---

## §Op-level features

| Feature | Status | Caveats |
|---|---|---|
| Operand/result/region/successor *count* checks | ✅ | Encoded in `Veir/Verifier.lean`. |
| Operand/result *type* checks (per-op verifier) | ⚠️ | Only generic count-and-shape; per-op type predicates (e.g. "lhs and rhs must be same type as result") **not encoded**. |
| `InferTypeOpInterface` | ❌ | Cast uses this; result type will need to be explicit in the textual form. |
| Custom assembly format (`%0 = felt.add %a, %b`) | ❌ | Generic format only (`"felt.add"(%a, %b) : (...) -> ...`). Lit tests use generic form. |
| Variadic operands | ⚠️ | Simple variadic supported via OpCode arms; verifier per-op. |
| Variadic-of-variadic operands | ❌ | Phase C.3. |
| Optional operands/results/attributes | ⚠️ | Optional attributes are handled (e.g. `parseOptionalAttribute`); optional operands case-by-case. |

---

## §Regions and structural features

| Feature | Status | Caveats |
|---|---|---|
| Multi-block regions | ❌ | Phase F. **Major architectural addition.** |
| Region entry block / argument list | ❌ | Phase F. |
| Terminator op validation | ❌ | Phase F. |
| `IsolatedFromAbove` trait | ❌ | Phase F. |
| `AffineScope` trait | ❌ | Out of initial scope. |
| `AutomaticAllocationScope` | ❌ | Out of initial scope. |
| `SingleBlock`, `NoTerminator`, `GraphRegionNoTerminator` | ❌ | Phase F (single-block variants). |

---

## §Op interfaces

LLZK defines several custom op interfaces. In VEIR there is no
mechanism to declare op interfaces as such; the marker effect is
achieved either by:
(a) checking the opcode in code that consumes the interface, or
(b) adding a `Properties` field that consumers read.

Either way, **no interface methods are dispatched dynamically**. The
implication: any LLZK pass that *requires* dynamic dispatch through an
op interface cannot be ported verbatim — it must be specialized to the
opcodes that implement the interface.

| Op interface | Used by | VEIR status |
|---|---|---|
| `ConstraintOpInterface` (marker) | Constrain ops | ❌ |
| `GlobalRefOpInterface` | Global | ❌ |
| `ArrayAccessOpInterface`, `ArrayRefOpInterface` | Array | ❌ |
| `MemberRefOpInterface` | Struct | ❌ |
| `FunctionOpInterface` (MLIR builtin) | Function | ❌ |
| `CallableOpInterface` (MLIR builtin) | Function call sites | ❌ |
| `SymbolUserOpInterface` (MLIR builtin) | Global, Function, etc. | ❌ |
| `PolymorphicOpInterface` | Polymorphic | ❌ |
| `InferTypeOpInterface` (MLIR builtin) | Cast | ❌ |
| `PromotableMemOpInterface` (MLIR builtin) | Array | ❌ |
| `ShapedTypeInterface` (MLIR builtin) | Array types | ❌ |

---

## §Traits (semantic markers)

| Trait | Status | Caveats |
|---|---|---|
| `Pure` | ❌ | Not modeled. DCE uses a heuristic ("zero results → side effects"). |
| `Commutative` | ❌ | Not modeled. Verified rewrites that depend on commutativity must prove it from the algebra, not the trait. |
| `Idempotent` | ❌ | — |
| `Involution` | ❌ | — |
| `MemRead`, `MemWrite`, `MemoryEffects<...>` | ❌ | Not modeled. RAM dialect ops will round-trip but VEIR sees them as generic ops. |
| `IsolatedFromAbove` | ❌ | Phase F. |
| `SymbolTable`, `Symbol` (MLIR builtin) | ❌ | Phase B (design). |
| `ConstantLike` | ❌ | — |
| `HasFolder` (`hasFolder = 1`) | ❌ | No folder dispatch. Folders are an LLZK concept that maps to "constant folding inside the verifier"; VEIR doesn't have this hook. |
| `NotFieldNative` (LLZK-specific) | ❌ | Marks ops that aren't field-native (e.g., bit ops on felts). Not encoded. |
| `WitnessGen`, `ConstraintGen` (LLZK-specific) | ❌ | Mark whether an op produces a witness or a constraint. Not encoded — important for any verification of constraint-soundness. |
| `AllowConstraintAttr`, `AllowWitnessAttr` (LLZK-specific) | ❌ | Function-level traits. Not encoded. |

---

## §Verification machinery (VEIR side)

| Capability | Status | Caveats |
|---|---|---|
| `WellFormed` preservation across rewrites | ✅ | All rewriter primitives have completed proofs (`Veir/Rewriter/WellFormed/`). Zero `sorry` in `Veir/IR/` and `Veir/Rewriter/`. |
| Data-level refinement (`isRefinedBy`) | ⚠️ | Framework exists in `Veir/Data/Refinement.lean`. Only two passes use it (RISCV `constant_refinement`, `add_refinement`). |
| Dominance | ❌ | **Axiomatized in `Veir/Dominance.lean`** (9 axioms). Blocks any pass that requires SSA dominance reasoning (e.g., a properly-verified CSE). |
| `interpret ; pass = interpret` | ❌ | No framework. Building one is its own project. |
| Side-effect analysis | ⚠️ | Heuristic in `Veir/Passes/DCE/dce.lean` (TODO at L12). Verified passes that depend on "this op is pure" must prove it explicitly. |
| Pattern preconditions discharged | ⚠️ | The `RewritePattern` infra requires several preconditions per call site; current passes discharge them with `sorry`. There are **~179 `sorry`s in `Veir/Passes/`** as of 2026-05-02 — none in the IR or Rewriter cores, all in pass implementations. |
| Pass composition theorems | ❌ | `PassPipeline` runs passes and re-verifies, but there is no theorem that two passes preserve a common invariant. |

---

## §Tests and tooling

| Capability | Status | Caveats |
|---|---|---|
| FileCheck lit suite | ✅ | 264/264. Felt has `Test/Felt/identity.mlir`. Per-dialect identity tests are the round-trip forcing function. |
| Unit tests (`lake test`) | ✅ | UnitTest target, 40/40. No Lean-level unit tests programmatically constructing and matching on LLZK `Attribute` cases (would catch Gotcha 2 from the Felt retro). |
| `veir-opt` CLI | ✅ | Single binary, parses and re-prints. Pass pipeline via `-p`. |
| Benchmarks | ⚠️ | `RunBenchmarks.lean` exists; not currently exercised by LLZK code. |

---

## §Known cross-cutting limitations

These are not LLZK-feature-specific but affect any downstream consumer:

1. **No structured LLZK attributes.** Everything `#dialect.name<...>`
   falls through to `UnregisteredAttr` (textual round-trip only).
   Pattern-matching on the structured form is not possible until VEIR
   gains a per-dialect attribute parser.
2. **Silent textual round-trip via `UnregisteredAttr`** — see
   `harness/porting-notes.md` §Gotcha 2. A test that only FileChecks
   text can pass even when the typed parser is dead code.
3. **No semantic interpretation of constraints.** Even when Felt
   round-trips, VEIR has no notion that `constrain.eq` defines a
   constraint over a finite field. Pass verification cannot use
   constraint semantics until that's modeled.
4. **No interpreter for any LLZK dialect.** VEIR's interpreter
   (`Veir/Interpreter/`) handles LLVM and RISCV. Felt has no
   interpreter arms. This blocks any `interpret ; pass = interpret`
   style proof for LLZK passes.
5. **Custom assembly is unsupported.** Anywhere LLZK MLIR uses
   `%0 = felt.add %a, %b` instead of `"felt.add"(%a, %b) : ...`, VEIR
   will reject it. Producers should emit generic-form MLIR before
   feeding to `veir-opt`.

---

## §Maintenance protocol

Three rules, restated from `plan.md` for visibility:

1. **Coverage updates are non-optional.** Any commit that changes the
   status of a row updates this file in the same commit.
2. **New gaps must be added.** Anyone hitting a previously-unrecorded
   gap during porting adds a row and links it from the porting commit
   message.
3. **Status downgrades are loud.** Removing or weakening support
   requires a status update and a note in `harness/porting-notes.md`
   explaining the regression.
