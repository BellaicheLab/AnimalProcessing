"""Data I/O: MATLAB-to-zarr conversion, image stacks, and metadata extraction."""

from .zarr import convert_SAP_to_zarr, convert_MAP_to_zarr, convert_animal_to_zarr
from .matlab import loadmat, extract_SAP_info
from .image import load_stack, save_stack
