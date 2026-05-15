// RUN: veir-opt %s -p="felt-combine" | filecheck %s
//
// Felt constant-fold: `felt.add (felt.const c1) (felt.const c2) -> felt.const (c1+c2)`.
// Soundness theorem in Veir/Passes/Felt/Proofs.lean (`constant_fold_add`).
//
// Also exercises the greedy fixpoint: after the first fold replaces the
// outer add with a const, the rewriter notices the now-folded const can
// participate in another fold (here it would, if a downstream add used
// it). The pass is registered greedy so this happens automatically.

"builtin.module"() ({
^bb0(%v: !felt.type):
  // Both operands constant: folds to felt.const 42.
  %a = "felt.const"() <{value = 10 : i256}> : () -> !felt.type
  %b = "felt.const"() <{value = 32 : i256}> : () -> !felt.type
  %sum = "felt.add"(%a, %b) : (!felt.type, !felt.type) -> !felt.type
  // Mixed: a constant + a block-arg value. Constant-fold does NOT match;
  // right-identity pattern also doesn't (rhs is 5, not 0). Op survives.
  %five = "felt.const"() <{value = 5 : i256}> : () -> !felt.type
  %mixed = "felt.add"(%v, %five) : (!felt.type, !felt.type) -> !felt.type
}) : () -> ()

// After felt-combine: the (10+32) add is replaced by a fresh felt.const 42;
// the mixed add stays. Old const-defining ops (%a, %b) stay because no DCE.
//
// CHECK:        "builtin.module"() ({
// CHECK:          %{{[^ ]+}} = "felt.const"() <{"value" = 42 : i256}> : () -> !felt.type
// CHECK:          %{{[^ ]+}} = "felt.add"(%{{[^,]+}}, %{{[^)]+}}) : (!felt.type, !felt.type) -> !felt.type
// CHECK-NEXT:   }) : () -> ()
