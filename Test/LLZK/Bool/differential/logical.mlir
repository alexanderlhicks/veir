// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Bool basic ops at module level. Excludes bool.cmp (deferred Phase D.4).

"builtin.module"() ({
^bb0(%a: i1, %b: i1):
  %0 = "bool.and"(%a, %b) : (i1, i1) -> i1
  %1 = "bool.or"(%a, %b) : (i1, i1) -> i1
  %2 = "bool.xor"(%a, %b) : (i1, i1) -> i1
  %3 = "bool.not"(%a) : (i1) -> i1
  "bool.assert"(%0) : (i1) -> ()
  "bool.assert"(%0) <{msg = "expected true"}> : (i1) -> ()
}) : () -> ()
