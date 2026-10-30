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

## SystemVerilog

The V0 reference model is the package `aes_pkg` (cipher, inverse cipher and
key expansion as SV functions). `fw_aes_api_pkg` is the operation-level API
every view implements; `fw_aes_wb_pkg` puts it behind the CSRs of the
generated register package `fw_aes_reg_pkg`.

```{eval-rst}
.. autosvpackage:: aes_pkg
   :members:
   :undoc-members:
```

```{eval-rst}
.. autosvpackage:: fw_aes_api_pkg
   :members:
   :undoc-members:
```

```{eval-rst}
.. autosvpackage:: fw_aes_wb_pkg
   :members:
   :undoc-members:
```

```{eval-rst}
.. autosvpackage:: fw_aes_reg_pkg
   :members:
```

`fw_aes_rtl` wraps the XLS-generated `aes_pkg__encrypt` and
`aes_pkg__decrypt` modules; `fw_aes_rtl_pkg` drives it through the same API.

```{eval-rst}
.. autosvmodule:: fw_aes_rtl
```

```{eval-rst}
.. autosvpackage:: fw_aes_rtl_pkg
   :members:
   :undoc-members:
```

The vector test runs the FIPS-197 vectors on whichever view the image selects:

```{eval-rst}
.. autosvmodule:: fw_aes_vectors_tb
```

```{eval-rst}
.. autosvpackage:: fw_aes_vectors_pkg
   :members:
   :undoc-members:
```

### A0: XLS RTL

`rundir/org.fwip.aes.a0-rtl/aes_pkg__encrypt.sv` is 5347 lines of flat,
2-stage pipelined Verilog (`synth.xls.Codegen`, `pipeline_stages: 2`). The
first 150 lines:

```{literalinclude} ../sv/generated/a0/aes_pkg__encrypt.head.sv
:language: systemverilog
```
