window.BENCHMARK_DATA = {
  "lastUpdate": 1777644102195,
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
      }
    ]
  }
}