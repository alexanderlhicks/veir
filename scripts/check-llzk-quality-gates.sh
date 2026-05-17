#!/usr/bin/env bash
# check-llzk-quality-gates.sh — enforce the gates defined in
# harness/quality-gates.md that can be checked statically.
#
# Exit codes:
#   0 — all gates passed
#   1 — at least one gate failed (output names the failed gate(s))
#
# Runs locally before committing; also intended as a CI step.

set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAIL=0

# --- §2: no new sorry/axiom in proof files or new LLZK ports ----------
# `Veir/Passes/<*>/Proofs.lean` and `Veir/Data/<*>/` and the entire
# `Veir/Dialects/LLZK/` subtree must be sorry-free and axiom-free.
# The legacy ~179 sorries in pass-implementation files are tolerated
# (see harness/coverage.md §Verification machinery).
echo "[gate §2] sorry/axiom hygiene in proofs + LLZK ports..."
PATHS=(
  Veir/Dialects/LLZK/
  Veir/Passes/Felt/Proofs.lean
  Veir/Data/Felt/
)
# Use Python to do comment-aware checking — naive grep would flag `sorry`
# inside docstrings (e.g. "the pass-side `sorry`s ..." in Proofs.lean's
# header), which is the wrong signal.
LOCAL_FAIL=0
for p in "${PATHS[@]}"; do
  [[ -e "$p" ]] || continue
  python3 - "$p" <<'PY' || LOCAL_FAIL=1
import re, sys, os
root = sys.argv[1]
paths = []
if os.path.isfile(root):
    paths = [root]
else:
    for dp, _, fns in os.walk(root):
        for fn in fns:
            if fn.endswith(".lean"):
                paths.append(os.path.join(dp, fn))
bad = []
for path in paths:
    in_block = False
    with open(path) as f:
        for i, line in enumerate(f, 1):
            stripped = line
            # Handle /- ... -/ block comments and /-- ... -/ docstrings.
            # Track open/close per line; conservative.
            if in_block:
                if "-/" in stripped:
                    stripped = stripped[stripped.index("-/")+2:]
                    in_block = False
                else:
                    continue
            # Strip /- ... -/ on the same line.
            while True:
                m = re.search(r'/--?', stripped)
                if not m:
                    break
                rest = stripped[m.end():]
                if "-/" in rest:
                    stripped = stripped[:m.start()] + rest[rest.index("-/")+2:]
                else:
                    in_block = True
                    stripped = stripped[:m.start()]
                    break
            # Strip -- line-comment portion.
            if "--" in stripped:
                stripped = stripped[:stripped.index("--")]
            # Check what's left.
            if re.search(r'\bsorry\b', stripped):
                bad.append(f"  {path}:{i}: sorry in code")
            if re.match(r'\s*(public\s+)?axiom\b', stripped):
                bad.append(f"  {path}:{i}: axiom in code")
if bad:
    print("\n".join(bad))
    sys.exit(1)
PY
done
if [[ "$LOCAL_FAIL" -eq 0 ]]; then echo "  PASS"; else FAIL=1; fi

# --- §3: coverage doc references real paths ---------------------------
# Every `Veir/Dialects/LLZK/<X>/` path mentioned in coverage.md should
# exist; conversely, every dialect under that path should be mentioned.
echo "[gate §3] harness/coverage.md path consistency..."
LOCAL_FAIL=0
for d in Veir/Dialects/LLZK/*/; do
  name="$(basename "$d")"
  # Match: lowercase mention in a dialect row, OR explicit path.
  if ! grep -qE "\b${name,,}\b|Dialects/LLZK/${name}" harness/coverage.md; then
    echo "  WARN: dialect $name not referenced in harness/coverage.md"
    # Warn only, don't fail — this is informational.
  fi
done
# Conversely: any harness/coverage.md mention of `Veir/Dialects/LLZK/<X>/`
# should refer to a real directory.
grep -oE 'Veir/Dialects/LLZK/[A-Za-z_]+' harness/coverage.md | sort -u | while read -r p; do
  if [[ ! -d "$p" ]]; then
    echo "  FAIL: harness/coverage.md references $p which doesn't exist"
    LOCAL_FAIL=1
  fi
done
if [[ "$LOCAL_FAIL" -eq 0 ]]; then echo "  PASS"; else FAIL=1; fi

# --- §3 cont.: lit count consistency ----------------------------------
# baseline.txt records the most recent lit-suite count; harness/coverage.md
# and plan.md should mention the same number if they cite a count at all.
echo "[gate §3] lit count consistency between baseline + coverage + plan..."
BASELINE_COUNT="$(grep -oE '[0-9]+ of [0-9]+ pass|[0-9]+/[0-9]+ \(' baseline.txt 2>/dev/null | tail -1 | grep -oE '[0-9]+' | head -1)"
if [[ -n "${BASELINE_COUNT:-}" ]]; then
  # Search coverage.md and plan.md for stale counts that are LOWER than
  # the baseline (i.e., predate it).
  STALE="$(grep -nE 'lit Test/ -v|lit Test/.*[0-9]+/[0-9]+|264/264|263/264|205/205|207/207|213/213' harness/coverage.md plan.md 2>/dev/null | grep -vE "${BASELINE_COUNT}" || true)"
  if [[ -n "$STALE" ]]; then
    echo "  WARN: stale count references (baseline says ~$BASELINE_COUNT):"
    echo "$STALE" | sed 's/^/    /'
    # Warn only — exact counts will fluctuate as tests are added.
  fi
fi
echo "  PASS (warnings non-fatal)"

# --- §7: tags pushed -----------------------------------------------------
# Check that every annotated tag matching port-* / tier-* / verif-* / infra-*
# exists on origin.
echo "[gate §7] tag push status..."
LOCAL_FAIL=0
if command -v git >/dev/null 2>&1; then
  for tag in $(git tag -l 'port-*' 'tier-*' 'verif-*' 'infra-*'); do
    if ! git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/${tag}\$"; then
      echo "  FAIL: local tag $tag not on origin (run: git push --tags)"
      LOCAL_FAIL=1
    fi
  done
fi
if [[ "$LOCAL_FAIL" -eq 0 ]]; then echo "  PASS"; else FAIL=1; fi

# --- summary ------------------------------------------------------------
echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "All quality gates passed."
  exit 0
else
  echo "One or more quality gates failed. See harness/quality-gates.md."
  exit 1
fi
