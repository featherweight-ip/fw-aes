# Step 5: built-in DMA, contracts and co-synthesis

**Shows:** fw-aes-dma, an AES with its own Wishbone master, whose
fetch -> rounds -> store loop is scheduled serially, overlapped or
pipelined; contracts C1-C4 between the core and its transactor, proved with
SBY; and a co-synthesis pass on A0 that uses them (X6, X2, X1, X3) to take
FF 999 -> 418, LUT4 111073 -> 83329 and 4 -> 3 clocks per op.

```bash
dfm run aes-dma-csr-run      # TEST PASSED
dfm run aes-dma-run          # "aesdma v3 clks=32 mem accesses=61"
dfm run bench-aesdma-run     # "view=aesdma blocks=8 clks=76"      (serial)
dfm run bench-aesdma-ov-run  # "view=aesdma-ov blocks=8 clks=55"   (overlap)
dfm run bench-aesdma-pipe-run  # "view=aesdma-pipe blocks=8 clks=50" (pipe)
dfm run bench-aesdma-pipe-a1-run   # 97 (a2 409, a3 1609, a4 57)
```

Contracts (yosys on PATH, ~20 s):

```bash
python3 -m fw.hdl.cosynth contracts src/cosynth/contracts.yaml rundir/cosynth/proofs \
  src/cosynth/fw_aes_dma_xtor.sv \
  --mutant C3_mut_nogate:C3:GATE_BUSY=0:FAIL --mutant C4_mut_nogate:C4:GATE_BUSY=0:FAIL \
  > logs/cosynth.log 2>&1
# JSON at the end: C1-C4, C4o "PASS"; both mutants "FAIL (expect FAIL)"
```

Co-synthesis pass:

```bash
dfm run -f a0-rtl; dfm run vectors-run-cs   # TEST PASSED, "encrypt clks per op: 3"
(ulimit -v 30000000; dfm run a0-cs-synth-ecp5)   # "TRELLIS_FF": 418, "LUT4": 83329
```

**Results:** {doc}`../design/dma-integrated`, {doc}`../design/contracts`
and {doc}`../design/baseline`, sections "fw-aes-dma vs opaque baseline" and
"Co-synthesis (A0)".
