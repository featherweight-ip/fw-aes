# AES architecture specs (A0-A5)

One algorithm source (fw-hdl `examples/xls/aes`, `aes_pkg::encrypt` /
`decrypt`) and one small spec per architecture, in `src/arch/a<N>.yaml`
(dv-flow FileSet `arch-specs`). This is the input format proposed to the
scheduler/binder in request `zuspec-arch-sched`; until that tool exists the
specs drive hand-written V3 stand-ins (outline item 12b).

## Fields

| Field | Meaning |
|---|---|
| `arch` | Name, A0-A5 (PLAN §7.2). |
| `algorithm` | The function the schedule is built from. |
| `fold` | How the round loop maps to hardware: `unrolled` (all rounds, or `unroll` rounds per clock), `iterated` (one round per clock), `column` (4 bytes per clock), `byte` (1 byte per clock). |
| `unroll` | Rounds per clock when `fold: unrolled` folds partly (A4). Default: all. |
| `sbox_count` | Resource limit: S-box instances the binder may use (data path and key expansion share them unless more are given). |
| `sbox_kind` | `lut` (256x8 table), `canright` (composite-field GF((2^4)^2) logic, smaller on LUT4 parts) or `canright_masked` (A5: Canright with domain-oriented masking, 2 register stages). |
| `mask_order` | A5 only: masking order d; each secret is split into d+1 shares. |
| `rand_bits_per_sbox` | A5 only: fresh random bits each masked S-box needs per evaluation (the binder must route a PRNG to them). |
| `key_expansion` | Where the round keys come from: `shared` (default; computed inline, using the `sbox_count` S-boxes), `separate` (inline, own `key_sbox_count` S-boxes) or `precomputed` (all round keys computed at `set_key` and held in registers; no S-box use per op). A1 and A4 need `precomputed` to meet their latency (shared: A1 14 enc / 20 dec, A4 8 / 10). |
| `key_sbox_count` | With `key_expansion: separate`: S-boxes for the key schedule (default 4). |
| `ii` | Target initiation interval, clks between accepted blocks. |
| `latency` | Clks from a call's start to its result at the `fw_aes_api` task. The V3 class waits this many `posedge clk`. |
| `pipeline_stages` | A0 only: XLS codegen stages. |
| `target` | Delay model for scheduling (`ecp5`; `ice40` planned). |

## The rows

| Arch | fold | S-boxes | kind | key_expansion | II | latency (clk) | scheduled (enc / dec) |
|---|---|---|---|---|---|---|---|
| A0 | unrolled | 200 | lut | - | 1 | 4 | XLS: 4 |
| A1 | iterated | 16 | lut | precomputed | 11 | 11 | 11 / 11 |
| A2 | column | 4 | lut | shared | 44 | ~44-50 | 50 / 50 (precomputed 41) |
| A3 | byte | 1 | canright | shared | 160 | ~160+ | 200 / 200 (precomputed 161) |
| A4 | unrolled x2 | 32 | canright | precomputed | 6 | 6 | 6 / 6 |
| A5 | iterated, masked d=1 | 16 | canright_masked | - | 21 | 21 | not modelled (stand-in 21) |

"scheduled": `zuspec.synth.ArchSched` (zuspec-synth wpk/arch-sched) on A0's XLS
IR for AES-128, the latency the generated V3 view waits (src/v3/flow.yaml
`v3-a<N>-sched`). The ii/latency columns are the spec targets.

A0's numbers are measured (baseline.md); A1-A5 are estimates for AES-128
encrypt, to be replaced by the scheduler's output. AES-256 adds 4 rounds
(scale latency by 14/10).

## A5: masked S-box (stretch, item 15a)

A5 is A1 (one round per clock, 16 S-boxes) with first-order masked S-boxes
for side-channel resistance. Each state byte is held as two shares; the
linear layers (ShiftRows, MixColumns, AddRoundKey) act on each share alone,
and only the S-box needs fresh randomness (18 bits per S-box evaluation for a
DOM-indep Canright design, 16 x 18 = 288 bits per round). Its two register
stages make a round 2 clks: latency and II 21 (1 load/mask + 10 x 2). The
key schedule is left unmasked (the key arrives over the CSR bus, C3, so it is
not a masked input anyway). What the scheduler must add for A5: registers it
may not retime across (glitch barriers), a randomness port, and share-wise
binding (it must not merge the two shares into one resource). The V3 stand-in
only models timing: `FW_AES_V3_CLKS=21` (bench-v3-a5-run); its values are
unmasked, so it says nothing about leakage.
