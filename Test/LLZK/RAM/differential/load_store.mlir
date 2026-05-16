// XFAIL: llzk-opt
// REQUIRES: llzk-opt
// RUN: %scripts/llzk-diff.sh %s
//
// RAM load/store at module level. We get felt + index values via the
// arith→cast chain since LLZK rejects builtin.module block args and we
// can't use felt.const (its IntegerAttr workaround diverges from
// LLZK's #felt.const<v> — see harness/coverage.md §Attributes).

"builtin.module"() ({
  %b = "arith.constant"() <{value = 1 : i1}> : () -> i1
  %val = "cast.tofelt"(%b) : (i1) -> !felt.type
  %addr = "cast.toindex"(%val) : (!felt.type) -> index
  "ram.store"(%addr, %val) : (index, !felt.type) -> ()
  %0 = "ram.load"(%addr) : (index) -> !felt.type
}) : () -> ()
