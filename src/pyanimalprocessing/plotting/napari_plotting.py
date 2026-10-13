"""Napari tensor visualization, legends, and interactive mask picking."""

import napari
import numpy as np
from warnings import warn
from pyanimalprocessing.rescaling.timings import median_time


def add_legend(
    legend: str,
    viewer=None,
    color="red",
    position="upper_left",
    translation=[-50, 0],
    size=30,
    image_size=None,
    n_frames=1,
    name=None,
    bbox=None,
):
    """Add a text legend to the viewer as a transparent Shapes layer.

    Parameters
    ----------
    legend : str
        Text to display.
    viewer : napari.Viewer
        The napari viewer.
    color : str
        Text colour.
    position : str
        Text anchor (e.g. ``"upper_left"``, ``"center"``).
    translation : list
        ``[dy, dx]`` pixel offset from the anchor.
    size : int
        Font size.
    image_size : tuple, optional
        ``(height, width)`` used to auto-generate a full-image bounding box.
        Ignored when *bbox* is provided.
    n_frames : int
        Number of time frames (repeats the bbox along axis 0).
    name : str, optional
        Explicit layer name.  When ``None`` napari auto-names the layer.
    bbox : np.ndarray, optional
        Custom bounding-box array.  When provided, *image_size* is ignored
        and the bbox is used directly (no frame repetition is applied).
    """
    if bbox is None:
        # Auto-generate full-image bbox from image_size
        bbox = np.array(
            [
                [0, 0],  # Top-left corner
                [image_size[0], 0],  # Top-right corner
                [image_size[0], image_size[1]],  # Bottom-right corner
                [0, image_size[1]],
            ]
        )  # Bottom-left corner
        bbox = bbox[np.newaxis, ...].repeat(n_frames, axis=0)

    n_shapes = bbox.shape[0] if bbox.ndim == 3 else 1

    features = {
        "quantity": [legend for _ in range(n_shapes)],
    }

    text_properties = {
        "string": "{quantity}",
        "anchor": position,
        "size": size,
        "color": color,
        "translation": translation,
    }

    kwargs = {}
    if name is not None:
        kwargs["name"] = name

    viewer.add_shapes(
        bbox,
        features=features,
        text=text_properties,
        face_color="transparent",
        edge_color="transparent",
        **kwargs,
    )


def _create_plotting_vectors(origins, vectors, scale=1):
    """
    Stretches and repositions vectors from their origin and projections, such that
    they are positioned halfway to the origin with size scaled by a scaling factor.

    This function is useful for formatting vectors for visualization. It takes an input
    of vector origins and the vectors themselves, scales the vectors, and adjusts their
    origins so they appear to emanate from a central point. The output is suitable for
    plotting.

    Parameters
    ----------
    origins : array-like
        The original starting points of the vectors. This should be an array-like object
        where each element is a vector origin point.

    vectors : array-like
        The original vectors to be scaled and repositioned. This should be an array-like
        object where each element is a vector.

    scale : float, optional
        The scaling factor by which to adjust the size of the vectors. By default, this
        is 1, indicating no scaling.

    Returns
    -------
    numpy.ndarray
        The transformed vectors in an array of shape (N, 2, D), where:
        - N is the number of vectors.
        - 2 indicates the origin and projection points.
        - D is the number of dimensions of the vectors.

    """

    new_vectors = vectors * scale
    new_origins = origins - (new_vectors / 2)

    return np.stack([new_origins, new_vectors], axis=1)


# ---------------------------------------------------------------------------
# Tensor display chrome (legends + scale bar) — drawn alongside a plot_property render
# ---------------------------------------------------------------------------


def _legend_bbox(image_size, n_frames, start_frame=0):
    """Per-frame image bounding box (n_frames, 4, 3) used to anchor tensor legends."""
    bbox = np.array(
        [[0, 0], [image_size[0], 0], [image_size[0], image_size[1]], [0, image_size[1]]],
        dtype=float,
    )
    bbox = bbox[np.newaxis].repeat(n_frames, axis=0)
    z = (np.arange(n_frames).repeat(4).reshape(-1, 4) + start_frame)[..., np.newaxis]
    return np.concatenate([z, bbox], axis=2)


def add_tensor_legends(
    viewer,
    time_array,
    image_size,
    quantity="",
    start_frame=0,
    quantity_color="blue",
    quantity_anchor="upper_left",
    quantity_translation=(-50, 0),
    time_color="black",
    time_anchor="upper_right",
    time_translation=(-50, 0),
    legend_size=30,
):
    """Add the quantity + developmental-time text legends, anchored to the image bbox.

    Tensor-map legend chrome, drawn next to a
    :func:`~pyanimalprocessing.plotting.property_plotting.plot_property` render. Keeps the
    layer names ``"quantity legend"`` / ``"time legend"`` / ``"median time legend"`` so the
    YAML ``layers:`` lists and ``reformat_time_legends`` keep working unchanged.
    """
    n = len(time_array)
    bbox = _legend_bbox(image_size, n, start_frame)

    def _pad(tr):  # napari >=0.6 indexes translation by display dim; pad 2-D -> 3-D
        tr = list(tr)
        return [0] + tr if len(tr) == 2 else tr

    if quantity:
        viewer.add_shapes(
            bbox,
            features={"quantity": [quantity] * n},
            text={"string": "{quantity}", "anchor": quantity_anchor, "size": legend_size,
                  "color": quantity_color, "translation": _pad(quantity_translation)},
            face_color="transparent", edge_color="transparent", name="quantity legend",
        )
    viewer.add_shapes(
        bbox,
        features={"beginning_interval": [t[0] for t in time_array],
                  "ending_interval": [t[1] for t in time_array]},
        text={"string": "{beginning_interval} - {ending_interval}", "anchor": time_anchor,
              "size": legend_size, "color": time_color, "translation": _pad(time_translation)},
        face_color="transparent", edge_color="transparent", name="time legend",
    )
    viewer.add_shapes(
        bbox,
        features={"median_time": [median_time(t[0], t[1]) for t in time_array]},
        text={"string": "{median_time}", "anchor": time_anchor, "size": legend_size,
              "color": time_color, "translation": _pad(time_translation)},
        face_color="transparent", edge_color="transparent", name="median time legend",
    )


def add_tensor_scale_bar(
    viewer,
    position,
    length,
    scale,
    n_frames,
    color,
    vector_style="line",
    edge_width=8,
    start_frame=0,
    scalar=None,
    name="scale bar",
):
    """Draw one reference vector (and optional scalar point) of known magnitude at a fixed
    image ``position`` (y, x) across frames — replaces the synthetic-NaN-array scale bars."""
    pos = np.zeros((n_frames, 3))
    pos[:, 0] = np.arange(n_frames) + start_frame
    pos[:, 1:] = position
    direction = np.zeros((n_frames, 3))
    direction[:, 2] = length  # reference vector points along +x
    vecs = _create_plotting_vectors(pos, direction, scale)
    viewer.add_vectors(vecs, edge_color=color, edge_width=edge_width,
                       vector_style=vector_style, name=name)
    if scalar is not None:
        viewer.add_points(pos, size=scalar * scale, face_color="white",
                          border_color=color, name=f"{name} scalar")


# ---------------------------------------------------------------------------
# Napari viewer helpers
# ---------------------------------------------------------------------------


def get_viewer_offset(viewer, n_tensor_frames):
    """Calculate offset to convert tensor index to viewer slider position.

    Call this AFTER adding layers to the viewer, as the slider range
    depends on loaded layers.

    Parameters
    ----------
    viewer : napari.Viewer
        Napari viewer (must have layers added).
    n_tensor_frames : int
        Number of frames in the tensor data.

    Returns
    -------
    int
        Offset such that ``viewer_idx = tensor_idx + offset``.
    """
    n_slider_ticks = viewer.dims.nsteps[0]
    return n_slider_ticks - n_tensor_frames


def display_spatial_clusters(
    viewer, p_values, cluster_map, name, colormap, affine_transform, time_offset=0
):
    """Add a LISA cluster layer to a napari viewer.

    Overlays ``-log10(p_values * cluster_map)`` with optional time padding.

    Parameters
    ----------
    viewer : napari.Viewer
    p_values : np.ndarray
        3-D array of p-values (time, y, x).
    cluster_map : np.ndarray
        Binary cluster map (same shape as *p_values*).
    name : str
        Layer name.
    colormap : str
        Napari colormap name.
    affine_transform : np.ndarray
        Affine transformation matrix.
    time_offset : int
        Number of empty frames to pad at the beginning for movie alignment.
    """
    import numpy as np

    final_array = p_values * cluster_map
    final_array = final_array.astype(np.float16)
    final_array[final_array == 0] = np.nan
    final_array_log = -np.log10(final_array)

    if time_offset > 0:
        pad_shape = (time_offset,) + final_array_log.shape[1:]
        pad_array = np.full(pad_shape, np.nan, dtype=final_array_log.dtype)
        final_array_log = np.concatenate([pad_array, final_array_log], axis=0)

    viewer.add_image(
        final_array_log,
        name=name,
        colormap=colormap,
        contrast_limits=(0, 3),
        opacity=0.5,
        affine=affine_transform,
    )


def setup_mask_picker(viewer, default_radius=100, config_section="figure_flow_deformation"):
    """Add interactive mask-picking Points layer and 'E' export shortcut.

    Adds a red editable "Mask picks" layer to the viewer.  After clicking
    bad grid positions, press **E** to cluster picks spatially and print
    YAML mask entries suitable for ``figure_config.yaml``.

    Parameters
    ----------
    viewer : napari.Viewer
        The napari viewer.
    default_radius : int
        Default radius written into exported YAML entries.
    config_section : str
        YAML section name printed in the export comment (e.g. ``"figure_morphodynamics_comparison"``).
    """
    import logging

    logger = logging.getLogger(__name__)

    viewer.add_points(
        ndim=3,
        name="Mask picks",
        face_color="red",
        border_color="white",
        size=40,
    )

    @viewer.bind_key("e")
    def _export_picks(viewer):
        _export_mask_picks(viewer, radius=default_radius,
                          config_section=config_section)

    logger.info(
        "Mask picker enabled — click bad positions in 'Mask picks' layer, "
        "then press 'E' to export YAML entries"
    )


def _export_mask_picks(viewer, radius=100, config_section="figure_flow_deformation"):
    """Read 'Mask picks' layer and print YAML mask entries.

    De-duplicates by spatial proximity: picks within *radius* of each
    other are merged into one entry.  If a cluster has picks at multiple
    distinct frames, a ``frames: [min, max]`` key is added.

    Parameters
    ----------
    viewer : napari.Viewer
        The napari viewer.
    radius : int
        Default radius for exported mask entries and spatial clustering
        threshold.
    config_section : str
        YAML section name printed in the export comment (e.g. ``"figure_morphodynamics_comparison"``).
    """
    from collections import defaultdict

    try:
        layer = viewer.layers["Mask picks"]
    except KeyError:
        print("No 'Mask picks' layer found.")
        return

    points = np.asarray(layer.data)  # (N, 3) — (t, y, x)
    if len(points) == 0:
        print("No mask picks to export.")
        return

    # Cluster by spatial proximity
    yx = points[:, 1:]  # (N, 2)
    assigned = np.full(len(points), -1, dtype=int)
    cluster_id = 0

    for i in range(len(points)):
        if assigned[i] >= 0:
            continue
        dists = np.linalg.norm(yx - yx[i], axis=1)
        members = (dists <= radius) & (assigned < 0)
        assigned[members] = cluster_id
        cluster_id += 1

    # Build mask entries
    clusters = defaultdict(list)
    for i, cid in enumerate(assigned):
        clusters[cid].append(points[i])

    entries = []
    for cid in sorted(clusters):
        pts = np.array(clusters[cid])
        center_y = float(np.mean(pts[:, 1]))
        center_x = float(np.mean(pts[:, 2]))
        unique_frames = sorted(set(int(t) for t in pts[:, 0]))

        entry = {"center": [round(center_y, 1), round(center_x, 1)],
                 "radius": radius}
        if len(unique_frames) >= 2:
            entry["frames"] = [min(unique_frames), max(unique_frames)]

        entries.append(entry)

    # Print YAML
    print(f"\n# --- {len(entries)} mask entries (radius={radius}) ---")
    print(f"# Paste under {config_section}.masks in figure_config.yaml")
    print("# Add 'frames: [start, end]' for time-dependent masks")
    print("masks:")
    for e in entries:
        if "frames" in e:
            print(
                f"  - {{center: {e['center']}, "
                f"radius: {e['radius']}, "
                f"frames: {e['frames']}}}"
            )
        else:
            print(
                f"  - {{center: {e['center']}, radius: {e['radius']}}}"
            )


def create_bbox_for_scale(scale_position, bbox_x, y_offset):
    """Create a bounding-box array for positioning a scale-bar label in napari.

    Parameters
    ----------
    scale_position : list
        ``[y, x]`` position of the scale bar.
    bbox_x : list
        ``[x_min, x_max]`` horizontal extent of the bounding box.
    y_offset : int
        Vertical half-height of the bounding box.

    Returns
    -------
    np.ndarray
        Shape ``(1, 4, 2)`` bounding box array suitable for
        ``viewer.add_shapes``.
    """
    x_min, x_max = bbox_x
    y, _ = scale_position
    return np.array(
        [
            [y - y_offset, x_min],
            [y + y_offset, x_min],
            [y + y_offset, x_max],
            [y - y_offset, x_max],
        ]
    )[np.newaxis, ...]


