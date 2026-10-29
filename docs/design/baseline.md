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

## Still to do (outline item 6b, 6c)

- Fmax: nextpnr-ecp5 cannot place a design this size on an ECP5. Options:
  out-of-context timing on a smaller unit (one round), or a bigger part.
- Equivalence verdict (synth.yosys.Equiv / synth.xls.Equiv) and simulation
  speed of `vectors-run-rtl`.
