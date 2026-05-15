module

namespace Veir.Data.Felt

public section

/--
  A field-element value, provisionally modeled as `Int` (no modular reduction).

  Real LLZK semantics would treat a felt as an element of a specific finite
  field `ZMod p` — but the modulus is left unspecified at the dialect level
  (`!felt.type` versus `!felt.type<"bn254">`), and VEIR has no machinery to
  thread the modulus through proofs today. Modeling as `Int` is sound for
  identities that hold under reduction by *any* modulus (e.g. `x + 0 = x`):
  the constant `0` reduces to `0` in every `ZMod p`, so the rewrite that
  depends on the identity is sound regardless of which field the IR will
  eventually be specialized to.

  This is the provisional model for Phase E.1. Upgrade to a proper field
  model when a pass depends on field-specific semantics.
-/
abbrev Felt := Int

/-- The constant `n` as a felt. Mirrors `Veir.Data.RISCV.li`. -/
def const (n : Int) : Felt := n

/-- Field addition (provisional: `Int.add`). Mirrors `Veir.Data.RISCV.add`. -/
def add (a b : Felt) : Felt := a + b

end

end Veir.Data.Felt
