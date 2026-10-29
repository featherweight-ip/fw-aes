# Boundary contracts for fw-aes (item 14d1)

The co-synthesis passes X1, X2, X3, X5 and X6 (plan §5.2, §7.4) are sound only
under the contracts below. Each record uses the fields of plan §5.1. A contract
is **checked where it is implemented** (sim assertions at every view, SBY on the
transactor side) and **assumed where it is consumed** (by the passes and the
link proofs). Nothing here is checked by a tool yet: the SBY proofs and the V4
pass are request `fw-hdl-cosynth` (outline 14d3).

Names: API `fw_aes_api` (`set_key`, `encrypt`, `decrypt`) in
`src/spl/fw_aes_api_pkg.sv`; CSRs in `src/rdl/fw_aes_regs.rdl` (KEY0-7,
DIN0-3, DOUT0-3, CTRL, STATUS) and `src/rdl/fw_aes_dma_regs.rdl` (SRC, DST,
LEN, CTRL, STATUS); the DMA master is `fw_aes_dma.m_master` in
`src/dma/fw_aes_dma.sv` (see `dma-integrated.md`).

## C1 AES block in (`encrypt`/`decrypt` argument; DIN0-3 or DMA fetch)

| Field | Value |
|---|---|
| protocol | 4 x 32-bit beats per block, byte 0 in [31:24] of beat 0; a block is complete after the 4th beat; then START (CSR) or the DMA loop starts the op |
| timing | consumer ready when STATUS.BUSY = 0; producer may stall arbitrarily between beats |
| ordering | in order; at most 1 block in flight (no new block while BUSY) |
| env. invariants | DIN0-3 not written while BUSY; DMA does not fetch block i+1 into the state register before op i has left it (sched 1/2 fetch into a separate buffer) |
| observability | DIN0-3 are write-only for the result: the host never reads the staged block back |
| implemented by | the producer: host (CSR bench) or `fw_aes_dma.fetch` |
| consumed by | X1, X3 |

## C2 AES block out (`encrypt`/`decrypt` result; DOUT0-3 or DMA store)

| Field | Value |
|---|---|
| protocol | 4 x 32-bit beats, same byte order as C1 |
| timing | valid from STATUS.DONE = 1 until the next START; consumer may read late |
| ordering | in order; 1 result per accepted block |
| env. invariants | DOUT0-3 are read only after DONE; in the DMA variant, store of block i ends before op i+2 writes the output (sched 2 keeps one store in flight) |
| observability | DOUT is the only visible state of the datapath; round state is not host-readable |
| implemented by | the AES view (V3/V5) |
| consumed by | X3 (out handshake = DONE, no skid buffer) |

## C3 CSR key (`set_key`; KEY0-7, CTRL.MODE)

| Field | Value |
|---|---|
| protocol | 8 x 32-bit CSR writes (4 used for AES-128) then CTRL.MODE |
| timing | no timing promise; key writes are rare |
| ordering | key and mode are complete before the first START after them |
| env. invariants | **KEY0-7 not written while BUSY**; **MODE fixed after init** (only 0 = AES-128 in this demo) |
| observability | KEY0-7 are write-only for the result (the host never relies on reading the key back during an op) |
| implemented by | the host / CSR block |
| consumed by | X2 (CSR key == key-expansion round 0), X5 (key expansion shares S-boxes, needs key stable during an op), X6 (MODE = 128 removes the 192/256 paths) |

## C4 DMA Wishbone master (`fw_aes_dma.m_master`, `wb_proto_if #(32,32)`)

| Field | Value |
|---|---|
| protocol | Wishbone classic, 32-bit, one beat per access; SRC/DST byte addresses, LEN in blocks |
| timing | ack after >= 1 cycle; slave may stall arbitrarily (bus-bound: ~6 clk/block in the bench, baseline.md "Exploration at V3") |
| ordering | per block: 4 reads then (after the op) 4 writes; blocks in address order; sched 2 interleaves store i-1 with fetch i+1, never two accesses at once |
| env. invariants | source and destination buffers do not overlap; SRC/DST/LEN/CTRL not written while STATUS.BUSY |
| observability | memory contents after DONE; intermediate stores are visible to other masters (no atomicity promise) |
| implemented by | `fw_aes_dma` (TL) / its V4 bus FSM |
| consumed by | X1 (fetched words go straight to the state lanes, round-0 AddRoundKey folded), X3 (in-ready = !busy on the AES side of the master) |

## What each X assumes

| X | Boundary | Assumes | Expected effect |
|---|---|---|---|
| X1 | C1/C4 -> AES state register | C1 ordering (1 in flight) + DIN/fetch not changed while BUSY; C3 key stable (for the folded AddRoundKey) | -128 FF, -1 clk/block |
| X2 | C3 -> key-expansion round 0 | C3 "key not written while BUSY" | -128 FF |
| X3 | C1, C2 handshakes | C1/C2 "<= 1 in flight"; C2 consumer reads after DONE | no skid buffers; ready = !busy |
| X5 | key expansion <-> datapath (A2/A3) | C3 key stable for the whole op (expansion may be interleaved with rounds) | S-boxes 8 -> 4 for A2 |
| X6 | mode | C3 "MODE fixed after init" = AES-128 | 192/256 paths removed |

X4 is not used by the AES demo (plan §7.4 lists no AES instance).

## Checks to add (with 14d2 / 14d3)

- Sim assertions (all views): no DIN/KEY/SRC/DST/LEN/CTRL write while BUSY;
  DOUT read only after DONE; MODE unchanged after the first START.
- SBY (request `fw-hdl-cosynth`): C1-C4 proved on the transactor / CSR side;
  pre- vs post-co-synthesis equivalence at the fw-aes boundary under C1-C4.

## At TL (item 14d2)

- Checks: fw_aes_dma counts `m_contract_errs` (write to 0x00-0x2C while BUSY;
  MODE changed after the first START) and prints `CONTRACT:`; the system
  bench adds the count to its errors. The unit test aes-dma-run runs AES-128
  and AES-256 on one instance, so it prints two `CONTRACT: MODE changed`
  lines (it is not under C3's "MODE fixed" invariant; not counted there).
- X1 (define `FW_AES_X1`, bench only): V3 clks_per_op - 1.
  bench-aesdma 76 -> 68 clks (8 blocks, -1/block); bench-aesdma-pipe 50 -> 48
  (bus-bound: only the fill/drain op shrinks the critical path).
- X2, X3, X6 save FFs (round-0 key copy, skid buffers, 192/256 paths), not
  clocks: zero-cycle at TL; only the checks above model them.
