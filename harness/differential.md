# LLZK ↔ VEIR differential testing

Architecture for catching silent semantic drift between VEIR's
implementation of an LLZK dialect and LLZK's own C++ implementation.

**Status**: scaffold complete and exercised against a built `llzk-opt`.
Hardened script + per-dialect tests land at `scripts/llzk-diff.sh`
and `Test/LLZK/<dialect>/differential/` (8 inputs as of 2026-05-17:
7 Tier-1 + 1 Tier-2 Global; no allowlists currently — the
IntegerAttr-vs-`#felt<const N>` divergence that the Felt allowlist
used to bridge was eliminated when the structured `FeltConstAttr`
parser landed). Running the diffs requires a local build of
`llzk-opt` (see §3.1). Tests carry `// REQUIRES: llzk-opt` and lit
auto-skips them as `UNSUPPORTED` when the binary is missing — the
suite stays green on hosts without LLZK built.

**Smoke check** (host without llzk-opt; full lit suite):
```
$ uv run lit Test/ -v
…
Total Discovered Tests: 329
  Unsupported:   8 (2.43%)   ← differential tests
  Passed     : 321 (97.57%)
```

**With `llzk-opt` active**: 324 PASS + 5 XFAIL + 0 FAIL. The 5 XFAIL
differentials all need a `function.def` wrapper (Phase G.1) to lift.

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
   `IntegerAttr` workaround — LLZK's `<{value = #felt<const 42> : !felt.type}>`
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
# Example syntax (no Test/LLZK/* currently uses an allowlist — the
# original Felt IntegerAttr divergence that needed one was eliminated
# in 2026-05-17 by adding the structured FeltConstAttr parser).
# Each line: "<from_pattern>" -> "<to_pattern>" (coverage row)
# "<{value = some.dialect-printed-form}>" -> "<{value = veir-printed-form}>"   (coverage.md §SomeRow)
```

The rule is matched as a **fixed string** (no regex) and applied
**globally to every line of both normalized files** before the diff.
Two implications:

- **Rules are not scoped to a specific op.** A rule like
  `"<{value = 42 : i256}>"` would also rewrite the same fragment if
  it appeared on an unrelated op. Write the `from` side with enough
  surrounding context (op mnemonic, attribute name) to make it unique.
- **Quotes inside `from`/`to` aren't escaped.** The parser's regex
  stops at the first inner `"`. If a rule needs an embedded `"`,
  widen the context to avoid the embedded quote rather than escape it.

Diff lines that survive normalization + allowlist substitution are a
hard fail. The allowlist is for *documented* divergences only — new
allowlist entries must reference a coverage row.

---

## §3. Setup

### §3.1 Building `llzk-opt` locally

LLZK ships two build paths (see `llzk-lib/doc/doxygen/01_setup.md`).
Both produce an `llzk-opt` binary; the Nix path uses LLZK's public
binary cache so the cold build is minutes, not the ~hour-plus of a
manual LLVM compile.

**Nix + Cachix (recommended)**

```bash
# Install Nix (single-user install, no sudo daemon):
sh <(curl -L https://nixos.org/nix/install) --no-daemon
# OR multi-user (recommended on shared hosts; needs sudo):
# sh <(curl -L https://nixos.org/nix/install) --daemon

# Configure LLZK's binary cache so LLVM doesn't compile from source:
nix-env -iA cachix -f https://cachix.org/api/v1/install
cachix use veridise-public

# Build llzk-opt:
cd llzk-lib
nix build '.#llzk-opt'         # ~5-20 min with cache hits
# binary lands at: result/bin/llzk-opt

export LLZK_OPT="$PWD/result/bin/llzk-opt"
```

**Manual (no Nix)**

Needs CMake 3.18+, Ninja, Clang 16+, Z3, Python3. See
`llzk-lib/doc/doxygen/01_setup.md` for the full procedure (it
includes building LLVM/MLIR from source, ~1–3 h).

**Verifying**

```bash
export LLZK_OPT=/path/to/llzk-opt        # (or just put on $PATH)
uv run lit Test/LLZK/ -v
# Differential tests should now report PASS, not UNSUPPORTED.
```

### §3.2 The diff script

`scripts/llzk-diff.sh` is the single-test runner:

```
scripts/llzk-diff.sh <input.mlir> [--allowlist <file>] [--lower-first]
```

Flags and env:
- `--allowlist <file>` — apply per-test fixed-string substitutions
  before diffing (see §4 for format)
- `--lower-first` — first pass the input through
  `llzk-opt --mlir-print-op-generic` (use when input is in LLZK's
  custom assembly; default assumes generic-form input)
- `$LLZK_OPT` — explicit path to llzk-opt (otherwise discovered on `$PATH`)
- `$VEIR_DIFF_VERBOSE=1` — stream stage progress to stderr
- `$VEIR_DIFF_KEEP=1` — retain intermediate temp files after exit

Exit codes:
- `0` — identical (modulo normalization + allowlist)
- `1` — differs
- `2` — bad invocation / unreadable input
- `77` — `llzk-opt` or `lake` not found (lit + `// REQUIRES: llzk-opt`
  treats this as UNSUPPORTED)

Internals (5 stages):
1. *(optional)* lower input via `llzk-opt --mlir-print-op-generic`
2. round-trip the generic-form input through both `veir-opt` and `llzk-opt`
3. normalize each output: trailing whitespace, blank-line runs,
   quoted-or-unquoted attribute keys, SSA value names (`%anything → %V<n>`),
   block labels (`^bb0 → ^B0`)
4. apply allowlist substitutions to both files (fixed-string, not regex)
5. unified-diff with file labels — exit 0 if identical, 1 with diff dumped
   to stderr if not

### §3.3 Lit integration

`Test/lit.cfg` registers the `llzk-opt` feature only when the binary
is on `$PATH` (or `$LLZK_OPT` is set), and substitutes `%scripts` for
the absolute path to `scripts/`. A differential test then reads:

```mlir
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s [--allowlist %s.allowlist] [--lower-first]
```

When the feature is unavailable, lit reports the test as `UNSUPPORTED`,
not `FAIL`. The host without LLZK built sees a fully green suite.

---

## §4. Per-dialect rollout

Differential tests are added **after** a dialect ports cleanly and
its `identity.mlir` passes. The rollout order:

| Dialect | Differential test added | Notes |
|---|---|---|
| Felt | ✅ scaffolded — PASSES (`differential/arith.mlir`). Allowlist removed 2026-05-17 once the structured `FeltConstAttr` parser landed; no current divergence. Limited to `felt.const` at module level since felt arith ops require a `function.def` wrapper in LLZK. |
| String | ✅ scaffolded | `differential/literals.mlir`. No known divergences. |
| Include | ✅ scaffolded | `differential/from.mlir`. Exercises FlatSymbolRefAttr round-trip. |
| RAM | ✅ scaffolded | `differential/load_store.mlir`. MemRead/MemWrite not in printed form, so expect a match. |
| Cast | ✅ scaffolded | `differential/casts.mlir`. No known divergences. |
| Bool | ✅ scaffolded | `differential/logical.mlir`. Excludes `bool.cmp` (deferred). |
| Constrain | ✅ scaffolded | `differential/eq.mlir`. `constrain.in` deferred (Phase D.3). |
| Global | ✅ scaffolded | `differential/def_read_write.mlir`. Exercises FlatSymbolRefAttr in both producer (`sym_name`) and user (`name_ref`) roles. No known divergences. |
| Function, Struct | (after port) | Wait for Tier 3. |

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
   (until Phase F lands nested symbol support).
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
