module

public import Veir.IR.Attribute
public import Veir.Properties

namespace Veir

public section

/--
  Properties of the `bool.assert` operation.

  `msg` is optional — a human-readable string emitted if the assertion fires.
  The LLZK custom assembly form is `bool.assert %cond` (no msg) or
  `bool.assert %cond, "message"`. In VEIR generic form: `<{msg = "message"}>`
  when present, absent otherwise.
-/
structure BoolAssertProperties where
  msg : Option StringAttr
deriving Inhabited, Repr, Hashable, DecidableEq

def BoolAssertProperties.fromAttrDict (attrDict : Std.HashMap ByteArray Attribute) :
    Except String BoolAssertProperties := do
  if attrDict.size > 1 then
    throw s!"bool.assert: expected at most 'msg' property, got {attrDict.size}"
  let msg ← match attrDict["msg".toUTF8]? with
    | some (.stringAttr m) => .ok (some m)
    | some attr => .error s!"bool.assert: expected 'msg' to be a string attribute, got {attr}"
    | none => .ok none
  -- Catch the case `size = 1` with an unrecognized key (which would otherwise
  -- silently coerce to `{ msg := none }`).
  if attrDict.size = 1 ∧ msg.isNone then
    throw "bool.assert: only 'msg' is a recognized property"
  return { msg := msg }

end

end Veir
