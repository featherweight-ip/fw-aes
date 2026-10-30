# Sphinx configuration for the fw-aes multi-view HLS demo documentation.
#
# Build:  python3 -m sphinx -W -b html docs docs/_build/html   (from the repo root)
#    or:  make -C docs html
# Needs sphinx, myst-parser and furo (all offline; /usr/bin/python3 has them),
# and sphinx-systemverilog with pyslang. If those are not importable, they are
# taken from a sphinx-systemverilog checkout ($SPHINX_SV, default
# ~/projects/fvutils/sphinx-systemverilog: its src/ and its packages/python venv).

import glob
import os
import sys

try:
    import sphinx_systemverilog  # noqa: F401
except ImportError:
    _sv = os.environ.get(
        "SPHINX_SV", os.path.expanduser("~/projects/fvutils/sphinx-systemverilog"))
    sys.path.insert(0, os.path.join(_sv, "src"))
    # Appended, so the running interpreter's own sphinx/myst/furo win.
    sys.path.extend(glob.glob(os.path.join(
        _sv, "packages/python/lib/python3*/site-packages")))

project = "fw-aes multi-view HLS demo"
copyright = "2026, Featherweight-HDL"
author = "Featherweight-HDL"
release = "0.1.0"

extensions = [
    "myst_parser",
    "sphinx_systemverilog",
]

source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}

myst_enable_extensions = [
    "colon_fence",
    "deflist",
]
myst_heading_anchors = 3

exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
]

html_theme = "furo"
html_title = "fw-aes multi-view HLS demo"

# Untagged code fences are plain text, so ASCII tables do not fail Pygments under -W.
highlight_language = "text"
suppress_warnings = ["misc.highlighting_failure"]

# SystemVerilog parsed by sphinx-systemverilog, in compile order: the
# dependencies (packages/ and deps/, see walkthrough/setup), the generated views
# snapshotted into sv/generated/ by sv/snapshot.py, then this repo's sources.
# Only files in this list are parsed; other snapshots are shown with literalinclude.
# Generated RTL too large to snapshot whole is parsed from its port-only copy;
# sv/generated/ll/aes_pkg__encrypt.v4.sv is left out (its stage package is 6 klines).
_fw_hdl = "../packages/fw-hdl/src/"
_wb = "../packages/fw-proto-wb/src/"
_gen = "sv/generated/"
sv_build_units = [
    "../src/ref/aes_pkg.sv",
    "../src/spl/fw_aes_api_pkg.sv",
    _fw_hdl + "fw_hdl_pkg.sv",
    _fw_hdl + "fw_clock_xtor_if.sv",
    _fw_hdl + "fw_clock_period_xtor_if.sv",
    _fw_hdl + "std/fw_std_pkg.sv",
    _wb + "fw_proto_wb_pkg.sv",
    _wb + "wb_initiator_xtor_if.sv",
    _wb + "wb_initiator_xtor_core.sv",
    _wb + "wb_initiator_xtor.sv",
    _wb + "wb_target_xtor_if.sv",
    _wb + "wb_target_xtor_core.sv",
    _wb + "wb_target_xtor.sv",
    "../deps/fw-proto-gpio/src/fw_proto_gpio_pkg.sv",
    "../deps/fw-wb-dma/src/spl/wb_dma_spl_pkg.sv",
    _gen + "fw_aes_reg_pkg.sv",
    _gen + "wb_dma_reg_pkg.sv",
    _gen + "fw_aes_dma_reg_pkg.sv",
    "../src/spl/fw_aes_wb_pkg.sv",
    _gen + "aes_pkg_api_pkg.sv",
    _gen + "aes_stage_tlm_pkg.sv",
    "../src/v3/fw_aes_v3.sv",
    _gen + "a0/aes_pkg__encrypt.ports.sv",
    _gen + "a0/aes_pkg__decrypt.ports.sv",
    "../src/rtl/fw_aes_rtl.sv",
    "../src/dma/fw_aes_dma.sv",
    "../src/cosynth/fw_aes_dma_xtor.sv",
    "../tests/unit/fw_aes_vectors_pkg.sv",
    "../tests/unit/fw_aes_vectors_tb.sv",
    "../tests/unit/fw_aes_csr_tb.sv",
    "../tests/unit/fw_aes_wb_tb.sv",
    "../tests/unit/fw_aes_vectors_v3_tb.sv",
    "../tests/unit/fw_aes_fid_tb.sv",
    "../tests/unit/fw_aes_speed_tb.sv",
    "../tests/unit/fw_aes_scale_tb.sv",
    "../tests/unit/fw_aes_vectors_v5_tb.sv",
    "../tests/unit/fw_aes_dma_csr_tb.sv",
    "../tests/unit/fw_aes_dma_tb.sv",
    "../tests/bench/fw_aes_bench_tb.sv",
    "../tests/bench/fw_aes_dma_bench_tb.sv",
]
# Include dirs are taken relative to the working directory, so make them absolute.
sv_include_dirs = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), d)
    for d in (_fw_hdl, _fw_hdl + "std", _wb, "../deps/fw-proto-gpio/src",
              "../deps/fw-wb-dma/src/spl")
]
sv_doc_style = "native"
