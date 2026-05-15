#!/usr/bin/env bash
# llzk-diff.sh — compare veir-opt and llzk-opt round-trips for an .mlir input.
#
# Exits 0 (identical mod normalization+allowlist), 1 (differs),
# 77 (skip: llzk-opt missing — lit treats as UNRESOLVED/SKIP).
#
# See harness/differential.md for context.

set -euo pipefail

usage() {
  echo "usage: $0 <input.mlir> [--allowlist <file>]" >&2
  echo "  Set \$LLZK_OPT or put llzk-opt on \$PATH to enable comparison." >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
INPUT="$1"
shift || true

ALLOWLIST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allowlist) ALLOWLIST="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[[ -r "$INPUT" ]] || { echo "input not readable: $INPUT" >&2; exit 2; }

# Find llzk-opt.
LLZK_OPT="${LLZK_OPT:-$(command -v llzk-opt || true)}"
if [[ -z "$LLZK_OPT" ]]; then
  echo "SKIP: llzk-opt not found (set \$LLZK_OPT or add to \$PATH)" >&2
  exit 77
fi

# Find veir-opt via lake.
VEIR_OPT_CMD=( lake exec veir-opt )

# Resolve repo root by walking up from the script's location.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Stage 1: lower input to generic form via llzk-opt. If the input is
# already in generic form, this is idempotent.
GENERIC="$(mktemp -t llzk-diff.generic.XXXXXX.mlir)"
trap 'rm -f "$GENERIC" "$VEIR_OUT" "$LLZK_OUT" "$VEIR_NORM" "$LLZK_NORM"' EXIT
"$LLZK_OPT" --mlir-print-op-generic "$INPUT" > "$GENERIC"

# Stage 2: round-trip through both.
VEIR_OUT="$(mktemp -t llzk-diff.veir.XXXXXX.mlir)"
LLZK_OUT="$(mktemp -t llzk-diff.llzk.XXXXXX.mlir)"
"${VEIR_OPT_CMD[@]}" < "$GENERIC" > "$VEIR_OUT"
"$LLZK_OPT" --mlir-print-op-generic < "$GENERIC" > "$LLZK_OUT"

# Stage 3: normalize. Conservative: strip trailing whitespace, collapse
# blank-line runs, normalize SSA names. Quote-or-not on attribute keys
# folded to no-quote.
normalize() {
  # 1. drop trailing whitespace
  # 2. collapse multiple blank lines
  # 3. unquote attribute keys: <{"key" = ...}> -> <{key = ...}>
  # 4. renumber SSA values in order of appearance: %anything -> %V0, %V1, ...
  sed -E \
    -e 's/[[:space:]]+$//' \
    -e 's/<\{"([A-Za-z_][A-Za-z0-9_]*)" = /<\{\1 = /g' \
    -e 's/, "([A-Za-z_][A-Za-z0-9_]*)" = /, \1 = /g' \
    "$1" \
    | awk '
        # collapse multiple blank lines
        /^$/ { if (prev_blank) next; prev_blank=1; print; next }
        { prev_blank=0; print }
      ' \
    | awk '
        # SSA renumbering: any %ident becomes %V<n> by first-occurrence index
        BEGIN { n = 0 }
        {
          line = $0
          out = ""
          while (match(line, /%[A-Za-z0-9_.]+/)) {
            name = substr(line, RSTART, RLENGTH)
            if (!(name in seen)) { seen[name] = "%V" n; n++ }
            out = out substr(line, 1, RSTART - 1) seen[name]
            line = substr(line, RSTART + RLENGTH)
          }
          print out line
        }
      '
}

VEIR_NORM="$(mktemp -t llzk-diff.veir.norm.XXXXXX.mlir)"
LLZK_NORM="$(mktemp -t llzk-diff.llzk.norm.XXXXXX.mlir)"
normalize "$VEIR_OUT" > "$VEIR_NORM"
normalize "$LLZK_OUT" > "$LLZK_NORM"

# Stage 4: apply allowlist substitutions if provided. Allowlist entries
# look like `"<from>" -> "<to>" (...)` — we apply <from> -> <to> on both
# normalized files so equivalent forms collapse.
if [[ -n "$ALLOWLIST" && -r "$ALLOWLIST" ]]; then
  while IFS= read -r entry; do
    # skip blank lines and comments
    [[ -z "$entry" || "${entry:0:1}" == "#" ]] && continue
    # Expect: "from" -> "to" (...optional context...)
    if [[ "$entry" =~ ^\"(.+)\"\ -\>\ \"(.+)\".*$ ]]; then
      FROM="${BASH_REMATCH[1]}"
      TO="${BASH_REMATCH[2]}"
      sed -i.bak -e "s|$FROM|$TO|g" "$VEIR_NORM" "$LLZK_NORM"
      rm -f "$VEIR_NORM.bak" "$LLZK_NORM.bak"
    fi
  done < "$ALLOWLIST"
fi

# Stage 5: diff.
if diff -u "$LLZK_NORM" "$VEIR_NORM" > /tmp/llzk-diff.$$.diff 2>&1; then
  echo "OK: outputs match" >&2
  rm -f /tmp/llzk-diff.$$.diff
  exit 0
else
  echo "DIFFER:" >&2
  cat /tmp/llzk-diff.$$.diff >&2
  rm -f /tmp/llzk-diff.$$.diff
  exit 1
fi
