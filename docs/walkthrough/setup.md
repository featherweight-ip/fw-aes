# Setup

The demo runs offline. Its tools come from local checkouts, some of them on
local branches that are not pushed yet.

## What must be present

| Path | What |
|---|---|
| `packages/` | Symlink to `~/projects/featherweight-ip/fw-uart16550/packages` (fw-hdl, fw-proto-wb, dv-flow, verilator 5.052, yosys, nextpnr, python) |
| `deps/fw-wb-dma`, `deps/fw-proto-gpio` | Symlinks to the fw-wb-dma checkout and its fw-proto-gpio package |
| `~/projects/featherweight-hdl/fw-hdl` | Branch `wpk/cosynth`: XLS schedule import (V3), co-synthesis pass |
| `~/projects/zuspec/zuspec-synth` | Branch `wpk/arch-sched`: architecture specs, scheduling, V5 emit for A1-A4 |
| `~/projects/dv-flow/dv-flow-libsynth` | Branch `wpk/lower`: our V3 -> V4 -> V5 lowering |
| `~/projects/edapack/xlsynth-bin/.build/release/xlsynth-bin/bin` | XLS binaries (codegen_main, ...) |

`packages/`, `deps/`, `rundir/` and `logs/` are git-ignored. To recreate `deps/`:

```bash
mkdir deps
ln -s ~/projects/featherweight-ip/fw-wb-dma deps/fw-wb-dma
ln -s ~/projects/featherweight-ip/fw-wb-dma/packages/fw-proto-gpio deps/fw-proto-gpio
```

## Shell

```bash
export IVPM_PACKAGES=$PWD/packages
export PATH=$PWD/packages/verilator/bin:$PWD/packages/python/bin:$PATH
export PYTHONPATH=$HOME/projects/dv-flow/dv-flow-libsynth/src:$HOME/projects/zuspec/zuspec-synth/src:$HOME/projects/featherweight-hdl/fw-hdl/python
# for the XLS RTL (A0), lowering and synthesis steps:
export PATH=$HOME/projects/edapack/xlsynth-bin/.build/release/xlsynth-bin/bin:$PWD/packages/yosys/bin:$PWD/packages/nextpnr/bin:$PATH
```

The Verilator in `packages/` (5.052) is required: an older one on the
default PATH fails on fw-hdl's `fw_dbg_ctx.svh`.

Check that the flow loads:

```bash
dfm show tasks > logs/dfm-show.log 2>&1
grep -c org.fwip.aes logs/dfm-show.log     # > 0
```

## Layout

| Directory | Contents |
|---|---|
| `src/ref` | The AES reference package (`aes_pkg.sv`, from fw-hdl's XLS AES example) |
| `src/spl` | V0: the untimed API package and the Wishbone CSR front-end |
| `src/rdl` | SystemRDL for the fw-aes and fw-aes-dma registers |
| `src/rtl` | A0: wrapper around the XLS codegen of the AES DSLX |
| `src/v3` | V3: stage-level TLM from the XLS schedule (A0) and ArchSched (A1-A4) |
| `src/arch` | Architecture specs a0..a5.yaml |
| `src/ll` | Our lowering V3 -> V4 -> V5 of A0 |
| `src/v5` | V5 RTL and ECP5 synthesis for A1-A4 |
| `src/dma` | fw-aes-dma: the integrated DMA (serial, overlap, pipe) |
| `src/cosynth` | Contracts C1-C4 and the co-synthesis pass on A0 |
| `tests/unit` | Vector, CSR, fidelity, speed and scaling tests |
| `tests/bench` | System benches (standalone and integrated) and the sweep |
| `docs` | This documentation |

## Building this documentation

```bash
python3 -m sphinx -W -b html docs docs/_build/html
# open docs/_build/html/index.html
```

It needs Sphinx, myst-parser and furo (the system `/usr/bin/python3` has them).
The SystemVerilog listings use the
[sphinx-systemverilog](https://github.com/fvutils/sphinx-systemverilog)
extension (with pyslang); `docs/conf.py` loads it from
`~/projects/fvutils/sphinx-systemverilog` when it is not installed.
Generated SV (XLS RTL, stage-TLM packages, register packages) is shown from
copies in `docs/sv/generated/`; after rerunning the flows, refresh them with

```bash
python3 docs/sv/snapshot.py    # copies from rundir/ (whole, head excerpt, or port-only stub)
```
