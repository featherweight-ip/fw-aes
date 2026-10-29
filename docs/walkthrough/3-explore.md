# Step 3: architecture exploration at V3 (A1-A5)

**Shows:** architecture specs (src/arch/a0..a5.yaml) drive native
scheduling and binding (zuspec-synth ArchSched) to new V3 views, so
architectures are compared in the system bench before any RTL exists; V5
RTL and ECP5 area for A1-A4 then price each one.

| Arch | Fold | clk/op | ECP5 LUT4 (V5) |
|---|---|---|---|
| A0 | XLS, fully unrolled, 2 pipeline stages | 4 | 106170 (XLS, AES-128+256) |
| A1 | iterated, one round per clock, 16 S-boxes | 11 | 24241 |
| A2 | column, 4 S-boxes | 50 | 6604 |
| A3 | byte, 1 Canright S-box | 200 | 6106 |
| A4 | unrolled x2 (two rounds per clock), 32 Canright S-boxes | 6 | 28643 |
| A5 | iterated, first-order masked S-boxes | 21 (spec) | not built |

A1-A4 areas are AES-128 encrypt only. A5 runs in the system bench as a V3
timing model only.

```bash
dfm run arch-specs                                  # a0..a5.yaml checked
dfm run vectors-run-v3-a1   # -a2 -a3 -a4: "v3 clks per op: 11" (50, 200, 6)
dfm run bench-v3-a1-run     # "view=v3 blocks=8 clks=184" (a2 496, a3 1696, a4 144)
dfm run bench-v3-a5-run     # "clks=264"
dfm run vectors-run-v5-a1   # -a2 -a3 -a4: "v5 encrypt clks per op: 11" (50, 200, 6)
(ulimit -v 30000000; dfm run v5-a2-synth-ecp5)   # stat.json "LUT4": 6604
```

**Results:** {doc}`../design/arch-specs` and {doc}`../design/baseline`,
section "Exploration at V3".
