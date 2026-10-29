# Design notes

Per-topic notes written while the demo was built. The numbers are in
`baseline`; the others explain one design question each.

- **baseline**: every measured number (A0 ECP5, benches per view, cycle
  fidelity, sim speed, scaling, exploration A0-A5, our lowering vs XLS,
  co-synthesis, best-case standalone, the bus x blocks x arch sweep).
- **arch-specs**: the architecture-spec fields of src/arch/a0..a5.yaml.
- **dma-integrated**: the fw-aes-dma design (built-in DMA).
- **standalone-vs-integrated**: the two DMA configurations as peers, the
  questions each one answers, and where they differ.
- **contracts**: contract records C1-C4 and what each co-synthesis
  transform assumes.
- **gcm-partition**: GCM V1/V3 partition (design only).

```{toctree}
:maxdepth: 1

baseline
arch-specs
dma-integrated
standalone-vs-integrated
contracts
gcm-partition
```
