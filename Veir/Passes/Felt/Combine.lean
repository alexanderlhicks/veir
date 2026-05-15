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
  let cstProp : FeltConstProperties :=
    { value := { value := sumVal, type := cstL.value.type } }
  -- lhs and the original add result share the same `!felt.type` type;
  -- reuse lhs's type for the new const op (mirrors InstCombine's pattern).
  let resultType := lhs.getType! rewriter.ctx.raw
  let (rewriter, newOp) ← rewriter.createOp (OpCode.felt Felt.const)
    #[resultType] #[] #[] #[] cstProp (some <| .before op) sorry sorry sorry sorry
  rewriter.replaceOp op newOp sorry sorry sorry sorry sorry

/-! # Pass implementation -/

def Combine.impl (ctx : WfIRContext OpCode) (op : OperationPtr) (_ : op.InBounds ctx.raw) :
    ExceptT String IO (WfIRContext OpCode) := do
  let pattern := RewritePattern.GreedyRewritePattern
    #[right_identity_zero_add, constant_fold_add]
  match RewritePattern.applyInContext pattern ctx with
  | none => throw "Error while applying felt-combine pattern rewrites"
  | some ctx => pure ctx

public def Combine : Pass OpCode :=
  { name := "felt-combine"
    description := "Felt-dialect peephole combines (right-identity zero add)"
    run := Combine.impl }

end Veir.FeltPass
