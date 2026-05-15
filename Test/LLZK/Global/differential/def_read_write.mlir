// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// Global ops at module level. Exercises FlatSymbolRefAttr in two
// roles: symbol producer (global.def's sym_name) and symbol user
// (global.read/write's name_ref). No nested symbols (Phase F).

"builtin.module"() ({
^bb0(%v: i32):
  "global.def"() <{sym_name = @counter, constant, type = i32}> : () -> ()
  "global.def"() <{sym_name = @mutable, type = i32}> : () -> ()
  "global.write"(%v) <{name_ref = @mutable}> : (i32) -> ()
  %0 = "global.read"() <{name_ref = @counter}> : () -> i32
}) : () -> ()
