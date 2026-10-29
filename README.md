# fw-aes

AES-128/256 built through the views of the multi-view HLS flow: an untimed
model (V0), XLS RTL (A0), stage-level TLM (V3), architecture exploration,
our own V3 -> V4 -> V5 lowering, a built-in DMA variant and a co-synthesis pass.

The documentation (a summary of the results and a step-by-step walkthrough)
is in `docs/`. Build it with Sphinx (needs sphinx, myst-parser and furo):

```bash
python3 -m sphinx -W --keep-going -b html docs docs/_build/html
```

Then open `docs/_build/html/index.html`.
