# Summary of the work

This page reports what was built in fw-aes, in four batches of work, and
where to find each result. To run the steps yourself, see
{doc}`walkthrough/index`; for all the numbers, see {doc}`design/baseline`.

## What was asked

1. **Batch 1: the multi-view HLS AES demo.** Build AES through the views of
   the multi-view HLS plan: an untimed model (V0), the XLS-generated RTL (A0),
   stage-level TLM (V3) from the XLS schedule, architecture exploration at V3,
   our own lowering V3 -> V4 -> V5, a built-in DMA variant, contracts and a
   co-synthesis pass (plan phases 0-5).
2. **Batch 2: standalone vs integrated DMA.** Keep both DMA configurations as
   peers: standalone (fw-aes as a CSR target plus an external fw-wb-dma, which is
   about what XLS gives alone) and integrated (fw-aes-dma, which has a built-in bus master).
   Show where they differ.
3. **Batch 3: documentation.** Write this summary, and Sphinx pages that walk
   a user through the steps and show where the results are.
4. **Batch 4: re-entry.** Check that the output at any level of the lowering
   can be saved and the lowering completed from it, with the same QoR as a
   single-shot lowering; add tests and report the findings.

## Results

| Phase | What exists | Headline result | Walkthrough |
|---|---|---|---|
| 0 Reference | V0 untimed model; A0 RTL from XLS codegen (2 stages); system bench with fw-wb-dma | A0 encrypt on ECP5: 106170 LUT4 (does not fit an LFE5U-85F) | {doc}`walkthrough/1-reference` |
| 1 V3 | V3 stage-TLM class generated from the XLS schedule | Cycle-exact with A0 RTL (32 ops in 128 clks on both); 4 clk/op; ~2.8x faster than RTL on stock Verilator | {doc}`walkthrough/2-v3` |
| 2 Exploration | Architecture specs A0-A5; native scheduling/binding to V3 for A1-A4 | A1/A2/A3/A4 = 11/50/200/6 clk/op, ECP5 LUT4 24241/6604/6106/28643 (AES-128 encrypt) | {doc}`walkthrough/3-explore` |
| 3 Lowering | Our V3 -> V4 -> V5 lowering of A0, with link proofs | Within 5 % LUT4 of XLS (111073 LUT4, 999 FF), 4 clk/op | {doc}`walkthrough/4-lowering` |
| 4 DMA + co-synthesis | fw-aes-dma; contracts C1-C4 proved with SBY; co-synthesis pass (X6, X2, X1, X3) on A0 | FF 999 -> 418, LUT4 111073 -> 83329, 4 -> 3 clk/op; pre == post proved over abstracted stages | {doc}`walkthrough/5-dma-cosynth` |
| 5 Stretch | A5 masked S-box spec (V3 timing only); GCM partition (design only) | A5: 21 clk/op (spec) | {doc}`design/gcm-partition` |
| B2 Standalone vs integrated | Best-case streaming standalone; bus/NB/arch knobs; 54-point sweep | Integrated pipe is 1.27x (A1, fast bus) to ~2.1x (slow bus) faster than the best standalone; first block 1-13 clks earlier | {doc}`walkthrough/6-standalone-vs-integrated` |

What batch 2 found: the two configurations agree on the datapath (II,
latency and area, which is what XLS alone gives) and do not fully agree on
anything at the system level. Best-case streaming removes 28-42 clks of CSR overhead per block
(A0, 8 blocks: 128 -> 100 clks). The integrated pipe reaches the op II,
while the stream adds the DOUT drain to every op. The best architecture
depends on the configuration and the bus: at 7 ns the stream cannot tell A0
from A4, so A4 wins on area, but at 3.5 ns the pipe shows A0 is 1.49x faster.
See {doc}`design/standalone-vs-integrated`.

What batch 4 found: before it, only the XLS schedule and V5 could be re-entered.
The libsynth Structure and the zuspec arch schedule now have full JSON forms
that the lowering reads again; V4 has no parser, and V3 is a timing view only.
From every re-entrable level the emitted V4/V5 is byte-identical to single-shot,
so the QoR is the same (A0 111073/999, A2 6604/705, A4 28643/420 LUT4/FF re-run;
`link-v4-v5` still equivalent). Tests: `tests/reentry/reentry_a0.py`,
`tests/reentry/reentry_arch.py`. See {doc}`design/reentry`.

## Decisions

- No network: `packages/` is a symlink to fw-uart16550's packages, plus
  `deps/` symlinks for fw-wb-dma ({doc}`walkthrough/setup`).
- The A0 RTL is generated locally with XLS codegen (xlsynth-bin), in 2 pipeline stages.
- The FPGA target is ECP5, because AES A0 is far too big for an iCE40UP5K.
- The two DMA configurations are peers, and neither is the baseline (the owner's decision in batch 2).
- The best-case standalone uses fw-wb-dma's HW-handshake mode, with bench glue
  in place of the dma_req/dma_ack pins. fw-aes itself is unchanged.
- Tool changes were made in the tool repos (fw-hdl, zuspec-synth,
  dv-flow-libsynth) on local branches, and re-verified before use.
- Dropped: a formal proof of cycle fidelity (A0 is too big for fw.hdl.formal), and X5
  (resource sharing) on A0, because A0 is fully unrolled and has nothing to share.
- For the co-synthesis, only the end-point numbers are quoted, because the LUT4 counts of
  the intermediate variants are noisy.

## Open items

- **Unpushed branches.** fw-aes `wpk/fw-aes-demo`, and the tool branches it
  needs (see {doc}`walkthrough/setup`): fw-hdl `wpk/cosynth` (contains
  `wpk/v3-import`), zuspec-synth `wpk/arch-sched`, dv-flow-libsynth
  `wpk/lower`. fw-aes cannot be rebuilt elsewhere until these are pushed or merged.
- **Co-synthesis checks that are missing.** There is no proof over the real AES stages (the proof uses abstracted
  stages). MODE=0 (AES-128) is assumed, not proved. Only one vector is simulated on the post-pass design.
  The ~96 FFs that Yosys removed were not analysed.
- **Not done.** X5 on A2/A3; decrypt lowering and synthesis (decrypt synthesis runs
  out of memory); an Fmax for A0; a GCM implementation; bus-width sweeps
  (the TL bus is 32-bit only); bus arbitration; and the area cost of the
  fw-aes-dma master port.
- **Re-entry gaps.** No V4 parser (lowering cannot restart from V4); no arch-schedule
  mutation that changes V5 was found (all tried were rejected); first-file picks
  in the task loaders are still a hidden input.
- **Area is not like for like.** A1-A4 areas are AES-128 encrypt only, but A0's area is XLS AES-128+256.
