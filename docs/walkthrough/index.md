# Walkthrough

Six steps, in the order the demo was built. Each step says what it shows,
the commands to run (from the repository root, after {doc}`setup`), what a
passing run prints, and where the numbers are written up.

Every simulation writes `rundir/org.fwip.aes.<task>/sim.log`. A `dfm run`
that finishes does not by itself mean the test passed: always look for
`TEST PASSED` in the sim.log.

```{toctree}
:maxdepth: 1

setup
1-reference
2-v3
3-explore
4-lowering
5-dma-cosynth
6-standalone-vs-integrated
```
