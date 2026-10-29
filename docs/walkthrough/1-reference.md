# Step 1: reference views (V0, A0 RTL)

**Shows:** the untimed model V0 meets the FIPS-197 vectors, behind CSR and
Wishbone front-ends; XLS turns the AES DSLX into RTL (A0, 2 pipeline
stages, 4 clocks per op) that meets the same vectors; A0's ECP5 area.

```bash
dfm run vectors-run-v0 > logs/v0.log 2>&1      # sim.log: 3 x PASS, TEST PASSED
dfm run csr-run        > logs/csr.log 2>&1     # TEST PASSED
dfm run wb-run         > logs/wb.log 2>&1      # TEST PASSED
dfm run bench-run      > logs/bench-run.log 2>&1   # system bench on V0, TEST PASSED
dfm run vectors-run-rtl > logs/rtl.log 2>&1    # A0 RTL (needs xlsynth-bin): 3 x PASS
dfm run bench-rtl-run  > logs/bench-rtl.log 2>&1   # TEST PASSED
```

Long runs (yosys on PATH):

```bash
dfm run a0-synth-ecp5 > logs/a0-synth.log 2>&1   # ~5 min, 15 GB
grep -o '"LUT4": [0-9]*' rundir/org.fwip.aes.a0-synth-ecp5/aes_pkg__encrypt.stat.json   # 106170
dfm run a0-equiv > logs/a0-equiv.log 2>&1        # ~10 min; verdict inconclusive (solver timeout)
```

**Results:** {doc}`../design/baseline`, sections "ECP5 synthesis", "Fmax"
(A0 does not fit an LFE5U-85F, so there is none), "Equivalence" and
"Simulation speed".
