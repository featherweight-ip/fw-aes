# AES-GCM partition (item 15b, plan Ph5 stretch)

Doc only: nothing here is built. It says how AES-GCM (NIST SP 800-38D) would
be split across views if fw-aes grew a GCM mode, reusing what exists:
`fw_aes_api` (`src/spl/fw_aes_api_pkg.sv`), the V3 class `fw_aes_v3`
(`src/v3/fw_aes_v3.sv`, any architecture A0-A5 via `clks_per_op`), and the
contract style of `contracts.md`.

## GCM in one paragraph

H = E_K(0^128). J0 = IV || 0^31 || 1 for a 96-bit IV (else GHASH of the IV).
Ciphertext C_i = P_i xor E_K(inc32^i(J0)). Tag
T = MSB_t(E_K(J0) xor GHASH_H(A || pad || C || pad || len(A)_64 || len(C)_64)),
with GHASH_H(X_1..X_m): Y_0 = 0, Y_i = (Y_{i-1} xor X_i) * H in GF(2^128)
(polynomial x^128 + x^7 + x^2 + x + 1, bit-reflected). Decrypt is the same
keystream plus a tag compare.

## Partition

| Part | View | Why |
|---|---|---|
| E_K (keystream, H, E_K(J0)) | V3: existing `fw_aes_v3` via `fw_aes_api.encrypt` | CTR needs only the forward cipher, so `decrypt` is unused; any A0-A5 schedule works unchanged |
| GHASH multiply Y = (Y xor X) * H | V3: new block `fw_gcm_ghash_v3` | the other timed datapath; its schedule is the design choice (below) |
| XOR of keystream with P/C | V3, folded into the CTR loop (0 clk, like X2/X6 at TL) | pure wiring at the C2 boundary |
| inc32 counter, J0, len block, padding, tag truncate + compare | V1 (untimed; control / firmware-side) | sequencing and bookkeeping, no datapath cost worth scheduling |
| Key / H setup | V1 calls `set_key` then `encrypt(0)` once per key, loads H into GHASH | once per key; H stays in a GHASH register (C3-like) |

The V1 layer is a class over two handles, `fw_aes_api aes` and
`fw_gcm_ghash_api gh`, and could live either as firmware (CSR bench style,
host drives every block) or as a DMA-integrated loop (`fw_aes_dma` style,
descriptor = IV, AAD ptr/len, text ptr/len, tag ptr).

## GHASH V3 options (arch-spec style, `src/arch/*.yaml`)

| Option | Multiply | clk/block | Notes |
|---|---|---|---|
| G1 bit-serial | 1 bit of X per clk (shift-and-add, reduce) | 128 | ~128 FF + ~256 LUT4; slower than every AES arch except A2 |
| G8 | 8 bits per clk (8 partial products + reduce) | 16 | balances A1 (11 clk) / A5 (21 clk) |
| G128 | full combinational Karatsuba | 1 (or 2-3 pipelined) | matches A0 (4 clk); big (~10-15k LUT4 guess, unmeasured) |

With E_K and GHASH as separate V3 blocks, they run concurrently on block i
(GHASH needs C_i, so GHASH of block i overlaps E_K of block i+1): throughput is
max(AES clk/op, GHASH clk/block) per 16 bytes, so the GHASH option should be
picked to match the AES arch (A0+G128, A1+G8, A2+G1). This is the same "bus /
neighbour picks the architecture" result as baseline.md "Exploration at V3".

## Contracts (as contracts.md C1/C2)

- **G1 GHASH in**: 128-bit block X_i (same byte order as C1), in order, one in
  flight; consumer ready when GHASH not busy. Implemented by V1 (A, len block)
  or the CTR loop (C_i); consumed by an X3-like handshake fusion.
- **G2 GHASH H**: written once per key, stable while any block is in flight
  (like C3 env. invariant "KEY not written while BUSY").
- **G3 GHASH out**: Y_m valid after the len block until the next H/clear; read
  once by V1 for the tag. Only visible state (round/partial Y not host-readable).
- **C1/C2 reuse**: the CTR loop is a C1 producer (counter blocks) and C2
  consumer (keystream), so X1 (fold start into last beat) and X3 apply as in
  the DMA variant.

## What the scheduler request would need

For `zuspec-arch-sched` (outline 12d) or a follow-up request:
1. A second scheduled unit in one arch spec (AES + GHASH) with a shared clock
   and an explicit overlap relation (GHASH(i) || E_K(i+1)).
2. GF(2^128) multiply as a bindable resource with digit size 1/8/128 (the
   G-options), like the S-box `impl:` field (lut / canright / masked).
3. V3 stage-TLM output for both units, each implementing its API class, so
   the V1 GCM class can use either view.
4. A GCM vector check (SP 800-38D test cases 1-4) at V1 and V3.

Not done: no GHASH code, no GCM vectors, no arch yaml for G-options.
