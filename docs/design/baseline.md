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

## Best-case standalone: HW-handshake streaming (B2-3b)

`bench-v3-run` charges standalone for per-block CSR work (two channels
programmed and polled per block). Define `FW_AES_BENCH_STREAM` on the same
bench (tests/bench/fw_aes_bench_tb.sv) gives it its best case with the stock
fw-wb-dma model and fw-aes unchanged: ch0 (mem -> DIN) and ch1 (DOUT -> mem)
are programmed once in HW-handshake mode (CSR.MODE, CHK_SZ=4, TOT_SZ=32), and
bench glue (`hs_glue`, standing in for dma_req/dma_ack pins on fw-aes) paces
them: ch0 fetches block i+1 as soon as START i has latched DIN (overlapping op
i), START i+1 waits for ch1 to drain DOUT i (one DOUT buffer), START is a bus
write to CTRL. The decoder folds two stream apertures (AES+0x1000, +0x2000)
onto DIN0-3/DOUT0-3, since the model has no address masks. The host waits
only for ch1 DONE.

| arch (clk/op) | per-block CSR (`bench-v3[-aN]-run`) | stream (`bench-v3-stream[-aN]-run`) | fw-aes-dma pipe |
|---------------|------|------|------|
| A0 (4)        | 128  | 100  | 50   |
| A1 (11)       | 184  | 142  | 97   |
| A4 (6)        | 144  | 102  | 57   |

Streaming removes 28-42 clks of CSR overhead (1.28-1.41x); integrated pipe is
still 2.0x (A0), 1.46x (A1), 1.79x (A4) faster. The remaining gap is
structural, not CSR: the external DMA moves every word as a read plus a write
on the one engine (16 accesses x 7 ns = 11.2 clks per block, so A0 and A4
are DMA-bound and differ by only 2 clks), where fw-aes-dma does 8 accesses per
block straight into the datapath; and the single DOUT buffer keeps op i+1
from starting before DOUT i is stored. A1 is op-bound in both. Same TL bus
caveats as above (no arbitration between DMA, glue and host).

## Sweep: bus speed x blocks x arch (B2-4b): `python3 tests/bench/sweep.py`

Standalone-stream (`bench-v3-stream[-aN]`) and integrated pipe
(`bench-aesdma-pipe[-aN]`) at FW_AES_BUS_PS {3500, 7000, 14000} (ps per bus
access; clk 10 ns) x FW_AES_NB {1, 8, 64} x A0/A1/A4: 54 points, all TEST
PASSED. Each point rebuilds the image via `dfm run -P` (about 8 s per point,
7 min total). Full rows: docs/design/sweep-b2-4b.csv (clks, blocks/clk,
first); script also writes logs/sweep.{csv,md}.

Steady state, clks per block at NB=64 (stream / pipe, ratio), and first-block
latency at NB=8 (clks until block 0 is in DST):

| arch (clk/op) | bus ns | stream clk/blk | pipe clk/blk | stream/pipe | first stream | first pipe |
|---|---|---|---|---|---|---|
| A0 (4)  | 3.5 | 7.0  | 4.1  | 1.73 | 9  | 8  |
| A0 (4)  | 7   | 12.0 | 5.7  | 2.11 | 17 | 12 |
| A0 (4)  | 14  | 23.9 | 11.3 | 2.11 | 35 | 22 |
| A1 (11) | 3.5 | 14.0 | 11.1 | 1.27 | 16 | 15 |
| A1 (11) | 7   | 17.1 | 11.1 | 1.54 | 22 | 19 |
| A1 (11) | 14  | 24.0 | 11.5 | 2.09 | 35 | 27 |
| A4 (6)  | 3.5 | 9.0  | 6.1  | 1.49 | 11 | 10 |
| A4 (6)  | 7   | 12.1 | 6.1  | 1.97 | 17 | 14 |
| A4 (6)  | 14  | 23.9 | 11.3 | 2.12 | 35 | 22 |

- Bus-bound limit: stream moves 16 accesses per block on the one DMA engine,
  pipe 8. At 14 ns every arch hits it (stream ~16 x 1.4 = 22.4 + ~1.5,
  pipe 8 x 1.4 = 11.2) and the ratio is the access count, ~2.1x; arch does
  not matter in either config.
- Op-bound limit: pipe runs at the op II whenever the bus allows (A0 4.1 at
  3.5 ns, A4 6.1 and A1 11.1 at 3.5 and 7 ns). Stream never reaches the II:
  with one DOUT buffer it adds the DOUT drain to each op (A1 14.0 = 11 + 3 at
  3.5 ns, 17.1 = 11 + 6 at 7 ns).
- Arch choice depends on config: at 7 ns stream cannot tell A0 from A4 (12.0
  vs 12.1, both bus-bound), so the cheaper A4 is the right pick; pipe at
  3.5 ns gives A0 1.49x over A4 (4.1 vs 6.1), and stream at 3.5 ns 1.29x
  (7.0 vs 9.0). Only the integrated view exposes the op II to the system.
- Gap is smallest where both are op-bound and the bus is fast (A1 at 3.5 ns,
  1.27x) and largest where both are bus-bound (2.1x).
- First-block latency: pipe is 1-13 clks earlier. In stream, from NB=8 on,
  block 0's store competes with block 1's fetch on the one engine (14 ns:
  27 clks at NB=1, 35 at NB=8); pipe's first barely moves with NB.
- NB=8 vs 64: clk/blk at NB=8 is within 6% of NB=64 for stream, up to 16%
  above it for pipe (pipeline fill and drain is a larger share of its shorter
  runs), so the 8-block numbers above slightly understate the pipe's lead.
- Bus width is not swept (32-bit TL bus only); same TL caveats as above.

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

| Arch | fold | S-boxes | key_expansion | II | latency | bench-v3 (ext. DMA, serial) | aesdma-pipe | ECP5 LUT4 / FF (V5 enc) |
|------|------|---------|---------------|----|---------|-----------------------------|-------------|-------------------------|
| A0 | unrolled | 200 LUT | inline (XLS) | 1 (4 clk/op in V3) | 4 | 128 | 50 | 106170 / 903 (XLS, AES-128+256) |
| A1 | iterated | 16 LUT | precomputed | 11 | 11 | 184 | 97 | 24241 / 421 (~6.5k LUT4 excl. keyexp) |
| A2 | column | 4 LUT | shared | 50 | 50 | 496 | 409 | 6604 / 705 |
| A3 | byte | 1 Canright | shared | 200 | 200 (161 precomputed) | 1696 | 1609 | 6106 / 763 |
| A4 | unrolled x2 | 32 Canright | precomputed | 6 | 6 | 144 | 57 | 28643 / 420 (~10.9k LUT4 excl. keyexp) |
| A5 | iterated, masked d=1 | 16 Canright-DOM | (stand-in) | 21 | 21 | 264 | - | - |

With `key_expansion: shared` A1 would be 14 enc / 20 dec and A4 8 / 10; A2
precomputed would be 41. Per-arch schedule (latency, II, ResMII, S-box binding):
rundir/org.fwip.aes.v3-a<N>-sched/{schedule.json,aes_pkg__*.A<N>.sched.txt}.

Area column (item 13c): `synth.yosys.Synth` ecp5 (`dfm run v5-a<N>-synth-ecp5`,
rundir/org.fwip.aes.v5-a<N>-synth-ecp5/stat.json) of the encrypt V5 from
`zuspec.synth.ArchLower` (zuspec-synth wpk/arch-sched 0003468): a folded
datapath built from the ArchSched schedule (step FSM, `sbox_count` S-box
instances, rerolled step logic, left-edge registers). `vectors-run-v5-a<N>`
pass FIPS-197 C.1 + App. B at 11/50/200/6 clk/op, the same as V3. Caveats:
- AES-128 only (A0 includes AES-256 and key_width muxing): not like-for-like.
- A1/A4 include about 17.8k LUT4 of combinational key expansion (40 S-boxes),
  not a sequential set_key expander; "excl. keyexp" is a plain subtraction of a
  separate keyexp synth.
- `canright` is not modelled: A3/A4 use the same LUT S-box ROM as A1/A2.
- No V4 class and no V3<->V4 / V4<->V5 link checks for A1-A4 (a Python cycle model
  stands in, checked against the XLS IR in zuspec-synth tests); encrypt only.
- No nextpnr timing.

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

## Our lowering V3 -> V4 -> V5 vs XLS codegen (item 13b)

`a0-ll` (src/ll/flow.yaml, `synth.xls.Lower`, dv-flow-libsynth wpk/lower 1a4dcdf)
reads the A0 encrypt schedule and scheduled IR that `a0-rtl` writes, and emits our
own V4 (class `aes_pkg__encrypt_v4`, named stage registers, `tick()`/`op()`) and V5
(SV: top + one combinational module per stage). Decrypt stays XLS Verilog.
Same structure as XLS: 2 stages (1612 + 1533 nodes), 29 boundary registers
(386 bits, XLS's `p0_*`), 386 input + 128 output flop bits, latency 3.

| check | task | result |
|---|---|---|
| FIPS-197 vectors on our V5 | `vectors-run-ll` | TEST PASSED, 4 clks/op (= XLS `vectors-run-rtl`) |
| V3 <-> V4 | `link-v3-v4` | equivalent: 500 random ops, 0 mismatches, 4 clks/op both (simulation) |
| V4 <-> V5 | `link-v4-v5` | equivalent: per-stage Yosys miter + SAT, ~13 s/stage, 5 GB |

| encrypt, ECP5 `synth_lattice` | LUT4 | PFUMX | L6MUX21 | TRELLIS_FF | Yosys time | peak mem |
|---|---|---|---|---|---|---|
| XLS codegen (`a0-synth-ecp5`) | 106170 | 40740 | 18289 | 903 | 320 s | 15.0 GB |
| ours (`a0-ll-synth-ecp5`) | 111073 (+4.6 %) | 43925 | 20940 | 999 | 162 s | 6.6 GB |

Reading:
- Our V5 is cycle-equal to XLS and passes the vectors; its QoR is within 5 % LUT4.
  Both are far over an LFE5U-85F (84k LUT4), as in item 6b.
- 96 extra FFs (999 vs 903 = 386 + 386 + 128 + 3 valid) and +4.9k LUT4 are not
  analyzed. Candidates: XLS block-level codegen passes we skip, and our S-box as
  `L[idx*8 +: 8]` on a 2048-bit constant vs XLS's unpacked array. Yosys's SV
  reader rejects our V5, so synthesis goes through sv2v (also a candidate).
- The V4 <-> V5 proof shares per-node expression strings between V4 and V5, so it
  checks registers, stage split and port packing, not each op's lowering; op
  semantics are covered by V3 <-> V4 (random sim) and the vectors.

## Co-synthesis (A0) (item 14d3): `dfm run a0-cs`, `vectors-run-cs`

`a0-cs` (src/cosynth/flow.yaml, fw-hdl wpk/cosynth 756c438, `fw.hdl.cosynth pass`)
rewrites the top of our A0 V5 (`a0-ll`) using the contract records in
src/cosynth/contracts.yaml (C1-C4, item 14d3a). It applies an X only if every
clause id it cites is in the records. Stage modules are copied verbatim (checked
byte-identical); only the top is regenerated. Applied: X6 (AES-128 only: key
width and key[255:128] tied 0), X2 (key flops removed, stage 0 reads the CSR
key), X1 (block input flops removed, `v0` folded into `input_valid`), X3 (p1
load enables and data resets removed). X5 (sharing) is N/A for A0: it is fully
unrolled and has nothing to share (needs A2/A3).

| encrypt, ECP5 `synth_lattice` | TRELLIS_FF | LUT4 | clk/op (sim) |
|---|---|---|---|
| ours, pre (`a0-ll-synth-ecp5`, item 13b) | 999 | 111073 | 4 (`vectors-run-ll`) |
| co-synthesized (`a0-cs-synth-ecp5`) | 418 (-58 %) | 83329 (-25 %) | 3 (`vectors-run-cs`) |

Equivalence pre == post: `python3 -m fw.hdl.cosynth equiv <a0-ll v5.sv>
<a0-cs cosynth.sv> <cosynth_pass.json> <outdir>` (CLI, no dfm task; ~4 min).
SBY `abc pdr` PASS at stage-output offsets 0/128/256/258. The X6 lemma
`S(key,0,blk) == S({0,key[127:0]},0,blk)` over S = stage1 o stage0 is PASS (ABC
iprove). Mutants FAIL as expected: a wrong latency shift, and zeroing the low key half.

Caveats:
- Only end points are quoted. LUT4 counts for the intermediate X steps vary by
  ±25k between runs (ABC on a 100k-LUT flat netlist is not monotone).
- The sequential proof abstracts the stages (stage 0 = injective normalize
  justified by the X6 lemma, stage 1 = projections). There is no BMC over the real AES stages.
- X6 assumes MODE=0 (AES-128) as a host premise. C3.mode_fixed proves only that
  MODE is stable. The AES-256 vector is out of contract and is not run on post.
- `vectors-run-cs` runs one vector (FIPS-197 C.1). The intermediate variants and
  random vectors were not simulated, and decrypt is still XLS.
- With `v0` folded, X1/X2 no longer need C1.block_stable / C3.key_stable_op (the
  no-stability mutant PASSes), but the pass still cites them. The link between the
  core-pin assumptions and the xtor proofs (C1-C4) is by clause id only.
- 418 FF is below the model's 514 register bits: Yosys removed ~96 p1 flops
  once enables and resets were gone. This was not analysed.
