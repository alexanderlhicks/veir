// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Include declarations at module level. include.from is a Symbol-producing
// op; we exercise the FlatSymbolRefAttr round-trip.

"builtin.module"() ({
^bb0():
  "include.from"() <{sym_name = @lib_a, path = "lib_a.llzk"}> : () -> ()
  "include.from"() <{sym_name = @lib_b, path = "lib_b.llzk"}> : () -> ()
}) : () -> ()
