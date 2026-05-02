window.BENCHMARK_DATA = {
  "lastUpdate": 1777751321606,
  "repoUrl": "https://github.com/alexanderlhicks/veir",
  "entries": {
    "VeIR Benchmarks": [
      {
        "commit": {
          "author": {
            "email": "48860705+luisacicolini@users.noreply.github.com",
            "name": "Luisa Cicolini",
            "username": "luisacicolini"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "08825380b5c8626638be684b7bf04cb1d4d0eecc",
          "message": "fix: generalized refinement for any width `w`  (#485)\n\nWe generalize the definition of the refinement relation for every width,\nand add support for the notation `⊑`.\n\nThis PR was originally part of #457, from where I am pulling out what is\nseparately upstreamable.",
          "timestamp": "2026-05-01T07:35:19Z",
          "tree_id": "d7c09bb8d79f93f02134a28ba98f4021d6f26dad",
          "url": "https://github.com/alexanderlhicks/veir/commit/08825380b5c8626638be684b7bf04cb1d4d0eecc"
        },
        "date": 1777644101564,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "add-fold-worklist/create",
            "value": 2266000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002266s"
          },
          {
            "name": "add-fold-worklist/rewrite",
            "value": 3741000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003741s"
          },
          {
            "name": "add-fold-worklist-local/create",
            "value": 2376000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002376s"
          },
          {
            "name": "add-fold-worklist-local/rewrite",
            "value": 3129000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003129s"
          },
          {
            "name": "add-zero-worklist/create",
            "value": 2309000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002309s"
          },
          {
            "name": "add-zero-worklist/rewrite",
            "value": 2388000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.002388s"
          },
          {
            "name": "add-zero-reuse-worklist/create",
            "value": 1963000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001963s"
          },
          {
            "name": "add-zero-reuse-worklist/rewrite",
            "value": 1958000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001958s"
          },
          {
            "name": "mul-two-worklist/create",
            "value": 2331000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002331s"
          },
          {
            "name": "mul-two-worklist/rewrite",
            "value": 5237000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.005237s"
          },
          {
            "name": "add-fold-forwards/create",
            "value": 2229000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002229s"
          },
          {
            "name": "add-fold-forwards/rewrite",
            "value": 3008000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003008s"
          },
          {
            "name": "add-zero-forwards/create",
            "value": 2333000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002333s"
          },
          {
            "name": "add-zero-forwards/rewrite",
            "value": 1993000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001993s"
          },
          {
            "name": "add-zero-reuse-forwards/create",
            "value": 2033000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002033s"
          },
          {
            "name": "add-zero-reuse-forwards/rewrite",
            "value": 1585000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001585s"
          },
          {
            "name": "mul-two-forwards/create",
            "value": 2305000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.002305s"
          },
          {
            "name": "mul-two-forwards/rewrite",
            "value": 3654000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003654s"
          },
          {
            "name": "add-zero-reuse-first/create",
            "value": 1927000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001927s"
          },
          {
            "name": "add-zero-reuse-first/rewrite",
            "value": 8000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.000008s"
          },
          {
            "name": "add-zero-lots-of-reuse-first/create",
            "value": 1827000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001827s"
          },
          {
            "name": "add-zero-lots-of-reuse-first/rewrite",
            "value": 771000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.000771s"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "mathieu.fehr@gmail.com",
            "name": "Mathieu Fehr",
            "username": "math-fehr"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "65b768d91cf519030f31b1df8b463fcf1934ee4e",
          "message": "Add `OperationPtr.getResultTypes` (#487)\n\nThis helper is useful in the interpreter, and makes it easier to write\nget-set lemmas for high-level rewriting operations.",
          "timestamp": "2026-05-02T05:54:32Z",
          "tree_id": "27d826907c35cae9f3e2c3f26f437edbb87c2297",
          "url": "https://github.com/alexanderlhicks/veir/commit/65b768d91cf519030f31b1df8b463fcf1934ee4e"
        },
        "date": 1777751311758,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "add-fold-worklist/create",
            "value": 1844000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001844s"
          },
          {
            "name": "add-fold-worklist/rewrite",
            "value": 3424000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003424s"
          },
          {
            "name": "add-fold-worklist-local/create",
            "value": 1867000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001867s"
          },
          {
            "name": "add-fold-worklist-local/rewrite",
            "value": 2886000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.002886s"
          },
          {
            "name": "add-zero-worklist/create",
            "value": 1832000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001832s"
          },
          {
            "name": "add-zero-worklist/rewrite",
            "value": 2168000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.002168s"
          },
          {
            "name": "add-zero-reuse-worklist/create",
            "value": 1552000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001552s"
          },
          {
            "name": "add-zero-reuse-worklist/rewrite",
            "value": 1806000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001806s"
          },
          {
            "name": "mul-two-worklist/create",
            "value": 1835000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001835s"
          },
          {
            "name": "mul-two-worklist/rewrite",
            "value": 4820000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.004820s"
          },
          {
            "name": "add-fold-forwards/create",
            "value": 1846000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001846s"
          },
          {
            "name": "add-fold-forwards/rewrite",
            "value": 2695000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.002695s"
          },
          {
            "name": "add-zero-forwards/create",
            "value": 1839000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001839s"
          },
          {
            "name": "add-zero-forwards/rewrite",
            "value": 1747000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001747s"
          },
          {
            "name": "add-zero-reuse-forwards/create",
            "value": 1596000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001596s"
          },
          {
            "name": "add-zero-reuse-forwards/rewrite",
            "value": 1384000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.001384s"
          },
          {
            "name": "mul-two-forwards/create",
            "value": 1863000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001863s"
          },
          {
            "name": "mul-two-forwards/rewrite",
            "value": 3272000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.003272s"
          },
          {
            "name": "add-zero-reuse-first/create",
            "value": 1550000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001550s"
          },
          {
            "name": "add-zero-reuse-first/rewrite",
            "value": 9000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.000009s"
          },
          {
            "name": "add-zero-lots-of-reuse-first/create",
            "value": 1561000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_create=0.001561s"
          },
          {
            "name": "add-zero-lots-of-reuse-first/rewrite",
            "value": 753000,
            "unit": "ns",
            "extra": "count=1000 pc=100 iterations=5 median_rewrite=0.000753s"
          }
        ]
      }
    ]
  }
}