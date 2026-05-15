module

public import Veir.IR.Simp
public import Veir.IR.OpInfo
public import Veir.Properties
public import Veir.Dialects.LLZK.Bool.Properties

namespace Veir

public section

@[expose, properties_of]
def Bool_.propertiesOf (op : Bool_) : Type :=
match op with
| .assert => BoolAssertProperties
| _ => Unit

instance : HasDialectOpInfo Bool_ where
  propertiesOf := Bool_.propertiesOf

end

end Veir
