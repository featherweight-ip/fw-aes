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

## fw-aes-dma vs opaque baseline (item 14a3): `dfm run bench-aesdma-run`

Same 8 blocks, key and bus timing (7 ns per access on the decoder, 10 ns
clock), v3 view, but no external fw-wb-dma: the host writes SRC/DST/LEN and
CTRL.START once, and fw-aes-dma's own master fetches, encrypts and stores every
block (tests/bench/fw_aes_dma_bench_tb.sv).

| bench                     | task             | clks | blocks/clk |
|---------------------------|------------------|------|------------|
| fw-aes + fw-wb-dma (v3)   | bench-v3-run     | 128  | 0.062500   |
| fw-aes-dma (v3)           | bench-aesdma-run | 76   | 0.105263   |
| fw-aes-dma overlap (v3)   | bench-aesdma-ov-run | 55 | 0.145455   |
| fw-aes-dma pipeline (v3)  | bench-aesdma-pipe-run | 50 | 0.160000 |

1.68x fewer clocks. The gain is all bus/control traffic: the timed region of
fw-aes-dma makes 69 accesses (4 descriptor/START, 64 fetch/store, 1 STATUS),
while the baseline programs two DMA channels per block, polls DONE and writes
CTRL. The AES op (4 clks/block, 32 total) is unchanged and still serial with
fetch and store in the serial loop. Item 14b, a hand-scheduled stand-in for
the co-synthesis step (PLAN Ph4): ctor arg `sched` = 1 in fw_aes_dma
(`run_overlap()`) forks the AES op on block i with the fetch of block i+1,
then stores i; 55 clks (1.38x vs serial, 2.33x vs baseline), same 69
accesses. Bus fetch (4 x 7 ns) and the 4-clk op now hide each other; stores
stay serial. In the unit test (aes-dma-ov-run) the bus-error case makes 65
accesses vs 61 (block 2 prefetched before the failing store of block 1);
COUNT/ERROR/DONE are unchanged. The TL bench charges no
arbitration between host and the fw-aes-dma master (one decoder, sequential).

Item 14c: `sched` = 2 (`run_pipe()`), a 3-stage pipeline: the AES op on
block i runs beside (store i-1; fetch i+1), which stay in sequence on the one
WB master. 50 clks (1.10x vs overlap, 1.52x vs serial, 2.56x vs baseline),
same 69 accesses. The loop is now bus-bound: 8 accesses x 7 ns per block
(5.6 clks) vs the 4-clk op, so a further gain needs a wider or second bus
port, not more scheduling. Unit test (aes-dma-pipe-run): 65 accesses, AES
clks 36 (op on block 2 runs beside the failing store of block 1);
COUNT/ERROR/DONE unchanged.

## Cycle fidelity V3 vs A0 RTL (item 9): `dfm run vectors-run-fid`

tests/unit/fw_aes_fid_tb.sv runs the `rtl` view (A0 XLS RTL) and the `v3`
view on one clock: 16 random keys (AES-128/256 alternating) and blocks, each
encrypted and decrypted on both views. Per op it checks equal results and
equal clocks. Result: TEST PASSED, 32 ops, 128 clks on each view (4 per op).
With the bench (128 clks each, above) this is the sim half of item 9.

Formal half: not done. The formal flows here (`fw.hdl.formal.Prove`, which
lifts SVUnit tests over the `fw.hdl.api.Functions` function API, and
`formal.sby.*`) do not take a clocked class view such as V3, and the A0 RTL
is too large for full proofs (encrypt-only IR equivalence is inconclusive at
600 s, above). Revisit with the generated V3 from request fw-hdl-v3-import.

## Sim speed V3 vs RTL (item 10): `dfm run vectors-run-speed-{rtl,v3}`

`tests/unit/fw_aes_speed_tb.sv`: one view, 400000 random ops (200000
enc+dec pairs, new key each pair, AES-128/256 alternating), 4 clks/op on both
views, 1600000 clks. Walltime from the Verilator report in sim.log (whole run,
testbench included). One run each, 1 thread; noise not measured.

| Verilator                     | view | walltime | blocks/s | kclk/s | vs rtl 5.052 |
|-------------------------------|------|---------:|---------:|-------:|-------------:|
| 5.052 (packages/verilator)    | rtl  | 3.824 s  | 104.6 k  | 418    | 1.0x |
| 5.052                         | v3   | 1.362 s  | 293.7 k  | 1175   | 2.8x |
| efficient-waits (5.053 devel, be33a0f6c..381356b19) | rtl | 3.726 s | 107.4 k | 429 | 1.0x |
| efficient-waits               | v3   | 0.814 s  | 491.4 k  | 1966   | 4.7x |

- There is no V5 view yet (Ph3 lowering); the A0 XLS RTL (`rtl`) stands in
  for V5. The claim "V3 sims faster than RTL" holds: 2.8x on stock 5.052,
  4.7x on the efficient-waits branch. The branch helps the class view (1.67x)
  and not the RTL view (1.03x), as expected: its gain is in timing waits.
- Branch build: the efficient-waits work packet's
  `work/verilator-efficient-waits/bin` put first on PATH, `dfm run -f`; then
  rerun `-f` with stock 5.052 so rundir/ holds stock images.
- Go/no-go: go for a speed claim of V3 over RTL; re-measure against a real V5
  when Ph3 makes one, and with several runs for spread.

## Scaling bench: cost against N and k (item 11, PLAN 6.4.3)

`tests/unit/fw_aes_scale_tb.sv`: N engines on one clock, k active, a fixed
40000 ops (enc+dec pairs) spread over the active ones; idle engines are
configured and wait. Tasks `scale-run-{rtl,v3}-n<N>k<K>` (tests/unit/flow.yaml).
Verilator 5.052, walltime from sim.log; every case TEST PASSED.

| N | k | clks | rtl wall (s) | v3 wall (s) | rtl us/block | v3 us/block |
|---|---|------|------|------|------|------|
| 1  | 1  | 160k | 0.454  | 0.185 | 11.4 | 4.6 |
| 4  | 1  | 160k | 1.428  | 0.180 | 35.7 | 4.5 |
| 16 | 1  | 160k | 8.032  | 0.181 | 201  | 4.5 |
| 64 | 1  | 160k | 33.236 | 0.183 | 831  | 4.6 |
| 16 | 4  | 40k  | 1.930  | 0.137 | 48.3 | 3.4 |
| 16 | 16 | 10k  | 0.522  | 0.124 | 13.1 | 3.1 |

- **rtl (stand-in for V5) cost grows with N** (~linear: 64 engines, 73x the
  N=1 time at the same clocks): every engine is evaluated every clock, busy or not.
- **v3 cost is flat in N** (0.18 s from N=1 to N=64): an idle v3 engine has no
  process, so it costs nothing. With more active engines it gets cheaper per block
  (fewer clocks total), so v3 cost follows activity, not size.
- Not done: memory per case; mixes (active engine at rtl, idle at v3); the full
  §7.3 system (wb ic + DMA) with N engines. The unit-level bench already shows P9.

## Exploration at V3 (item 12c): "the bus picks the architecture"

A1-A4 are V3 views scheduled by `zuspec.synth.ArchSched` (zuspec-synth branch
wpk/arch-sched, item 12d) from the `src/arch/a*.yaml` specs and A0's XLS IR,
specialized to AES-128; tasks `v3-a<N>-view` in src/v3/flow.yaml. Encrypt and
decrypt have the same latency for the `key_expansion` chosen. A0 uses XLS's own
2-stage schedule (fw.hdl.xls.StageTLM). A5 is still a stand-in (`fw_aes_v3`
ctor `clks_per_op`, define `FW_AES_V3_CLKS=21`): the scheduler does not model
masking. `a6` (define `FW_AES_V3_CLKS=6`) was the stand-in for A4 and gives the
same 57 as the scheduled A4. Clocks are for 8 blocks; each V3 sim runs in well
under 1 s wall.

| Arch | fold | S-boxes | key_expansion | II | latency | bench-v3 (ext. DMA, serial) | aesdma-pipe |
|------|------|---------|---------------|----|---------|-----------------------------|-------------|
| A0 | unrolled | 200 LUT | inline (XLS) | 1 (4 clk/op in V3) | 4 | 128 | 50 |
| A1 | iterated | 16 LUT | precomputed | 11 | 11 | 184 | 97 |
| A2 | column | 4 LUT | shared | 50 | 50 | 496 | 409 |
| A3 | byte | 1 Canright | shared | 200 | 200 (161 precomputed) | 1696 | 1609 |
| A4 | unrolled x2 | 32 Canright | precomputed | 6 | 6 | 144 | 57 |
| A5 | iterated, masked d=1 | 16 Canright-DOM | (stand-in) | 21 | 21 | 264 | - |

With `key_expansion: shared` A1 would be 14 enc / 20 dec and A4 8 / 10; A2
precomputed would be 41. Per-arch schedule (latency, II, ResMII, S-box binding):
rundir/org.fwip.aes.v3-a<N>-sched/{schedule.json,aes_pkg__*.A<N>.sched.txt}.

Tasks: `bench-v3-run`, `bench-v3-a{1,2,3,4,5}-run`, `bench-aesdma-pipe-run`,
`bench-aesdma-pipe-a{1,2,3,4,6}-run` (tests/bench/flow.yaml).

Reading: with the external DMA the bus and the op add (128 = 8 x 16), so any
arch costs its op time on top of the bus. In fw-aes-dma pipe mode the op
overlaps store+fetch: A0 is bus-bound at ~6.25 clk/block (50/8). An op of
6 clk (A4-class, 32 Canright S-boxes vs A0's 200) costs only 57 (+14%);
A1 at 11 clk/op is op-bound (97 ~ 8 x 11 + fill), and so are A2 (409) and
A3 (1609). So with the integrated DMA
the bus cycle per block, not the datapath, sets the useful II: architectures
with II <= ~6 give about the same throughput, and the smallest of them wins.
