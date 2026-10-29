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
baseline", "Exploration at V3"). Clocks are for 8 blocks.

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
  pipe 50 (0.16). The standalone bench programs two DMA channels per block
  and polls DONE, so part of this 2.56x is CSR/control overhead, not
  integration. TODO(B2-3): a best-case standalone (streaming / linked DMA) to
  split the gap into overhead and real integration gain.
- **Q-d First-block latency.** Needs the system bench. Not measured yet in
  either config. TODO(B2-4b).
- **Q-e Bus-bound or op-bound.** Needs the system bench. Standalone (serial):
  bus and op add, 128 = 8 x 16, so every arch pays its op on top of the bus.
  Integrated pipe: A0 is bus-bound (8 accesses x 7 ns = 5.6 clk/block vs a
  4-clk op; 50 clks), A4 nearly so (57), A1-A3 op-bound (97, 409, 1609).
  TODO(B2-4b): how the boundary moves with bus access time and width.
- **Q-f Which architecture to pick.** Needs Q-b with Q-c. Standalone: a
  faster op always helps (A0 128 < A4 144 < A1 184 < A2 496 < A3 1696).
  Integrated pipe: any arch with II <= ~6 gives about the bus rate, so A4
  (57 clks, ~27% of A0's LUT4) beats A0 (50) on throughput per area. The
  choice flips with the configuration. TODO(B2-3): does a streaming
  standalone hide the op enough to flip it too? TODO(B2-4b): at which bus
  speed does it flip back?
- **Q-g Sensitivity to bus speed, width and block count N.** Needs the
  system bench. TODO(B2-4).
- **Q-h Is the scheduled loop correct and safe?** Integrated only: contracts
  C1-C4 with SBY proofs on fw_aes_dma_xtor (contracts.md) and the co-synthesis
  pass on A0 with equivalence checks. Standalone relies on the CSR protocol
  and the separately verified DMA; nothing joint to prove.

## Summary so far

Where they agree: the datapath (Q-a, Q-b), which is what XLS alone answers.
Where they part: system throughput and arch choice (Q-c, Q-e, Q-f), where the
integrated loop hides the op behind the bus and makes the bus cycle per block
set the useful II. How much of the gap survives a fair standalone, and how it
moves with the bus, is B2-3 and B2-4; the write-up is B2-5.

Caveats: TL bus model (fixed access delay, no arbitration between the host
and the fw-aes-dma master); AES-128 only for A1-A4 area; V3 numbers, not RTL.
