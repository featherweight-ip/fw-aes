# fw-aes design notes

The multi-view HLS AES demo (plan §7). Per-phase notes go beside this file;
`baseline.md` will hold the A0 numbers.

- `standalone-vs-integrated.md`: the two DMA configurations (fw-aes + external
  fw-wb-dma, and fw-aes-dma) as peers, the questions each one answers, and
  where they differ: same datapath answers (what XLS alone gives); integrated
  pipe 1.27x-2.1x faster than the best standalone (stream), first block
  1-13 clks earlier, and the arch pick depends on config and bus speed.
- `dma-integrated.md`: the fw-aes-dma design.
