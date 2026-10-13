"""Small shared helpers used across the registration / measurement / averaging /
plotting pipeline: verbose printing, joblib↔tqdm glue, zarr attr writing, and
matrix polar-decomposition.
"""

import warnings
from contextlib import contextmanager
from typing import Optional, Tuple

import joblib
import numpy as np
from numpy.typing import NDArray
from scipy.linalg import polar

import zarr


def _write_attrs(zarr_obj, **kwargs):
    """Write attributes to a zarr group or dataset."""
    if not isinstance(zarr_obj, (zarr.hierarchy.Group, zarr.core.Array)):
        raise TypeError("zarr_obj must be a Zarr group or dataset")
    for key, value in kwargs.items():
        zarr_obj.attrs[key] = value
    return zarr_obj


def _initialize_viewer(viewer: Optional["napari.Viewer"] = None, **kwargs) -> "napari.Viewer":
    if viewer is None:
        # Local import to avoid importing napari at module import time.
        import napari  # type: ignore

        viewer = napari.Viewer(**kwargs)
    return viewer


def _vprint(message: str, verbose: bool) -> None:
    if verbose:
        print(message)


def _set_warning_filters(verbose: bool) -> None:
    if verbose:
        warnings.filterwarnings("default")
    else:
        warnings.filterwarnings("ignore")


@contextmanager
def _tqdm_joblib(tqdm_object):
    """Patch joblib to report batch completion into a tqdm progress bar."""

    class TqdmBatchCompletionCallback(joblib.parallel.BatchCompletionCallBack):
        def __call__(self, *args, **kwargs):
            tqdm_object.update(n=self.batch_size)
            return super().__call__(*args, **kwargs)

    old_batch_callback = joblib.parallel.BatchCompletionCallBack
    joblib.parallel.BatchCompletionCallBack = TqdmBatchCompletionCallback
    try:
        yield tqdm_object
    finally:
        joblib.parallel.BatchCompletionCallBack = old_batch_callback
        tqdm_object.close()


def _extract_rotation_and_scaling(
    matrix_transform: NDArray, side="left"
) -> Tuple[NDArray, NDArray]:
    """Split a transformation matrix into rotation and scaling via polar decomposition."""
    rotation_matrix, scaling_matrix = polar(matrix_transform, side=side)
    return rotation_matrix, scaling_matrix


def _correct_matrix(matrix: NDArray, rotation_matrix: NDArray) -> NDArray:
    """Rotate a stack of 2x2 matrices by ``rotation_matrix`` (R M Rᵀ)."""
    matrix_reshaped = matrix.reshape(matrix.shape[:-1] + (2, 2))
    corrected_matrix = np.matmul(rotation_matrix, matrix_reshaped)
    corrected_matrix = np.matmul(corrected_matrix, rotation_matrix.T)
    return corrected_matrix.reshape(matrix.shape)
