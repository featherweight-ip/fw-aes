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

## SystemVerilog

Files from `rundir/org.fwip.aes.a0-ll/` (written by `synth.xls.Lower`) and
`rundir/org.fwip.aes.link-v3-v4/`. The V3 side is A0's `aes_stage_tlm_pkg`,
shown in {doc}`2-v3`.

### V4: register-transfer class

`aes_pkg__encrypt_v4` holds every pipeline register XLS scheduled, by name,
as a current and a next value. Each `stage<s>()` computes the next values of
stage `s+1` from stage `s`'s registers; `tick()` runs the stages and commits,
one call per clock; `op()` times an operation the way the RTL transactor
does. Class head, the stage methods and `op` (full file 206 lines):

```{literalinclude} ../sv/generated/ll/aes_pkg__encrypt.v4.sv
:language: systemverilog
:lines: 1-14,96-106,189-206
```

The stage logic is one function per stage in
`aes_pkg__encrypt_v4_stages_pkg` (6412 lines; header and the start of
`stage0_f`):

```{literalinclude} ../sv/generated/ll/aes_pkg__encrypt.v4_stages.head.sv
:language: systemverilog
:lines: 1-5,51-55
```

### V5: RTL with the same registers

The V5 file has one module per stage, with the same register names as V4
ports, and a top with XLS `codegen_main`'s ports and latency, so it drops in
for the A0 RTL. Header and the first stage's ports (6667 lines in all):

```{literalinclude} ../sv/generated/ll/aes_pkg__encrypt.v5.head.sv
:language: systemverilog
:lines: 1-40
```

### Link test V3 -> V4

`link-v3-v4` generates this bench: 500 random keys and blocks go to the V3 stage
TLM and the V4 class side by side; results and clocks per op must match. The
whole generated file:

```{literalinclude} ../sv/generated/ll/link_v3_v4_tb.sv
:language: systemverilog
```

V4 -> V5 is checked formally instead (`link-v4-v5`: per-stage combinational
equivalence, Yosys miter + SAT).
