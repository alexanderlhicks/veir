# LLZK ↔ VEIR differential testing

Architecture for catching silent semantic drift between VEIR's
implementation of an LLZK dialect and LLZK's own C++ implementation.

**Status**: architecture only. The harness scripts are scaffolded;
running them requires a local build of `llzk-opt` (see §3.1). Tests
that require `llzk-opt` skip gracefully if the binary isn't on
`$PATH`, so the suite stays green on hosts without LLZK built.

---

## §1. Motivation

VEIR is implementing LLZK dialects on a closed-world Lean inductive,
with per-dialect parsers and printers. LLZK's reference is the C++
implementation in `llzk-lib/` (built as `llzk-opt`). Two things can
drift between them:

1. **Textual divergence** — VEIR emits something LLZK doesn't accept,
   or vice versa. Example: VEIR quotes attribute keys
   (`<{"value" = 42 : i256}>`); LLZK doesn't (`<{value = 42 : i256}>`).
   FileCheck tests against VEIR's own output won't catch this.
2. **Semantic divergence** — VEIR's typed representation loses
   information that LLZK preserves. Example: the `FeltConst`
   `IntegerAttr` workaround — LLZK's `<{value = #felt.const<42>}>`
   becomes VEIR's `<{"value" = 42 : i256}>`. Round-trip via VEIR
   degrades the IR even when both forms parse.

Differential testing catches both classes by comparing canonical
outputs of `veir-opt` and `llzk-opt` on the same input.

---

## §2. The pipeline

For an LLZK input in custom assembly:

```
input.llzk
  │
  ├──[ llzk-opt --mlir-print-op-generic ]──> generic.mlir  (canonical form)
  │
  ├──[ generic.mlir | veir-opt           ]──> veir.out
  │
  └──[ generic.mlir | llzk-opt           ]──> llzk.out
                                              │
                                         normalize + diff
                                              │
                                  ✓ identical (modulo allowlist)
```

For an input authored directly in generic form (e.g., when starting
from an existing VEIR test), the first step is skipped.

### Normalization

A raw `diff` is too strict. The normalizer should canonicalize:

- **SSA value names**: `%0`, `%c`, `%result_0` all become `%V<n>` in
  order of appearance.
- **Attribute key quoting**: `<{value = ...}>` and
  `<{"value" = ...}>` collapse to one form.
- **Whitespace and trailing comma differences**.
- **Region argument names** when they differ but counts/types match.

Anything that survives normalization is a real divergence.

### Allowlist

Known divergences are tracked in `harness/coverage.md` and recorded
in a per-test allowlist file. Each entry references the coverage row
that documents the divergence:

```
# Test/LLZK/Felt/differential/felt-const.allowlist
# Each line: "<from_pattern>" -> "<to_pattern>" (coverage row)
"#felt.const<42>" -> "42 : i256"   (coverage.md §Attributes:#felt.const)
```

Diff that matches an allowlist entry is downgraded to a warning, not
a failure. Anything not on the list is a hard fail.

---

## §3. Setup

### §3.1 Building `llzk-opt` locally

LLZK builds via Nix (`llzk-lib/flake.nix`) or CMake. Either way the
build requires:

- LLVM/MLIR headers (matching version)
- `llzk-tblgen` to generate per-dialect inc files
- C++17 toolchain

Recommended one-time setup:

```bash
cd llzk-lib
nix build .#llzk-opt           # if Nix available, ~30 min cold
# OR
mkdir build && cd build
cmake .. -DMLIR_DIR=...        # standard MLIR out-of-tree pattern
make llzk-opt -j
```

After building, put `llzk-opt` on `$PATH` or set `$LLZK_OPT` to the
absolute path.

### §3.2 The diff script

`scripts/llzk-diff.sh` (created alongside this doc) is the
single-test runner:

```
scripts/llzk-diff.sh <input.mlir> [--allowlist <file>]
```

Exit codes:
- `0` — identical (modulo allowlist)
- `1` — differs
- `77` — `llzk-opt` not found (lit treats as SKIP)

### §3.3 Lit integration

A differential test is a normal `.mlir` file in
`Test/LLZK/<Dialect>/differential/` with a `RUN` line invoking the
diff script:

```mlir
// RUN: scripts/llzk-diff.sh %s --allowlist %s.allowlist
```

If `llzk-opt` is missing, the test SKIPs (exit 77 per lit convention).
The host without LLZK built still sees a green suite.

---

## §4. Per-dialect rollout

Differential tests are added **after** a dialect ports cleanly and
its `identity.mlir` passes. The rollout order:

| Dialect | Differential test added | Notes |
|---|---|---|
| Felt | 🚧 pending | First candidate. Known divergence: `#felt.const<v>` ↔ `IntegerAttr`. Module-level Felt tests need no Function wrapper. |
| String | 🚧 pending | Simple. `string.new "x"` at module level. |
| Cast | (after port) | Depends on Felt. |
| RAM | (after port) | MemRead/MemWrite traits not encoded in VEIR — divergence in attribute dictionary likely. |
| Bool | (after port) | Enum-as-IntegerAttr divergence likely. |
| Constrain | (after port) | Trivial; almost no surface. |
| Global, Function, Struct | (after port) | Wait for Tier 3. |

Each dialect gets a directory:

```
Test/LLZK/<Dialect>/
├── identity.mlir            # VEIR-only round-trip (already exists)
└── differential/
    ├── README.md            # what's in this set
    ├── <feature>.mlir       # input
    └── <feature>.mlir.allowlist  # known divergences (optional)
```

---

## §5. Authoring guidance

A useful differential test:

1. **Is at module level**, not nested in `function.def` / `struct.def`
   (those gate on Tier 3).
2. **Exercises every op of the target dialect** at least once.
3. **Combines with other ported dialects** where natural — a Felt
   test can include `string.new` if convenient, to test parser
   interactions.
4. **Avoids LLZK-only sugar**: no `function.return` short forms,
   no `affine_map` literals (until Phase C), no `@symbol::@nested`
   (until Phase B).
5. **Documents** the expected divergences in the allowlist with
   `coverage.md` row references.

A bad differential test is one where the diff fails for incidental
reasons (whitespace, SSA naming) and we end up papering over with
allowlist entries — that turns the harness into a rubber stamp.
Catch incidental noise in the normalizer; reserve the allowlist for
genuinely documented divergences.

---

## §6. Maintenance

- **A new caveat surfaced by the differential harness must be added
  to `coverage.md`** in the same commit as its allowlist entry.
  Otherwise the allowlist drifts from the documentation.
- **A caveat that's been *fixed* (e.g., we add a structured
  `#felt.const<v>` attribute later) flips the coverage row to ✅ and
  removes the allowlist entry in the same commit.**
- **The diff script is held to the same `sorry`/`axiom` bar as
  proof code**: no shortcuts.

---

## §7. Open design questions

- **Should `veir-opt` add a `--mlir-print-op-generic` equivalent?**
  Today it always prints generic. If a future custom-assembly mode
  lands, both modes need testing.
- **How do we differentially test passes?** A diff against `llzk-opt
  -p <pass>` would compare LLZK's pass implementation to a VEIR pass.
  Out of scope for the initial harness; revisit when verified passes
  start landing.
- **CI integration**: should differential tests run on every PR?
  Probably gated on `llzk-opt` being available in CI image. Defer.

---

## §8. Cross-references

- `harness/coverage.md` — the source of truth for known divergences
- `harness/dialect-port-checklist.md` — Phase 7 should include adding
  a `differential/` directory once `llzk-opt` is available locally
- `harness/evaluation-criteria.md` §A — port acceptance criteria
  reference this harness once a dialect ships
