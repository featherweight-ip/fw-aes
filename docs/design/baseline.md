# A0 baseline numbers

A0 is the XLS RTL of `aes_pkg::encrypt` / `::decrypt` (`a0-rtl` in
src/ref/flow.yaml: `fw.hdl.xls.IR` -> `synth.xls.Codegen`, 2 pipeline stages).
These are the numbers later views (V3..V5, A1-A4) are compared against.

## ECP5 synthesis (`dfm run a0-synth-ecp5`)

Yosys `synth_lattice` (target `ecp5`, via `synth.yosys.Synth`, sv2v frontend),
on the packages/yosys build.

| module | LUT4 | PFUMX | L6MUX21 | TRELLIS_FF | cells | Yosys time | Yosys peak mem |
|---|---|---|---|---|---|---|---|
| aes_pkg__encrypt | 106170 | 40740 | 18289 | 903 | 166102 | 320 s (5 min wall) | 15.0 GB |
| aes_pkg__decrypt | - | - | - | - | - | killed after ~9 min | > 58 GB (OOM, 60 GB host) |

What this shows:

- The two-stage A0 is a fully unrolled datapath: all 10 rounds, with the
  S-boxes and key schedule as logic. Encrypt alone needs about 106k LUT4. That
  is more than the biggest ECP5 (LFE5U-85F, about 84k LUTs), so **A0 does not fit
  any ECP5** and there is no placed Fmax for it. This is the reason for
  the A1-A4 architectures (iterative rounds, LUT/Canright S-box) in Phase 2.
- 903 FFs = the pipeline registers (2 stages x ~128-bit state + key + valid).
- Decrypt (inverse MixColumns) makes Yosys run out of memory in `opt_expr` (step
  2.34) on a 60 GB host. The task therefore synthesizes encrypt only (`top:
  aes_pkg__encrypt`).

## Fmax (item 6b): none, A0 does not fit

`nextpnr-ecp5 --85k --package CABGA381 --json aes_pkg__encrypt.netlist.json`
(8 s, 1.9 GB) reports `Total LUT4s: 106170/83640 126%` and stops with
`ERROR: Unable to place cell 'block_[23]$tr_io', no BELs remaining ... TRELLIS_IO`.
The bare module's ports need far more pins than the package has, and its
logic is 126% of the LUTs. So the A0 Fmax result is "does not fit
LFE5U-85F". Timing numbers start with A1-A4 (Phase 2), which are much smaller.

## Equivalence (item 6c): `dfm run a0-equiv`

`synth.xls.Equiv` (`check_ir_equivalence_main`) of A0 encrypt: the IR that
`fw.hdl.xls.IR` makes from `aes_pkg::encrypt` (`a0-ir-enc`) vs the optimized
IR that codegen schedules (`a0-rtl-enc`). Verdict: **inconclusive**. The
solver had no answer after 600 s (2.9 GB); with 256 input bits there is no
exhaustive fallback. `gate: false` so the task does not fail. The FIPS-197
vectors pass on the RTL (`vectors-run-rtl`), so A0's evidence is simulation,
not a proof. Yosys equivalence of the 106k-LUT netlist was not tried: the
synth alone takes 15 GB, and the IR-level check already times out.
(Equiv selects packages by top name, so `a0-rtl` (encrypt + decrypt) cannot
be used; `a0-ir-enc`/`a0-rtl-enc` are an encrypt-only IR/Codegen pair.)

## Simulation speed (item 6c): `vectors-run-rtl`

Verilator 5.052, 1 thread: 3 vectors x (encrypt + decrypt) = 6 ops at 4
clks/op, simtime 185 ps, wall 0.001 s, 6 MB (sim_stats.json). The run is too
short to give a rate: start-up dominates. Throughput (blocks/s, kclk/s) needs
a long run and is item 10 (V3 vs V5).

## System bench per view (item 8)

The DMA bench (tests/bench, 8 blocks mem -> fw-aes -> mem through fw-wb-dma),
picked by define on `hdlsim.vlt.SimImage`:

| view | task          | clks | blocks/clk |
|------|---------------|------|------------|
| v0   | bench-run     | 102  | 0.078431   |
| rtl  | bench-rtl-run | 128  | 0.062500   |
| v3   | bench-v3-run  | 128  | 0.062500   |

V3 (stage-TLM stand-in, src/v3) matches the A0 RTL cycle count at the system
level; V0 is zero-time, so its count is only bus/DMA traffic.
