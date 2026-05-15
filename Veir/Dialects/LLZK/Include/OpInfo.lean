module

public import Veir.IR.Simp
public import Veir.IR.OpInfo
public import Veir.Properties
public import Veir.Dialects.LLZK.Include.Properties

namespace Veir

public section

@[expose, properties_of]
def Include_.propertiesOf (op : Include_) : Type :=
match op with
| .from => IncludeFromProperties

instance : HasDialectOpInfo Include_ where
  propertiesOf := Include_.propertiesOf

end

end Veir
