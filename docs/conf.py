# Sphinx configuration for the fw-aes multi-view HLS demo documentation.
#
# Build:  python3 -m sphinx -W -b html docs docs/_build/html   (from the repo root)
#    or:  make -C docs html
# Needs sphinx, myst-parser and furo (all offline; /usr/bin/python3 has them).

project = "fw-aes multi-view HLS demo"
copyright = "2026, Featherweight-HDL"
author = "Featherweight-HDL"
release = "0.1.0"

extensions = [
    "myst_parser",
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
