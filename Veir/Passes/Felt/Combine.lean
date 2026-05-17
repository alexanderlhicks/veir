import Veir.Pass
import Veir.PatternRewriter.Basic
import Veir.Passes.Felt.Matching
-- Pull in the soundness proof so default `lake build` checks it.
-- (Existing Combines/Proofs.lean and InstructionSelection/Proofs.lean
-- are orphan files in the current lakefile; we depart from that
-- precedent here to defend against silent proof bitrot.)
import Veir.Passes.Felt.Proofs

namespace Veir.FeltPass

/-!
  Felt-dialect peephole combines. First entry (Phase E.1) is the right-
  identity rewrite `felt.add x (felt.const 0) -> x`. Soundness is proved in
  `Veir/Passes/Felt/Proofs.lean` against the provisional `Veir/Data/Felt/`
  semantic model (Felt ≈ Int, no modular reduction). The rewrite is
  sound under any `ZMod p` model because `const 0` stays `0` after
  reduction.

  Mirrors `Veir/Passes/Combines/Combine.lean` (RISCV's right-identity-zero
  add).
-/

/-! # Lowering Patterns -/

set_option warn.sorry false in
/-- felt.add x (felt.const 0) -> x -/
def right_identity_zero_add (rewriter : PatternRewriter OpCode) (op : OperationPtr) :
    Option (PatternRewriter OpCode) := do
  let some (lhs, rhs, _) := matchAdd op rewriter.ctx | return rewriter
  let some rhsOp := rhs.getDefiningOp! rewriter.ctx.raw | return rewriter
  let some cst := matchConst rhsOp rewriter.ctx | return rewriter
  if cst.value.value ≠ 0 then return rewriter
  let rewriter ← rewriter.replaceValue (op.getResult 0) lhs sorry sorry
  rewriter.eraseOp op sorry sorry sorry

set_option warn.sorry false in
/-- felt.add (felt.const c1) (felt.const c2) -> felt.const (c1+c2) -/
def constant_fold_add (rewriter : PatternRewriter OpCode) (op : OperationPtr) :
    Option (PatternRewriter OpCode) := do
  let some (lhs, rhs, _) := matchAdd op rewriter.ctx | return rewriter
  let some cstL := matchConstFromValue lhs rewriter.ctx | return rewriter
  let some cstR := matchConstFromValue rhs rewriter.ctx | return rewriter
  let sumVal := cstL.value.value + cstR.value.value
  -- Preserve the input constants' field type (they're TypesUnify'd by
  -- felt.add's input constraint, so picking either is fine).
  let cstProp : FeltConstProperties :=
    { value := { value := sumVal, fieldType := cstL.value.fieldType } }
  -- lhs and the original add result share the same `!felt.type` type;
  -- reuse lhs's type for the new const op (mirrors InstCombine's pattern).
  let resultType := lhs.getType! rewriter.ctx.raw
  let (rewriter, newOp) ← rewriter.createOp (OpCode.felt Felt.const)
    #[resultType] #[] #[] #[] cstProp (some <| .before op) sorry sorry sorry sorry
  rewriter.replaceOp op newOp sorry sorry sorry sorry sorry

set_option warn.sorry false in
/-- felt.sub x x -> felt.const 0 -/
def self_subtraction_to_zero (rewriter : PatternRewriter OpCode) (op : OperationPtr) :
    Option (PatternRewriter OpCode) := do
  let some (lhs, rhs, _) := matchSub op rewriter.ctx | return rewriter
  -- ValuePtr equality: both operands flow from the same SSA value.
  if lhs ≠ rhs then return rewriter
  -- Synthesize a `#felt<const 0> : !felt.type` (structured form post-2026-05-17).
  -- Use an unnamed felt field; if the surrounding context has a named
  -- field, a later canonicalizer (not implemented) would refine it.
  let cstProp : FeltConstProperties :=
    { value := { value := 0, fieldType := { fieldName := none } } }
  let resultType := lhs.getType! rewriter.ctx.raw
  let (rewriter, newOp) ← rewriter.createOp (OpCode.felt Felt.const)
    #[resultType] #[] #[] #[] cstProp (some <| .before op) sorry sorry sorry sorry
  rewriter.replaceOp op newOp sorry sorry sorry sorry sorry

set_option warn.sorry false in
/--
  felt.add (felt.add x c1) c2  ->  felt.add x (c1+c2)
  when c1 and c2 are felt.const literals.

  Doesn't require dominance reasoning beyond what `getDefiningOp!`
  provides: the inner add's operands and the outer constant are
  visible from the outer add's match, and we replace the outer add
  in-place (no SSA value is referenced before defined).
-/
def assoc_const_fold_add (rewriter : PatternRewriter OpCode) (op : OperationPtr) :
    Option (PatternRewriter OpCode) := do
  let some (innerVal, c2Val, _) := matchAdd op rewriter.ctx | return rewriter
  -- Outer add's rhs must be a constant.
  let some c2 := matchConstFromValue c2Val rewriter.ctx | return rewriter
  -- Outer add's lhs must be the result of another felt.add (x + c1).
  let some (x, c1Val, _) := matchAddFromValue innerVal rewriter.ctx | return rewriter
  -- Inner add's rhs must be a constant.
  let some c1 := matchConstFromValue c1Val rewriter.ctx | return rewriter
  -- Build the combined constant (c1+c2) and create a fresh add.
  let combinedVal := c1.value.value + c2.value.value
  let combinedCst : FeltConstProperties :=
    { value := { value := combinedVal, fieldType := c1.value.fieldType } }
  let resultType := x.getType! rewriter.ctx.raw
  let (rewriter, combinedConstOp) ← rewriter.createOp (OpCode.felt Felt.const)
    #[resultType] #[] #[] #[] combinedCst (some <| .before op) sorry sorry sorry sorry
  -- The new add's RHS is the combined constant we just created.
  let combinedConstVal : ValuePtr := .opResult ⟨combinedConstOp, 0⟩
  let (rewriter, newAdd) ← rewriter.createOp (OpCode.felt Felt.add)
    #[resultType] #[x, combinedConstVal] #[] #[] ()
    (some <| .before op) sorry sorry sorry sorry
  rewriter.replaceOp op newAdd sorry sorry sorry sorry sorry

/-! # Pass implementation -/

def Combine.impl (ctx : WfIRContext OpCode) (op : OperationPtr) (_ : op.InBounds ctx.raw) :
    ExceptT String IO (WfIRContext OpCode) := do
  let pattern := RewritePattern.GreedyRewritePattern
    #[right_identity_zero_add, constant_fold_add, self_subtraction_to_zero,
      assoc_const_fold_add]
  match RewritePattern.applyInContext pattern ctx with
  | none => throw "Error while applying felt-combine pattern rewrites"
  | some ctx => pure ctx

public def Combine : Pass OpCode :=
  { name := "felt-combine"
    description := "Felt-dialect peephole combines (right-identity zero add)"
    run := Combine.impl }

end Veir.FeltPass
