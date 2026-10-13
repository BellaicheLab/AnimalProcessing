"""Unified property rendering: :func:`read_property` turns a zarr backup quantity
(pyap-native or MATLAB-converted, SAP or AOA) into ready-to-plot inputs, and
:func:`plot_property` renders scalars, vectors, and 2x2 tensors in napari with
registration-aware rescaling, masks, and scale legends.
"""

from __future__ import annotations

import math
import numbers
from typing import Any, Dict, List, Literal, Optional, Sequence, Tuple, Union

import napari
import numpy as np
from dask import array as da
from tqdm import tqdm

import zarr
from pyanimalprocessing.plotting.property_utils import (
    OriginSource,
    OriginType,
    PropertyType,
    _affine_transform_sanity_check,
    _convert_matrix_to_scalars_and_vectors,
    _coords_to_centroids,
    _extract_channel,
    _keep_intersecting_cells,
    _property_data_sanity_checks,
    _property_origin_sanity_checks,
    add_dimension,
    create_plotting_vectors,
    generate_grid_mask,
    get_image_shape_coords_cell,
    get_image_shape_coords_grid,
)
from pyanimalprocessing.rescaling.geometry import box_centres_from_backup
from pyanimalprocessing.rescaling.registration import (
    _apply_matrix_transform_to_points,
)
from pyanimalprocessing.rescaling.temporal_alignment import (
    create_time_matrix_transform,
    create_time_matrix_transform_from_zarr,
)
from pyanimalprocessing.rescaling.timings import (
    find_frame,
    frame_to_time,
    median_time,
    update_time_step,
)
from pyanimalprocessing.utils import (
    _extract_rotation_and_scaling,
    _set_warning_filters,
    _vprint,
)


# Small, testable helpers to keep plot_property focused
def _normalize_plot_property_inputs(
    property_data: np.ndarray,
    property_origin: np.ndarray,
    property_color: dict | np.ndarray,
    property_name: Union[str, list[str]],
    scalar_scale: float | list[float],
    vector_scale: float | list[float],
    affine_transform: Optional[np.ndarray],
):
    """
    Normalize and validate inputs for plot_property, returning harmonized values.

    Returns a tuple:
        property_data, property_origin, property_color, property_name,
        scalar_scale_list, vector_scale_list, property_channel_number,
        affine_transform, origin_source, origin_dimension, origin_type
    """
    if not isinstance(property_data, np.ndarray):
        property_data = np.array(property_data)
    if not isinstance(property_origin, np.ndarray):
        property_origin = np.array(property_origin)
    if not isinstance(property_color, dict):
        property_color = {"color": np.array(property_color)}

    property_channel_number = property_data.shape[1]

    if not isinstance(property_name, list):
        property_name = [property_name] * property_channel_number
    if not isinstance(scalar_scale, list):
        scalar_scale = [scalar_scale] * property_channel_number
    if not isinstance(vector_scale, list):
        vector_scale = [vector_scale] * property_channel_number

    if affine_transform is not None and not isinstance(affine_transform, np.ndarray):
        affine_transform = np.array(affine_transform)

    origin_source, origin_dimension, origin_type = _property_origin_sanity_checks(
        property_data, property_origin
    )
    affine_transform = _affine_transform_sanity_check(
        affine_transform, origin_dimension
    )

    # If cell-centroid origins, drop the channel axis on origins
    if origin_source == OriginSource.CELL and origin_type == OriginType.CENTROID:
        property_origin = property_origin[:, 0]

    return (
        property_data,
        property_origin,
        property_color,
        property_name,
        scalar_scale,
        vector_scale,
        property_channel_number,
        affine_transform,
        origin_source,
        origin_dimension,
        origin_type,
    )


def _compute_rescaling_factors(
    affine_transform: np.ndarray,
    rescale_property: Literal["Full", "Rotation", "Iso_scaling"],
    unit_exponent: int,
    origin_dimension: OriginType | OriginSource | Any = None,
):
    """
    Compute scalar and vector rescaling factors from affine and unit exponent.
    """
    if rescale_property == "Iso_scaling":
        unit_exponent = 0

    # spatial 2x2 block lives at [-3:-1, -3:-1] for both 3x3/4x4/5x5 conventions used here
    general_scaling = np.sqrt(np.abs(np.linalg.det(affine_transform[-3:-1, -3:-1])))
    if rescale_property == "Rotation":
        rescaling_vectors = 1
        rescaling_scalars = 1
    else:
        rescaling_vectors = general_scaling ** (unit_exponent - 1)
        rescaling_scalars = general_scaling ** (unit_exponent)
        if rescaling_scalars == 1:
            # keep dtype as int when exactly one
            rescaling_scalars = 1

    return rescaling_scalars, rescaling_vectors, unit_exponent


# Helper to clip outliers by percentile for different property types
def _clip_outliers_percentile(
    data: np.ndarray,
    property_type: PropertyType,
    clipping_percentile: tuple[float, float],
) -> np.ndarray:
    """
    Replace outliers by NaNs according to percentile thresholds.

    For scalars: clip on values.
    For vectors: clip on L2 norm.
    For matrices: clip on the union of (trace) and (Frobenius norm of deviatoric part).
    """
    if clipping_percentile is None:
        return data

    q_low, q_high = float(clipping_percentile[0]), float(clipping_percentile[1])
    if not (0.0 <= q_low < q_high <= 1.0):
        raise ValueError(
            "clipping_percentile must be a tuple (low, high) with 0 <= low < high <= 1"
        )

    arr = np.asarray(data, dtype=float)

    if arr.ndim == 2:
        arr3 = arr[..., np.newaxis]
    elif arr.ndim == 3:
        arr3 = arr
    else:
        # Unsupported dimensionality for clipping; return as-is
        return arr

    t, n, m = arr3.shape

    if property_type == PropertyType.SCALAR:
        values = arr3[..., 0]
        lo = np.nanquantile(values, q_low)
        hi = np.nanquantile(values, q_high)
        mask = (values < lo) | (values > hi)
        arr3[mask, :] = np.nan

    elif property_type == PropertyType.VECTOR:
        norms = np.linalg.norm(arr3, axis=-1)
        lo = np.nanquantile(norms, q_low)
        hi = np.nanquantile(norms, q_high)
        mask = (norms < lo) | (norms > hi)
        arr3[mask, :] = np.nan

    elif property_type == PropertyType.MATRIX:
        side = int(round(np.sqrt(m)))
        if side * side != m:
            return arr3
        mats = arr3.reshape(t * n, side, side)
        tr = np.trace(mats, axis1=-2, axis2=-1).reshape(t, n)
        I = np.eye(side)[None, None, ...]
        dev = mats.reshape(t, n, side, side) - (tr[..., None, None] / side) * I
        dev_norm = np.linalg.norm(dev, axis=(-2, -1))

        tr_lo = np.nanquantile(tr, q_low)
        tr_hi = np.nanquantile(tr, q_high)
        dn_lo = np.nanquantile(dev_norm, q_low)
        dn_hi = np.nanquantile(dev_norm, q_high)
        mask = (tr < tr_lo) | (tr > tr_hi) | (dev_norm < dn_lo) | (dev_norm > dn_hi)
        arr3[mask, :] = np.nan

    else:
        # Unknown property type; leave unchanged
        return arr3 if arr.ndim == 3 else arr3[..., 0]

    if data.ndim == 2:
        return arr3[..., 0]
    return arr3


def _layer_exists(viewer: napari.Viewer, name: str) -> bool:
    return any(ly.name == name for ly in viewer.layers)


def _flatten_object_array(values: np.ndarray) -> np.ndarray:
    """Flatten values possibly stored in an object array (e.g. list of arrays per time)."""
    if isinstance(values, np.ndarray) and values.dtype == object:
        parts = []
        for v in values:
            if v is None:
                continue
            arr = np.asarray(v)
            if arr.size == 0:
                continue
            parts.append(
                arr.reshape(-1, arr.shape[-1]) if arr.ndim > 1 else arr.reshape(-1)
            )
        if len(parts) == 0:
            return np.array([], dtype=float)
        try:
            flat = np.concatenate(parts, axis=0)
        except ValueError:
            # Fallback to ravel if shapes mismatch
            flat = np.concatenate([p.ravel() for p in parts], axis=0)
        return flat
    else:
        arr = np.asarray(values)
        return arr.reshape(-1, arr.shape[-1]) if arr.ndim > 1 else arr.reshape(-1)


def _nice_round_from_distribution(
    median_value: float, values_for_spread: np.ndarray
) -> float:
    vals = np.asarray(values_for_spread, dtype=float)
    vals = vals[np.isfinite(vals)]
    if vals.size == 0:
        return float(np.round(median_value, 2))
    vals = np.abs(vals)
    q10 = np.nanpercentile(vals, 10)
    q90 = np.nanpercentile(vals, 90)
    spread = q90 - q10
    if not np.isfinite(spread) or spread <= 0:
        digits = 2
    else:
        order = int(math.floor(math.log10(spread)))
        digits = max(0, -order + 1)
        digits = min(digits, 4)
    return float(np.round(median_value, digits))


def _compute_median_scale_from_values(values: np.ndarray) -> float:
    vals = np.asarray(values, dtype=float)
    vals = vals[np.isfinite(vals)]
    if vals.size == 0:
        return 1.0
    vals = np.abs(vals)
    med = float(np.nanmedian(vals))
    if not np.isfinite(med) or med <= 0:
        pos = vals[vals > 0]
        med = float(np.nanmedian(pos)) if pos.size else 1.0
    return _nice_round_from_distribution(med, vals)


def _compute_timewise_scale_anchors(
    centroids: np.ndarray,
    margin_ratio: float = 0.05,
    fixed_position: Optional[Tuple[float, float]] = None,
) -> np.ndarray:
    """Return one anchor per time using a fixed (y, x) from the first timepoint.

    centroids: array of shape (m, d) with first column the time coordinate.
    """
    if centroids.size == 0:
        return np.zeros((0, centroids.shape[1]), dtype=float)
    d = centroids.shape[1]
    times = np.unique(centroids[:, 0].astype(int))
    if times.size == 0:
        return np.zeros((0, d), dtype=float)

    # Determine reference (y, x)
    if fixed_position is not None and len(fixed_position) == 2:
        y_ref, x_ref = float(fixed_position[0]), float(fixed_position[1])
    else:
        # From the first timepoint present
        t0 = int(times.min())
        ref_mask = centroids[:, 0].astype(int) == t0
        ref_pts = centroids[ref_mask]
        if ref_pts.size == 0:
            return np.zeros((0, d), dtype=float)
        y_ref_arr = ref_pts[:, -2]
        x_ref_arr = ref_pts[:, -1]
        y_min, y_max = np.nanmin(y_ref_arr), np.nanmax(y_ref_arr)
        x_min, x_max = np.nanmin(x_ref_arr), np.nanmax(x_ref_arr)
        if not np.all(np.isfinite([y_min, y_max, x_min, x_max])):
            return np.zeros((0, d), dtype=float)
        y_margin = (y_max - y_min) * margin_ratio
        x_margin = (x_max - x_min) * margin_ratio
        y_ref = y_max - y_margin
        x_ref = x_min + x_margin

    anchors = []
    for t in times:
        anchor = np.zeros((d,), dtype=float)
        anchor[0] = t
        anchor[-2] = y_ref
        anchor[-1] = x_ref
        anchors.append(anchor)
    return np.stack(anchors, axis=0) if anchors else np.zeros((0, d), dtype=float)


def _add_scalar_scale_legend(
    viewer: napari.Viewer,
    centroids: np.ndarray,
    affine_transform: np.ndarray,
    scale_value: float,
    quantity_name: str,
    scalar_scale: float,
    rescaling_factor: float,
    scalar_kwargs: Optional[Dict[str, Any]] = None,
    scale_legend_position: Optional[Tuple[float, float]] = None,
):
    if scale_value <= 0 or not np.isfinite(scale_value):
        return
    layer_name = f"scale_{quantity_name}_scalar"
    if _layer_exists(viewer, layer_name):
        return
    anchors = _compute_timewise_scale_anchors(
        centroids, fixed_position=scale_legend_position
    )
    if anchors.shape[0] == 0:
        return
    add_points_kwargs = {**(scalar_kwargs or {})}
    if "face_color" not in add_points_kwargs:
        add_points_kwargs["face_color"] = "white"
    sizes = np.full(
        (anchors.shape[0],), scale_value * scalar_scale * rescaling_factor, dtype=float
    )
    viewer.add_points(
        anchors,
        size=sizes,
        name=layer_name,
        affine=affine_transform,
        features={},
        text={
            "string": [f"{scale_value}"] * anchors.shape[0],
            "size": 12,
            "color": add_points_kwargs.get("border_color", "white"),
            "anchor": "upper_left",
        },
        **add_points_kwargs,
    )


def _add_vector_scale_legend(
    viewer: napari.Viewer,
    centroids: np.ndarray,
    affine_transform: np.ndarray,
    scale_value: float,
    quantity_name: str,
    vector_scale: float,
    rescaling_vectors: float,
    vectors_kwargs: Optional[Dict[str, Any]] = None,
    rescale_property: str = "Full",
    scale_legend_position: Optional[Tuple[float, float]] = None,
):
    if scale_value <= 0 or not np.isfinite(scale_value):
        return
    layer_name = f"scale_{quantity_name}_vector"
    if _layer_exists(viewer, layer_name):
        return
    anchors = _compute_timewise_scale_anchors(
        centroids, fixed_position=scale_legend_position
    )
    if anchors.shape[0] == 0:
        return
    # Build vectors pointing towards +X with requested magnitude
    vecs = np.zeros_like(anchors, dtype=float)
    vecs[:, -1] = scale_value * rescaling_vectors
    display_vectors = create_plotting_vectors(anchors, vecs, vector_scale)
    # Use a time-only affine (same strategy as _plot_vector)
    time_affine = affine_transform.copy()
    time_affine[1:, 1:] = np.eye(time_affine.shape[0] - 1)
    vw_kwargs = {**(vectors_kwargs or {})}
    vw_kwargs["visible"] = True
    viewer.add_vectors(
        display_vectors,
        name=layer_name,
        features={},
        affine=time_affine,
        **vw_kwargs,
    )
    # Add a tiny points layer for the text next to the vector anchor
    viewer.add_points(
        anchors,
        size=1,
        name=f"{layer_name}_text",
        affine=time_affine,
        features={},
        face_color="transparent",
        border_color="transparent",
        text={
            "string": [f"{scale_value}"] * anchors.shape[0],
            "size": 12,
            "color": vw_kwargs.get("edge_color", "white"),
            "anchor": "upper_left",
        },
    )


def _box_centres(backup, common_frame=False):
    """Box centres ``(Ny, Nx, 2)`` ``(y, x)`` for MATLAB stores with no stored centroids.

    Thin wrapper over :func:`rescaling.geometry.box_centres_from_backup` (shared with the
    converter's ``stamp_aoa_centroids``).
    """
    return box_centres_from_backup(backup, common_frame=common_frame)


def _grid_mask(backup, quantity, has_animals, significance, grid_bulk_threshold):
    """Per-box keep-mask (area-ratio + optional AOA significance), shaped for ``plot_property``.

    Returns ``(T, 1, Ny, Nx, K)`` with ``K=2`` for matrices (iso, dev) and ``K=1``
    otherwise, or ``None`` when there is nothing to mask (no thresholds, or a
    difference backup with no per-animal samples to compute significance from).
    """
    if not has_animals or (significance <= 0 and grid_bulk_threshold <= 0):
        return None
    raw = np.asarray(backup[quantity])[:, 0]                    # (T, Ny, Nx, comp, animals)
    area = np.asarray(backup["AreaRatios"])[:, 0, :, :, 0, :]   # (T, Ny, Nx, animals)
    mask = generate_grid_mask(
        properties=raw[..., 1:],
        weights=area[..., 1:] ** 2,
        mean_property=raw[..., 0],
        mean_weights=area[..., 0],
        min_sigma=significance or None,
        min_weight=grid_bulk_threshold,
    )
    if mask.ndim == 3:  # area-ratio-only mask -> broadcast to the iso/dev columns
        mask = np.repeat(mask[..., None], 2 if raw.shape[-2] == 4 else 1, axis=-1)
    return mask[:, None]  # add the channel axis


def read_property(
    backup,
    quantity,
    animal_number=0,
    reference_animal=None,
    significance=0,
    grid_bulk_threshold=0,
    lagrangian=False,
    tracking_mask=None,
    lagrangian_time_ref="17h40",
):
    """Read ``quantity`` from a backup group as ready-to-render :func:`plot_property` inputs.

    One schema-aware reader for both pyap-native and MATLAB-converted backups (which now
    share one layout). ``backup`` is the zarr backup group itself; the reader re-opens the
    store root to find the grid geometry and registration affine on its own. Across-animal
    (AOA) stacks carry a trailing animal axis (index 0 = mean); the mean is used by
    default, or pass ``animal_number`` to pick one. Returns the :func:`plot_property`
    kwargs, so the usage is ``plot_property(**read_property(backup, quantity), viewer=v)``.

    Pass ``reference_animal`` (a registered animal store) to overlay an averaged grid onto
    that animal's movie image: origins are placed via its SAP registration (see
    :func:`_box_centres`), 2-component vectors are reordered to image ``(y, x)``, and the
    affine carries only the animal's start-frame offset. ``significance`` /
    ``grid_bulk_threshold`` add the inter-animal + area-ratio ``property_origin_mask``;
    ``lagrangian`` replaces the origins with tissue-tracked ones.

    :param backup: The zarr backup group (``TIME_AVERAGE/<grid>[/<type>]/D2/<name>``, or a flat MATLAB AOA ``TENSORS/<field>``).
    :param quantity: Name of the quantity dataset inside ``backup``.
    :param animal_number: Trailing-axis index sliced from an AOA stack (0 = mean). Ignored for backups without an animal axis.
    :param reference_animal: Registered animal store whose movie the averaged grid is overlaid onto (None = plot in the common frame).
    :param significance: Minimum inter-animal significance (in sigmas) kept by ``property_origin_mask``; 0 disables.
    :param grid_bulk_threshold: Minimum mean area-ratio kept by ``property_origin_mask``; 0 disables.
    :param lagrangian: If True, replace the grid origins with tissue-tracked (Lagrangian) ones.
    :param tracking_mask: Tracking label movie used to compute the Lagrangian origins.
    :param lagrangian_time_ref: Developmental time ("XXhYY") at which cells are assigned to grid boxes for tracking.
    :return: Keyword arguments for :func:`plot_property` (``property_data``, ``property_origin``, ``affine_transform``, ``property_name``, ``property_origin_mask``).
    """
    arr = backup[quantity]  # zarr array — slice the needed animal before decompressing
    has_animals = arr.ndim == 6  # (T,1,Ny,Nx,comp,animals); difference backups are 5-D
    data = np.asarray(arr[..., animal_number]) if has_animals else np.asarray(arr)
    if reference_animal is not None and data.shape[-1] == 2:
        data = data[..., ::-1]  # 2-component vectors render in image (y, x) order

    root = zarr.open_group(store=backup.store, mode="r")
    # Nested backups (TIME_AVERAGE/<grid>/.../D2/<name>) carry grid geometry at
    # GRID/<grid>; flat MATLAB AOA backups (TENSORS/<field>) have none.
    parts = backup.name.strip("/").split("/")
    grid = (
        root["GRID"][parts[1]]
        if parts[0] == "TIME_AVERAGE" and "GRID" in root and parts[1] in root["GRID"]
        else None
    )
    gp = grid["GRID_PROPERTIES"] if grid is not None else None

    # Origins: tissue-tracked (Lagrangian), stored centroids (pyap SAP / nested AOA), or
    # box arithmetic (MATLAB-converted SAP that carries no centroids array).
    if lagrangian and tracking_mask is not None:
        from pyanimalprocessing.transformation.tensors import compute_lagrangian_origins

        origins = compute_lagrangian_origins(
            backup, tracking_mask, time_ref=lagrangian_time_ref, reference_animal=reference_animal
        )[..., 1:]  # drop the time column -> (T, Ny, Nx, 2)
    elif gp is not None and "centroids" in gp:
        origins = np.asarray(gp["centroids"])  # native SAP: GRID/<grid>/GRID_PROPERTIES
    elif "grid_centroids" in backup:
        origins = np.asarray(backup["grid_centroids"])  # native AOA + nested MATLAB AOA
    else:
        origins = _box_centres(backup, common_frame=reference_animal is not None)

    # Affine. Overlaying onto a reference animal: its inverse SAP registration maps the
    # archetype origins onto the movie's pixels; the time row carries the start-frame
    # offset. Lagrangian origins are already tracked in movie pixels (identity space).
    if reference_animal is not None:
        affine = np.eye(4)
        # Align to the reference MOVIE's frames: map the average's earliest developmental
        # time onto the movie via *its* frame reference. Using the backup's own FrameArray
        # would be wrong for a cross-genotype overlay (e.g. a Tolloi average on the vi
        # movie starts ~57 frames earlier in its own numbering).
        ra = reference_animal.attrs
        ta0 = np.asarray(backup.attrs["TimeArray"])[0]
        frame0 = find_frame(ra["frame_ref"], ra["time_ref"], ra["temperature"],
                            median_time(ta0[0], ta0[1]), ra["dt"])
        affine[0, -1] = int(np.floor(np.median(np.atleast_1d(frame0)))) - 1
        if not lagrangian:
            affine[1:, 1:] = np.linalg.inv(np.array(reference_animal.attrs["matrix_transform"]))
    elif "time_array" in backup and backup.attrs.get("time_step"):  # 0 for a single window
        ta = backup["time_array"]
        affine = create_time_matrix_transform(
            frame_ref=0,
            time_ref=median_time(ta[0][0], ta[0][1]),
            dt=backup.attrs["time_step"],
            temperature=25,  # time_step is already in developmental minutes
            geometric_matrix_transform=np.array(
                gp.attrs["matrix_transform"]
                if gp is not None and "matrix_transform" in gp.attrs
                else root.attrs.get("matrix_transform", np.eye(3))
            ),
            time_target="00h00",
        )
    else:
        affine = np.eye(4)
        affine[1:, 1:] = np.array(
            gp.attrs["matrix_transform"]
            if gp is not None and "matrix_transform" in gp.attrs
            else root.attrs.get("matrix_transform", np.eye(3))
        )

    return {
        "property_data": data,
        "property_origin": origins,
        "affine_transform": affine,
        "property_name": quantity,
        "property_origin_mask": _grid_mask(
            backup, quantity, has_animals, significance, grid_bulk_threshold
        ),
    }


def plot_property(
    property_data: np.ndarray,
    property_origin: np.ndarray,
    property_color={},
    affine_transform=None,
    property_origin_mask: Optional[np.ndarray] = None,
    property_name: Union[str, list[str]] = "property",
    viewer: Optional[napari.Viewer] = None,
    scalar_scale: float = 0.3,
    vector_scale: float = 0.3,
    rescale_property: Literal["Full", "Rotation", "Iso_scaling"] = "Full",
    unit_exponent: int = 0,  # Renamed parameter for clarity
    vectors_kwargs: Optional[Dict[str, Any]] = {},
    scalar_kwargs: Optional[Dict[str, Any]] = {},
    clipping_percentile: Optional[tuple[float, float]] = None,
    scale_legend: Union[bool, float] = False,
    scale_legend_position: Optional[Tuple[float, float]] = None,
    verbose: bool = False,
) -> napari.Viewer:
    """
    Visualizes a single animal property based on its dimensionality.

    :param property_data: The property data as a numpy array.
    :type property_data: np.ndarray
    :param property_origin: Origin of the plotted data (centroid or coordinate based).
    :type property_origin: np.ndarray
    :param property_color: Scalar backup to use for the color intensity of the property displayed.
    :type property_color: dict, optional
    :param affine_transform: Affine transform matrix to correct vectors and matrices (default is identity).
    :type affine_transform: np.ndarray, optional
    :param property_origin_mask: Boolean array to select the origins to plot, defaults to None.
    :type property_origin_mask: Optional[np.ndarray], optional
    :param property_name: The name of the property being visualized, defaults to "property".
    :type property_name: Union[str, list[str]]
    :param viewer: An instance of a napari Viewer. If None, a new viewer will be created, defaults to None.
    :type viewer: Optional[napari.Viewer], optional
    :param scalar_scale: Scale factor of the point layer to represent scalar properties, defaults to 0.3.
    :type scalar_scale: float, optional
    :param vector_scale: Scale factor of the vectors to represent vectorial properties, defaults to 0.3.
    :type vector_scale: float, optional
    :param rescale_property: A string indicating the type of rescaling to apply to the properties:
                    - 'Full': Apply full rescaling including rotation and scaling.
                    - 'Rotation': Apply only rotation without the scaling part.
                    - 'Iso_scaling': Apply the full rotation corrected from the isotropic scaling only.
    :type rescale_property: Literal['Full', 'Rotation', 'Iso_scaling'], optional
    :param unit_exponent: The exponent associated with the property unit, used to correct the visualization
                          by its dimensionality. For instance, set to 2 for areas, 3 for volumes, 1 for lengths,
                          and 0 for intensities. This reflects the exponent present on the distance unit.
    :type unit_exponent: int, optional
    :param vectors_kwargs: Dictionary of the napari vector layers parameters, defaults to {}.
    :type vectors_kwargs: Optional[Dict[str, Any]], optional
    :param scalar_kwargs: Dictionary of the napari points layers parameters, defaults to {}.
    :type scalar_kwargs: Optional[Dict[str, Any]], optional
    :param clipping_percentile: Tuple (low, high) in [0,1] to clip outliers by percentile; set to None to disable.
    :type clipping_percentile: Optional[tuple[float, float]], optional
    :param scale_legend: If False (default), no scale legend is drawn. If True, a legend is added with
                         the median magnitude (rounded nicely). If a float is provided, that value is
                         used instead of the median.
    :type scale_legend: Union[bool, float], optional
    :param scale_legend_position: Optional fixed (y, x) position for the scale legend. If None, the
                                  anchor is computed from the first timepoint bounding box.
    :type scale_legend_position: Optional[Tuple[float, float]]
    :param verbose: Whether to print verbose output, defaults to False.
    :type verbose: bool, optional

    :return: The napari Viewer instance used for visualization.
    :rtype: napari.Viewer

    **Example:**

    .. code-block:: python

        import napari
        import zarr
        from pyanimalprocessing.plotting.property_plotting import read_property, plot_property

        animal = zarr.open("path/to/animal.zarr")
        # Backups live under TIME_AVERAGE/<grid>[/<type>]/D2/<backup>
        backup = animal["TIME_AVERAGE"]["EULERIAN"]["D2"]["default"]

        viewer = napari.Viewer()
        plot_property(**read_property(backup, "EpsilonPIV"), viewer=viewer)
    """

    _set_warning_filters(verbose)

    if viewer is None:
        viewer = napari.Viewer()

    (
        property_data,
        property_origin,
        property_color,
        property_name,
        scalar_scale,
        vector_scale,
        property_channel_number,
        affine_transform,
        origin_source,
        origin_dimension,
        origin_type,
    ) = _normalize_plot_property_inputs(
        property_data,
        property_origin,
        property_color,
        property_name,
        scalar_scale,
        vector_scale,
        affine_transform,
    )

    rescaling_scalars, rescaling_vectors, unit_exponent = _compute_rescaling_factors(
        affine_transform, rescale_property, unit_exponent, origin_dimension
    )

    # Split channels
    property_data = _extract_channel(property_data)
    for key, value in property_color.items():
        property_color[key] = _extract_channel(value)
    if property_origin_mask is not None:
        property_origin_mask = _extract_channel(property_origin_mask)
    else:
        property_origin_mask = [None] * property_channel_number
    # Identifying the characteristics of the property
    # We check on only one channel
    property_type = _property_data_sanity_checks(property_data[0], origin_source)
    layer_number = 0
    for i, (
        channel_property_data,
        channel_property_name,
        channel_property_mask,
    ) in enumerate(zip(property_data, property_name, property_origin_mask)):
        channel_property_color = {
            key: value[i] for key, value in property_color.items()
        }
        # Handling all data source origins
        if origin_source == OriginSource.CELL:
            (
                intersected_channel_property_data,
                intersected_property_origin,
                intersected_channel_property_color,
            ) = _keep_intersecting_cells(
                channel_property_data, property_origin, channel_property_color
            )

            # Apply percentile clipping on the intersected data if requested
            if clipping_percentile is not None:
                intersected_channel_property_data = _clip_outliers_percentile(
                    intersected_channel_property_data,
                    property_type,
                    clipping_percentile,
                )

            for key, value in intersected_channel_property_color.items():
                intersected_channel_property_color[key] = (
                    add_dimension(
                        value,
                        n_dimensions=0,
                        add_zeros=True,
                    ).astype(float)
                    * rescaling_scalars
                )

            centroids = (
                _coords_to_centroids(intersected_property_origin)
                if origin_type == OriginType.COORD
                else intersected_property_origin
            )
            centroids = add_dimension(centroids, add_zeros=False).astype(float)
            _process_cell_origin_type(
                viewer,
                property_type,
                origin_type,
                intersected_channel_property_data,
                intersected_channel_property_color,
                channel_property_name,
                intersected_property_origin,
                centroids,
                affine_transform,
                scalar_scale[layer_number],
                scalar_kwargs,
                vector_scale[layer_number],
                vectors_kwargs,
                channel_property_data,
                rescale_property,
                rescaling_scalars,
                rescaling_vectors,
                scale_legend,
                scale_legend_position,
            )
        elif origin_source == OriginSource.GRID:
            channel_property_data = _process_grid_property_data(
                property_type, channel_property_data
            )

            # Apply percentile clipping on the grid-shaped data if requested
            if clipping_percentile is not None:
                channel_property_data = _clip_outliers_percentile(
                    channel_property_data, property_type, clipping_percentile
                )

            for key, value in channel_property_color.items():
                channel_property_color[key] = _process_grid_property_data(
                    PropertyType.SCALAR, value
                )
            for key, value in channel_property_color.items():
                channel_property_color[key] = (
                    add_dimension(
                        value,
                        n_dimensions=0,
                        add_zeros=True,
                    ).astype(
                        float
                    )[:, 0]
                    * scalar_scale
                )

            viewer = _process_grid_origin_type(
                viewer,
                origin_type,
                property_type,
                channel_property_data,
                channel_property_color,
                affine_transform,
                property_origin,
                rescaling_scalars,
                rescaling_vectors,
                channel_property_name,
                vector_scale[layer_number],
                scalar_scale[layer_number],
                vectors_kwargs,
                scalar_kwargs,
                rescale_property,
                channel_property_mask,
                scale_legend,
                scale_legend_position,
            )
        layer_number += 1

    return viewer


def _process_matrix(
    viewer,
    channel_property_data,
    centroids,
    features,
    affine_transform,
    property_name,
    vector_scale,
    vectors_kwargs,
    property_mask=None,
    rescale_property="Full",
    rescaling_scalars=1,
    rescaling_vectors=1,
    scalar_scale=None,
    scalar_func=None,
    scalar_kwargs=None,
    matrix_origin_info=None,
    tuple_type=None,
    clipping_percentile: Optional[tuple[float, float]] = None,
    scale_legend: Union[bool, float] = False,
    scale_legend_position: Optional[Tuple[float, float]] = None,
):
    """Processes vectors and scalars from the given property data and visualizes them using provided plotting functions.

    This function converts 2x2 or 3x3 matrix data into separate vectors and scalars, adjusts dimensions if necessary, and
    visualizes them using provided functions for scalar and vector plotting.

    :param viewer: Viewer object for plotting data.
    :param channel_property_data: np.ndarray, property data of channels to be processed.
    :param centroids: np.ndarray, coordinates of centroids corresponding to the property data.
    :param property_name: str, name of the property being processed.
    :param vector_scale: float, scale for vector visualization.
    :param vectors_kwargs: dict, additional keyword arguments for vector plotting.
    :param scalar_scale: float, scale for scalar visualization, defaults to None.
    :param scalar_func: function, function to plot scalar data, defaults to None.
    :param scalar_kwargs: dict, additional keyword arguments for scalar plotting, defaults to None.
    :return: Updated viewer object with the plotted data.
    """

    shape_matrix = int(np.sqrt(channel_property_data[0].shape[-1]))
    channel_property_data = (
        np.concatenate(
            [channel_property_data[time] for time in range(len(channel_property_data))],
            axis=0,
        )
        .reshape(-1, shape_matrix, shape_matrix)
        .astype(float)
    )

    # Apply clipping on tensors before transformation if requested
    if clipping_percentile is not None:
        flat = channel_property_data.reshape(channel_property_data.shape[0], -1)
        flat = _clip_outliers_percentile(flat, PropertyType.MATRIX, clipping_percentile)
        channel_property_data = flat.reshape(-1, shape_matrix, shape_matrix)

    if rescale_property == "Rotation":
        affine_to_correct, _ = _extract_rotation_and_scaling(
            affine_transform[-3:-1, -3:-1], side="right"
        )
    else:
        affine_to_correct = affine_transform[-3:-1, -3:-1]

    transformed_tensor = np.matmul(
        np.matmul(affine_to_correct * rescaling_vectors, channel_property_data),
        (affine_to_correct * rescaling_vectors).T,
    )
    vectors, scalars = _convert_matrix_to_scalars_and_vectors(transformed_tensor)
    scalars /= rescaling_scalars
    vectors /= rescaling_scalars
    if property_mask is not None:
        property_mask = property_mask.reshape(-1, 2)

        iso_mask = property_mask[:, 0]
        dev_mask = property_mask[:, 1]

        scalars[~iso_mask] = np.nan

        vector_mask = np.broadcast_to(
            dev_mask[:, None, None], vectors.shape
        )  # This expands the mask to (N, 1, 1)
        vectors[~vector_mask] = np.nan  # This flattens the vectors

    # This is an equivalent of the function add_dimension but for an array
    # that was already made flat (in the conversion above)

    if scalar_func:
        if scalar_func == _plot_scalar_property_grid:
            scalar_func(
                viewer=viewer,
                scalar=scalars,
                centroids=centroids,
                features={},
                scale=scalar_scale,
                affine_transform=affine_transform,
                quantity_name=property_name,
                scalar_kwargs=scalar_kwargs,
            )
        elif scalar_func == _plot_scalar_property_cell_coords:
            scalar_func(
                viewer=viewer,
                cell_property=scalars,
                property_name=property_name,
                coords=matrix_origin_info.get("coords"),
                affine_transform=affine_transform,
                property_is_flattened=matrix_origin_info.get(
                    "property_is_flattened", True
                ),
            )
        elif scalar_func == _plot_scalar_property_grid_coords:
            scalar_func(
                viewer=viewer,
                channel_property_data=scalars,
                property_name=property_name,
                affine_transform=affine_transform,
                coords=matrix_origin_info.get("coords"),
                property_is_flattened=matrix_origin_info.get(
                    "property_is_flattened", True
                ),
                tuple_type=tuple_type,
            )
    # Pad with zeros at the start to match centroid dimensions
    vectors = np.pad(
        vectors, ((0, 0), (0, 0), (centroids.shape[-1] - vectors.shape[-1], 0))
    )

    pos_vectors = vectors[:, 0]
    neg_vectors = vectors[:, 1]

    vectors_kwargs = {**vectors_kwargs, "vector_style": "line"}

    centroids[:, -2:] = _apply_matrix_transform_to_points(
        np.hstack((centroids[:, -2:], np.ones((centroids.shape[0], 1)))),
        affine_transform[-3:, -3:],
    )[:, :-1]

    affine_no_geometric_transform = affine_transform.copy()
    affine_no_geometric_transform[-3:-1, -3:-1] = np.eye(
        2
    )  # remove the geometrical component of the matrix, keep the time

    viewer = _plot_vector(
        viewer=viewer,
        vectors=pos_vectors,
        centroids=centroids,
        features=features,
        vector_scale=vector_scale,
        affine_transform=affine_no_geometric_transform,
        property_name=f"{property_name}_negative",
        vectors_kwargs=vectors_kwargs,
        rescale_property=rescale_property,
    )

    viewer = _plot_vector(
        viewer=viewer,
        vectors=neg_vectors,
        centroids=centroids,
        features=features,
        vector_scale=vector_scale,
        affine_transform=affine_no_geometric_transform,
        property_name=f"{property_name}_positive",
        vectors_kwargs=vectors_kwargs,
        rescale_property=rescale_property,
    )
    if vectors.shape[-2] == 3:
        viewer = _plot_vector(
            viewer=viewer,
            vectors=vectors[:, -1],
            centroids=centroids,
            features=features,
            vector_scale=vector_scale,
            affine_transform=affine_no_geometric_transform,
            property_name=f"{property_name}_third_axis",
            vectors_kwargs=vectors_kwargs,
            rescale_property=rescale_property,
        )

    # Add scale legends when requested and centroids are used (scalar_func implies centroids for scalars)
    if scale_legend and scalar_func in (
        _plot_scalar_property_grid,
        _plot_scalar_property_cell_coords,
    ):
        # Decide override or median
        scalar_scale_value = (
            float(scale_legend)
            if (
                isinstance(scale_legend, numbers.Real)
                and not isinstance(scale_legend, bool)
            )
            else _compute_median_scale_from_values(scalars)
        )
        _add_scalar_scale_legend(
            viewer=viewer,
            centroids=centroids,
            affine_transform=affine_transform,
            scale_value=scalar_scale_value,
            quantity_name=f"{property_name}_trace",
            scalar_scale=scalar_scale if scalar_scale is not None else 1.0,
            rescaling_factor=rescaling_scalars,
            scalar_kwargs=scalar_kwargs,
            scale_legend_position=scale_legend_position,
        )
        # Vector (deviatoric)
        dev_mags = np.linalg.norm(
            vectors.reshape(vectors.shape[0], -1, vectors.shape[-1])[:, 0:2, -2:],
            axis=-1,
        ).reshape(-1)
        vector_scale_value = (
            float(scale_legend)
            if (
                isinstance(scale_legend, numbers.Real)
                and not isinstance(scale_legend, bool)
            )
            else _compute_median_scale_from_values(dev_mags)
        )
        _add_vector_scale_legend(
            viewer=viewer,
            centroids=centroids,
            affine_transform=affine_no_geometric_transform,
            scale_value=vector_scale_value,
            quantity_name=f"{property_name}_deviatoric",
            vector_scale=vector_scale,
            rescaling_vectors=1.0,
            vectors_kwargs=vectors_kwargs,
            rescale_property=rescale_property,
            scale_legend_position=scale_legend_position,
        )

    return viewer


def _process_grid_property_data(property_type, channel_property_data):
    if property_type == PropertyType.SCALAR:
        channel_property_data = channel_property_data[..., np.newaxis]
    channel_property_data = channel_property_data.reshape(
        channel_property_data.shape[0],
        -1,
        channel_property_data.shape[-1],
    )
    return channel_property_data


def _preprocess_centroids(property_origin, time_steps):
    if property_origin.ndim == 3:
        centroids = property_origin.reshape(-1, property_origin.shape[-1])
        centroids = np.tile(centroids, (time_steps, 1, 1))
    elif property_origin.ndim == 4:
        centroids = property_origin.reshape(
            property_origin.shape[0], -1, property_origin.shape[-1]
        )
    elif property_origin.ndim == 5:
        centroids = property_origin[:, 0].reshape(
            property_origin.shape[0], -1, property_origin.shape[-1]
        )
    else:
        raise (ValueError)
    centroids = add_dimension(centroids, add_zeros=False).astype(float)
    return centroids


def _process_cell_origin_type(
    viewer,
    property_type,
    origin_type,
    intersected_channel_property_data,
    intersected_channel_property_color,
    property_name,
    intersected_property_origin,
    centroids,
    affine_transform,
    scalar_scale,
    scalar_kwargs,
    vector_scale,
    vectors_kwargs,
    channel_property_data,
    rescale_property,
    rescaling_scalars,
    rescaling_vectors,
    scale_legend: Union[bool, float] = False,
    scale_legend_position: Optional[Tuple[float, float]] = None,
):
    if property_type == PropertyType.SCALAR:
        if origin_type == OriginType.COORD:
            _plot_scalar_property_cell_coords(
                viewer=viewer,
                cell_property=intersected_channel_property_data,
                property_name=property_name,
                coords=intersected_property_origin,
                affine_transform=affine_transform,
                rescaling_factor=rescaling_scalars,
            )

        elif origin_type == OriginType.CENTROID:
            scalars = add_dimension(
                intersected_channel_property_data,
                n_dimensions=0,
                add_zeros=True,
            ).astype(float)

            _plot_scalar_property_grid(
                viewer=viewer,
                scalar=scalars,
                centroids=centroids,
                features=intersected_channel_property_color,
                affine_transform=affine_transform,
                scale=scalar_scale,
                quantity_name=property_name,
                scalar_kwargs=scalar_kwargs,
                rescaling_factor=rescaling_scalars,
            )
            # Add scalar scale legend (centroids only) when requested
            if scale_legend:
                flat_vals = _flatten_object_array(intersected_channel_property_data)
                scale_val = (
                    float(scale_legend)
                    if (
                        isinstance(scale_legend, numbers.Real)
                        and not isinstance(scale_legend, bool)
                    )
                    else _compute_median_scale_from_values(flat_vals)
                )
                _add_scalar_scale_legend(
                    viewer=viewer,
                    centroids=centroids,
                    affine_transform=affine_transform,
                    scale_value=scale_val,
                    quantity_name=property_name,
                    scalar_scale=scalar_scale,
                    rescaling_factor=rescaling_scalars,
                    scalar_kwargs=scalar_kwargs,
                    scale_legend_position=scale_legend_position,
                )
    elif property_type == PropertyType.VECTOR:
        # Add zeros column to match the dimension of the centroids

        vectors = add_dimension(
            intersected_channel_property_data,
            n_dimensions=centroids[0].shape[-1]
            - intersected_channel_property_data[0].shape[-1],
            add_zeros=True,
        ).astype(float)

        vectors[..., -2:] *= rescaling_vectors
        centroids[:, -2:] = _apply_matrix_transform_to_points(
            np.hstack((centroids[:, -2:], np.ones((centroids.shape[0], 1)))),
            affine_transform[-3:, -3:],
        )[:, :-1]
        viewer = _plot_vector(
            viewer=viewer,
            vectors=vectors,
            centroids=centroids,
            features=intersected_channel_property_color,
            affine_transform=affine_transform,
            vector_scale=vector_scale,
            property_name=property_name,
            vectors_kwargs=vectors_kwargs,
            rescale_property=rescale_property,
        )
        # Add vector scale legend when requested
        if scale_legend:
            raw_vecs = _flatten_object_array(intersected_channel_property_data)
            if raw_vecs.ndim == 1:
                raw_vecs = raw_vecs.reshape(-1, 2)
            mags = np.linalg.norm(np.asarray(raw_vecs, dtype=float)[..., -2:], axis=-1)
            scale_val = (
                float(scale_legend)
                if (
                    isinstance(scale_legend, numbers.Real)
                    and not isinstance(scale_legend, bool)
                )
                else _compute_median_scale_from_values(mags)
            )
            _add_vector_scale_legend(
                viewer=viewer,
                centroids=centroids,
                affine_transform=affine_transform,
                scale_value=scale_val,
                quantity_name=property_name,
                vector_scale=vector_scale,
                rescaling_vectors=rescaling_vectors,
                vectors_kwargs=vectors_kwargs,
                rescale_property=rescale_property,
                scale_legend_position=scale_legend_position,
            )
    elif property_type == PropertyType.MATRIX:
        scalar_func = (
            _plot_scalar_property_grid
            if origin_type == OriginType.CENTROID
            else _plot_scalar_property_cell_coords
        )
        matrix_origin_info = (
            {
                "scale": scalar_scale,
            }
            if origin_type == OriginType.CENTROID
            else {
                "coords": intersected_property_origin,
                "property_is_flattened": True,
            }
        )
        viewer = _process_matrix(
            viewer=viewer,
            channel_property_data=intersected_channel_property_data,
            centroids=centroids,
            features=intersected_channel_property_color,
            affine_transform=affine_transform,
            property_name=property_name,
            vector_scale=vector_scale,
            vectors_kwargs=vectors_kwargs,
            scalar_scale=scalar_scale,
            rescale_property=rescale_property,
            rescaling_scalars=rescaling_scalars,
            rescaling_vectors=rescaling_vectors,
            scalar_func=scalar_func,
            scalar_kwargs=scalar_kwargs,
            matrix_origin_info=matrix_origin_info,
            clipping_percentile=None,
            scale_legend=scale_legend,
            scale_legend_position=scale_legend_position,
        )

    return viewer


def _process_grid_origin_type(
    viewer,
    origin_type,
    property_type,
    channel_property_data,
    features,
    affine_transform,
    property_origin,
    rescaling_salars,
    rescaling_vectors,
    property_name,
    vector_scale,
    scalar_scale,
    vectors_kwargs,
    scalar_kwargs,
    rescale_property,
    property_mask,
    scale_legend: Union[bool, float] = False,
    scale_legend_position: Optional[Tuple[float, float]] = None,
):
    if origin_type == OriginType.CENTROID:
        centroids = _preprocess_centroids(
            property_origin, channel_property_data.shape[0]
        )
        if property_type == PropertyType.SCALAR:
            _plot_scalar_property_grid(
                viewer=viewer,
                scalar=channel_property_data,
                centroids=centroids,
                features=features,
                scale=scalar_scale,
                quantity_name=property_name,
                affine_transform=affine_transform,
                property_mask=property_mask,
                scalar_kwargs=scalar_kwargs,
                rescaling_factor=rescaling_salars,
            )
            # Add scalar scale legend for grid-centroid
            if scale_legend:
                scale_val = (
                    float(scale_legend)
                    if (
                        isinstance(scale_legend, numbers.Real)
                        and not isinstance(scale_legend, bool)
                    )
                    else _compute_median_scale_from_values(channel_property_data)
                )
                _add_scalar_scale_legend(
                    viewer=viewer,
                    centroids=centroids,
                    affine_transform=affine_transform,
                    scale_value=scale_val,
                    quantity_name=property_name,
                    scalar_scale=scalar_scale,
                    rescaling_factor=rescaling_salars,
                    scalar_kwargs=scalar_kwargs,
                    scale_legend_position=scale_legend_position,
                )
        elif property_type == PropertyType.VECTOR:
            vectors = add_dimension(
                channel_property_data,
                n_dimensions=centroids[0].shape[-1]
                - channel_property_data[0].shape[-1],
                add_zeros=True,
            ).astype(float)

            vectors[..., -2:] *= rescaling_vectors
            centroids[:, -2:] = _apply_matrix_transform_to_points(
                np.hstack((centroids[:, -2:], np.ones((centroids.shape[0], 1)))),
                affine_transform[-3:, -3:],
            )[:, :-1]

            viewer = _plot_vector(
                viewer=viewer,
                vectors=vectors,
                centroids=centroids,
                features=features,
                vector_scale=vector_scale,
                property_name=property_name,
                vectors_kwargs={"vector_style": "triangle", **vectors_kwargs},
                affine_transform=affine_transform,
                property_mask=property_mask,
                rescale_property=rescale_property,
            )
            # Add vector scale legend for grid-centroid
            if scale_legend:
                mags = np.linalg.norm(
                    np.asarray(channel_property_data, dtype=float)[..., -2:], axis=-1
                )
                scale_val = (
                    float(scale_legend)
                    if (
                        isinstance(scale_legend, numbers.Real)
                        and not isinstance(scale_legend, bool)
                    )
                    else _compute_median_scale_from_values(mags)
                )
                _add_vector_scale_legend(
                    viewer=viewer,
                    centroids=centroids,
                    affine_transform=affine_transform,
                    scale_value=scale_val,
                    quantity_name=property_name,
                    vector_scale=vector_scale,
                    rescaling_vectors=rescaling_vectors,
                    vectors_kwargs=vectors_kwargs,
                    rescale_property=rescale_property,
                    scale_legend_position=scale_legend_position,
                )
        elif property_type == PropertyType.MATRIX:
            viewer = _process_matrix(
                viewer=viewer,
                channel_property_data=channel_property_data,
                centroids=centroids,
                features=features,
                affine_transform=affine_transform,
                property_name=property_name,
                vector_scale=vector_scale,
                vectors_kwargs={"vector_style": "line", **vectors_kwargs},
                scalar_scale=scalar_scale,
                scalar_kwargs=scalar_kwargs,
                scalar_func=_plot_scalar_property_grid,
                rescale_property=rescale_property,
                rescaling_scalars=rescaling_salars,
                rescaling_vectors=rescaling_vectors,
                property_mask=property_mask,
                clipping_percentile=None,
                scale_legend=scale_legend,
                scale_legend_position=scale_legend_position,
            )

    elif origin_type == OriginType.COORD:
        # the issue is that coords is in argwhere and mask_positions is in where
        if isinstance(property_origin.item(0), tuple):
            tuple_type = 1
        else:
            tuple_type = 0
        if property_origin.ndim < 3:
            coords = np.concatenate(
                [
                    property_origin[np.newaxis, ...]
                    for _ in range(channel_property_data.shape[0])
                ],
                axis=0,
            )

            coords = np.reshape(coords, (coords.shape[0], -1))
        else:
            coords = property_origin.reshape(property_origin.shape[0], -1)
        if property_type == PropertyType.SCALAR:
            _plot_scalar_property_grid_coords(
                viewer=viewer,
                channel_property_data=channel_property_data * rescaling_salars,
                property_name=property_name,
                coords=coords,
                affine_transform=affine_transform,
                property_mask=property_mask,
                tuple_type=tuple_type == 1,
            )
        else:
            centroids = _coords_to_centroids(
                property_origin.reshape(property_origin.shape[0], -1), axis=tuple_type
            ).reshape(*property_origin.shape, 2)
            centroids = _preprocess_centroids(centroids, channel_property_data.shape[0])
            if property_type == PropertyType.VECTOR:

                vectors = add_dimension(
                    channel_property_data,
                    n_dimensions=centroids[0].shape[-1]
                    - channel_property_data[0].shape[-1],
                    add_zeros=True,
                ).astype(float)
                vectors[..., -2:] *= rescaling_vectors
                centroids[:, -2:] = _apply_matrix_transform_to_points(
                    np.hstack((centroids[:, -2:], np.ones((centroids.shape[0], 1)))),
                    affine_transform[-3:, -3:],
                )[:, :-1]

                viewer = _plot_vector(
                    viewer=viewer,
                    vectors=vectors,
                    centroids=centroids,
                    features=features,
                    vector_scale=vector_scale,
                    property_name=property_name,
                    vectors_kwargs=vectors_kwargs,
                    affine_transform=affine_transform,
                    property_mask=property_mask,
                    rescale_property=rescale_property,
                )

            elif property_type == PropertyType.MATRIX:
                scalar_func = _plot_scalar_property_grid_coords

                matrix_origin_info = {
                    "coords": coords,
                    "property_is_flattened": True,
                }

                viewer = _process_matrix(
                    viewer=viewer,
                    channel_property_data=channel_property_data,
                    centroids=centroids,
                    features=features,
                    affine_transform=affine_transform,
                    property_name=property_name,
                    vector_scale=vector_scale,
                    vectors_kwargs=vectors_kwargs,
                    scalar_scale=scalar_scale,
                    scalar_func=scalar_func,
                    scalar_kwargs=scalar_kwargs,
                    rescale_property=rescale_property,
                    property_mask=property_mask,
                    rescaling_scalars=rescaling_salars,
                    rescaling_vectors=rescaling_vectors,
                    matrix_origin_info=matrix_origin_info,
                    tuple_type=tuple_type == 1,
                    clipping_percentile=None,
                    scale_legend=scale_legend,
                    scale_legend_position=scale_legend_position,
                )
    return viewer


def plot_rescaling(
    animals: List[zarr.hierarchy.group],
    dimension="D2",
    grid_type="eulerian",
    grid_name=None,
    viewer=None,
    verbose: bool = False,
    show_time_legend: bool = True,
    lazy_load: bool = True,
) -> None:
    """
    Allows to see the rescaled animals to appreciate quality of affine transformation and aligns them in time.

    :param animals: List of animals zarrs instantiated, space registered for which a common grid was generated (either using average_over_space or generate_grid).
    :param dimension: The dimension to plot (default: "D2").
    :param grid_type: The grid type to use for transformation (default: "eulerian").
    :param viewer: Napari viewer instance (optional).
    :param verbose: Whether to print verbose output (default: False).
    :param show_time_legend: Whether to show a time legend (default: True).
    :type animals: list
    """
    if not isinstance(animals, list):
        animals = [animals]
    if viewer is None:
        viewer = napari.Viewer()

    time_ref = "00h00"
    group_key = grid_name if grid_name is not None else grid_type.upper()

    # For storing image boundaries to use with the time legend
    max_boundaries = [0, 0]
    matrix_transform = None
    for i, animal in enumerate(animals):
        _vprint(f"Adding animal {animal.attrs['name']} to viewer", verbose)

        # Extracting relevant parameters
        channel_names = [
            f"{name} - Transformed {animal.attrs['name']}"
            for name in animal.attrs["channels"]
        ]

        matrix_transform = create_time_matrix_transform_from_zarr(
            animal, group_key, time_ref, dimension=dimension
        )

        if lazy_load:
            raw = da.from_zarr(animal.IMAGE[dimension]["raw"])

            viewer.add_image(
                raw,
                visible=False,
                affine=matrix_transform,
                channel_axis=1,
                name=channel_names,
                blending="additive",
            )
        else:

            viewer.add_image(
                animal.IMAGE[dimension]["raw"],
                visible=False,
                affine=matrix_transform,
                channel_axis=1,
                name=channel_names,
                blending="additive",
            )

        # Update max boundaries based on image shape
        img_shape = animal.IMAGE[dimension]["raw"].shape[-2:]
        max_boundaries[0] = max(max_boundaries[0], img_shape[1])
        max_boundaries[1] = max(max_boundaries[1], img_shape[0])

    if show_time_legend and matrix_transform is not None:
        add_time_legend_from_animal(
            viewer,
            animals[-1],
            dimension,
            matrix_transform,
            max_boundaries[::-1],
        )

    return viewer


def add_time_legend_from_animal(
    viewer, animal, dimension, affine_transform, bbox_boundaries, legend_size=30
):
    """Adds a time legend to the viewer based on animal metadata."""
    if all(attr in animal.attrs for attr in ["frame_ref", "time_ref", "dt"]):
        frame_ref = animal.attrs["frame_ref"]
        time_ref = animal.attrs["time_ref"]
        dt = update_time_step(animal.attrs["dt"], animal.attrs["temperature"])
        n_frames = animal.IMAGE[dimension]["raw"].shape[0]
        frames = np.arange(n_frames)
        time_array = np.array(
            [frame_to_time(f, time_ref, frame_ref, dt) for f in frames]
        )
        _add_time_array_layer(
            viewer=viewer,
            bbox_boundaries=bbox_boundaries,
            time_array=time_array,
            legend_size=legend_size,
            affine_transform=affine_transform,
        )


def _add_time_array_layer(
    viewer,
    bbox_boundaries,
    time_array,
    legend_size,
    affine_transform,
    text_color="white",
):
    # Compute the bounding box based on image_size
    bbox = np.array(
        [
            [0, 0],  # Top-left corner
            [bbox_boundaries[0], 0],  # Top-right corner
            [bbox_boundaries[0], bbox_boundaries[1]],  # Bottom-right corner
            [0, bbox_boundaries[1]],  # Bottom-left corner
        ]
    )

    if time_array is not None:
        time_array = np.array(time_array)  # Convert to numpy array if it's not already

        if time_array.ndim == 2 and time_array.shape[1] == 2:
            # Handle 2D array case
            interval_case = True
        elif time_array.ndim == 1:
            # Handle 1D array case
            interval_case = False
        else:
            raise ValueError(f"Unexpected time_array shape: {time_array.shape}")

        bbox = bbox[np.newaxis, ...].repeat(len(time_array), axis=0)
        # t positions of the bbox
        z_pos = np.arange(len(time_array)).repeat(4).reshape(-1, 4)
        z_pos = z_pos[..., np.newaxis]
        # final bbox calculation
        bbox = np.concatenate([z_pos, bbox], axis=2)

        if interval_case:
            # Interval case
            features = {
                "beginning_interval": [
                    t[0].decode("utf-8") if isinstance(t[0], bytes) else str(t[0])
                    for t in time_array
                ],
                "ending_interval": [
                    t[1].decode("utf-8") if isinstance(t[1], bytes) else str(t[1])
                    for t in time_array
                ],
            }
            text_properties = {
                "string": "{beginning_interval} - {ending_interval}",
                "anchor": "upper_right",
                "size": legend_size,
                "color": text_color,
                "affine": affine_transform,
            }
        else:
            # Single time point case
            features = {
                "frame_time": [
                    t.decode("utf-8") if isinstance(t, bytes) else str(t)
                    for t in time_array
                ]
            }
            text_properties = {
                "string": "{frame_time}",
                "anchor": "upper_right",
                "size": legend_size,
                "color": text_color,
                "affine": affine_transform,
            }

        time_layer = viewer.add_shapes(
            bbox,
            features=features,
            text=text_properties,
            face_color="transparent",
            edge_color="transparent",
            affine=affine_transform,
        )
        return time_layer


def _plot_scalar_property_grid_coords(
    viewer: napari.Viewer,
    channel_property_data: np.ndarray,
    property_name: str,
    coords: list,
    affine_transform=None,
    property_is_flattened=False,
    property_mask=None,
    tuple_type=None,
) -> None:
    """
    Plot scalar properties of cells on a napari viewer.

    :param viewer: An instance of a napari Viewer.
    :param cell_property: A numpy array containing the scalar properties of cells.
    :param property_name: The name of the property to visualize.
    :param coords: A list of numpy arrays containing the coordinates of cells.
    :param animal: A dictionary containing animal data, including the image to base the property visualization on.
    :param dimension: The dimension ("D2" or "D3") of the data to visualize.
    """


    if property_mask is not None:
        property_mask = property_mask.reshape(property_mask.shape[0], -1)

    # Generate image
    if tuple_type:
        image_shape = get_image_shape_coords_grid(coords)
    else:
        image_shape = get_image_shape_coords_cell(coords)

    floats = np.issubdtype(channel_property_data.dtype, np.floating)
    if floats:
        property_image = np.full(
            (coords.shape[0], *image_shape), np.nan, dtype=np.float16
        )
    else:
        property_image = np.full((coords.shape[0], *image_shape), 0, dtype=np.uint16)

    if property_is_flattened:
        # Calculate cumulative indices for each time point
        property_counts = [coord.shape[0] for coord in coords]
        cumulative_indices = np.cumsum([0] + property_counts)[:-1]
    for time in tqdm(range(coords.shape[0])):
        for i, coord in enumerate(coords[time]):
            if not tuple_type:
                coord = tuple(coord.T)
            if not property_is_flattened:
                value = channel_property_data[time][i]

                if (floats or value > 0) and (property_mask is None or property_mask[time][i]):
                    property_image[time][coord] = value
            else:
                flat_index = cumulative_indices[time] + i
                value = channel_property_data[flat_index]
                if (floats or value > 0) and (property_mask is None or property_mask[time][i]):
                    property_image[time][coord] = value

    if floats:
        viewer.add_image(property_image, name=property_name, affine=affine_transform)
    else:
        viewer.add_labels(property_image, name=property_name, affine=affine_transform)


def _plot_scalar_property_cell_coords(
    viewer: napari.Viewer,
    cell_property: np.ndarray,
    property_name: str,
    coords: list,
    property_is_flattened=False,
    affine_transform=None,
    is_grid=False,
    rescaling_factor=1,
) -> None:
    """
    Plot scalar properties of cells on a napari viewer.

    :param viewer: An instance of a napari Viewer.
    :param cell_property: A numpy array containing the scalar properties of cells.
    :param property_name: The name of the property to visualize.
    :param coords: A list of numpy arrays containing the coordinates of cells.
    :param animal: A dictionary containing animal data, including the image to base the property visualization on.
    :param dimension: The dimension ("D2" or "D3") of the data to visualize.
    """

    # Generate image
    image_shape = get_image_shape_coords_cell(coords)

    # In the case where the property is already flattened (t,n ,cells -> tn, cells)
    # we need use the coords to count in which frames the labels go
    if property_is_flattened:
        # Calculate cumulative indices for each time point
        property_counts = [coord.shape[0] for coord in coords]
        cumulative_indices = np.cumsum([0] + property_counts)[:-1]

    first = cell_property[(0,) * cell_property.ndim]
    if isinstance(first, np.ndarray):
        if np.issubdtype(first.dtype, np.integer):
            floats = False
        else:
            floats = True
    else:
        if isinstance(first, int):
            floats = False
        else:
            floats = True

    if floats:
        property_image = np.full(
            (coords.shape[0], *image_shape), np.nan, dtype=np.float16
        )
    else:
        property_image = np.zeros((coords.shape[0], *image_shape), dtype=np.uint16)

    for time in range(coords.shape[0]):
        for i, coord in enumerate(coords[time]):
            if property_is_flattened:
                flat_index = cumulative_indices[time] + i

                property_image[time][tuple(coord.T)] = (
                    cell_property[flat_index] * rescaling_factor
                )

            else:
                property_image[time][tuple(coord.T)] = (
                    cell_property[time][..., 0][i] * rescaling_factor
                )

    if floats:
        viewer.add_image(property_image, name=property_name, affine=affine_transform)
    else:
        viewer.add_labels(property_image, name=property_name, affine=affine_transform)


def _plot_scalar_property_grid(
    viewer: napari.Viewer,
    scalar: np.ndarray,
    centroids: np.ndarray,
    features: dict,
    affine_transform: np.ndarray,
    scale: float,
    quantity_name: str,
    scalar_kwargs={"border_color": "red"},
    property_mask=None,
    rescaling_factor=1,
):
    """
    Adds value layers to a napari viewer, distinguishing between positive and negative values.

    This function creates two layers of points on the viewer: one for positive values and one for negative values. The size of each point is determined by its associated value multiplied by a scale factor. Positive values are indicated with a white face color, while negative values use grey.

    :param viewer: An instance of a napari Viewer.
    :param values: A numpy array containing the values associated with each point. Positive and negative values are treated separately.
    :param origins: A numpy array containing the origins (coordinates) of the points.
    :param scale: A scaling factor for the size of the points.
    :param quantity_name: A string that serves as a prefix to the name of the layers added to the viewer.
    :param value_kwargs: the parameters for the point layer.
    """
    scalar[np.isinf(scalar.astype(float))] = 0

    if property_mask is not None:
        property_mask = property_mask.flatten()
        centroids[~property_mask] = np.nan
    scalar = scalar.flatten()
    scalar[np.any(np.isnan(centroids), axis=-1)] = np.nan

    positive_mask = scalar > 0
    negative_mask = scalar < 0

    add_points_kwargs = {**scalar_kwargs}
    if centroids[positive_mask].shape[0] > 0:
        if "face_color" not in scalar_kwargs:
            add_points_kwargs["face_color"] = "white"
        viewer.add_points(
            centroids[positive_mask],
            size=scalar[positive_mask] * scale * rescaling_factor,
            name=f"positive_{quantity_name}",
            affine=affine_transform,
            features={key: item[positive_mask] for key, item in features.items()},
            **add_points_kwargs,
        )
        if features != {}:
            viewer.layers[-1].face_color_mode = "colormap"

    if centroids[negative_mask].shape[0] > 0:
        if "face_color" not in scalar_kwargs:
            add_points_kwargs["face_color"] = "grey"
        viewer.add_points(
            centroids[negative_mask],
            size=-scalar[negative_mask] * scale * rescaling_factor,
            name=f"negative_{quantity_name}",
            affine=affine_transform,
            features={key: item[negative_mask] for key, item in features.items()},
            **add_points_kwargs,
        )
        if features != {}:
            viewer.layers[-1].face_color_mode = "colormap"


def _plot_vector(
    viewer: Optional[napari.Viewer],
    vectors: np.ndarray,
    centroids: np.ndarray,
    features,
    affine_transform: Optional[np.ndarray] = None,
    vector_scale: float = 1.0,
    property_name: str = "property",
    vectors_kwargs: Optional[Dict[str, Any]] = None,
    property_mask: Optional[np.ndarray] = None,
    rescale_property="Full",
) -> None:
    """
    Create and visualize vectors and values derived from a 4D tensor representing cell properties, on a napari viewer.

    :param viewer: An instance of a napari Viewer. If None, a new viewer will be created.
    :param vectors: A numpy array representing the vector to be plot (must have shape (t, n, 3) or (t, n, 4)).
    :param centroids: A numpy array containing the centroids of cells (must have shape (t, n, 3) or (t, n, 4)).
    :param vector_scale: The scale factor for visualizing the vectors. Default is 1.0.
    :param property_name: The base name for the property to visualize. Default is 'property'.
    :param vectors_kwargs: Additional keyword arguments to pass to the `add_vector_layers` function.
    """
    if viewer is None:
        viewer = napari.Viewer()

    if vectors_kwargs is None:
        vectors_kwargs = {}

    if property_mask is not None:
        vectors[~property_mask.reshape(-1)] = np.nan

    valid = ~np.any(np.isnan(vectors), axis=1) & ~np.any(np.isnan(centroids), axis=1)
    vectors = vectors[valid]
    centroids = centroids[valid]
    for key, value in features.items():
        features[key] = value[valid]
    affine_to_correct = affine_transform.copy()
    if rescale_property == "Rotation":
        rotation_matrix, _ = _extract_rotation_and_scaling(
            affine_transform[-3:-1, -3:-1], side="right"
        )
        affine_to_correct[-3:-1, -3:-1] = rotation_matrix
    vectors = _apply_matrix_transform_to_points(vectors, affine_to_correct[:-1, :-1])
    display_vectors = create_plotting_vectors(centroids, vectors, vector_scale)
    valid_mask = np.all(np.isfinite(display_vectors), axis=(1, 2))
    # Filter out invalid display_vectors
    valid_display_vectors = display_vectors[valid_mask]
    time_affine = affine_transform.copy()
    time_affine[1:, 1:] = np.eye(time_affine.shape[0] - 1)

    for key, value in features.items():
        features[key] = value[valid_mask]

    non_null_mask = np.all(np.linalg.norm(valid_display_vectors, axis=-1) > 0, axis=-1)
    valid_display_vectors = valid_display_vectors[non_null_mask]
    for key, value in features.items():
        features[key] = value[non_null_mask]

    viewer.add_vectors(
        valid_display_vectors,
        name=property_name,
        features=features,
        **vectors_kwargs,
        affine=time_affine,
    )
    return viewer


def add_scale_bar(
    viewer: napari.Viewer,
    pixel_size_yx_um: float | Sequence[float] = 0.161,
    pixel_size_z_um: float | None = None,
    *,
    bar_color: str | tuple[float, float, float, float] = "white",
    bar_box_color: tuple[float, float, float, float] = (0, 0, 0, 0.6),
    bar_position: str = "bottom_right",
    font_size: int = 12,
) -> None:
    """
    Propagate physical pixel sizes to every layer and show a clean scale bar.

    Parameters
    ----------
    viewer
        An active :class:`napari.Viewer`.
    pixel_size_xy_um
        Micrometre size of one pixel in (Y, X).  Pass a single float for square
        pixels or a 2-tuple for anisotropic imaging.
    pixel_size_z_um
        Z-step in micrometres.  Ignored when ``viewer`` data are ≥2-D only.
    bar_color, bar_box_color, bar_position, font_size
        Cosmetic scale-bar settings.
    """

    # -- normalise XY argument -------------------------------------------------
    if isinstance(pixel_size_yx_um, numbers.Real):
        size_y_um = size_x_um = float(pixel_size_yx_um)
    else:
        size_y_um, size_x_um = map(float, pixel_size_yx_um[:2])

    # -- update every layer that exposes .scale --------------------------------
    for layer in viewer.layers:
        if not hasattr(layer, "scale"):
            continue

        old_scale = list(layer.scale)
        new_scale = list(layer.scale)
        n = len(new_scale)

        if n >= 1:
            new_scale[-1] = size_x_um  # X
        if n >= 2:
            new_scale[-2] = size_y_um  # Y
        if pixel_size_z_um is not None and n >= 3:
            new_scale[-3] = float(pixel_size_z_um)  # Z

        layer.scale = tuple(new_scale)
        # Store original scale to allow clean inversion if the scale_bar layer is removed
        if hasattr(layer, "metadata"):
            layer.metadata["scalebar_prev_scale"] = tuple(old_scale)

        # Rescale affine translation components (Y, X) by the corresponding ratios
        fx = float(new_scale[-1]) / float(old_scale[-1]) if n >= 1 else 1.0
        fy = float(new_scale[-2]) / float(old_scale[-2]) if n >= 2 else 1.0

        affine_matrix = np.asarray(layer.affine)
        assert (
            affine_matrix.ndim == 2
            and affine_matrix.shape[0] >= 3
            and affine_matrix.shape[1] >= 3
        ), "Affine matrix must be 2D with at least 3x3 shape"

        # Rows -3 and -2 correspond to spatial Y and X; last row (-1) is homogeneous
        affine_matrix[-3, -1] *= fy  # Y translation
        affine_matrix[-2, -1] *= fx  # X translation
        layer.affine = affine_matrix

    # -- configure the scale bar ----------------------------------------------
    sb = viewer.scale_bar
    sb.visible = True
    sb.unit = "µm"
    sb.color = bar_color
    sb.box = True
    sb.box_color = bar_box_color
    sb.font_size = font_size
    sb.position = bar_position
    sb.colored = False

    # Add an invisible shapes layer as a toggle/sentinel for scaling effect
    names = [ly.name for ly in viewer.layers]
    if "scale_bar" not in names:
        rect = np.array([[0, 0], [1, 0], [1, 1], [0, 1]])
        viewer.add_shapes(
            [rect],
            shape_type="polygon",
            name="scale_bar",
            visible=False,
        )

    # Connect a removal hook to invert scaling when the sentinel is deleted
    def _revert_on_remove(event):
        removed_layer = event.value
        if removed_layer is None or removed_layer.name != "scale_bar":
            return
        viewer.scale_bar.visible = False
        for ly in viewer.layers:
            if not hasattr(ly, "scale") or not hasattr(ly, "metadata"):
                continue
            if "scalebar_prev_scale" not in ly.metadata:
                continue
            prev = list(ly.metadata["scalebar_prev_scale"])
            cur = list(ly.scale)
            m = len(cur)
            fx_inv = float(cur[-1]) / float(prev[-1]) if m >= 1 else 1.0
            fy_inv = float(cur[-2]) / float(prev[-2]) if m >= 2 else 1.0

            A = np.asarray(ly.affine)
            assert (
                A.ndim == 2 and A.shape[0] >= 3 and A.shape[1] >= 3
            ), "Affine matrix must be 2D with at least 3x3 shape"
            # Undo translation scaling
            A[-3, -1] /= fy_inv
            A[-2, -1] /= fx_inv
            ly.affine = A

            # Restore original per-axis scales
            ly.scale = tuple(prev)
            del ly.metadata["scalebar_prev_scale"]

    viewer.layers.events.removed.connect(_revert_on_remove)
