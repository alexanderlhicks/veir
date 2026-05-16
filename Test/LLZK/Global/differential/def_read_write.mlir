// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// **XFAIL until Function dialect ports**: LLZK's global.write requires
// a function.def wrapper with `function.allow_witness`. The narrower
// global.def + global.read subset *would* diff cleanly, but a useful
// test exercises all three ops; we wait for Phase G.1.
//
// Global ops at module level. sym_name is StringAttr (per LLZK ODS);
// name_ref is FlatSymbolRefAttr (the `@`-prefix form).
// Uses !felt.type for the global type — LLZK requires the global's
// type to be an "LLZK type" (not built-in i32 or similar). This means
// our identity.mlir's i32 usage is VEIR-only and won't diff.

"builtin.module"() ({
  "global.def"() <{sym_name = "counter", type = !felt.type}> : () -> ()
  "global.def"() <{sym_name = "mutable", type = !felt.type}> : () -> ()
  %v = "global.read"() <{name_ref = @counter}> : () -> !felt.type
  "global.write"(%v) <{name_ref = @mutable}> : (!felt.type) -> ()
}) : () -> ()
