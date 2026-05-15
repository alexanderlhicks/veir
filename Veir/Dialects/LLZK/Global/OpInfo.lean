module

public import Veir.IR.Simp
public import Veir.IR.OpInfo
public import Veir.Properties
public import Veir.Dialects.LLZK.Global.Properties

namespace Veir

public section

@[expose, properties_of]
def Global.propertiesOf (op : Global) : Type :=
match op with
| .«def» => GlobalDefProperties
| .read => GlobalRefProperties
| .write => GlobalRefProperties

instance : HasDialectOpInfo Global where
  propertiesOf := Global.propertiesOf

end

end Veir
