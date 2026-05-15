// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// String literal ops at module level. No known divergences; if the diff
// fires, the allowlist gap belongs in harness/coverage.md.

"builtin.module"() ({
^bb0():
  %0 = "string.new"() <{value = "hello"}> : () -> !string.type
  %1 = "string.new"() <{value = ""}> : () -> !string.type
}) : () -> ()
