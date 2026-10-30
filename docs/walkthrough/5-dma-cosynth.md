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

## SystemVerilog

### fw-aes-dma

`fw_aes_dma_pkg` (`src/dma/fw_aes_dma.sv`) is the transaction-level
fw-aes-dma: the AES with its own Wishbone master, descriptor registers
SRC/DST/LEN and the fetch -> rounds -> store loop, scheduled serially,
overlapped or pipelined (the `sched` argument of `new`).

```{eval-rst}
.. autosvpackage:: fw_aes_dma_pkg
   :members:
   :undoc-members:
```

### The transactor the contracts are about

`fw_aes_dma_xtor` (`src/cosynth/fw_aes_dma_xtor.sv`) is the RTL between the
CSR/Wishbone side and the AES core; contracts C1-C4 are properties of it.

```{eval-rst}
.. autosvmodule:: fw_aes_dma_xtor
```

### A contract checker: C3

C3 ("CSR key", `src/cosynth/contracts.yaml`) says the key at the core does
not change while BUSY, equals the key at op start for the whole op, and MODE
is fixed after the first START; X2, X5 and X6 rely on it. The contracts tool
generates one checker per contract from the clauses' `check:` expressions;
its ports are the transactor's signals, and SBY proves the asserts:

```{literalinclude} ../sv/generated/cosynth/chk_C3.sv
:language: systemverilog
```

### Co-synthesis output

The top module that the co-synthesis pass writes for A0 with X6 (AES-128
only), X2, X1 and X3: input flops folded away (stage 0 runs in the
`input_valid` cycle, 3 clocks per op) and data registers without reset. The
stage modules are left out:

```{literalinclude} ../sv/generated/cosynth/aes_pkg__encrypt.cosynth.top.sv
:language: systemverilog
```

### Test

`vectors-run-cs` runs the FIPS-197 AES-128 vector on the `rtl` view with the
co-synthesized encrypt:

```{eval-rst}
.. autosvmodule:: fw_aes_vectors_cs_tb
```
