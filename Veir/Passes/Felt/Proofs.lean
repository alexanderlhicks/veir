import Veir.Data.Felt.Basic

/-!
  Soundness proofs for `Veir/Passes/Felt/Combine.lean`.

  Each pattern in `Combine.lean` is paired with an algebraic identity
  here. The pattern matches the syntactic shape; this file proves the
  semantic equivalence. The pass-side `sorry`s on rewriter preconditions
  are consistent with current VEIR practice (see `harness/coverage.md`
  §Verification machinery); the bar this file clears is the semantic
  theorem, not the precondition discharge.
-/

namespace Veir.Data.Felt

/--
  `felt.add x (felt.const 0) = x`. Soundness of the
  `right_identity_zero_add` pattern in `Veir/Passes/Felt/Combine.lean`.

  Proven against the provisional `Felt := Int` model. Lifts to any
  `ZMod p` semantics because `const 0 = 0` in every modulus.
-/
theorem right_identity_zero_add (lhs : Felt) :
    add lhs (const 0) = lhs := by
  -- `Felt` is `abbrev Felt := Int` so it's reducible by default; only
  -- the wrapper functions need to be unfolded. The remaining goal is
  -- `lhs + 0 = lhs`, discharged by `Int.add_zero` via simp's default
  -- simp set.
  simp [add, const]

/--
  `felt.add (felt.const c1) (felt.const c2) = felt.const (c1 + c2)`.
  Soundness of `constant_fold_add` in `Veir/Passes/Felt/Combine.lean`.

  Lifts to `ZMod p` because `+` commutes with the canonical ring
  homomorphism `ℤ → ZMod p`.
-/
theorem constant_fold_add (c1 c2 : Int) :
    add (const c1) (const c2) = const (c1 + c2) := by
  simp [add, const]

/--
  `felt.sub x x = felt.const 0`. Soundness of `self_subtraction_to_zero`
  in `Veir/Passes/Felt/Combine.lean`.

  Lifts to any `ZMod p` because `x - x = 0` is preserved by every ring
  homomorphism.
-/
theorem self_subtraction_to_zero (x : Felt) :
    sub x x = const 0 := by
  simp [sub, const]

/--
  `felt.add (felt.add x c1) c2 = felt.add x (c1 + c2)`. Soundness of
  `assoc_const_fold_add` in `Veir/Passes/Felt/Combine.lean`.

  Lifts to `ZMod p` because associativity of `+` is preserved by every
  ring homomorphism.
-/
theorem assoc_const_fold_add (x : Felt) (c1 c2 : Int) :
    add (add x (const c1)) (const c2) = add x (const (c1 + c2)) := by
  simp [add, const, Int.add_assoc]

end Veir.Data.Felt
