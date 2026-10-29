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
