# DMA built into fw-aes (integrated configuration)

Owner question: shouldn't the DMA be built into fw-aes, for more
co-design/co-synthesis opportunities?

## Decision

**Both, as peers** (owner, batch 2). Neither is the baseline of the other;
standalone-vs-integrated.md lists the questions each one answers and where
they differ. In short (B2-3b/B2-4b, baseline.md): with standalone at its
best (HW-handshake streaming), integrated pipe is still 1.27x (A1, fast bus,
op-bound) to ~2.1x (any arch, slow bus, bus-bound) faster, because the
external DMA moves 16 accesses per block on one engine against 8 and the
single DOUT buffer stalls the next op; the pipe reaches the op II, delivers
the first block 1-13 clks earlier, and changes which arch is worth its area.

- **Standalone (fw-aes + external DMA):** the system bench (`tests/bench`):
  fw-aes is a Wishbone CSR target (`src/rdl/fw_aes_regs.rdl`,
  `fw_aes_wb_target`), and a separate fw-wb-dma moves blocks
  mem -> DIN and DOUT -> mem. AES is a client and the system moves the data:
  the closest match to what XLS supports alone (a datapath compiled to RTL
  and placed in a fixed system). Plan Ph4's "opaque baseline" comparison
  uses it.
- **Integrated (fw-aes-dma):** where the multi-view flow answers bandwidth
  and latency questions. fw-aes gets its own Wishbone master port and
  descriptor registers:
  - `SRC`, `DST` (byte addresses), `LEN` (blocks), `CTRL` (start, mode
    enc/dec, irq enable), `STATUS` (busy, done, error).
  - One loop, `fetch block -> AES rounds -> store block`, written once in
    the arch view and scheduled together with the datapath. The scheduler
    can then overlap fetch of block n+1 and store of block n-1 with the
    rounds of block n, share one bus FSM for reads and writes, and drop the
    DIN/DOUT CSR staging registers and the DONE poll.
  - The key stays CSR-loaded (KEY0-7); only data moves over the master port.

## Measuring the gain

The bench's blocks/clk today is a TL delay-model figure (bus access `#7ns`,
DONE poll every 10 ns; see the bench notes): 8 blocks take 102 clks on V0
and 128 on the A0 RTL. It measures the bench, not hardware. A fair
baseline vs variant comparison needs clocked (cycle-accurate) buses on
both sides: the V3 stage-TLM or RTL views with a clocked wb interconnect
and memory.

Update (batch 2): the comparison now uses the V3 views on both sides with
the same TL bus model (`bench-v3-stream[-aN]-run` vs
`bench-aesdma-pipe[-aN]-run`) and a sweep over bus access time, block count
and arch (`tests/bench/sweep.py`); results in baseline.md and
standalone-vs-integrated.md. A clocked interconnect is still not modelled.

## Outline items affected

- 8 (V3 in the bench): the bench needs a clocked bus, and the variant slots
  in as a second DUT configuration.
- 14 (Ph4 co-synthesis): fw-aes-dma is the co-synthesized design; the
  baseline is the external-DMA bench. Sub-item 14a builds the variant.
