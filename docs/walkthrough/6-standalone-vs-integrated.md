# Step 6: standalone vs integrated DMA

**Shows:** the two DMA configurations as peers. Standalone (fw-aes as a CSR
target, an external fw-wb-dma moving data) is what XLS alone supports;
integrated (fw-aes-dma) is where the multi-view flow schedules the bus with
the op. A best-case standalone (HW-handshake streaming) removes the CSR
overhead; a sweep over bus speed, block count and architecture shows where
the two still differ.

```bash
dfm run bench-v3-stream-run      # "view=v3 blocks=8 clks=100 ... first=17"
dfm run bench-v3-stream-a1-run   # clks=142
dfm run bench-v3-stream-a4-run   # clks=102
rm -f logs/sweep.csv
python3 tests/bench/sweep.py > logs/sweep.log 2>&1   # ~7 min, ends "54 rows, 54 passed"
python3 tests/bench/sweep.py --restore               # rebuild the default images
```

One point by hand (define override, rebuilds the image):

```bash
dfm run -u log -P '{"tasks":{"bench-v3-img":{"defines":["FW_AES_BENCH_V3","FW_AES_NB=1"]}}}' bench-v3-run
```

The sweep rows are in `docs/design/sweep-b2-4b.csv`.

**Results:** {doc}`../design/standalone-vs-integrated` and
{doc}`../design/baseline`, sections "Best-case standalone" and "Sweep".

## SystemVerilog

The two benches move the same 8 blocks over the same bus timing; the
difference is who programs what in the timed region.

### Standalone: fw-aes + external fw-wb-dma

```{eval-rst}
.. autosvmodule:: fw_aes_bench_tb
```

Header and the timed region of the host's `run()`. Per block, the host
programs DMA channel 0 (mem -> DIN), writes CTRL.START, and programs
channel 1 (DOUT -> mem); with `FW_AES_BENCH_STREAM` both channels are
programmed once in HW-handshake mode and `hs_glue` paces them (340 lines in
all):

```{literalinclude} ../../tests/bench/fw_aes_bench_tb.sv
:language: systemverilog
:lines: 1-12,166-181
```

### Integrated: fw-aes-dma

```{eval-rst}
.. autosvmodule:: fw_aes_dma_bench_tb
```

Header and the timed region: the host writes SRC, DST, LEN and START once
and reads STATUS; fw-aes-dma's own master does the rest (141 lines in all):

```{literalinclude} ../../tests/bench/fw_aes_dma_bench_tb.sv
:language: systemverilog
:lines: 1-8,100-112
```
