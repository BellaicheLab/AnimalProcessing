"""Space-time affine transforms: combine a geometric registration matrix with a
temporal (frame) rescaling so animals can be registered across movies in time as
well as space.
"""

from typing import Literal

import numpy as np

from pyanimalprocessing.rescaling.timings import time_to_frame, update_time_step


def create_time_matrix_transform(
    frame_ref,
    time_ref,
    dt,
    temperature,
    geometric_matrix_transform,
    time_target,
    dimension: Literal["D2", "D3"] = "D2",
):
    """Build a time-augmented affine matrix (time row + geometric block).

    The leading axis carries the temperature-corrected frame rescaling onto
    ``time_target``; the trailing block is the geometric registration matrix.
    """
    dt_adjusted = update_time_step(dt, temperature)

    if dimension == "D2":
        matrix_transform = np.eye(4)
        matrix_transform[0, 0] = dt_adjusted
        target_frame = time_to_frame(time_target, time_ref, frame_ref, dt_adjusted)
        matrix_transform[0, -1] = -target_frame * dt_adjusted
        matrix_transform[1:, 1:] = np.array(geometric_matrix_transform)

    elif dimension == "D3":
        matrix_transform = np.eye(5)
        matrix_transform[0, 0] = dt_adjusted
        target_frame = time_to_frame(time_target, time_ref, frame_ref, dt_adjusted)
        matrix_transform[0, -1] = -target_frame * dt_adjusted
        matrix_transform[2:, 2:] = np.array(geometric_matrix_transform)

    return matrix_transform


def create_time_matrix_transform_from_zarr(
    animal, grid_name, time_target="00h00", dimension: Literal["D2", "D3"] = "D2"
):
    """Build the space-time affine for ``animal`` from its stored attrs.

    Reads the geometric ``matrix_transform`` from ``GRID/<grid_name>/GRID_PROPERTIES``.
    If the animal carries the temporal attrs (``frame_ref``/``time_ref``/``dt``/
    ``temperature``) the full space-time transform is built; otherwise a purely
    geometric transform with an identity time axis is returned (time-agnostic
    fixed images, e.g. the atlas).
    """
    grid_properties = animal.GRID[grid_name].GRID_PROPERTIES
    if "matrix_transform" not in grid_properties.attrs:
        raise KeyError(
            f"GRID/{grid_name}/GRID_PROPERTIES has no 'matrix_transform' attr"
        )
    geometric_matrix_transform = grid_properties.attrs["matrix_transform"]

    time_attrs = ("frame_ref", "time_ref", "dt", "temperature")
    if all(attr in animal.attrs for attr in time_attrs):
        return create_time_matrix_transform(
            animal.attrs["frame_ref"],
            animal.attrs["time_ref"],
            animal.attrs["dt"],
            animal.attrs["temperature"],
            geometric_matrix_transform,
            time_target,
            dimension,
        )

    # Time-agnostic fixed image: geometric block with an identity time axis.
    if dimension == "D2":
        matrix_transform = np.eye(4)
        matrix_transform[1:, 1:] = geometric_matrix_transform
    elif dimension == "D3":
        matrix_transform = np.eye(5)
        matrix_transform[2:, 2:] = geometric_matrix_transform
    return matrix_transform
