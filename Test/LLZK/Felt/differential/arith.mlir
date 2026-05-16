// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s --allowlist %s.allowlist
//
// Felt arithmetic, module-level only (no function.def wrapper — Function
// dialect is Tier 3). Known divergence: VEIR stores felt.const's value
// as IntegerAttr (`<{"value" = N : i256}>`); LLZK uses the structured
// `#felt.const<N>`. See arith.mlir.allowlist for the substitution that
// collapses these to equivalent forms before diffing.

"builtin.module"() ({
^bb0(%a: !felt.type, %b: !felt.type):
  %c1 = "felt.const"() <{value = 42 : i256}> : () -> !felt.type
  %c2 = "felt.const"() <{value = 7 : i256}> : () -> !felt.type
  %s = "felt.add"(%a, %c1) : (!felt.type, !felt.type) -> !felt.type
  %p = "felt.mul"(%s, %c2) : (!felt.type, !felt.type) -> !felt.type
  %n = "felt.neg"(%p) : (!felt.type) -> !felt.type
}) : () -> ()
