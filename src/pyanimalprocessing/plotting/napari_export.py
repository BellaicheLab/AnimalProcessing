"""Napari viewer screenshot and SVG export utilities.

Provides functions for saving napari viewer state as raster (PNG) or vector
(SVG) images.  The SVG path works around limitations of the ``napari-svg``
plugin by creating flattened 2-D clones of each visible layer before writing.
"""

import copy
import logging
import os
import subprocess
import xml.etree.ElementTree as ET

import napari
import numpy as np
from scipy import ndimage
from scipy.spatial import cKDTree

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Public API – canonical export function
# ---------------------------------------------------------------------------


def save_viewer_state(
    viewer,
    output_path,
    *,
    time_axis=0,
    frames=None,
    start=None,
    stop=None,
    step=None,
    layers=None,
    selected_layers=None,
    convert_points=True,
    scale_factor=1,
    fps=10,
    crf=18,
    progress=True,
    interleave_tensors=True,
):
    """Save napari viewer state as PNG, SVG, video, or frame sequence.

    The output mode, format, and filename prefix are auto-detected from *output_path*:

    ==============================  ============  =======  ================================
    ``output_path``                 Mode          Format   Engine
    ==============================  ============  =======  ================================
    ``"out/panel.svg"``             single frame  SVG      layer-flattening + save_layers
    ``"out/panel.png"``             single frame  PNG      ``viewer.export_figure()``
    ``"out/movie.mp4"``             video         PNG>MP4  ``export_figure()`` + imageio
    ``"out/frames_dir"`` (no ext)   sequence      PNG      ``export_figure()`` per frame
    ==============================  ============  =======  ================================

    If a specific file path (e.g., ``"plot.png"``) is given alongside a ``frames`` list,
    the function intuitively appends the frame indices (e.g., ``"plot_0001.png"``).

    Parameters
    ----------
    viewer : napari.Viewer
        The napari viewer to export.
    output_path : str
        Destination file or directory. Extension determines the format.
    time_axis : int, optional
        Dimension axis representing time (default 0).
    frames : None, int, or list of int, optional
        Frame indices to export. *None* → current position for single-frame
        mode, all frames for sequence/video mode. An *int* sets the viewer to
        that frame. A *list* exports those frames.
    start, stop, step : int or None, optional
        Alternative range-style frame specification (ignored when *frames* is given).
    layers : list of str or None, optional
        Layers to show, listed from bottom to top.
    selected_layers : list of int or str or None, optional
        Deprecated alias for *layers*. Use *layers* instead.
    convert_points : bool, optional
        Convert Points layers to Shapes before export (avoids vispy size bug).
    scale_factor : int, optional
        Scale factor for PNG export via ``viewer.export_figure()``.
    fps : int, optional
        Frames per second for video output (default 10).
    crf : int, optional
        H.264 Constant Rate Factor for video quality (default 18).
    progress : bool, optional
        Show a tqdm progress bar for multi-frame export (default True).
    interleave_tensors : bool, optional
        When True, export via SVG with post-processing that interleaves
        each circle with its associated vector lines. Default True.

    Returns
    -------
    list of str
        Paths of saved files. For video mode, the last element is the ``.mp4``.
    """
    # Resolve layers / selected_layers (backward compat)
    effective_layers = layers if layers is not None else selected_layers

    # Dynamically extract mode, directory, and the core filename
    mode, fmt, out_dir, base_name = _resolve_output_mode(output_path)
    frame_list = _resolve_frames(viewer, frames, start, stop, step, time_axis, mode)

    # Save original state
    original_visibility = [layer.visible for layer in viewer.layers]
    original_order = [layer.name for layer in viewer.layers]

    if convert_points:
        convert_points_to_shapes(viewer)

    if effective_layers is not None:
        _apply_layer_selection(viewer, effective_layers)

    try:
        saved_paths = []

        if frame_list is not None and progress:
            try:
                from tqdm import tqdm

                frame_iter = tqdm(frame_list, desc="Exporting frames")
            except ImportError:
                frame_iter = frame_list
        elif frame_list is not None:
            frame_iter = frame_list
        else:
            frame_iter = None

        if interleave_tensors:
            saved_paths = _export_interleaved(
                viewer,
                output_path,
                base_name,
                time_axis,
                frame_iter,
                mode,
                fmt,
                out_dir,
                scale_factor,
            )
        elif fmt == "svg":
            if frame_iter is None:
                saved_paths.append(_export_svg_frame(viewer, output_path))
            else:
                os.makedirs(out_dir, exist_ok=True)
                for fidx in frame_iter:
                    viewer.dims.set_point(time_axis, fidx)
                    path = os.path.join(out_dir, f"{base_name}_{fidx:04d}.svg")
                    saved_paths.append(_export_svg_frame(viewer, path))
        else:
            if frame_iter is None:
                os.makedirs(out_dir, exist_ok=True)
                viewer.export_figure(path=output_path, scale_factor=scale_factor)
                saved_paths.append(output_path)
            else:
                os.makedirs(out_dir, exist_ok=True)
                for fidx in frame_iter:
                    viewer.dims.set_point(time_axis, fidx)
                    path = os.path.join(out_dir, f"{base_name}_{fidx:04d}.png")
                    viewer.export_figure(path=path, scale_factor=scale_factor)
                    saved_paths.append(path)

        if mode == "video":
            video_path = output_path
            # For interleaved mode, saved_paths already contains PNGs.
            png_paths = [p for p in saved_paths if p.endswith(".png")]
            assemble_frames_to_video(png_paths, video_path, fps=fps, crf=crf)
            saved_paths.append(video_path)

        return saved_paths

    finally:
        if effective_layers is not None:
            _restore_layer_order(viewer, original_order)
        for layer, vis in zip(viewer.layers, original_visibility):
            layer.visible = vis


# ---------------------------------------------------------------------------
# Video assembly
# ---------------------------------------------------------------------------


def assemble_frames_to_video(frame_paths, output_path, fps=10, crf=18):
    """Assemble PNG frames into a video using imageio + ffmpeg.

    The codec is chosen automatically from the file extension:

    ========  =========  ================================================
    Ext       Codec      Notes
    ========  =========  ================================================
    ``.mp4``  H.264      Universal playback; *crf* controls quality
    ``.avi``  MJPEG      High-quality AVI; *crf* mapped to qscale (1-31)
    ========  =========  ================================================

    Parameters
    ----------
    frame_paths : list of str
        Ordered list of PNG file paths to include as frames.
    output_path : str
        Output video file path (e.g. ``"movie.mp4"`` or ``"movie.avi"``).
    fps : int, optional
        Frames per second. Default 10.
    crf : int, optional
        Quality parameter (default 18).  For MP4 this is the H.264 CRF
        (0 = lossless, 51 = worst).  For AVI/MJPEG it is mapped to the
        ffmpeg ``-qscale:v`` range (2–31); CRF 0–18 → qscale 2 (best),
        CRF 51 → qscale 31 (worst).

    Returns
    -------
    str
        The output video path.
    """
    import imageio

    if not frame_paths:
        raise ValueError("frame_paths is empty – nothing to assemble")

    ext = os.path.splitext(output_path)[1].lower()

    if ext == ".avi":
        # Map CRF (0–51) to MJPEG qscale (2–31): lower CRF → lower qscale
        qscale = max(2, min(31, int(2 + (crf / 51) * 29)))
        writer = imageio.get_writer(
            output_path,
            fps=fps,
            codec="mjpeg",
            pixelformat="yuvj420p",
            quality=None,
            output_params=["-qscale:v", str(qscale)],
        )
    else:
        writer = imageio.get_writer(
            output_path,
            fps=fps,
            codec="libx264",
            pixelformat="yuv420p",
            quality=None,
            output_params=["-crf", str(crf)],
            macro_block_size=2,
        )

    for path in frame_paths:
        writer.append_data(imageio.imread(path))
    writer.close()
    return output_path


# ---------------------------------------------------------------------------
# Internal helpers for save_viewer_state
# ---------------------------------------------------------------------------
def _export_interleaved(
    viewer,
    output_path,
    base_name,
    time_axis,
    frame_iter,
    mode,
    fmt,
    out_dir,
    scale_factor,
):
    """SVG-based export with circle/vector interleaving and text injection."""
    final_is_svg = fmt == "svg" and mode == "single_frame"

    # Setup directories securely, preventing NoneType errors
    if mode in ("video", "frame_sequence"):
        svg_dir = out_dir.rstrip(os.sep) + "_svg"
        png_dir = out_dir
        os.makedirs(svg_dir, exist_ok=True)
        os.makedirs(png_dir, exist_ok=True)
    elif final_is_svg:
        svg_dir = out_dir
        png_dir = None
    else:
        svg_dir = out_dir
        png_dir = out_dir

    saved_paths = []

    if frame_iter is None:
        svg_path = (
            output_path if final_is_svg else os.path.join(svg_dir, base_name + ".svg")
        )
        text_entries = _build_text_entries_from_viewer(viewer)
        _export_svg_frame(viewer, svg_path)
        reorder_tensor_svg(svg_path)

        if text_entries:
            inject_text_into_svg(svg_path, text_entries)

        if final_is_svg:
            saved_paths.append(svg_path)
        else:
            rasterize_svg(svg_path, output_path, scale_factor=scale_factor)
            saved_paths.append(output_path)
    else:
        svg_paths = []
        for fidx in frame_iter:
            viewer.dims.set_point(time_axis, fidx)
            text_entries = _build_text_entries_from_viewer(viewer)

            # Using base_name directly constructed from user's output_path
            svg_path = os.path.join(svg_dir, f"{base_name}_{fidx:04d}.svg")
            _export_svg_frame(viewer, svg_path)
            reorder_tensor_svg(svg_path)

            if text_entries:
                inject_text_into_svg(svg_path, text_entries)
            svg_paths.append(svg_path)

        if len(svg_paths) > 1:
            _normalize_svg_canvas(svg_paths)

        for svg_path in svg_paths:
            if final_is_svg:
                saved_paths.append(svg_path)
            else:
                png_path = os.path.join(
                    png_dir,
                    os.path.splitext(os.path.basename(svg_path))[0] + ".png",
                )
                rasterize_svg(svg_path, png_path, scale_factor=scale_factor)
                saved_paths.append(png_path)

    return saved_paths


def _normalize_svg_canvas(svg_paths):
    """Force all SVGs to share the same canvas size and translate offset.

    The SVG canvas (``width``/``height`` and the ``<g transform>`` offset)
    is computed by napari-svg from per-frame data extents.  In Lagrangian
    mode these extents vary, producing frames at different pixel positions.

    This function computes the bounding box that encloses ALL frames
    (maximum width/height, minimum translate offset) and applies it to
    every SVG.  This ensures the tissue stays at the same pixel position
    across frames and no content is clipped.
    """
    import re

    if not svg_paths:
        return

    _translate_re = re.compile(r"translate\(\s*([^\s]+)\s+([^\s]+)\s*\)")

    # First pass: collect canvas parameters from every frame.
    widths = []
    heights = []
    tx_list = []
    ty_list = []

    for svg_path in svg_paths:
        tree = ET.parse(svg_path)
        root = tree.getroot()
        widths.append(float(root.get("width", "0")))
        heights.append(float(root.get("height", "0")))
        g = root.find(_svg_tag("g"))
        if g is not None:
            m = _translate_re.search(g.get("transform", ""))
            if m:
                tx_list.append(float(m.group(1)))
                ty_list.append(float(m.group(2)))

    if not tx_list:
        return  # No translates found — nothing to normalise.

    # The translate is `translate(-min_x, -min_y)` where min_x/min_y
    # are the data minima.  A more negative translate means a smaller
    # data minimum.  To encompass all frames we need the most negative
    # translate (largest offset) and the largest canvas.
    #
    # Canvas width  = max_x - min_x  →  width  = data_range + |translate_x|
    # Canvas height = max_y - min_y  →  height = data_range + |translate_y|
    #
    # To get a stable canvas: use the minimum translate (most negative
    # = most offset) and recompute width/height to cover the maximum
    # extent of any frame.
    min_tx = min(tx_list)
    min_ty = min(ty_list)

    # For each frame: the right/bottom edge in world coords is
    #   max_x = width - translate_x,  max_y = height - translate_y
    # (because translate = -min, so world_max = canvas_size + min)
    max_right = max(w - tx for w, tx in zip(widths, tx_list))
    max_bottom = max(h - ty for h, ty in zip(heights, ty_list))

    # Final canvas: from the global minimum to the global maximum.
    final_width = max_right - min_tx
    final_height = max_bottom - min_ty
    final_transform = f"translate({min_tx} {min_ty})"

    # Second pass: apply to all SVGs that differ.
    changed = 0
    for svg_path in svg_paths:
        tree = ET.parse(svg_path)
        root = tree.getroot()

        cur_w = root.get("width")
        cur_h = root.get("height")
        g = root.find(_svg_tag("g"))
        cur_t = g.get("transform") if g is not None else None

        new_w = str(final_width)
        new_h = str(final_height)

        if cur_w == new_w and cur_h == new_h and cur_t == final_transform:
            continue

        root.set("width", new_w)
        root.set("height", new_h)
        if g is not None:
            g.set("transform", final_transform)
        _write_svg(root, svg_path)
        changed += 1

    if changed:
        logger.info(
            "Normalised SVG canvas on %d/%d frames to %.0fx%.0f",
            changed,
            len(svg_paths),
            final_width,
            final_height,
        )


def _apply_layer_selection(viewer, layer_spec):
    """Set visibility and z-order from a layer specification.

    Parameters
    ----------
    viewer : napari.Viewer
    layer_spec : list of str or list of int
        Layers to show.  When strings, layers are reordered to match the
        given order (bottom → top).  Integer indices only set visibility
        (no reordering, backward-compatible behaviour).
    """
    if not layer_spec:
        return

    if isinstance(layer_spec[0], int):
        # Legacy integer-index mode: visibility only, no reordering
        for i, layer in enumerate(viewer.layers):
            layer.visible = i in layer_spec
        return

    # String-name mode: set visibility and reorder
    selected_set = set(layer_spec)
    existing_names = {layer.name for layer in viewer.layers}
    missing = selected_set - existing_names
    if missing:
        logger.warning(
            "Layer selection: %d layer(s) not found in viewer: %s. "
            "Available layers: %s",
            len(missing),
            sorted(missing),
            sorted(existing_names),
        )

    for layer in viewer.layers:
        layer.visible = layer.name in selected_set

    # Reorder visible layers to match list order (bottom → top)
    for target_pos, name in enumerate(layer_spec):
        current_pos = next(
            (i for i, l in enumerate(viewer.layers) if l.name == name), None
        )
        if current_pos is not None and current_pos != target_pos:
            viewer.layers.move(current_pos, target_pos)


def _restore_layer_order(viewer, original_order):
    """Restore layer order to *original_order* (list of names)."""
    for target_pos, name in enumerate(original_order):
        current_pos = next(
            (i for i, l in enumerate(viewer.layers) if l.name == name), None
        )
        if current_pos is not None and current_pos != target_pos:
            viewer.layers.move(current_pos, target_pos)


def _resolve_output_mode(output_path):
    """Determine export mode, format, output directory, and base filename."""
    ext = os.path.splitext(output_path)[1].lower()

    # Video file (e.g., "results/movie.mp4")
    if ext in (".mp4", ".avi"):
        out_dir = os.path.dirname(output_path) or "."
        base_name = os.path.splitext(os.path.basename(output_path))[0]
        video_dir = os.path.join(out_dir, base_name + "_frames")
        return "video", "png", video_dir, base_name

    # Directory/Sequence mode (e.g., "results/my_frames")
    if not ext:
        out_dir = output_path
        base_name = (
            "frame"  # Automatically prefix frames with "frame_0000" in the folder
        )
        return "frame_sequence", "png", out_dir, base_name

    # Specific file with extension (e.g., "results/plot.png")
    out_dir = os.path.dirname(output_path) or "."
    base_name = os.path.splitext(os.path.basename(output_path))[0]
    fmt = "svg" if ext == ".svg" else "png"
    return "single_frame", fmt, out_dir, base_name


def _resolve_frames(viewer, frames, start, stop, step, time_axis, mode):
    """Resolve *frames* / *start/stop/step* into a list or None.

    Returns *None* when the export should use the current viewer position
    (single-frame mode with no explicit frame).  Otherwise returns a list
    of integer frame indices.
    """
    if frames is not None:
        if isinstance(frames, int):
            viewer.dims.set_point(time_axis, frames)
            if mode == "single_frame":
                return None  # current position is now set
            return [frames]
        return list(frames)

    if start is not None or stop is not None or step is not None:
        dim_range = viewer.dims.range[time_axis]
        r_start = start if start is not None else int(dim_range[0])
        r_stop = stop if stop is not None else int(dim_range[1])
        r_step = step if step is not None else 1
        return list(range(r_start, r_stop, r_step))

    if mode in ("frame_sequence", "video"):
        dim_range = viewer.dims.range[time_axis]
        return list(range(int(dim_range[0]), int(dim_range[1])))

    return None  # single frame at current position


def _export_svg_frame(viewer, path):
    """Export the current viewer state as SVG via layer-flattening.

    Calls the ``napari-svg`` writer directly rather than napari's
    ``save_layers``.  ``save_layers`` relies on plugin auto-discovery whose
    npe2 layer-type matching rejects some valid combinations — notably an
    image with only shapes and no vectors/points (the scalar-quantity
    scenes) — raising "Unable to find plugin capable of writing this
    combination of layer types".  We always want napari-svg for these
    flattened 2-D layers, so we invoke it on the layer-data tuples (exactly
    what napari would pass it) and skip the fragile writer resolution.
    """
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    flattened_layers = _build_svg_layers(viewer)
    if not flattened_layers:
        raise ValueError("No layers available for SVG export in current view.")
    try:
        from napari_svg.hook_implementations import writer as svg_writer

        layer_data = [layer.as_layer_data_tuple() for layer in flattened_layers]
        svg_writer(path, layer_data)
    finally:
        del flattened_layers
    return path


# ---------------------------------------------------------------------------
# Public utilities
# ---------------------------------------------------------------------------


def convert_points_to_shapes(viewer):
    """Convert all Points layers in a napari viewer to Shapes (ellipses).

    This avoids the OpenGL/vispy bug where Points layers have a maximum
    rendered pixel size when zooming in, while Shapes layers scale infinitely.

    Parameters
    ----------
    viewer : napari.Viewer
        The napari viewer containing the layers to convert.

    Returns
    -------
    list
        List of newly created Shapes layers.
    """
    new_shape_layers = []
    points_layers_to_remove = []

    for layer in viewer.layers:
        if isinstance(layer, napari.layers.Points):
            points_layers_to_remove.append(layer)

    for points_layer in points_layers_to_remove:
        data = points_layer.data
        size = points_layer.size
        face_color = points_layer.face_color
        # napari >=0.5 renamed edge_color -> border_color on Points layers
        edge_color = getattr(
            points_layer, "border_color", getattr(points_layer, "edge_color", None)
        )
        visible = points_layer.visible
        name = points_layer.name
        opacity = points_layer.opacity
        # Shapes built from the points lose the layer affine, so bake it into the
        # coordinates below (identity affine is a no-op for already-baked layers).
        affine = np.asarray(points_layer.affine.affine_matrix)

        if np.isscalar(size) or size.ndim == 0:
            sizes = np.full(len(data), float(size))
        elif size.ndim == 1:
            sizes = size
        else:
            sizes = np.mean(size, axis=1)

        ellipse_data = []
        ndim = data.shape[1]

        for i, (point, point_size) in enumerate(zip(data, sizes)):
            radius = point_size / 2
            point = (affine @ np.append(point, 1.0))[:-1]  # -> world coords

            if ndim == 2:
                row, col = point
                corners = np.array(
                    [
                        [row - radius, col - radius],
                        [row + radius, col - radius],
                        [row + radius, col + radius],
                        [row - radius, col + radius],
                    ]
                )
            else:
                corners = np.zeros((4, ndim))
                corners[:] = point
                corners[0, -2] -= radius
                corners[0, -1] -= radius
                corners[1, -2] += radius
                corners[1, -1] -= radius
                corners[2, -2] += radius
                corners[2, -1] += radius
                corners[3, -2] -= radius
                corners[3, -1] += radius

            ellipse_data.append(corners)

        # Assign z_index = array position so that the original grid
        # ordering is preserved across frames.  Without this, all shapes
        # get z_index=0 and overlapping co-planar shapes may render in
        # an unstable order, causing flickering in movies.
        z_indices = list(range(len(ellipse_data)))

        shapes_layer = viewer.add_shapes(
            ellipse_data,
            shape_type="ellipse",
            face_color=face_color,
            edge_color=edge_color,
            z_index=z_indices,
            edge_width=10,
            visible=visible,
            name=f"{name} (shapes)",
            opacity=opacity,
        )

        new_shape_layers.append(shapes_layer)
        viewer.layers.remove(points_layer)

    return new_shape_layers


# ---------------------------------------------------------------------------
# SVG post-processing: interleave circles with their vectors
# ---------------------------------------------------------------------------

_SVG_NS = "http://www.w3.org/2000/svg"
_XLINK_NS = "http://www.w3.org/1999/xlink"

# Register namespaces so ElementTree serialises without ns0/ns1 prefixes.
ET.register_namespace("", _SVG_NS)
ET.register_namespace("xlink", _XLINK_NS)

_SVG_PREAMBLE = (
    '<?xml version="1.0" standalone="no"?>\n'
    '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"\n'
    '"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n'
)


def _svg_tag(local):
    """Return the namespace-qualified SVG tag name."""
    return f"{{{_SVG_NS}}}{local}"


def reorder_tensor_svg(svg_path, output_path=None):
    """Post-process a napari-exported SVG to fix vector/circle z-ordering.

    napari exports all circles (``<ellipse>``) in one block and all vector
    lines (``<line>``) in another, so every line is rendered above every
    circle.  This function matches each circle to its associated vector
    line(s) by spatial proximity and interleaves them: each circle is
    immediately followed by its matched lines.  The existing circle order
    is preserved.

    Parameters
    ----------
    svg_path : str
        Path to the input SVG file (written by ``napari-svg``).
    output_path : str or None
        Destination for the corrected SVG.  ``None`` overwrites the input.

    Returns
    -------
    str
        Path of the written SVG file.
    """
    tree = ET.parse(svg_path)
    root = tree.getroot()

    # The single <g transform="translate(...)"> that wraps all elements.
    g_tag = _svg_tag("g")
    g = root.find(g_tag)
    if g is None:
        # Fallback: first child
        g = root[0] if len(root) else None
    if g is None:
        logger.warning("reorder_tensor_svg: no <g> found in %s", svg_path)
        return output_path or svg_path

    children = list(g)
    ellipse_tag = _svg_tag("ellipse")
    line_tag = _svg_tag("line")
    rect_tag = _svg_tag("rect")

    # Partition children into data (ellipses/lines), background, and
    # overlay rects to drop.  napari-svg emits full-screen semi-
    # transparent black <rect> elements from legend Shapes layers;
    # these must be removed or they darken the entire image.
    ellipses = []  # (original_index, element)
    lines = []  # (original_index, element)
    background = []  # (original_index, element) — images
    overlay_rects = []  # full-screen rects to drop

    def _is_fullscreen_overlay(el):
        """Detect full-screen semi-transparent rects from legend layers."""
        if el.tag != rect_tag:
            return False
        try:
            w = float(el.get("width", "0"))
            h = float(el.get("height", "0"))
        except ValueError:
            return False
        # These are full-image-size rects with a dark fill.
        return w > 1000 and h > 1000

    for idx, child in enumerate(children):
        if child.tag == ellipse_tag:
            ellipses.append((idx, child))
        elif child.tag == line_tag:
            lines.append((idx, child))
        elif _is_fullscreen_overlay(child):
            overlay_rects.append((idx, child))
        else:
            background.append((idx, child))

    if overlay_rects:
        logger.info(
            "reorder_tensor_svg: dropped %d full-screen overlay rect(s)",
            len(overlay_rects),
        )

    if not ellipses or not lines:
        # Nothing to interleave — either circles-only or vectors-only.
        # Still remove overlay rects if present.
        if overlay_rects:
            for child in list(g):
                g.remove(child)
            for _, el in background:
                g.append(el)
            for _, el in ellipses:
                g.append(el)
            for _, el in lines:
                g.append(el)
            out = output_path or svg_path
            _write_svg(root, out)
            return out
        out = output_path or svg_path
        if out != svg_path:
            _write_svg(root, out)
        return out

    first_data_idx = min(
        ellipses[0][0] if ellipses else float("inf"),
        lines[0][0] if lines else float("inf"),
    )

    # ── Match ellipses ↔ lines by spatial proximity ──────────────────
    ellipse_centers = np.array(
        [(float(el.get("cx", "0")), float(el.get("cy", "0"))) for _, el in ellipses]
    )
    line_midpoints = np.array(
        [
            (
                (float(el.get("x1", "0")) + float(el.get("x2", "0"))) / 2,
                (float(el.get("y1", "0")) + float(el.get("y2", "0"))) / 2,
            )
            for _, el in lines
        ]
    )

    kd = cKDTree(line_midpoints)
    # Tolerance: generous enough for floating-point differences.
    matches = kd.query_ball_point(ellipse_centers, r=2.0)

    matched_line_indices = set()
    groups = []  # [(ellipse_element, [matched_line_elements])]
    for i, (_, el) in enumerate(ellipses):
        matched = [lines[j][1] for j in matches[i]]
        matched_line_indices.update(matches[i])
        groups.append((el, matched))

    unmatched = [el for j, (_, el) in enumerate(lines) if j not in matched_line_indices]

    # ── Rebuild <g> children ─────────────────────────────────────────
    # Clear children while preserving <g> attributes.
    for child in list(g):
        g.remove(child)

    # Background elements (images, non-overlay shapes) before data.
    for orig_idx, el in background:
        if orig_idx < first_data_idx:
            g.append(el)

    # Interleaved data: circle first, then its lines on top.
    # Each grid point's circle + vectors form a group.  Later groups
    # are drawn above earlier ones, fixing cross-grid-point z-ordering.
    for ellipse_el, matched_lines in groups:
        g.append(ellipse_el)
        for line_el in matched_lines:
            g.append(line_el)

    # Unmatched lines (defensive — shouldn't normally happen).
    for el in unmatched:
        g.append(el)

    # Background elements that came after the data block.
    # (Full-screen overlay rects are intentionally excluded.)
    for orig_idx, el in background:
        if orig_idx >= first_data_idx:
            g.append(el)

    out = output_path or svg_path
    _write_svg(root, out)
    return out


def inject_text_into_svg(svg_path, text_entries, output_path=None):
    """Add ``<text>`` elements to an SVG file.

    napari-svg does not export the text annotations from Shapes layers.
    This function injects them so that rasterised PNGs include legends.

    Parameters
    ----------
    svg_path : str
        Path to the SVG file to modify.
    text_entries : list of dict
        Each dict must have keys ``x``, ``y``, ``text``, ``font_size``,
        ``color``.  Optional: ``anchor`` (default ``"start"``).
    output_path : str or None
        Destination path.  ``None`` overwrites the input.

    Returns
    -------
    str
        Path of the written SVG file.
    """
    if not text_entries:
        return output_path or svg_path

    tree = ET.parse(svg_path)
    root = tree.getroot()

    g = root.find(_svg_tag("g"))
    if g is None:
        g = root[0] if len(root) else root

    for entry in text_entries:
        attrib = {
            "x": str(entry["x"]),
            "y": str(entry["y"]),
            "font-size": str(entry["font_size"]),
            "fill": entry["color"],
            "text-anchor": entry.get("anchor", "start"),
            "font-family": "sans-serif",
        }
        text_el = ET.SubElement(g, _svg_tag("text"), attrib)
        text_el.text = str(entry["text"])

    out = output_path or svg_path
    _write_svg(root, out)
    return out


def rasterize_svg(svg_path, png_path, *, scale_factor=1):
    """Convert an SVG file to PNG.

    Uses ``rsvg-convert`` (from librsvg) if available on ``PATH``,
    otherwise falls back to the ``cairosvg`` Python package.

    Parameters
    ----------
    svg_path : str
        Input SVG file.
    png_path : str
        Output PNG file.
    scale_factor : int or float
        Zoom multiplier (default 1 = native SVG size).

    Returns
    -------
    str
        The *png_path*.

    Raises
    ------
    RuntimeError
        If neither ``rsvg-convert`` nor ``cairosvg`` is available.
    """
    os.makedirs(os.path.dirname(png_path) or ".", exist_ok=True)

    # Try rsvg-convert first (fast, reliable, commonly installed via brew).
    try:
        cmd = [
            "rsvg-convert",
            "-z",
            str(scale_factor),
            "-o",
            png_path,
            svg_path,
        ]
        subprocess.run(cmd, check=True, capture_output=True)
        return png_path
    except FileNotFoundError:
        pass

    # Fallback: cairosvg Python package.
    try:
        import cairosvg

        cairosvg.svg2png(url=svg_path, write_to=png_path, scale=scale_factor)
        return png_path
    except ImportError:
        pass

    raise RuntimeError(
        "SVG rasterisation requires either `rsvg-convert` (brew install "
        "librsvg) or the `cairosvg` Python package (pip install cairosvg)."
    )


def _write_svg(root, path):
    """Serialise an ElementTree *root* to *path* with the SVG preamble."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    svg_body = ET.tostring(root, encoding="unicode", method="xml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(_SVG_PREAMBLE)
        f.write(svg_body)


# ---------------------------------------------------------------------------
# Text extraction from napari viewer for SVG injection
# ---------------------------------------------------------------------------

_ANCHOR_MAP = {
    "upper_left": "start",
    "lower_left": "start",
    "upper_right": "end",
    "lower_right": "end",
    "center": "middle",
}


def _build_text_entries_from_viewer(viewer):
    """Extract text legend info from visible napari Shapes layers.

    Reads the current viewer frame and returns a list of text entry dicts
    suitable for :func:`inject_text_into_svg`.

    Parameters
    ----------
    viewer : napari.Viewer

    Returns
    -------
    list of dict
        Each dict has keys: ``x``, ``y``, ``text``, ``font_size``,
        ``color``, ``anchor``.
    """
    entries = []
    for layer in viewer.layers:
        if not layer.visible:
            continue
        if not isinstance(layer, napari.layers.Shapes):
            continue
        text_mgr = getattr(layer, "text", None)
        if text_mgr is None:
            continue

        text_dict = text_mgr.dict() if hasattr(text_mgr, "dict") else {}
        fmt_string = text_dict.get("string", "")
        # napari >=0.5 returns string as a dict with an encoding_type:
        #   {"format": "{qty}", "encoding_type": "FormatStringEncoding"}
        #   {"constant": "literal", "encoding_type": "ConstantStringEncoding"}
        if isinstance(fmt_string, dict):
            fmt_string = fmt_string.get("format") or fmt_string.get("constant") or ""
        if not fmt_string or fmt_string == "":
            continue

        anchor_name = text_dict.get("anchor", "center")
        if hasattr(anchor_name, "value"):
            anchor_name = anchor_name.value
        font_size = text_dict.get("size", 12)
        translation = text_dict.get("translation", [0, 0])
        text_color = text_dict.get("color", "black")

        # napari >=0.5 wraps color as {"constant": ColorValue([...]), ...}.
        if isinstance(text_color, dict):
            if "constant" in text_color:
                text_color = text_color["constant"]
            elif "array" in text_color:
                text_color = text_color["array"]
            else:
                text_color = "black"

        # Resolve color — may be an RGBA array or a string.
        if isinstance(text_color, np.ndarray):
            c = (np.asarray(text_color)[:3] * 255).astype(int)
            text_color = f"rgb({c[0]},{c[1]},{c[2]})"
        elif isinstance(text_color, (list, tuple)) and len(text_color) >= 3:
            c = [
                int(v * 255) if isinstance(v, float) and v <= 1 else int(v)
                for v in text_color[:3]
            ]
            text_color = f"rgb({c[0]},{c[1]},{c[2]})"

        # Get visible shape indices for the current frame.
        indices = np.asarray(getattr(layer, "_indices_view", []), dtype=int)
        if indices.size == 0:
            continue

        features = layer.features
        for idx in indices:
            # Resolve the format string with feature values.
            row = {k: np.asarray(v)[idx] for k, v in features.items()}
            try:
                resolved = fmt_string.format(**row)
            except (KeyError, IndexError):
                continue
            if not resolved.strip():
                continue

            # Compute position from shape geometry.
            shape_data = np.asarray(layer._data_view.shapes[idx].data_displayed)
            # shape_data is (N, 2) in napari (row, col) coordinates.
            rows = shape_data[:, 0]
            cols = shape_data[:, 1]
            min_row, max_row = rows.min(), rows.max()
            min_col, max_col = cols.min(), cols.max()

            # Translation may be 2D (row, col) or 3D (t, row, col).
            t = list(translation)
            if len(t) == 3:
                t = t[1:]  # drop time dimension
            t_row, t_col = t[0], t[1]

            # Anchor determines which corner of the bbox is the reference.
            if "lower" in anchor_name:
                ref_row = max_row + t_row
            elif "upper" in anchor_name:
                ref_row = min_row + t_row
            else:
                ref_row = (min_row + max_row) / 2 + t_row

            if "right" in anchor_name:
                ref_col = max_col + t_col
            elif "left" in anchor_name:
                ref_col = min_col + t_col
            else:
                ref_col = (min_col + max_col) / 2 + t_col

            # napari (row, col) → SVG (x=col, y=row).
            svg_x = ref_col
            svg_y = ref_row

            entries.append(
                {
                    "x": svg_x,
                    "y": svg_y,
                    "text": resolved,
                    "font_size": font_size,
                    "color": text_color,
                    "anchor": _ANCHOR_MAP.get(anchor_name, "start"),
                }
            )

    return entries


# ---------------------------------------------------------------------------
# SVG layer flattening helpers
# ---------------------------------------------------------------------------


def _build_svg_layers(viewer):
    """Create a list of stand-alone 2-D layers mirroring the current view."""
    flattened_layers = []
    for layer in viewer.layers:
        if not layer.visible:
            continue

        flattened = None
        if isinstance(layer, (napari.layers.Image, napari.layers.Labels)):
            flattened = _flatten_image_like_layer(layer)
        elif isinstance(layer, napari.layers.Shapes):
            # Fully transparent shapes only anchor legend text (injected separately);
            # napari-svg drops the fill alpha and would draw them as opaque black.
            if not layer.face_color[:, 3].any() and not layer.edge_color[:, 3].any():
                continue
            flattened = _flatten_shapes_layer(layer)
        elif isinstance(layer, napari.layers.Vectors):
            flattened = _flatten_vectors_layer(layer)
        if flattened is not None:
            flattened_layers.append(flattened)
    return flattened_layers


def _flatten_image_like_layer(layer):
    """Return a 2-D napari Image/Labels layer representing the current view."""
    # napari >=0.5 removed _slice_indices; use _data_view which gives the
    # already-sliced 2-D array for the currently displayed frame.
    data_view = getattr(layer, "_data_view", None)
    if data_view is None:
        # Fallback for napari <0.5
        slice_indices = getattr(layer, "_slice_indices", None)
        if slice_indices is None:
            return None
        data_view = layer.data[slice_indices]
    data = np.asarray(data_view)

    affine_2d = _extract_2d_affine(layer)

    base_kwargs = {
        "name": layer.name,
        "metadata": _copy_metadata(layer.metadata),
        "opacity": layer.opacity,
        "blending": _enum_to_value(layer.blending),
        "visible": layer.visible,
    }

    if affine_2d is not None:
        data, affine_translate = _apply_affine_to_image(data, affine_2d)
        layer_scale, layer_translate = _select_display_params(layer)
        final_translate = (
            affine_translate[0] + layer_translate[0],
            affine_translate[1] + layer_translate[1],
        )
        base_kwargs["translate"] = final_translate
        base_kwargs["scale"] = (1.0, 1.0)
    else:
        scale, translate = _select_display_params(layer)
        base_kwargs["scale"] = scale
        base_kwargs["translate"] = translate

    if isinstance(layer, napari.layers.Image):
        base_kwargs.update(
            {
                "rgb": layer.rgb,
                "colormap": layer.colormap,
                "contrast_limits": layer.contrast_limits,
                "gamma": layer.gamma,
                "interpolation2d": getattr(layer, "interpolation2d", "nearest"),
            }
        )
        return napari.layers.Image(data, **base_kwargs)
    if isinstance(layer, napari.layers.Labels):
        # napari >=0.5 replaced color/num_colors with colormap
        if hasattr(layer, "color") and hasattr(layer, "num_colors"):
            base_kwargs["color"] = layer.color
            base_kwargs["num_colors"] = layer.num_colors
        elif hasattr(layer, "colormap"):
            base_kwargs["colormap"] = layer.colormap
        return napari.layers.Labels(data, **base_kwargs)
    return None


def _flatten_shapes_layer(layer):
    """Return a 2-D Shapes layer corresponding to the current slice."""
    indices = np.asarray(getattr(layer, "_indices_view", []), dtype=int)
    if indices.size == 0:
        return None
    shapes_data = []
    shape_types = []
    for idx in indices:
        shape_obj = layer._data_view.shapes[idx]
        shapes_data.append(np.asarray(shape_obj.data_displayed))
        shape_types.append(shape_obj.name)
    face_colors = np.asarray(layer._data_view.face_color)[indices]
    edge_colors = np.asarray(layer._data_view.edge_color)[indices]
    edge_widths = [layer._data_view.edge_widths[i] for i in indices]
    z_indices = [layer._data_view.z_indices[i] for i in indices]
    features = _subset_table(layer.features, indices)
    properties = _subset_table(layer.properties, indices)
    text_config = None
    if getattr(layer, "text", None) is not None:
        text_dict = layer.text.dict()
        if text_dict.get("string"):
            text_config = text_dict

    scale, translate = _select_display_params(layer)

    return napari.layers.Shapes(
        shapes_data,
        shape_type=shape_types,
        face_color=face_colors,
        edge_color=edge_colors,
        edge_width=edge_widths,
        z_index=z_indices,
        properties=properties,
        features=features,
        text=text_config,
        name=layer.name,
        metadata=_copy_metadata(layer.metadata),
        opacity=layer.opacity,
        blending=_enum_to_value(layer.blending),
        visible=layer.visible,
        scale=scale,
        translate=translate,
    )


def _flatten_vectors_layer(layer):
    """Return a 2-D Vectors (or Shapes) layer for the current slice.

    If the layer's ``vector_style`` is ``"triangle"`` or ``"arrow"``,
    returns a Shapes layer with triangle polygons instead, because
    napari-svg ignores ``vector_style`` and always renders vectors as
    plain ``<line>`` elements.
    """
    indices = np.asarray(getattr(layer, "_view_indices", []), dtype=int)
    if indices.size == 0:
        return None
    data = np.asarray(layer._view_data)
    if data.size == 0:
        return None
    edge_color = layer.edge_color
    if (
        isinstance(edge_color, np.ndarray)
        and edge_color.shape[0] == layer.data.shape[0]
    ):
        edge_color = edge_color[indices]

    scale, translate = _select_display_params(layer)

    vector_style = _enum_to_value(layer.vector_style)

    if vector_style in ("triangle", "arrow"):
        return _vectors_to_triangle_shapes(
            data=data,
            edge_color=edge_color,
            edge_width=layer.edge_width,
            length=layer.length,
            name=layer.name,
            opacity=layer.opacity,
            blending=_enum_to_value(layer.blending),
            visible=layer.visible,
            scale=scale,
            translate=translate,
            metadata=_copy_metadata(layer.metadata),
        )

    return napari.layers.Vectors(
        data,
        name=layer.name,
        metadata=_copy_metadata(layer.metadata),
        edge_width=layer.edge_width,
        vector_style=vector_style,
        length=layer.length,
        edge_color=edge_color,
        edge_colormap=layer.edge_colormap,
        edge_contrast_limits=layer.edge_contrast_limits,
        opacity=layer.opacity,
        blending=_enum_to_value(layer.blending),
        visible=layer.visible,
        scale=scale,
        translate=translate,
    )


def _vectors_to_triangle_shapes(
    *,
    data,
    edge_color,
    edge_width,
    length,
    name,
    opacity,
    blending,
    visible,
    scale,
    translate,
    metadata,
):
    """Convert napari Vectors to a Shapes layer of triangle polygons.

    Each vector is rendered as an isoceles triangle whose tip is at the
    endpoint and whose base sits perpendicular to the vector direction
    at the origin.  Base half-width is set from ``edge_width`` so the
    rasterised output resembles napari's triangle vector style.
    """
    # data shape: (N, 2, D) — D is usually 2 for 2-D or 3 for (t,y,x).
    # We take the last two dims as (y, x).
    origins = data[:, 0, -2:]
    directions = data[:, 1, -2:] * length

    n = len(origins)
    if n == 0:
        return None

    # Ensure edge_color is an (N, 4) RGBA array aligned with the vectors.
    ec = np.asarray(edge_color)
    if ec.ndim == 1:
        ec = np.tile(ec, (n, 1))
    elif ec.shape[0] != n:
        ec = np.tile(ec[0], (n, 1))

    # Width per vector.
    ew = edge_width
    if np.isscalar(ew) or getattr(ew, "ndim", 1) == 0:
        widths = np.full(n, float(ew))
    else:
        widths = np.asarray(ew, dtype=float)
        if widths.shape[0] != n:
            widths = np.full(n, float(widths[0]))

    shapes_data = []
    face_colors = []
    edge_colors = []
    for origin, direction, color, w in zip(origins, directions, ec, widths):
        tip = origin + direction
        dy, dx = direction
        dlen = float(np.hypot(dy, dx))
        if dlen == 0:
            continue
        # Unit perpendicular (rotate 90°).
        py, px = -dx / dlen, dy / dlen
        half_w = max(w * 2.0, 1.0)
        base1 = np.array([origin[0] + py * half_w, origin[1] + px * half_w])
        base2 = np.array([origin[0] - py * half_w, origin[1] - px * half_w])
        shapes_data.append(np.array([tip, base1, base2]))
        face_colors.append(color)
        edge_colors.append(color)

    if not shapes_data:
        return None

    return napari.layers.Shapes(
        shapes_data,
        shape_type="polygon",
        face_color=np.asarray(face_colors),
        edge_color=np.asarray(edge_colors),
        edge_width=0,
        name=name,
        metadata=metadata,
        opacity=opacity,
        blending=blending,
        visible=visible,
        scale=scale,
        translate=translate,
    )


# ---------------------------------------------------------------------------
# Affine / geometry helpers
# ---------------------------------------------------------------------------


def _apply_affine_to_image(data, affine_2d):
    """Apply a 2-D affine transform to image data.

    Since ``napari-svg`` doesn't properly handle the affine parameter, we
    transform the image data directly and return it in world coordinates.

    Parameters
    ----------
    data : np.ndarray
        2-D image data to transform.
    affine_2d : np.ndarray
        3x3 affine transformation matrix.

    Returns
    -------
    transformed_data : np.ndarray
        The transformed image data.
    translate : tuple
        The (y, x) translation to position the image correctly.
    """
    scale_y = affine_2d[0, 0]
    scale_x = affine_2d[1, 1]
    translate_y = affine_2d[0, 2]
    translate_x = affine_2d[1, 2]

    input_h, input_w = data.shape[:2]
    output_h = int(np.ceil(input_h * abs(scale_y)))
    output_w = int(np.ceil(input_w * abs(scale_x)))

    inv_scale_y = 1.0 / scale_y if scale_y != 0 else 1.0
    inv_scale_x = 1.0 / scale_x if scale_x != 0 else 1.0

    transform_matrix = np.array([[inv_scale_y, 0], [0, inv_scale_x]])
    offset = np.array([0, 0])

    original_dtype = data.dtype
    if data.dtype == np.float16:
        data = data.astype(np.float32)

    transformed_data = ndimage.affine_transform(
        data,
        transform_matrix,
        offset=offset,
        output_shape=(output_h, output_w),
        order=0,
        mode="constant",
        cval=np.nan if np.issubdtype(data.dtype, np.floating) else 0,
    )

    if original_dtype == np.float16:
        transformed_data = transformed_data.astype(np.float16)

    translate = (translate_y, translate_x)
    return transformed_data, translate


def _extract_2d_affine(layer):
    """Extract the 2-D affine transform for displayed dimensions.

    Returns the 2-D affine matrix (3x3) if the layer has a non-trivial
    affine, otherwise returns ``None``.
    """
    affine = getattr(layer, "affine", None)
    if affine is None:
        return None

    affine_matrix = np.asarray(affine.affine_matrix)

    if np.allclose(affine_matrix, np.eye(affine_matrix.shape[0])):
        return None

    slice_input = getattr(layer, "_slice_input", None)
    if slice_input is None:
        if affine_matrix.shape == (3, 3):
            return affine_matrix
        return None

    displayed = slice_input.displayed
    if len(displayed) != 2:
        return None

    n = affine_matrix.shape[0] - 1
    indices = list(displayed) + [n]
    affine_2d = affine_matrix[np.ix_(indices, indices)]
    return affine_2d


# ---------------------------------------------------------------------------
# Tiny utilities
# ---------------------------------------------------------------------------


def _enum_to_value(value):
    """Return the primitive value for Enum-like objects."""
    return getattr(value, "value", value)


def _copy_metadata(metadata):
    """Safely copy layer metadata dictionaries."""
    if isinstance(metadata, dict):
        return copy.deepcopy(metadata)
    return metadata


def _select_display_params(layer):
    """Get scale / translate for currently displayed axes."""
    slice_input = getattr(layer, "_slice_input", None)
    if slice_input is None:
        return tuple(layer.scale), tuple(layer.translate)
    displayed = slice_input.displayed
    try:
        scale = tuple(layer.scale[i] for i in displayed)
        translate = tuple(layer.translate[i] for i in displayed)
    except Exception:  # noqa: BLE001
        scale = tuple(layer.scale)
        translate = tuple(layer.translate)
    return scale, translate


def _subset_table(table, indices):
    """Subset napari feature/property tables when possible."""
    if table is None or len(table) == 0:
        return table
    if hasattr(table, "iloc"):
        subset = table.iloc[indices]
        try:
            return subset.copy()
        except Exception:  # noqa: BLE001
            return subset
    if isinstance(table, dict):
        return {k: np.asarray(v)[indices] for k, v in table.items()}
    try:
        return table[indices]
    except Exception:  # noqa: BLE001
        return table
