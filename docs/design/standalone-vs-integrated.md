# Standalone vs integrated DMA: two peer configurations

Owner decision (batch 2): keep both configurations as peers, and show where
they differ. Neither one is "the baseline".

## The two configurations

| | Standalone (`fw-aes` + external `fw-wb-dma`) | Integrated (`fw-aes-dma`, src/dma) |
|---|---|---|
| AES role | A client: a Wishbone CSR target (`src/rdl/fw_aes_regs.rdl`), DIN/DOUT/CTRL/STATUS | Owns the transfer: its own WB master port, descriptor regs SRC/DST/LEN, CTRL, STATUS |
| Who moves data | The system: fw-wb-dma copies mem -> DIN and DOUT -> mem | fw-aes-dma: one `fetch -> rounds -> store` loop |
| What is designed together | The datapath only; bus, DMA and host program are fixed | Datapath, bus FSM and loop schedule (serial / overlap / pipe) |
| Closest tool flow | XLS alone: a function or proc compiled to RTL, then dropped into a system | Multi-view: V0..V5 of the whole loop, scheduled and checked as one |
| Bench | tests/bench/fw_aes_bench_tb.sv (`bench-v3-run`, `bench-v3-a<N>-run`) | tests/bench/fw_aes_dma_bench_tb.sv (`bench-aesdma{,-ov,-pipe}-run`, `bench-aesdma-pipe-a<N>-run`) |

Both use the same AES views (A0 from XLS, A1-A4 from `zuspec.synth.ArchSched`),
the same key, 8 blocks, 10 ns clock and a TL bus model of 7 ns per access.

## What XLS alone gives, and what needs the system views

XLS (and our own ArchSched/ArchLower for A1-A4) answers questions about the
**datapath**: II, latency, pipeline stages, RTL and its area. Those answers
are the same in both configurations. Questions about **the system**, how fast
blocks get through, how long the first one takes, whether the bus or the op
limits it, and so which architecture is worth its area, depend on how data
reaches the datapath. The standalone answer to those is "whatever the
external DMA and host program do"; the integrated configuration is where the
multi-view flow can schedule the bus with the op and so answer them.

## Questions, and which view/config answers them

Numbers from baseline.md ("System bench per view", "fw-aes-dma vs opaque
baseline", "Exploration at V3", "Best-case standalone (B2-3b)", "Sweep
(B2-4b)"). Clocks are for 8 blocks and a 7 ns bus unless given as clk/blk
(NB=64, from the sweep).

- **Q-a Datapath II and latency per arch.** Answered by the XLS schedule (A0)
  and ArchSched (A1-A4), V3 view; same for both configs. A0 4 clk/op, A1 11,
  A2 50, A3 200, A4 6.
- **Q-b Datapath area per arch.** Answered by V5 + yosys ECP5; same for both.
  A0 106170 LUT4 (XLS, AES-128+256), A1 24241, A2 6604, A3 6106, A4 28643
  (AES-128 only; caveats in baseline.md). Not measured: the extra area of the
  fw-aes-dma master port and descriptor regs vs the CSR target plus a
  fw-wb-dma channel (not planned in batch 2).
- **Q-c System throughput (blocks/clk).** Needs the system bench.
  Standalone A0 128 clks (0.0625); integrated A0 serial 76, overlap 55,
  pipe 50 (0.16). The per-block standalone bench programs two DMA channels
  per block and polls DONE; its best case (B2-3b, `bench-v3-stream-run`:
  channels programmed once in HW-handshake mode) removes 28-42 clks of that
  CSR overhead: A0 100, A1 142, A4 102. Integrated pipe is still 2.0x (A0),
  1.46x (A1), 1.79x (A4) faster. That remainder is structural: the external
  DMA moves each word as a read plus a write on one engine (16 accesses per
  block), fw-aes-dma reads straight into the datapath and writes from it (8);
  and with one DOUT buffer the stream cannot start op i+1 before DOUT i is
  stored.
- **Q-d First-block latency.** Needs the system bench (B2-4a: `first=` in the
  BENCH line). Pipe delivers block 0 1-13 clks earlier than stream (NB=8:
  A0 7 ns 12 vs 17, 14 ns 22 vs 35; A1 3.5 ns 15 vs 16). In stream, block 0's
  store competes with block 1's fetch on the one engine, so its first grows
  with NB (14 ns: 27 clks at NB=1, 35 at NB=8); the pipe's barely moves.
- **Q-e Bus-bound or op-bound.** Needs the system bench. Per-block standalone:
  bus and op add (128 = 8 x 16), every arch pays its op on top of the bus.
  Stream and pipe (B2-4b sweep, clk/block at NB=64): the bus limit is 16
  accesses per block for stream, 8 for pipe, so at 14 ns every arch is
  bus-bound in both (stream ~23.9, pipe ~11.3, ratio ~2.1x) and arch does not
  matter. As the bus gets faster the pipe reaches the op II (A0 4.1 at
  3.5 ns; A4 6.1 and A1 11.1 at 3.5 and 7 ns); the stream never does, it adds
  the DOUT drain to each op (A1 14.0 = 11 + 3 at 3.5 ns, 17.1 = 11 + 6 at
  7 ns). Only the access time was swept; bus width is fixed at 32 bits.
- **Q-f Which architecture to pick.** Needs Q-b with Q-c. Per-block
  standalone: a faster op always helps (A0 128 < A4 144 < A1 184 < A2 496 <
  A3 1696). Stream at 7 ns: A0 and A4 are both bus-bound (12.0 vs 12.1
  clk/blk), so the stream also flips the choice to A4 (~27% of A0's LUT4);
  at 3.5 ns it shows A0 only 1.29x over A4 (7.0 vs 9.0). Integrated pipe at
  7 ns: any arch with II <= ~6 gives the bus rate, A4 again; at 3.5 ns the
  pipe exposes the full op ratio, A0 1.49x over A4 (4.1 vs 6.1). In the pipe
  A0 pulls ahead of A4 once 8 accesses take less than A4's 6-clk op (bus
  below ~7.5 ns; 5.7 vs 6.1 at 7 ns), so the choice flips back to A0 only if
  that gain is worth ~3.7x the LUT4 (A0's figure includes AES-256). At 14 ns all three tie in both configs. The
  integrated view is the one that exposes the op II to the system; the
  stream hides part of it behind the DOUT drain.
- **Q-g Sensitivity to bus speed, width and block count N.** Needs the
  system bench (B2-4b, 54 points, docs/design/sweep-b2-4b.csv). Bus speed:
  above. N: clk/blk at NB=8 is within 6% of NB=64 for stream and up to 16%
  above it for pipe (fill and drain is a larger share of its shorter runs),
  so 8-block numbers slightly understate the pipe's lead; NB=1 is dominated
  by first-block latency. Width: not swept (the TL bus is 32-bit only in
  both benches); a wider bus would move both bus limits down and widen the
  op-bound region, more so for the pipe (guess, not measured).
- **Q-h Is the scheduled loop correct and safe?** Integrated only: contracts
  C1-C4 with SBY proofs on fw_aes_dma_xtor (contracts.md) and the co-synthesis
  pass on A0 with equivalence checks. Standalone relies on the CSR protocol
  and the separately verified DMA; nothing joint to prove.

## Summary: where the two differ

Where they agree: the datapath (Q-a, Q-b): II, latency and area per arch,
which is all XLS (or ArchSched) alone answers, and the same in both configs.

Where they part, after giving standalone its best case (stream):

- Nowhere fully equal. The gap is smallest where both are op-bound and the
  bus is fast (A1 at 3.5 ns, 1.27x) and largest where both are bus-bound
  (~2.1x at 14 ns, any arch): the access count per block, 16 vs 8.
- Control overhead (per-block CSR programming and polling) is 1.28-1.41x of
  the original 2.56x A0 gap; the rest is structure (one DMA engine doing read
  plus write, one DOUT buffer), which only a change of the system removes.
- The integrated pipe runs at the op II whenever the bus allows; the stream
  adds the DOUT drain to every op, so it never reaches the II.
- Arch choice depends on the configuration and bus: at 7 ns the stream cannot
  tell A0 from A4 and the pipe makes them near-equal per block, so A4 wins
  on area; at 3.5 ns the pipe shows A0 1.49x over A4 (stream 1.29x); at
  14 ns all archs tie. A datapath-only (XLS) view would always pick the fastest op.
- First block: pipe 1-13 clks earlier, and its latency does not grow with N.
- Q-h (joint correctness proofs) applies to the integrated config only.

Caveats: TL bus model (fixed access delay, no arbitration between host, DMA,
handshake glue and the fw-aes-dma master); 32-bit bus only, width not swept;
AES-128 encrypt only for A1-A4 area (A0 is XLS AES-128+256); V3 numbers, not
RTL; the stream's handshake glue stands in for dma_req/dma_ack pins fw-aes
does not have.
