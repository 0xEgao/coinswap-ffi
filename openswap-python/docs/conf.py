import os
import sys

# Point Sphinx at the generated bindings so autodoc can import the module
sys.path.insert(0, os.path.abspath("../src/openswap/native/linux-x86_64"))

project = "Openswap Python"
copyright = "2026, citadel-foss"
author = "citadel-foss"

extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
]

# Napoleon settings (for Google-style docstrings in the generated bindings)
napoleon_google_docstrings = True
napoleon_numpy_docstrings = False

# Autodoc settings
autodoc_member_order = "bysource"
autodoc_default_options = {
    "members": True,
    "undoc-members": True,
    "show-inheritance": True,
    "exclude-members": "_uniffi_clone_handle, _uniffi_make_instance",
}

# Theme
html_theme = "furo"
html_title = "Openswap Python API"
html_theme_options = {
    "source_repository": "https://github.com/citadel-foss/openswap-ffi/",
    "source_branch": "main",
    "source_directory": "openswap-python/docs/",
}

# Suppress warnings about missing native library during doc generation
autodoc_mock_imports = []
