# Audit-agent prompt template

Reusable prompt for spawning a code-review/audit agent after a tier
batch, dialect port, infrastructure phase, or other multi-commit unit
of work. Captures the structure that worked twice during the
2026-05-15 → 2026-05-17 session (`SESSION_RETRO_2026-05-17.md`).

Use this every time per `harness/quality-gates.md` §5. Don't ad-hoc.

---

## When to spawn

- After **every tier batch** completes (last port committed, before
  merging to `main` or tagging).
- After **every Phase X** ships (D.1 Global, E.1 first verified pass,
  D.4 Bool full, etc.) — even single-commit phases benefit from a
  read-only pair of eyes.
- After **any significant infrastructure addition** (Phase C, F, G
  pieces).

## Why

Audit agents have caught:
- A silent attribute-coercion bug (BoolAssertProperties)
- Stale lit counts in `coverage.md` and `plan.md`
- Misleading phrasing ("typed shape checks" implying type predicates
  when only counts are checked)
- Missing test pairs (Felt had no `invalid.mlir`)
- Inconsistent verifier-arm style across dialects
- Patterns worth promoting to `harness/porting-notes.md`

These wouldn't have surfaced from PR self-review alone.

## Template

Spawn via the Agent tool, `general-purpose` subagent_type, with a
self-contained prompt of this shape:

```
Audit the work landed since <PREVIOUS-CHECKPOINT> on /home/alh/veir
branch <BRANCH>. Be a careful reviewer; identify real issues, don't
pad the report. Build green (<N>/<N>), lit green (<M>/<M>), lake
test clean. No build issues to find — focus on code/proof/doc quality.

<DESCRIPTION OF WHAT LANDED — list each major piece (port, infra,
verified pass, harness change) with commit hash and one-line
summary. Reference the new/changed files for each piece.>

Audit areas:

1. **<Dialect/component> specifics**: <specific files/functions to
   examine, with concrete edge cases to check (e.g. "does the size
   check catch unknown 1-key attrs?", "is the type field validated?")>

2. **<Central dispatch files>**: <list each, with what to verify in
   each (e.g. "every dialect's verifier arm uses ctx.raw opIn", "all
   property-bearing ops have toAttrDict arms")>

3. **Tests** under <directories>:
   - Each dialect has identity.mlir + invalid.mlir
   - invalid.mlir actually exercises the typed verifier arm (the CHECK
     message should reference one that ONLY the typed arm emits)
   - identity.mlir exercises every op the port claims to support

4. **Harness conformance**:
   - `harness/coverage.md`: every row reflects current code state
   - `harness/evaluation-criteria.md` §A.1-A.5: spot-check whether the
     ports meet the bars
   - `plan.md` status checkboxes match the code state

5. **Sorry/axiom hygiene**: no new sorry or axiom in any file under
   `Veir/Dialects/LLZK/` or in any new proof file. The legacy ~179
   sorries in `Veir/Passes/` are tolerated; new files must be clean.
   Run: `grep -rn "sorry\|axiom " <newly-added-paths>`

6. **The gotchas from porting-notes.md**: any port at risk of any
   gotcha? Specifically check the most recent 2-3 gotchas, which are
   most likely to recur on the next port.

7. **Things worth documenting** that aren't yet:
   - Patterns that emerged but aren't captured
   - Workarounds used but not in coverage.md
   - Naming/style choices that the next porter would benefit from

Report structure (this exact 5-category split):
- **Real issues** (with file:line refs) — needs fixing
- **Nits** (minor cleanups, optional fixes)
- **Coverage/doc drift** — places where the harness disagrees with the
  code
- **Worth adding to porting-notes.md** — patterns the next porter would
  benefit from
- **No issues found** for areas that audited clean

Keep the report tight (1500-2500 words). Use code snippets only when
needed to demonstrate an issue.
```

## Substitution checklist

When filling in the template for a given audit:

- [ ] **`<PREVIOUS-CHECKPOINT>`**: most recent tag, or commit hash, or
      named milestone (e.g. "the Tier 1 review" or "commit 82fa7fa").
- [ ] **`<BRANCH>`**: current working branch.
- [ ] **`<N>` / `<M>`**: actual lake build / lit test counts. Get from
      `lake build 2>&1 | tail -1` and `uv run lit Test/ 2>&1 | tail -3`.
- [ ] **`<DESCRIPTION>`**: paragraph per major piece. Cite commit
      hashes and the actual files touched (use `git log --stat`).
- [ ] **`<Dialect/component> specifics`**: for each major piece, the
      specific edge cases to probe. Crib from §1 of the past audit
      prompts in this session — they're stored in the agent task
      outputs at `/tmp/claude-*/tasks/*.output` and can be inspected
      via the harness's git history for the prompts I wrote.

## Response handling

The agent returns a categorized report. For each finding:

| Category | Action |
|---|---|
| Real issue | Fix in a commit; reference the finding in the commit message. |
| Nit | Fix if cheap; defer if not. Don't ignore silently. |
| Coverage/doc drift | Fix in `harness/coverage.md` (or relevant doc) in a commit, same commit as the fix that prompted the drift, when possible. |
| Worth adding to porting-notes.md | Add a dated note in `harness/porting-notes.md`. |
| No issues found | Acknowledge in the close-out commit so the audit's positive findings aren't silently lost. |

The audit close-out commit references all five categories explicitly,
even when some are empty:

```
<Phase X> review: address audit findings

Real issues (3):
- ...

Nits (2):
- ...

Coverage drift (1):
- ...

Worth adding (2):
- ...

No issues found in: <areas the audit cleared>.

Build: 267/267. Lit: 327/327. Lake test: clean.

Co-Authored-By: ...
```

This format makes the audit visible in `git log` and easy to find
later via `git log --grep "audit findings"`.

## Anti-patterns

- **Spawning the audit agent without specific files to examine.** Get
  the specific files-changed list from `git log --stat` and feed them
  into the prompt's §1.
- **Letting the agent's report sit unaddressed.** Either commit fixes
  or document deliberate non-fixes in the close-out commit.
- **Running the audit on a branch with uncommitted changes.** The
  audit's frame of reference is the state of `HEAD`; uncommitted
  changes won't be visible to the agent (it walks the tree but
  doesn't know git status).
