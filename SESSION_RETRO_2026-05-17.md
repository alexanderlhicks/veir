# LLZK → VEIR session retrospective (2026-05-15 → 2026-05-17)

Companion to `LLZK_PORT_RETRO.md`. That doc captured the original Felt
port; this one covers everything since.

If you are about to continue this work, read this first.

## TL;DR

Three days of work; 36 commits on top of `origin/main`. Shipped:

- **9 LLZK dialects ported** (was 1: Felt). New: String, Include, RAM,
  Cast, Bool (all 6 ops), Constrain.eq, Global. Plus the `index` type
  infra used by RAM and Cast.
- **4 verified peephole rewrites** in `felt-combine` with proven
  algebraic theorems, all imported into the default build (no
  orphan-file bitrot).
- **Active differential testing harness** vs `llzk-opt` (built locally
  via Nix, ~24h source build). 3 diffs pass, 6 XFAIL with documented
  gating reasons. The harness caught two real port bugs that would
  have shipped silently.
- **Harness expanded** from 7 docs to 9, with 6 gotchas + 4 reusable
  patterns accumulated in `harness/porting-notes.md`.
- **Phase B retired** based on empirical evidence (the symbol-table
  spike turned out unnecessary for Tier 1+2).

Build: 267/267. Lit: 327/327 (321 PASS + 6 XFAIL). Lake test: clean.
Zero new `sorry` or `axiom` in this session's code or proofs.

## The session's arc

| Day | Done | Key takeaway |
|---|---|---|
| 1 | Harness setup, parallel surveys, Phase A.2 String port, reorganization into `Veir/Dialects/LLZK/` subtree | The harness pays for itself if porting >1 dialect. Reorg cost ~30 min and saved much more by isolating LLZK work. |
| 1 | Tier 1 audit + cleanup pass | Audit-agent findings included one real correctness issue (BoolAssertProperties silently coerced unknown attrs). Worth running on every batch. |
| 1 | Upstream sync (+21 commits including FlatSymbolRefAttr, HW dialect, WfIRContext restructure) | Pre-emptively fixing the Verifier `ctx.raw` signature *before* lake built was the right call — saved a recompile cycle. |
| 1 | Phase B retired, folded into Phase F | Empirical evidence (Tier 1 worked without symbol-table machinery) trumped the original speculative design. Good outcome from doing the cheap thing first. |
| 2 | Phase D.1 Global port; verification pilots E.1-E.4; Phase D.4 Bool full | Verified pilots came quickly once the recipe was clear. The `Felt := Int` provisional model + ZMod-lift argument was the right level of semantic commitment. |
| 2 | Differential harness scaffold (offline) | Wrote the harness without `llzk-opt` available; tests skipped UNSUPPORTED cleanly. Lit's REQUIRES/XFAIL mechanism worked well. |
| 2-3 | Nix build of llzk-opt; activated differential testing | Cachix didn't have the variants we needed → 24h source build. Once active, the diffs found 2 real bugs and 1 normalizer bug + several structural learnings about LLZK that aren't in its docs. |

## What went well

### Maintained harness paid off repeatedly

Coverage.md was updated in every commit that touched a feature. This
prevented drift between code and documentation. The two audit passes
(post-Tier 1, post-Phase D.1+E.1) both found doc/code inconsistencies
that would have accumulated otherwise.

### Parallel agents for surveys

The three initial surveys (dialect catalog, pass catalog, VEIR
verification surface) ran in parallel and produced comprehensive
reports in ~6 minutes wall-clock. Doing those sequentially would have
been ~18 minutes plus context bloat. The pattern is: spawn agents for
*read-only research* that doesn't depend on subsequent decisions;
synthesize the results yourself.

### Phase retirement as a first-class operation

Phase B was retired with a documented decision trail. The original
framing is preserved as historical context with a "deferred" banner;
all references were rerouted to Phase F. The next maintainer sees:
"this question was asked, this answer was given (defer), here's where
it lives now." No silent abandonment.

### Differential testing caught real bugs

Two ports (Include and Global) had `sym_name` stored as
`FlatSymbolRefAttr` (`@x`) instead of `StringAttr` (`"x"`). Gotcha 3
(2026-05-15) was wrong about this. Without the differential harness,
both ports would have shipped with the wrong attribute encoding and
nobody would have known until somebody tried to feed VEIR output into
`llzk-opt`. The differential test failed at the LLZK *parse* step
(not at the diff step), surfacing the bug as a hard error with a
clear message.

This justifies the 24h Nix build cost on its own.

### Tier 1 batched as a single conceptual unit

Doing 6 small dialects in one batch with the same recipe each time
let the recipe converge fast. By Bool (4th port), the dialect-port-
checklist's Phase 3 split (3.A "no properties" vs 3.B "with
properties") was clear and the next porter wouldn't need to discover
it.

### Imported proofs

The departure from existing precedent (`Combines/Proofs.lean` and
`InstructionSelection/Proofs.lean` are orphan files, never built by
default) — importing `Felt/Proofs.lean` from `Felt/Combine.lean` —
defends against silent bitrot. Verifying this was worth the 5-second
extra build cost.

## What went less well

### Gotcha 3 was wrong, fixed by Gotcha 5

Initial framing (2026-05-15): "Symbol-trait ops need `@name`
parsing." That was based on a guess about how MLIR's generic printer
specializes `sym_name` for Symbol-trait ops. Wrong: `SymbolNameAttr`
is just a `StringAttr` constraint in ODS; the `@`-prefix is for
SymbolRefAttr *users*, not Symbol *producers*.

Cost: two port bugs (Include + Global) that ate ~20 minutes of triage
to find via differentials. Gotcha 3 has been amended; Gotcha 5
captures the correct rule.

**Improvement opportunity**: when porting a dialect, *empirically check
the round-trip against `llzk-opt`* before declaring it ✅. Don't trust
the dialect catalog's assumptions about printed form. Differential
testing should be a pre-flight on every dialect port, not a
post-batch artifact. This goes into the improved harness.

### Nix build was 24 hours

The `.#llzk` (release) and `.#debugGCC` (CI variant) Nix flake
targets both built LLVM from source despite Cachix being configured
correctly. Cause: the LLZK Cachix doesn't host LLVM derivations
matching the exact `.drv` hashes our flake evaluates to (maybe
toolchain or commit differences). 24 hours of CPU.

**Improvement opportunity**: write a "verify Cachix coverage" script
or note: before kicking off a full build, run
`nix-store --query --references $(nix path-info '.#mlir')` style and
check substituter coverage. Or: try `nix-store --realise --dry-run`
to preview what would be built locally vs downloaded.

### The empty-block-header artifact in VEIR's printer

VEIR emits `^4():` even for modules whose body has no block args.
This made differential tests harder (one of the divergences). The
normalizer now strips these. This is a VEIR-side polish item that
the LLZK port doesn't fix, but the normalizer paper-over is a
reasonable workaround.

### Lit's environment sanitization

`config.environment["LLZK_OPT"]` had to be set explicitly in
`Test/lit.cfg` to pass the path through to the test scripts. I didn't
discover this until tests failed with "no output" silently — and
that was a `log()` issue compounding it. Worth a defensive note in
`harness/differential.md` and in the lit.cfg comments.

### `set -e` + `[[ ... ]] && cmd` bug

My `log()` function used `[[ ... ]] && echo` which evaluates false
when verbose is off; under `set -e` this aborted the script silently.
Classic bash gotcha. Caught only when I ran with `bash -x`. Documented
inline in the script now.

**Improvement opportunity**: any new bash script in this repo should
have a small smoke test that exercises both the verbose-on and
verbose-off paths. Or just don't use `set -e` for new scripts that
have non-trivial conditional logic.

### Phase numbering doesn't match commit order

Plan.md lists phases as A.1, A.2, A.3, ..., G.3 but the actual commit
order interleaves them (e.g., A.2 String shipped before A.1 Include).
The numbering reflects the *dependency* order in the original plan,
not the chronological order. This is a recurring small friction; an
audit caught a confusing presentation of build/lit counts that
appeared "in reverse" because of it.

**Improvement opportunity**: in plan.md status table, sort phases by
*completion date* not by phase number, or add an explicit "completed
in order: A.2, A.4, A.3, A.5, A.6, A.1, D.1, E.1-4, D.4" line.

## Patterns and gotchas (now in `harness/porting-notes.md`)

Six gotchas accumulated:
1. Exhaustive-match coupling across `Verifier.lean` + `GlobalOpInfo.lean`
2. Silent textual round-trip via `UnregisteredAttr` (made worse by
   upstream PR #569)
3. ~~`Symbol`-trait ops need `@name` parsing~~ → wrong; superseded by 5
4. Lean keywords as inductive/constructor names (`String_`, `«from»`)
5. `SymbolNameAttr` is `StringAttr`, not `SymbolRefAttr`
6. Most LLZK ops require a `function.def` wrapper with specific attributes

Four reusable patterns:
1. Optional-attr property fields with the `size = 1 ∧ isNone` guard
2. Property-less dialects skip the per-dialect `OpInfo`/`Properties` files
3. `«keyword»` escaping rule (term-mode vs tactic-mode)
4. Provisional `Felt := Int` semantic model with the ZMod-lift argument
5. Enum attributes via the `IntegerAttr` workaround

## Scaling estimates for the remaining work

Reality check on the original estimates in `LLZK_PORT_RETRO.md`:

| | Original estimate | Actual |
|---|---|---|
| Tier 1 batch (Constrain, Bool, Cast, String) | ~2-3 weeks | ~1 day with the harness |
| Per Tier-1 dialect | ~90 min hands-on | ~30-45 min with the recipe matured |
| Differential test setup | Not estimated | 24h llzk-opt build + 1h triage |

The recipe matured. The harness paid for itself. Empirical evidence
from differential testing was more valuable than speculative review.

For what's left, revised estimates:

| Phase | Original | Revised |
|---|---|---|
| C (AffineMap + variadic) | ~2 weeks | ~3-5 days with the recipe |
| D.2 POD | Subset of C | ~1 day after C |
| D.3 Array types | Subset of C | ~2-3 days after C (parametric types are real work) |
| F (regions) | 3-6 weeks | Still 3-6 weeks — this is a real architectural addition |
| G.1 Function | "After F" | ~1-2 weeks after F |
| G.2/G.3 (Poly, Struct) | "Late" | 2-4 weeks each |
| Pilot 5+ (LLZK transforms) | Each pilot is a week+ | Still applies; dominance must be replaced first |

The cliff is still at Phase F. Everything before F has matured to
Tier-1-pace; Phase F is the next real project.

## What the next maintainer needs to know

1. **Read `plan.md` for the current status snapshot.** Status table at
   the top, then phased roadmap. Phase B is retired (folded into F).
2. **Read `harness/coverage.md`** before writing any code that touches
   LLZK. Every row reflects current state; caveats are explicit.
3. **Read `harness/porting-notes.md`** before porting a new dialect.
   6 gotchas + 4 patterns will save real time.
4. **Use `harness/dialect-port-checklist.md`** as the recipe. It's
   matured through 9 ports; trust it.
5. **`harness/evaluation-criteria.md`** is the "done" bar for both
   ports and verified passes. Use it as the PR-review checklist.
6. **Differential testing is gated on `llzk-opt`** being on `$PATH`
   or `$LLZK_OPT` env. Build via `cd llzk-lib && nix build '.#llzk'`
   (or `.#debugGCC` — both are slow without proper Cachix coverage;
   the tests pass without it, just as UNSUPPORTED).
7. **Verified passes live in `Veir/Passes/Felt/`** and import their
   proofs to defend against bitrot. Mirror the pattern.
8. **Phase F is the next architectural project.** It's well-scoped in
   `plan.md` §Phase F (with the symbol-table questions folded in) and
   the recommended hybrid approach is preserved in
   `harness/symbol-table-spike.md` as deferred reference material.

## Open follow-ups (concrete next steps)

In priority order, smallest first:

1. **Structured `#felt.const<v>` attribute parser** (~1 day): would
   un-XFAIL the Felt differential. Establishes the per-dialect
   structured-attribute pattern. Pairs with `#bool<eq>` etc.
2. **CI workflow** (~half-day): build + lit + lake test on PR. Without
   CI, regressions are caught only by the next manual run.
3. **Phase F design note** (~3-5 days): write F.1 (the design doc for
   regions + symbol-table semantics) without code. Concrete plan for
   the next implementor.
4. **Phase C infra** (~3-5 days): `AffineMapAttr` (black-box) +
   variadic-of-variadic. Unblocks POD + Array TYPES.
5. **More verified `felt-combine` rewrites** (variable): low-cost
   demonstrations of the technique. Distributivity, neg-of-neg, etc.

## Tag history

```
4cfc353 Add retrospective doc for the Felt port      ← original Felt
73ca69b Set up harness for LLZK Felt → VEIR port
... (Phase 0-5 Felt, then this session)
202a177 Merge origin/main (nightly-2026-05-14, +21 commits)
... (Tier 1, Global, E.1-4, D.4)
997b36d Activate differential testing; fix two real port bugs
```

Tags (push with `git push --tags`):
- `port-string-v1`, `port-include-v1` — early ports
- `tier-1-complete` — Tier 1 done
- `verif-felt-right-identity-v1` — first verified pass
- `verif-felt-combine-v2` — felt-combine with 4 rewrites

## Files changed this session

```
Test/LLZK/                      9 dialects × (identity + invalid + sometimes differential + sometimes passes/)
  ↑ 30 lit tests total
Veir/Dialects/LLZK/             5 sub-dirs (Felt, String, Include, Bool, Global)
  ↑ per-dialect OpInfo + Properties (Cast/RAM/Constrain are property-less)
Veir/Data/Felt/Basic.lean       provisional Felt semantic model
Veir/Passes/Felt/               Combine, Matching, Proofs — the verified pilots
Veir/{OpCode,Verifier,GlobalOpInfo,Properties}.lean
Veir/IR/Attribute.lean
Veir/Meta/OpCode.lean           trailing-underscore strip
Veir/Parser/AttrParser.lean
VeirOpt.lean                    register felt-combine
harness/                        8 docs maintained; 1 new (symbol-table-spike.md retired)
plan.md                         master roadmap, updated per phase
baseline.txt                    appended tier-1-complete baseline
scripts/llzk-diff.sh            hardened diff script (Python normalizer)
Test/lit.cfg                    llzk-opt feature + env propagation
SESSION_RETRO_2026-05-17.md     this file
```
