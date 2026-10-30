# Re-entry: lowering from an intermediate level (batch 4)

The question: can the output at any level of the lowering be saved, and the
lowering then completed from that file, with the same QoR as a single-shot
lowering? "Same QoR" here means byte-identical emitted views, and equal ECP5
LUT4/TRELLIS_FF, latency and clks/op.

## The two lowering paths

- **A0 (XLS):** DSLX -> IR -> XLS codegen (schedule textproto + scheduled IR)
  -> libsynth `Lower` builds a `Structure` (nodes placed in stages, stage
  registers, SV names) -> V4 (`*.v4_stages.sv`, `*.v4.sv`) and V5 (`*.v5.sv`)
  -> Yosys. fw-hdl `StageTLM` makes V3 from the same schedule.
- **A1-A4 (zuspec-synth):** opt IR + `src/arch/aN.yaml` -> `ArchSched`
  (scheduling and binding) -> V3; `ArchLower` folds the schedule into V5 -> Yosys.
  There is no V4 on this path.

## Which levels are re-entrable

| Level | Artifact | Before batch 4 | Now |
|---|---|---|---|
| XLS schedule | `<m>.schedule.textproto` + `<m>.sched.ir` | yes: `Lower` takes any schedule fileset | yes |
| Structure | `<m>.structure.full.json` | no: memory only; `structure.json` is a summary | yes: `Lower` takes it as input, or `lower.py --from-structure FILE` |
| Arch schedule (A1-A4) | `<m>.<arch>.sched.full.json` | no: `schedule.json` is a summary, and `ArchLower` scheduled again on its own | yes: `ArchLower` reads it; it refuses a file whose IR or inputs hash differs |
| V3 | `aes_stage_tlm_pkg.sv` | terminal (timing view only) | terminal |
| V4 | `*.v4_stages.sv`, `*.v4.sv` | no parser | no parser (V5 cannot be made from V4) |
| V5 | `*.v5.sv` | yes, for Yosys and the co-synthesis pass | yes |

Tool changes (local branches, not pushed): dv-flow-libsynth `wpk/lower`
3f96fcf (`Structure.to_json`/`from_json`, `build_structure`, `emit_all`,
`lower_structure`, `--from-structure`); zuspec-synth `wpk/arch-sched` 7700ba1
(`sched.full.json`, IR/inputs hash guard). In fw-aes, `v5-aN` now needs
`v3-aN-sched`, so V3 and V5 of one architecture come from **one** schedule.
Before, they came from two scheduling runs that agreed only because their inputs were the same.

## Tests

- `tests/reentry/reentry_a0.py`: copies a0-ll's schedule and structure
  files, lowers again from each copy, and compares the outputs with
  `rundir/org.fwip.aes.a0-ll`. Schedule -> 5 files SAME; structure ->
  5 files SAME (structure, structure_full, v4, v4_stages, v5). A mutation of the
  structure (one node moved back a stage) is detected in v4_stages and v5.
- `tests/reentry/reentry_arch.py`: for A1-A4, lowers V5 from a copy of
  the arch schedule and compares V5 `.v`, `v5.json`, `sched.txt` and V3: 20 SAME.
  A mutated schedule is rejected by the V5 fold, and a schedule for other IR
  is rejected with `ir-hash-mismatch`.
- Unit tests: libsynth `tests/xls` 28 passed (5 new in `test_lower_structure.py`);
  zuspec-synth archsched 22 passed (4 new in `test_archsched_json.py`).

## QoR results

| Path / level | Single-shot | Re-entered |
|---|---|---|
| A0 schedule -> V5 | 111073 LUT4 / 999 FF, 4 clk/op | V5 byte-identical; synth 111073 / 999 |
| A0 structure -> V5 | 111073 / 999 | V5 byte-identical |
| A1 arch schedule -> V5 | 24241 / 421, 11 clk/op | V5 byte-identical |
| A2 arch schedule -> V5 | 6604 / 705, 50 clk/op | synth 6604 / 705 |
| A3 arch schedule -> V5 | 6106 / 763, 200 clk/op | V5 byte-identical |
| A4 arch schedule -> V5 | 28643 / 420, 6 clk/op | synth 28643 / 420 |

The V4 <-> V5 link proof (`link-v4-v5`) is still `equivalent`. The vector
sims pass at the same clks/op: 4 (A0 lowered) and 11/50/200/6 (A1-A4 V5).

## Findings

- Re-entry from every level that has a serialised form gives the same QoR as
  single-shot, because the emitted RTL is byte-identical. The emitters have no
  seeds or timestamps, and their orders are fixed by the IR text or sorted keys.
- Two levels were not re-entrable before this batch: the Structure and the zuspec
  schedule. Both now are.
- V4 is still a view only: there is no V4 parser, so lowering cannot restart
  from an edited V4. V3 is a timing view on both paths and is not lowered.
- Hidden inputs that are left: `ArchLower`/`Lower` take the first matching
  file when a fileset has several (`task.py` `_load`); the co-synthesis report
  holds absolute paths.
- Not done: a mutation of the arch schedule that the fold accepts but that changes
  V5 (every mutation tried was rejected); decrypt (only encrypt is lowered).

To run the checks: set up the shell as in {doc}`../walkthrough/setup`, then run `python3 tests/reentry/reentry_a0.py`
and `python3 tests/reentry/reentry_arch.py` (both need the a0-ll and v5-aN
runs, and `packages/python/bin` on PATH for zuspec).
