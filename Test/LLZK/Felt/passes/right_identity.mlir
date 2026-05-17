// RUN: veir-opt %s -p="felt-combine" | filecheck %s
//
// Felt right-identity rewrite: `felt.add x (felt.const 0) -> x`.
// Soundness theorem in Veir/Passes/Felt/Proofs.lean.

"builtin.module"() ({
^bb0(%a: !felt.type):
  // %z is unused after rewrite; DCE doesn't run here, so it stays.
  %z = "felt.const"() <{"value" = #felt<const 0> : !felt.type}> : () -> !felt.type
  %r = "felt.add"(%a, %z) : (!felt.type, !felt.type) -> !felt.type
  // Sanity: a non-matching add (rhs is not zero) is left untouched.
  %c1 = "felt.const"() <{"value" = #felt<const 1> : !felt.type}> : () -> !felt.type
  %s = "felt.add"(%a, %c1) : (!felt.type, !felt.type) -> !felt.type
}) : () -> ()

// The first felt.add disappears (its result is replaced by %a); the
// second one stays because its rhs is felt.const 1, not 0. Note the
// CHECK-NEXT chain implicitly asserts no extra `"felt.add"` lines
// between the surviving add and the closing brace — i.e. only one
// felt.add survives, as the soundness theorem
// (Veir/Passes/Felt/Proofs.lean) requires.
//
// CHECK:        "builtin.module"() ({
// CHECK:          %{{[^ ]+}} = "felt.const"() <{"value" = #felt<const 0> : !felt.type}> : () -> !felt.type
// CHECK-NEXT:     %{{[^ ]+}} = "felt.const"() <{"value" = #felt<const 1> : !felt.type}> : () -> !felt.type
// CHECK-NEXT:     %{{[^ ]+}} = "felt.add"(%{{[^,]+}}, %{{[^)]+}}) : (!felt.type, !felt.type) -> !felt.type
// CHECK-NEXT:   }) : () -> ()
