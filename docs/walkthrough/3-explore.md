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

## SystemVerilog

### V3: one stage-TLM package per architecture

`zuspec.synth.ArchSched` writes, for each architecture, a package with the
same name and API as the A0 one in {doc}`2-v3` (`aes_stage_tlm_pkg`, classes
`encrypt_stage_tlm` and `decrypt_stage_tlm`), so `fw_aes_v3` and every test
take any of them unchanged. Only the latency and the schedule comment
differ. Because all four use one package name they are shown as source, not
through autodoc. Files from `rundir/org.fwip.aes.v3-aN-sched/`.

**A1** (iterated, 16 LUT S-boxes): one round per step, 11 clocks; each step
binds its 16 S-box lookups to `sbox[0..15]`. The whole file:

```{literalinclude} ../sv/generated/a1/aes_stage_tlm_pkg.sv
:language: systemverilog
```

**A2** (column, 4 S-boxes): four steps per round plus key-expansion steps
on the same S-boxes, 50 clocks. Header and the encrypt class (the per-step
list runs to 50 lines; full file 168 lines):

```{literalinclude} ../sv/generated/a2/aes_stage_tlm_pkg.sv
:language: systemverilog
:lines: 1-15,62-86
```

**A3** (byte, 1 Canright S-box): one S-box lookup per step, 200 clocks.
Header and the encrypt class (full file 468 lines):

```{literalinclude} ../sv/generated/a3/aes_stage_tlm_pkg.sv
:language: systemverilog
:lines: 1-15,212-236
```

**A4** (unrolled x2, 32 Canright S-boxes): two rounds per step, 6 clocks.
The whole file:

```{literalinclude} ../sv/generated/a4/aes_stage_tlm_pkg.sv
:language: systemverilog
```

### V5: RTL from the same schedule

`zuspec.synth.ArchLower` turns each schedule into Verilog for
`aes_pkg__encrypt` (AES-128 encrypt): steps with the same logic share one
"step class", values live in a register file sized by the binder. The file
header lists the step classes; the rest is the S-box module, the class
datapaths and the step FSM (2278-2471 lines; in `rundir/org.fwip.aes.v5-aN/`).

```{literalinclude} ../sv/generated/a1/aes_pkg__encrypt.A1.v5.head.sv
:language: systemverilog
:caption: A1 V5 header
:end-before: "module aes_pkg__encrypt__sbox"
```

```{literalinclude} ../sv/generated/a2/aes_pkg__encrypt.A2.v5.head.sv
:language: systemverilog
:caption: A2 V5 header
:end-before: "module aes_pkg__encrypt__sbox"
```

```{literalinclude} ../sv/generated/a3/aes_pkg__encrypt.A3.v5.head.sv
:language: systemverilog
:caption: A3 V5 header
:end-before: "module aes_pkg__encrypt__sbox"
```

```{literalinclude} ../sv/generated/a4/aes_pkg__encrypt.A4.v5.head.sv
:language: systemverilog
:caption: A4 V5 header
:end-before: "module aes_pkg__encrypt__sbox"
```

### Tests

The V3 runs (`vectors-run-v3-aN`) use `fw_aes_vectors_v3_tb` from
{doc}`2-v3`. The V5 runs put the V5 encrypt behind the `rtl` view and count
encrypt clocks separately:

```{eval-rst}
.. autosvmodule:: fw_aes_vectors_v5_tb
```
