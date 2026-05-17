# Checkpoint protocol

Branch, commit, and tag conventions for this fork. Designed so that
work can be paused, audited, and resumed without losing state.

The bar is: anyone (a future maintainer, a reviewer, an automated
audit) can answer "what is the state of the LLZK port?" by reading
`plan.md` + `harness/coverage.md` + `git tag -l 'port-*' 'verif-*' 'infra-*'`.

---

## §1. Branch naming

| Kind of work | Branch pattern | Example |
|---|---|---|
| Single dialect port | `llzk<dialect>_<n>` | `llzkfelt_test1`, `llzkconstrain_1` |
| Tier batch | `llzk-tier<N>_<batch-id>` | `llzk-tier1_a`, `llzk-tier2_b` |
| Infrastructure | `infra/<feature>` | `infra/symbol-ref-attr`, `infra/regions` |
| Verification pilot | `verif/<dialect>/<pass-name>` | `verif/felt/right-identity` |
| Design spike | `spike/<topic>` | `spike/symbol-table-arch` |
| Hotfix | `fix/<short-name>` | `fix/parser-felt-named-type` |

`<n>` is a counter that increments if a previous attempt was abandoned
(the `llzkfelt_test1` branch follows this — first attempt of the felt
port).

---

## §2. Commit cadence

The Felt port established **one phase per commit** as the default. This
makes audits trivial: `git log --oneline` reads like a phase
checklist.

Exceptions:

- **Phase 2 of a dialect port is atomic.** Adding the opcode inductive
  forces the verifier arms and the properties placeholder; all three
  changes are one commit (see `harness/porting-notes.md` Gotcha 1).
- **Coverage updates ride the substantive commit.** Don't make a
  separate "update coverage.md" commit; it makes review harder. The
  `harness/coverage.md` diff is part of the work.
- **Build health is per-commit, not per-PR.** Every commit on a feature
  branch must build clean. This makes bisect work.

### Commit message format

```
<phase>: <imperative short summary>

<optional body explaining what and why, not how>
```

Examples (from current history):

```
Phase 1: add FeltType to Attribute inductive
Phase 2+4: register Felt opcodes and verifier shape checks
Phase 3: wire up FeltConstProperties
Phase 5: typed parser branch for !felt.type
```

For infrastructure or verification:

```
infra/symbol-ref-attr: parser + Attribute case
verif/felt/right-identity: theorem + lit test
```

---

## §3. Build gates

Before any commit:

```bash
lake build 2>&1 | tail -5     # expect "Build completed successfully (N jobs)"
lake test 2>&1 | tail -3       # expect "0 of N failed"
```

Before any PR / branch push:

```bash
lake build && lake test && uv run lit Test/ -v 2>&1 | tail -3
```

The third command's "N of N passed" count must equal or exceed the
previous baseline. If it decreased, the PR is not ready.

### `baseline.txt` discipline

The repo has a `baseline.txt` from the Felt port. Each tier batch (not
each commit) updates this file with the current build/test counts and
the toolchain. Format:

```
# Baseline at <tag-name>
# Date: YYYY-MM-DD
# Branch: <branch>
# Toolchain: <output of `cat lean-toolchain`>

## lake build
<N>/<N> jobs

## lake test
PASS / FAIL

## uv run lit Test/ -v
<N> of <N> pass

## Coverage delta since previous baseline
<bullet list of rows that moved>
```

---

## §4. Tagging

Tags are immutable checkpoints. Three kinds:

| Tag pattern | When | Example |
|---|---|---|
| `port-<dialect>-v<n>` | Dialect lands on `main` | `port-felt-v1` |
| `tier-<N>-complete` | Tier batch all merged | `tier-1-complete` |
| `infra-<feature>-v<n>` | Infra phase complete | `infra-symbol-ref-attr-v1` |
| `verif-<dialect>-<pass>-v<n>` | Verification pilot complete | `verif-felt-right-identity-v1` |
| `spike-<topic>` | Design spike concluded | `spike-symbol-table-arch` |

Tag annotations summarize:
- What landed
- Acceptance criteria reference (`harness/evaluation-criteria.md` §A/§B/§C)
- Build/test counts
- Coverage rows moved

Use `git tag -a` (annotated). Example:

```bash
git tag -a port-felt-v1 -m "$(cat <<'EOF'
Felt dialect port complete (Phase A.0 of plan.md).

Scope: 18 ops + !felt.type{,<"name">}
Build: 207/207
Tests: 264/264 (was 263/264)
Coverage rows moved:
  - felt dialect: ❌ → ✅ (with caveats: traits, folder, custom-asm)
  - !felt.type, !felt.type<"name">: ❌ → ✅
  - #felt<const v> : !felt.type: stays ❌ (workaround: IntegerAttr — superseded 2026-05-17, see structured FeltConstAttr)

Acceptance criteria: harness/evaluation-criteria.md §A
EOF
)"
```

---

## §5. Merge protocol

1. **Squash vs. preserve history**: preserve. The phased history is
   part of the audit trail. Don't squash unless the branch was a
   single logical change (a typo fix, a one-line tweak).
2. **No merge commits inside feature branches**: rebase onto current
   `main` before merging. The first commit after the branch base
   should be the Phase-0 setup commit.
3. **PR review checklist**: reviewer uses `harness/evaluation-criteria.md`
   §A / §B / §C as appropriate. PR description fills the §F template.
4. **Post-merge tag**: tagged on the merge commit on `main`, not on
   the feature branch.
5. **Push the tag.** `git push --tags`. Or one-time setup:
   `git config --global push.followTags true` to auto-push annotated
   tags with their commit. Forgetting this leaves the tag local-only
   (this happened twice during the 2026-05-15 session before being
   caught — gate §7 in `harness/quality-gates.md`).
6. **Run quality gates.** `bash scripts/check-llzk-quality-gates.sh`
   should exit 0 after the merge. CI runs this on PR via
   `.github/workflows/llzk-quality-gates.yml`; the local run is the
   pre-push check.

---

## §6. Resuming after a pause

If work pauses for >1 week:

1. `git tag -l` to see the last checkpoint
2. Read `plan.md` to find the next un-checked phase
3. Read `harness/coverage.md` for the current state of features
4. Read `harness/porting-notes.md` for any new gotchas since you last
   worked
5. Verify the baseline:
   ```bash
   lake build && lake test && uv run lit Test/ -v 2>&1 | tail -3
   ```
6. If `lean-toolchain` has moved (this repo regularly bumps nightlies),
   account for any new build flakes (see the elan toolchain-lock note
   in `baseline.txt`)

If work pauses for >1 month, consider whether the dialect or pass
under attempt is still the right next step — `plan.md` ordering may
have shifted.

---

## §7. Abandoning a branch

It's fine to abandon a port if it revealed dependencies that aren't
ready (e.g., the dialect needs regions and Phase F isn't done).

To abandon cleanly:

1. Write the discovery to `harness/coverage.md` (mark the dialect as
   blocked on infra X, link the relevant plan phase)
2. Add a note to `harness/porting-notes.md` if a new gotcha surfaced
3. Push the branch to origin so the work isn't lost (don't delete)
4. Tag with `spike-<topic>` if anything design-grade emerged
5. Open a tracking issue/note in `plan.md` so the dialect's eventual
   restart picks up the discoveries

The next attempt branches as `llzk<dialect>_<n+1>` from current `main`.

---

## §8. Tag history audit

To answer "what is the state of the LLZK port?":

```bash
git tag -l 'port-*' 'tier-*' 'infra-*' 'verif-*' 'spike-*' --sort=-creatordate | head -20
```

Combined with `plan.md` status table and `harness/coverage.md`, this is
the audit trail.

If a tag is missing for a phase that's marked complete in `plan.md`,
that's an audit failure — tag it retroactively (with the original
commit) or downgrade the plan status.

---

## §9. Toolchain bumps

The upstream VEIR repo bumps `lean-toolchain` regularly (recent commits
show `nightly-2026-04-29`, `nightly-2026-04-27`, `nightly-2026-04-24`).

When merging upstream into a working branch:

1. Bump `lean-toolchain` in a dedicated commit, no other changes
2. `lake build` → may flake on first run due to elan toolchain-lock
   (documented in `baseline.txt`); retry once
3. `lake test && uv run lit Test/` to confirm nothing regressed
4. If a regression surfaces, file under `harness/porting-notes.md`
   §Toolchain regressions and consider whether to pin
