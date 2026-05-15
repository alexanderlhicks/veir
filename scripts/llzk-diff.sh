#!/usr/bin/env bash
# llzk-diff.sh — compare veir-opt and llzk-opt round-trips for an .mlir input.
#
# Exit codes:
#   0   identical (modulo normalization + allowlist)
#   1   differs
#   2   bad invocation / unreadable input
#   77  skip (llzk-opt or lake missing — lit treats as UNRESOLVED/SKIP)
#
# Env / flags:
#   $LLZK_OPT             explicit path to llzk-opt (otherwise discovered on $PATH)
#   $VEIR_DIFF_VERBOSE=1  print intermediate stages to stderr
#   $VEIR_DIFF_KEEP=1     don't delete intermediate temp files (debug aid)
#   --allowlist <file>    apply per-test fixed-string substitutions before diffing
#   --lower-first         first pass input through `llzk-opt --mlir-print-op-generic`
#                         (use when the input is in LLZK custom assembly; default
#                         assumes input is already in generic MLIR form)
#
# See harness/differential.md for the protocol and harness/coverage.md for the
# per-dialect divergences that the allowlist entries should track.

set -euo pipefail

# --- args ---------------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: llzk-diff.sh <input.mlir> [--allowlist <file>] [--lower-first]
  Diffs the generic-MLIR round-trip output of veir-opt against
  `llzk-opt --mlir-print-op-generic` for the same input.

  $LLZK_OPT or llzk-opt on $PATH selects the LLZK binary.
  $VEIR_DIFF_VERBOSE=1 streams intermediate stages to stderr.
  $VEIR_DIFF_KEEP=1 keeps intermediate temp files after exit.
USAGE
  exit 2
}

[[ $# -ge 1 ]] || usage
INPUT="${1:-}"
shift || true

ALLOWLIST=""
LOWER_FIRST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allowlist) ALLOWLIST="${2:-}"; shift 2 ;;
    --lower-first) LOWER_FIRST=1; shift ;;
    -h|--help) usage ;;
    *) echo "unknown flag: $1" >&2; usage ;;
  esac
done

[[ -n "$INPUT" ]] || usage
[[ -r "$INPUT" ]] || { echo "input not readable: $INPUT" >&2; exit 2; }

# --- tool discovery -----------------------------------------------------------
LLZK_OPT="${LLZK_OPT:-$(command -v llzk-opt 2>/dev/null || true)}"
if [[ -z "${LLZK_OPT:-}" ]]; then
  echo "SKIP: llzk-opt not found (set \$LLZK_OPT or add to \$PATH)" >&2
  exit 77
fi
if ! command -v lake >/dev/null 2>&1; then
  echo "SKIP: lake not on \$PATH (cannot run veir-opt)" >&2
  exit 77
fi

# --- temp file setup ----------------------------------------------------------
TMPDIR_LOCAL="$(mktemp -d -t llzk-diff-XXXXXX)"
cleanup() {
  if [[ "${VEIR_DIFF_KEEP:-0}" == "1" ]]; then
    echo "kept intermediates in $TMPDIR_LOCAL" >&2
  else
    rm -rf "$TMPDIR_LOCAL"
  fi
}
trap cleanup EXIT

GENERIC="$TMPDIR_LOCAL/generic.mlir"
VEIR_OUT="$TMPDIR_LOCAL/veir.out.mlir"
LLZK_OUT="$TMPDIR_LOCAL/llzk.out.mlir"
VEIR_NORM="$TMPDIR_LOCAL/veir.norm.mlir"
LLZK_NORM="$TMPDIR_LOCAL/llzk.norm.mlir"
DIFF_OUT="$TMPDIR_LOCAL/diff.txt"

# --- repo root ----------------------------------------------------------------
# llzk-diff.sh lives in <repo>/scripts/. veir-opt is invoked from <repo> so
# lake finds the manifest.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

log() {
  [[ "${VEIR_DIFF_VERBOSE:-0}" == "1" ]] && echo "[llzk-diff] $*" >&2
}

# --- stage 1: optionally lower input via llzk-opt -----------------------------
if [[ "$LOWER_FIRST" -eq 1 ]]; then
  log "stage 1: lowering input via llzk-opt --mlir-print-op-generic"
  if ! "$LLZK_OPT" --mlir-print-op-generic "$INPUT" > "$GENERIC" 2>"$TMPDIR_LOCAL/llzk-lower.err"; then
    echo "FAIL: llzk-opt could not lower input" >&2
    cat "$TMPDIR_LOCAL/llzk-lower.err" >&2
    exit 1
  fi
else
  log "stage 1: skipped (--lower-first not set; assuming input is generic)"
  cp "$INPUT" "$GENERIC"
fi

# --- stage 2: round-trip through both -----------------------------------------
log "stage 2: round-trip through veir-opt and llzk-opt"
if ! lake exec veir-opt "$GENERIC" > "$VEIR_OUT" 2>"$TMPDIR_LOCAL/veir.err"; then
  echo "FAIL: veir-opt failed on input" >&2
  cat "$TMPDIR_LOCAL/veir.err" >&2
  exit 1
fi
if ! "$LLZK_OPT" --mlir-print-op-generic "$GENERIC" > "$LLZK_OUT" 2>"$TMPDIR_LOCAL/llzk.err"; then
  echo "FAIL: llzk-opt failed on input" >&2
  cat "$TMPDIR_LOCAL/llzk.err" >&2
  exit 1
fi

# --- stage 3: normalize -------------------------------------------------------
# Conservative normalization:
#   - drop trailing whitespace
#   - collapse runs of blank lines to a single blank line
#   - unquote attribute keys: <{"key" = ...}> -> <{key = ...}> (VEIR quotes,
#     LLZK doesn't always)
#   - renumber SSA values in order of appearance: %anything -> %V<n>
#   - normalize block label names: ^bb0(...): -> ^B0(...)
# Other forms of equivalent-but-different output should go through the
# per-test allowlist, not this normalizer.
normalize() {
  local src="$1" dst="$2"
  awk '
    BEGIN { ssa_n = 0; blk_n = 0; prev_blank = 0 }
    {
      line = $0
      # 1. trailing whitespace
      sub(/[[:space:]]+$/, "", line)
      # 2. blank-line collapse
      if (line == "") {
        if (prev_blank) next
        prev_blank = 1; print ""; next
      }
      prev_blank = 0
      # 3. unquote attribute keys
      gsub(/<\{"([A-Za-z_][A-Za-z0-9_]*)" = /, "<{\\1 = ", line)
      gsub(/, "([A-Za-z_][A-Za-z0-9_]*)" = /, ", \\1 = ", line)
      # 4. SSA renumbering and 5. block-label renaming
      out = ""
      rest = line
      while (1) {
        # find earliest of %ident or ^ident
        ps = match(rest, /%[A-Za-z0-9_.]+/)
        ps_start = (ps > 0) ? RSTART : 99999
        ps_len = (ps > 0) ? RLENGTH : 0
        bs = match(rest, /\^[A-Za-z_][A-Za-z0-9_]*/)
        bs_start = (bs > 0) ? RSTART : 99999
        bs_len = (bs > 0) ? RLENGTH : 0
        if (ps_start == 99999 && bs_start == 99999) break
        if (ps_start < bs_start) {
          name = substr(rest, ps_start, ps_len)
          if (!(name in ssa_seen)) { ssa_seen[name] = "%V" ssa_n; ssa_n++ }
          out = out substr(rest, 1, ps_start - 1) ssa_seen[name]
          rest = substr(rest, ps_start + ps_len)
        } else {
          name = substr(rest, bs_start, bs_len)
          if (!(name in blk_seen)) { blk_seen[name] = "^B" blk_n; blk_n++ }
          out = out substr(rest, 1, bs_start - 1) blk_seen[name]
          rest = substr(rest, bs_start + bs_len)
        }
      }
      print out rest
    }
  ' "$src" > "$dst"
}

log "stage 3: normalize both outputs"
normalize "$VEIR_OUT" "$VEIR_NORM"
normalize "$LLZK_OUT" "$LLZK_NORM"

# --- stage 4: per-test allowlist (fixed-string substitution) ------------------
# Allowlist format, one per line:
#   "from-literal" -> "to-literal"   (optional trailing context for humans)
#
# Both <from> and <to> are matched as *fixed strings* (no regex). Applied to
# BOTH normalized files so equivalent forms collapse. Use this for documented
# divergences (e.g. VEIR's IntegerAttr representation of #felt.const<v>).
if [[ -n "$ALLOWLIST" ]]; then
  if [[ ! -r "$ALLOWLIST" ]]; then
    echo "WARN: allowlist $ALLOWLIST not readable; ignoring" >&2
  else
    log "stage 4: applying allowlist $ALLOWLIST"
    python3 - "$VEIR_NORM" "$LLZK_NORM" "$ALLOWLIST" <<'PY'
import re, sys
veir_path, llzk_path, allow_path = sys.argv[1], sys.argv[2], sys.argv[3]
rules = []
with open(allow_path) as f:
    for ln in f:
        ln = ln.rstrip("\n")
        if not ln or ln.startswith("#"):
            continue
        # "from" -> "to"  (anything after is ignored)
        m = re.match(r'^\s*"(.*?)"\s*->\s*"(.*?)"', ln)
        if m:
            rules.append((m.group(1), m.group(2)))
for path in (veir_path, llzk_path):
    with open(path) as f:
        s = f.read()
    for frm, to in rules:
        s = s.replace(frm, to)  # fixed-string, not regex
    with open(path, "w") as f:
        f.write(s)
PY
  fi
fi

# --- stage 5: diff ------------------------------------------------------------
log "stage 5: diff"
if diff -u --label "llzk-opt (normalized)" "$LLZK_NORM" --label "veir-opt (normalized)" "$VEIR_NORM" > "$DIFF_OUT" 2>&1; then
  echo "OK: outputs match (input: $INPUT)" >&2
  exit 0
else
  echo "DIFFER: $INPUT" >&2
  cat "$DIFF_OUT" >&2
  if [[ -n "$ALLOWLIST" ]]; then
    echo >&2
    echo "Hint: documented divergences belong in $ALLOWLIST; see harness/differential.md §4." >&2
  fi
  exit 1
fi
