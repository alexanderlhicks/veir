// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Bool basic ops at module level. Uses arith.constant for i1 inputs
// (LLZK rejects `builtin.module` regions with block arguments, so we
// can't use the `^bb0(%a: i1, ...)` form).

"builtin.module"() ({
  %a = "arith.constant"() <{value = 1 : i1}> : () -> i1
  %b = "arith.constant"() <{value = 0 : i1}> : () -> i1
  %0 = "bool.and"(%a, %b) : (i1, i1) -> i1
  %1 = "bool.or"(%a, %b) : (i1, i1) -> i1
  %2 = "bool.xor"(%a, %b) : (i1, i1) -> i1
  %3 = "bool.not"(%a) : (i1) -> i1
  "bool.assert"(%0) : (i1) -> ()
  "bool.assert"(%0) <{msg = "expected true"}> : (i1) -> ()
}) : () -> ()
