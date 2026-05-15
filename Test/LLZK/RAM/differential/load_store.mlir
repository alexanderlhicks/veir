// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// RAM load/store at module level. Note: LLZK's MemRead/MemWrite memory
// effects are not encoded in VEIR (harness/coverage.md §Traits) — diff
// should still match because effects don't appear in the printed text.

"builtin.module"() ({
^bb0(%addr: index, %val: !felt.type):
  "ram.store"(%addr, %val) : (index, !felt.type) -> ()
  %0 = "ram.load"(%addr) : (index) -> !felt.type
}) : () -> ()
