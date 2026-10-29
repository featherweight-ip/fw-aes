# AES architecture specs (A0-A4)

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
| `sbox_kind` | `lut` (256x8 table) or `canright` (composite-field GF((2^4)^2) logic, smaller on LUT4 parts). |
| `ii` | Target initiation interval, clks between accepted blocks. |
| `latency` | Clks from a call's start to its result at the `fw_aes_api` task. The V3 class waits this many `posedge clk`. |
| `pipeline_stages` | A0 only: XLS codegen stages. |
| `target` | Delay model for scheduling (`ecp5`; `ice40` planned). |

## The rows

| Arch | fold | S-boxes | kind | II | latency (clk) |
|---|---|---|---|---|---|
| A0 | unrolled | 200 | lut | 1 | 4 |
| A1 | iterated | 16 | lut | 11 | 11 |
| A2 | column | 4 | lut | 44 | ~44-50 |
| A3 | byte | 1 | canright | 160 | ~160+ |
| A4 | unrolled x2 | 32 | canright | 6 | 6 |

A0's numbers are measured (baseline.md); A1-A4 are estimates for AES-128
encrypt, to be replaced by the scheduler's output. AES-256 adds 4 rounds
(scale latency by 14/10).
