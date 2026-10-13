"""Tensor-field utilities shared by the reader/plotting path: time-varying
Lagrangian grid origins from tracking data (:func:`compute_lagrangian_origins`),
unbiased weighted std across AOA samples, mask application to fields, and
percentile clamping of scalar/vector fields.
"""

import copy
import warnings

import numpy as np
import zarr

from pyanimalprocessing.rescaling.geometry import (
    map_points_to_movie,
    movie_frame_coordinate_system,
)


def compute_lagrangian_origins(
    target_backup,
    tracking_mask,
    time_ref="17h40",
    reference_animal=None,
):
    """Compute time-varying Lagrangian grid origins from tracking data.

    At the tensor time step closest to *time_ref*, assigns each cell label
    to its nearest grid box.  For every other time step, computes the mean
    centroid of each box's tracked cells.

    Uses :func:`~pyanimalprocessing.rescaling.geometry.movie_frame_coordinate_system`,
    so the returned origins live in the same image space as the Eulerian ones.

    Parameters
    ----------
    target_backup : zarr.hierarchy.Group
        Zarr group containing tensor datasets (the average/AOA backup).
    tracking_mask : np.ndarray, shape (n_frames, H, W)
        Division-agnostic cell labels (uint16).
    time_ref : str
        Developmental time in ``"HHhMM"`` format when the grid is set
        (default ``"17h40"``).
    reference_animal : zarr.hierarchy.Group, optional
        Registered animal store to place the origins onto (its SAP registration);
        see :func:`~pyanimalprocessing.rescaling.geometry.movie_frame_coordinate_system`.

    Returns
    -------
    np.ndarray, shape (T, Ny, Nx, 3)
        Lagrangian origins ``[t, y, x]``.  Grid boxes where all tracked
        labels have disappeared are set to NaN.
    """
    from collections import defaultdict

    from skimage.measure import regionprops

    from pyanimalprocessing.rescaling.timings import (
        find_closest_time_index,
        median_time,
    )

    n_frames = tracking_mask.shape[0]

    # ── 1. Coordinate system (placed onto reference_animal's movie) ──
    start_movie, start_grid, boxsizes, overlaps = movie_frame_coordinate_system(
        target_backup, reference_animal
    )

    # ── 2. Grid dimensions and frame arrays ───────────────────────────────
    Ny, Nx = target_backup.attrs["Size"]
    frame_array = np.array(target_backup.attrs["FrameArray"])
    time_array = target_backup.attrs["TimeArray"]
    T = len(frame_array)

    # ── 3. Build Eulerian grid ───────────
    tensor_dims = (T, Ny, Nx)
    slices = [slice(0, d) for d in tensor_dims]
    grid = np.mgrid[tuple(slices)]
    grid = np.moveaxis(grid, 0, -1).reshape(-1, 3)

    eulerian_origins = map_points_to_movie(
        grid[:, ::-1], start_grid, start_movie, overlaps, boxsizes
    ).reshape(T, Ny, Nx, 3)

    # ── 4. Frame mapping: tensor time index → tracking mask frame ─────────
    #    FrameArray midpoints (1-based) → 0-based tracking mask index
    frame_map = ((frame_array[:, 0] + frame_array[:, 1]) / 2).astype(int) - 1

    # ── 5. Find reference frame from time_ref ─────────────────────────────
    midpoints = [median_time(s, e) for s, e in time_array]
    t_ref_idx = find_closest_time_index(time_ref, midpoints)
    frame_ref = int(frame_map[t_ref_idx])

    if frame_ref < 0 or frame_ref >= n_frames:
        warnings.warn(
            f"time_ref '{time_ref}' maps to tracking frame {frame_ref} "
            f"(out of range [0, {n_frames})). "
            "Returning Eulerian origins unchanged."
        )
        return eulerian_origins

    # ── 6. Assign labels → grid boxes at frame_ref ────────────────────────
    # Grid step and origin in image pixels (from Eulerian origins)
    step_y = eulerian_origins[0, 1, 0, 1] - eulerian_origins[0, 0, 0, 1]
    step_x = eulerian_origins[0, 0, 1, 2] - eulerian_origins[0, 0, 0, 2]
    origin_y = eulerian_origins[0, 0, 0, 1]
    origin_x = eulerian_origins[0, 0, 0, 2]

    props_ref = regionprops(tracking_mask[frame_ref])
    grid_labels = defaultdict(list)
    for p in props_ref:
        cy, cx = p.centroid
        i = int(round((cy - origin_y) / step_y))
        j = int(round((cx - origin_x) / step_x))
        if 0 <= i < Ny and 0 <= j < Nx:
            grid_labels[(i, j)].append(p.label)

    # ── 7. Blank out grid boxes with no tracked cells ───────────────────
    lagrangian = eulerian_origins.copy()
    tracked_mask = np.zeros((Ny, Nx), dtype=bool)
    for i, j in grid_labels:
        tracked_mask[i, j] = True
    lagrangian[:, ~tracked_mask, :] = np.nan

    # ── 8. Track centroids through time ───────────────────────────────────
    for t_idx in range(T):
        movie_frame = int(frame_map[t_idx])
        if movie_frame < 0 or movie_frame >= n_frames:
            continue

        frame_centroids = {
            p.label: p.centroid for p in regionprops(tracking_mask[movie_frame])
        }
        for (i, j), labels in grid_labels.items():
            ys, xs = [], []
            for lbl in labels:
                if lbl in frame_centroids:
                    cy, cx = frame_centroids[lbl]
                    ys.append(cy)
                    xs.append(cx)
            if ys:
                lagrangian[t_idx, i, j, 1] = float(np.mean(ys))
                lagrangian[t_idx, i, j, 2] = float(np.mean(xs))
            else:
                lagrangian[t_idx, i, j, :] = np.nan

    return lagrangian


def get_unbiased_weighted_std_matrix_aoa(sample_tensors, mean_tensor, weights):
    """Unbiased weighted std over the last (animal) axis for average-over-animals maps.

    The bias term ignores weights where the sample is NaN, and the variance is
    summed over the final animal axis of
    ``(t, c, y, x, prop, num_animals)`` inputs. Returns an array shaped like ``mean_tensor``.
    """
    mean_tensor = np.expand_dims(mean_tensor, axis=-1)
    mean_tensor = np.repeat(mean_tensor, sample_tensors.shape[-1], axis=-1)

    # For bias, ignore weights where samples are NaN.
    weights_for_bias = np.where(np.isnan(sample_tensors), np.nan, weights)
    sum_weight = np.nansum(weights_for_bias, axis=-1, keepdims=True)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")  # suppress division-by-zero for empty bins
        bias = sum_weight / (
            sum_weight**2 - np.nansum(weights_for_bias**2, axis=-1, keepdims=True)
        )

    weighted_variance = np.nansum(
        weights * (sample_tensors - mean_tensor) ** 2, axis=-1
    )
    return np.sqrt(bias.squeeze(axis=-1) * weighted_variance)


def mask_fields(fields, masks, frame_offset=0):
    """Apply circular spatial masks to tensor field arrays.

    Sets masked grid positions to NaN so plotting skips them.

    Parameters
    ----------
    fields : tuple of 4 arrays
        ``(origins_vectors, origins_values, vectors, values)``

        - origins_vectors shape: ``(T, Ny, Nx, 3)`` — ``(t, y, x)`` coords
        - origins_values  shape: ``(T, Ny, Nx, 3)`` — ``(t, y, x)`` coords
        - vectors         shape: ``(T, Ny, Nx, 2, 3)``
        - values          shape: ``(T, Ny, Nx)``
    masks : list of dict
        Each dict has keys ``center`` ``[y, x]``, ``radius`` (pixels), and
        optional ``frames`` ``[start, end]`` (inclusive, in **viewer**
        coordinates). If ``frames`` is absent or ``None``, the mask
        applies to all frames.
    frame_offset : int
        Offset to convert viewer frame numbers to array indices.
        Typically ``startFrame - 1`` where ``startFrame`` comes from
        the movie's FrameArray computation.  Array index =
        viewer frame − frame_offset.

    Returns
    -------
    tuple of 4 arrays
        Masked copies of the input arrays.
    """
    import logging

    from scipy.spatial.distance import cdist

    logger = logging.getLogger(__name__)

    if not masks:
        return fields

    # Some field components may be None (e.g. scalar quantities have no
    # origins_vectors/vectors, velocity has no origins_values/values).
    copied = tuple(a.copy() if a is not None else None for a in fields)

    # Pick the first non-None origin array to read grid geometry from.
    # Prefer origins_vectors (index 0), fall back to origins_values (index 1).
    ref_origins = copied[0] if copied[0] is not None else copied[1]
    if ref_origins is None:
        logger.warning("mask_fields: no origin arrays available, skipping")
        return fields

    n_frames = ref_origins.shape[0]

    # Grid (y, x) positions are the same at every frame but some frames
    # may be all-NaN (e.g. frame 0 is before the data window).  Use
    # nanmean across time to recover the spatial grid reliably.
    grid_yx = np.nanmean(ref_origins[:, :, :, 1:], axis=0)  # (Ny, Nx, 2)
    ny, nx = grid_yx.shape[:2]
    grid_flat = grid_yx.reshape(-1, 2)  # (Ny*Nx, 2)

    total_positions_masked = 0
    for mask in masks:
        center = np.array(mask["center"], dtype=float).reshape(1, 2)
        radius = float(mask["radius"])
        frame_range = mask.get("frames")

        # Spatial selection: grid points within radius
        dists = cdist(grid_flat, center).ravel()  # (Ny*Nx,)
        spatial_mask_flat = dists <= radius
        n_hit = int(spatial_mask_flat.sum())
        if n_hit == 0:
            continue
        spatial_mask = spatial_mask_flat.reshape(ny, nx)
        total_positions_masked += n_hit

        # Frame selection (convert viewer frames → array indices)
        if frame_range is not None:
            t_start = int(frame_range[0]) - frame_offset
            t_end = int(frame_range[1]) - frame_offset
            frame_slice = slice(max(t_start, 0), min(t_end + 1, n_frames))
        else:
            frame_slice = slice(None)

        for arr in copied:
            if arr is not None:
                arr[frame_slice, spatial_mask] = np.nan

    logger.info(
        "Applied %d mask(s): %d grid positions masked",
        len(masks),
        total_positions_masked,
    )
    return copied


# ---------------------------------------------------------------------------
# Outlier clamping
# ---------------------------------------------------------------------------


