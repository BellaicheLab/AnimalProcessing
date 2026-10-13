"""Sphinx configuration for pyanimalprocessing documentation."""

import os
import re
import sys

# pyanimalprocessing uses a src/ layout — point autodoc to the package source
sys.path.insert(0, os.path.abspath("../src"))

# -- Project information -----------------------------------------------------
project = "pyanimalprocessing"
author = "Boris Guirao, Adrien Leroy, Stephane Rigaud, Mehdi Ech-Chouini"
copyright = "2026, Bellaiche Lab — Institut Curie"

# Single-sourced from the package (regex, not import — autodoc mocks the deps)
with open(os.path.abspath("../src/pyanimalprocessing/__init__.py")) as _f:
    release = re.search(r'__version__ = "([^"]+)"', _f.read()).group(1)
version = release

# -- Extensions --------------------------------------------------------------
extensions = [
    "sphinx.ext.autodoc",       # Pull docstrings from Python source
    "sphinx.ext.autosummary",   # Auto-generate module summary pages
    "sphinx.ext.napoleon",      # Parse NumPy/Google-style docstrings
    "sphinx.ext.intersphinx",   # Cross-link to numpy/pandas/scipy docs
    "sphinx.ext.viewcode",      # Add "[source]" links beside functions
    "sphinx.ext.mathjax",       # Render LaTeX math in HTML
    "myst_parser",              # Write pages in Markdown (not just RST)
    "sphinx_copybutton",        # Copy button on code blocks
    "sphinx_design",            # Cards, tabs, badges, grid layouts
    "nbsphinx",                 # Render Jupyter notebooks as doc pages
]

source_suffix = {".rst": "restructuredtext", ".md": "markdown"}
exclude_patterns = [
    "_build", "Thumbs.db", ".DS_Store", "**.ipynb_checkpoints",
]

# -- Notebooks (rendered from stored outputs, never executed at build) -------
nbsphinx_execute = "never"
nbsphinx_allow_errors = False

# nbsphinx (<= 0.9.8) silently drops image/gif outputs; render them inline as
# data URIs, like it already does for notebook attachments.
import nbsphinx

nbsphinx.DISPLAY_DATA_PRIORITY_HTML = ("image/gif",) + nbsphinx.DISPLAY_DATA_PRIORITY_HTML
nbsphinx.RST_TEMPLATE = nbsphinx.RST_TEMPLATE.replace(
    "{%- elif datatype in ['image/svg+xml', 'image/png', 'image/jpeg', 'application/pdf'] %}",
    """{%- elif datatype == 'image/gif' %}

    .. raw:: html

        <img src="data:image/gif;base64,{{ output.data['image/gif'] | replace('\\n', '') }}" style="max-width: 100%;"/>
{%- elif datatype in ['image/svg+xml', 'image/png', 'image/jpeg', 'application/pdf'] %}""",
)

# nbsphinx warns on in-notebook anchors and repo-relative paths; they are intentional.
suppress_warnings = ["ref.ref", "nbsphinx.localfile"]


def _sync_tutorial_notebooks(app, config):
    """Mirror ../notebooks/*.ipynb into docs/notebooks/ so Sphinx can render them.

    The source of truth lives at the repo root. Copying keeps nbsphinx happy
    without duplicating files in git (docs/notebooks/ is .gitignored). The
    repo-root-relative guide links (valid on GitHub) are rewritten to resolve
    from the synced location.
    """
    import shutil
    from pathlib import Path

    src = Path(app.srcdir).parent / "notebooks"
    dst = Path(app.srcdir) / "notebooks"
    if not src.exists():
        return
    dst.mkdir(exist_ok=True)
    for nb in src.glob("*.ipynb"):
        text = nb.read_text(encoding="utf-8")
        (dst / nb.name).write_text(
            text.replace("(../docs/guides/", "(../guides/"), encoding="utf-8"
        )
        shutil.copystat(nb, dst / nb.name)


def setup(app):
    app.connect("config-inited", _sync_tutorial_notebooks)

# -- Mock imports (so autodoc runs without the heavy runtime deps) -----------
autodoc_mock_imports = [
    "napari", "napari_svg", "zarr", "matplotlib", "seaborn", "pandas", "dask",
    "scipy", "skimage",
    "joblib", "tqdm",
    "libpysal", "esda",
    "imageio_ffmpeg", "imageio", "cairosvg",
    "qtpy",
    "rasterio", "shapely", "natsort", "yaml",
]

# -- Napoleon (docstring parsing) --------------------------------------------
# Both styles coexist: numpydoc in io/plotting, Google-style in the MATLAB ports.
napoleon_google_docstring = True
napoleon_numpy_docstring = True
napoleon_use_rtype = True
napoleon_use_param = True
napoleon_preprocess_types = True

# -- Autodoc -----------------------------------------------------------------
autodoc_default_options = {
    "members": True,
    "member-order": "bysource",
    "show-inheritance": True,
    "undoc-members": False,
}
autodoc_typehints = "description"
autosummary_generate = True

# -- Intersphinx (ecosystem cross-linking) -----------------------------------
intersphinx_mapping = {
    "python":     ("https://docs.python.org/3", None),
    "numpy":      ("https://numpy.org/doc/stable/", None),
    "pandas":     ("https://pandas.pydata.org/docs/", None),
    "scipy":      ("https://docs.scipy.org/doc/scipy/", None),
    "matplotlib": ("https://matplotlib.org/stable/", None),
    "napari":     ("https://napari.org/stable/", None),
    "zarr":       ("https://zarr.readthedocs.io/en/stable/", None),
    # Cross-repo links (uncomment once each site is deployed on RTD):
    # "vgep":               ("https://vgep.readthedocs.io/en/latest/", None),
    # "morphodomains":      ("https://morphodomains.readthedocs.io/en/latest/", None),
}

# -- HTML output -------------------------------------------------------------
html_theme = "pydata_sphinx_theme"
html_static_path = ["_static"]

# Generated (gitignored): single-sources the navbar version badge consumed by custom.css
with open(os.path.abspath("_static/_version.css"), "w") as _f:
    _f.write(f':root {{ --logo-version: "v{release}"; }}\n')
html_css_files = ["_version.css", "custom.css"]

# Navbar brand: show just the project name; version is rendered as a small
# secondary line below via CSS (.logo__title::after in custom.css).
html_title = project

html_theme_options = {
    "icon_links": [
        {
            "name": "GitHub",
            "url": "https://github.com/BellaicheLab/AnimalProcessing",
            "icon": "fa-brands fa-github",
        },
    ],
    "navbar_align": "left",
    "show_prev_next": True,
    "navigation_depth": 3,
    "show_nav_level": 2,
    "secondary_sidebar_items": ["page-toc"],
    "footer_start": ["copyright"],
    "footer_end": [],
}

html_context = {
    "github_user": "BellaicheLab",
    "github_repo": "AnimalProcessing",
    "github_version": "main",
    "doc_path": "docs",
}

# -- MyST Markdown extensions ------------------------------------------------
myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "dollarmath",
    "fieldlist",
    "tasklist",
]
myst_heading_anchors = 3
