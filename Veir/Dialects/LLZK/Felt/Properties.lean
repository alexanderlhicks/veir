module

public import Veir.IR.Attribute
public import Veir.Properties

namespace Veir

public section

/--
  Properties of the `felt.const` operation.

  The `value` field stores the constant as an `IntegerAttr` rather than as a
  structured `#felt.const<v>` attribute; this matches VEIR's `arith.constant` /
  `mod_arith.constant` precedent. See `harness/coverage.md` §Attributes for the
  caveat.
-/
structure FeltConstProperties where
  value : IntegerAttr
deriving Inhabited, Repr, Hashable, DecidableEq

def FeltConstProperties.fromAttrDict (attrDict : Std.HashMap ByteArray Attribute) :
    Except String FeltConstProperties := do
  if attrDict.size > 1 then
    throw s!"felt.const: expected only 'value' property, but got {attrDict.size} properties"
  let some attr := attrDict["value".toUTF8]?
    | throw "felt.const: missing 'value' property"
  let .integerAttr intAttr := attr
    | throw s!"felt.const: expected 'value' to be an integer attribute, but got {attr}"
  return { value := intAttr }

end

end Veir
