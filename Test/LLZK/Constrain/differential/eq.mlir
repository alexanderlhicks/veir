// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Constrain equality at module level. constrain.in deferred (Phase D.3).
// Note: LLZK ConstraintOpInterface / ConstraintGen traits not encoded
// (harness/coverage.md §Op interfaces, §Traits) — diff should still
// match because traits don't appear in the printed text.

"builtin.module"() ({
^bb0(%a: !felt.type, %b: !felt.type):
  "constrain.eq"(%a, %b) : (!felt.type, !felt.type) -> ()
}) : () -> ()
