// RUN: veir-opt %s -p="felt-combine" | filecheck %s
//
// Felt self-subtraction: `felt.sub x x -> felt.const 0`.
// Soundness theorem in Veir/Passes/Felt/Proofs.lean (`self_subtraction_to_zero`).
//
// Tests that the SSA value-equality check fires only when both operands
// flow from the SAME defining value, not from two different ops with
// equal contents.

"builtin.module"() ({
^bb0(%x: !felt.type, %y: !felt.type):
  // Same value on both sides — folds to felt.const 0.
  %s1 = "felt.sub"(%x, %x) : (!felt.type, !felt.type) -> !felt.type
  // Two distinct block-args, even if semantically equal at runtime —
  // doesn't match (lhs ≠ rhs as ValuePtrs). Op survives.
  %s2 = "felt.sub"(%x, %y) : (!felt.type, !felt.type) -> !felt.type
}) : () -> ()

// CHECK:        "builtin.module"() ({
// CHECK:          %{{[^ ]+}} = "felt.const"() <{"value" = #felt<const 0> : !felt.type}> : () -> !felt.type
// CHECK-NEXT:     %{{[^ ]+}} = "felt.sub"(%{{[^,]+}}, %{{[^)]+}}) : (!felt.type, !felt.type) -> !felt.type
// CHECK-NEXT:   }) : () -> ()
