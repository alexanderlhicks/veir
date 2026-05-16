// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Constrain equality at module level. Felt operands materialized via
// arith.constant → cast.tofelt (LLZK won't accept the felt.const
// IntegerAttr workaround we use elsewhere).

"builtin.module"() ({
  %b = "arith.constant"() <{value = 1 : i1}> : () -> i1
  %a = "cast.tofelt"(%b) : (i1) -> !felt.type
  "constrain.eq"(%a, %a) : (!felt.type, !felt.type) -> ()
}) : () -> ()
