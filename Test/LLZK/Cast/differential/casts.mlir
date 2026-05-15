// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Casts between integer/felt/index types at module level.

"builtin.module"() ({
^bb0(%i: i32, %f: !felt.type):
  %0 = "cast.tofelt"(%i) : (i32) -> !felt.type
  %1 = "cast.toindex"(%f) : (!felt.type) -> index
}) : () -> ()
