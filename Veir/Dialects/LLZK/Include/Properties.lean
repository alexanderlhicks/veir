module

public import Veir.IR.Attribute
public import Veir.Properties

namespace Veir

public section

/--
  Properties of the `include.from` operation.

  - `sym_name`: the local alias the included module is bound to (e.g. `@aliasName`).
  - `path`: the file path to include (e.g. `"lib.llzk"`).

  Caveat: the `Symbol` trait on `include.from` is not encoded in VEIR; we
  store the name as a `FlatSymbolRefAttr` for textual round-trip only.
  No symbol-table lookup; no uniqueness invariant.
-/
structure IncludeFromProperties where
  sym_name : FlatSymbolRefAttr
  path : StringAttr
deriving Inhabited, Repr, Hashable, DecidableEq

def IncludeFromProperties.fromAttrDict (attrDict : Std.HashMap ByteArray Attribute) :
    Except String IncludeFromProperties := do
  if attrDict.size > 2 then
    throw s!"include.from: expected 'sym_name' and 'path' properties, got {attrDict.size}"
  let some symAttr := attrDict["sym_name".toUTF8]?
    | throw "include.from: missing 'sym_name' property"
  let .flatSymbolRefAttr sym := symAttr
    | throw s!"include.from: expected 'sym_name' to be a flat symbol ref, got {symAttr}"
  let some pathAttr := attrDict["path".toUTF8]?
    | throw "include.from: missing 'path' property"
  let .stringAttr path := pathAttr
    | throw s!"include.from: expected 'path' to be a string attribute, got {pathAttr}"
  return { sym_name := sym, path := path }

end

end Veir
