// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Felt constants at module level. Uses the structured
// `#felt<const N> : !felt.type` attribute (landed 2026-05-17,
// replaces the prior IntegerAttr workaround that the allowlist used
// to bridge). No more allowlist needed; the diff matches cleanly.
//
// LLZK's felt arithmetic ops (add, mul, neg, etc.) require a
// function.def wrapper with function.allow_non_native_field_ops, so
// we only exercise felt.const at module level until Phase G.1
// (Function dialect) ports.

"builtin.module"() ({
  %c1 = "felt.const"() <{value = #felt<const 42> : !felt.type}> : () -> !felt.type
  %c2 = "felt.const"() <{value = #felt<const 7> : !felt.type}> : () -> !felt.type
}) : () -> ()
