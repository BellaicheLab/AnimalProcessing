"""Python toolkit for tissue mechanics quantification and napari visualization.

Bridges MATLAB SAP/MAP analysis outputs with Python-based tensor processing,
spatial statistics, and interactive visualization via napari.
"""

import os
import platform

__version__ = "0.11.0"

PYANIMALPROCESSING_ROOT = os.path.abspath(os.path.dirname(__file__))

# joblib backend: loky everywhere except Windows (which needs multiprocessing).
JOBLIB_BACKEND = "multiprocessing" if platform.system() == "Windows" else "loky"
