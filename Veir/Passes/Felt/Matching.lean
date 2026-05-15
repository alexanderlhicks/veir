import Veir.Pass
import Veir.PatternRewriter.Basic
import Veir.Passes.Matching

/-! Helper matchers for Felt-dialect ops. -/

namespace Veir.FeltPass

def matchAdd (op : OperationPtr) (ctx : IRContext OpCode) :
    Option (ValuePtr × ValuePtr × propertiesOf (OpCode.felt Felt.add)) := do
  let (operands, properties) ← matchOp op ctx (OpCode.felt Felt.add) 2
  return (operands[0]!, operands[1]!, properties)

def matchConst (op : OperationPtr) (ctx : IRContext OpCode) :
    Option (propertiesOf (OpCode.felt Felt.const)) := do
  let (_, properties) ← matchOp op ctx (OpCode.felt Felt.const) 0
  return properties

/-- Follow a ValuePtr to its defining `felt.const` op and return its
    properties; mirrors `Veir.matchConstantVal` for LLVM. -/
def matchConstFromValue (val : ValuePtr) (ctx : IRContext OpCode) :
    Option (propertiesOf (OpCode.felt Felt.const)) := do
  let .opResult opResultPtr := val | none
  matchConst opResultPtr.op ctx

end Veir.FeltPass
