// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Casts: i1 -> felt -> index. LLZK's cast.tofelt only accepts i1 or
// index inputs (the i32 case our identity.mlir uses works in VEIR
// because VEIR doesn't enforce the operand-type predicate — a
// documented coverage gap).

"builtin.module"() ({
  %b = "arith.constant"() <{value = 1 : i1}> : () -> i1
  %f = "cast.tofelt"(%b) : (i1) -> !felt.type
  %i = "cast.toindex"(%f) : (!felt.type) -> index
}) : () -> ()
