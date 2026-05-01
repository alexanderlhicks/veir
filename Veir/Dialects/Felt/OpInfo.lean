module

public import Veir.IR.Simp
public import Veir.IR.OpInfo
public import Veir.Properties

namespace Veir

public section

@[expose, properties_of]
def Felt.propertiesOf (op : Felt) : Type :=
match op with
| .const => FeltConstProperties
| _ => Unit

instance : HasDialectOpInfo Felt where
  propertiesOf := Felt.propertiesOf

end

end Veir
