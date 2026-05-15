// RUN: veir-opt %s | filecheck %s
//
// bool.cmp with all six FeltCmpPredicate values, encoded via the
// IntegerAttr-as-enum workaround (see harness/porting-notes.md
// 2026-05-15 enum-attr pattern and harness/coverage.md §Attributes).
// Mapping: eq=0, ne=1, lt=2, le=3, gt=4, ge=5.

"builtin.module"() ({
^bb0(%a: !felt.type, %b: !felt.type):
  %eq = "bool.cmp"(%a, %b) <{predicate = 0 : i32}> : (!felt.type, !felt.type) -> i1
  %ne = "bool.cmp"(%a, %b) <{predicate = 1 : i32}> : (!felt.type, !felt.type) -> i1
  %lt = "bool.cmp"(%a, %b) <{predicate = 2 : i32}> : (!felt.type, !felt.type) -> i1
  %le = "bool.cmp"(%a, %b) <{predicate = 3 : i32}> : (!felt.type, !felt.type) -> i1
  %gt = "bool.cmp"(%a, %b) <{predicate = 4 : i32}> : (!felt.type, !felt.type) -> i1
  %ge = "bool.cmp"(%a, %b) <{predicate = 5 : i32}> : (!felt.type, !felt.type) -> i1
}) : () -> ()

// CHECK:       "builtin.module"() ({
// CHECK-NEXT:    ^{{.*}}(%{{.*}}: !felt.type, %{{.*}}: !felt.type):
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 0 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 1 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 2 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 3 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 4 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT:      %{{.*}} = "bool.cmp"(%{{.*}}, %{{.*}}) <{"predicate" = 5 : i32}> : (!felt.type, !felt.type) -> i1
// CHECK-NEXT: }) : () -> ()
