module

public import Veir.IR.Simp
public import Veir.IR.OpInfo
public import Veir.Properties
public import Veir.Dialects.LLZK.String.Properties

namespace Veir

public section

@[expose, properties_of]
def String_.propertiesOf (op : String_) : Type :=
match op with
| .new => StringNewProperties

instance : HasDialectOpInfo String_ where
  propertiesOf := String_.propertiesOf

end

end Veir
