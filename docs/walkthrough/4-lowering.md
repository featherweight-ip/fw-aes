# Step 4: our lowering V3 -> V4 -> V5

**Shows:** the flow's own lowering of A0 (dv-flow-libsynth) from V3 through a
register-transfer V4 to V5 RTL, with an equivalence link at each step and a
result within 5 % LUT4 of XLS codegen.

```bash
dfm run -f a0-rtl                     # the XLS schedule IR the lowering starts from
dfm run vectors-run-ll                # 3 x PASS, "rtl clks per op: 4"
dfm run link-v3-v4                    # link_v3_v4.json: "verdict": "equivalent"
dfm run link-v4-v5                    # link_v4_v5.json: "verdict": "equivalent"
dfm run a0-ll-synth-ecp5              # ~3 min: "LUT4": 111073, "TRELLIS_FF": 999
```

**Results:** {doc}`../design/baseline`, section "Our lowering V3 -> V4 -> V5
vs XLS codegen".
