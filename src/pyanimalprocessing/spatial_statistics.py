"""Spatial statistics and spatial post-processing.

Provides functions for computing global and local spatial autocorrelation
on 2-D gridded data using queen-contiguity spatial weights, as well as
spatial cluster post-processing utilities.
"""

import logging

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# esda's Moran / Moran_Local use permutation tests for p-values (999 perms by
# default). Without a fixed seed the per-cell p_sim values jitter across runs,
# which propagates into downstream LISA ROIs (e.g. flow_roi bin counts) and
# Mann-Whitney significance on aggregated quantities. Pinning the seed makes
# every subsequent run bit-reproducible for a given input array.
DEFAULT_MORAN_SEED = 42


# ---------------------------------------------------------------------------
# Cluster post-processing
# ---------------------------------------------------------------------------


def clean_clusters(df, max_iterations=5):
    """Reassign spatially isolated bins to the majority cluster of their neighbourhood.

    A bin is *isolated* when none of its 4-connected (cardinal) neighbours
    share the same cluster label.  The algorithm reassigns it to the most
    frequent label among its 4-neighbours; when there is a tie, it expands
    to the 8-connected neighbourhood (adding diagonal neighbours) and picks
    the majority there.  The procedure is repeated for up to
    *max_iterations* passes until no more isolated bins remain.

    After relabelling, cluster IDs are re-indexed to consecutive integers
    starting from 0.

    Parameters
    ----------
    df : pd.DataFrame
        DataFrame with a ``pd.MultiIndex`` of ``(x, y)`` bin coordinates.
        Each column holds integer cluster labels for a different partition
        (e.g. columns ``2, 3, ..., 13`` for k = 2 to 13).
    max_iterations : int, optional
        Maximum number of reassignment passes per column (default 5).

    Returns
    -------
    pd.DataFrame
        Cleaned cluster labels, same shape and index as *df*.

    Examples
    --------
    >>> cleaned = clean_clusters(all_clusters.copy())
    """
    cleaned_df = df.copy()

    for col_label in cleaned_df.columns:
        changes_made = True
        iteration = 0

        while changes_made and iteration < max_iterations:
            changes_made = False
            iteration += 1
            pending_changes = {}
            current_labels = cleaned_df[col_label].copy()
            cluster_sizes = current_labels.value_counts()

            for (x, y), _row in cleaned_df.iterrows():
                current_cluster = current_labels.loc[(x, y)]

                # 4-connected neighbours (cardinal)
                neighbors4 = []
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    neighbor = (x + dx, y + dy)
                    if neighbor in cleaned_df.index:
                        neighbors4.append(neighbor)

                if not neighbors4:
                    continue

                neighbor4_clusters = [current_labels.loc[n] for n in neighbors4]
                is_isolated = current_cluster not in neighbor4_clusters

                if not is_isolated:
                    continue

                if cluster_sizes[current_cluster] == 1:
                    continue

                # Majority vote among 4-neighbours
                cluster_counts = {}
                for n_cluster in neighbor4_clusters:
                    cluster_counts[n_cluster] = cluster_counts.get(n_cluster, 0) + 1

                if not cluster_counts:
                    continue

                most_common_clusters = sorted(
                    cluster_counts.items(), key=lambda item: item[1], reverse=True
                )

                if (
                    len(most_common_clusters) > 1
                    and most_common_clusters[0][1] == most_common_clusters[1][1]
                ):
                    # Tie — expand to 8-connected neighbourhood
                    all_neighbors = neighbors4.copy()
                    for dx, dy in [(-1, -1), (-1, 1), (1, -1), (1, 1)]:
                        neighbor = (x + dx, y + dy)
                        if neighbor in cleaned_df.index:
                            all_neighbors.append(neighbor)

                    extended_clusters = [current_labels.loc[n] for n in all_neighbors]
                    extended_counts = {}
                    for n_cluster in extended_clusters:
                        extended_counts[n_cluster] = (
                            extended_counts.get(n_cluster, 0) + 1
                        )

                    extended_most_common = sorted(
                        extended_counts.items(),
                        key=lambda item: item[1],
                        reverse=True,
                    )

                    if (
                        len(extended_most_common) == 1
                        or extended_most_common[0][1] > extended_most_common[1][1]
                    ):
                        majority_cluster = extended_most_common[0][0]
                        if majority_cluster != current_cluster:
                            pending_changes[(x, y)] = majority_cluster
                else:
                    majority_cluster = most_common_clusters[0][0]
                    if majority_cluster != current_cluster:
                        pending_changes[(x, y)] = majority_cluster

            if pending_changes:
                changes_made = True
                for (x, y), new_cluster in pending_changes.items():
                    cleaned_df.at[(x, y), col_label] = new_cluster

        # Re-index to consecutive integers starting from 0
        unique_clusters = pd.unique(cleaned_df[col_label])
        cluster_map = {old: new for new, old in enumerate(sorted(unique_clusters))}
        cleaned_df[col_label] = cleaned_df[col_label].map(cluster_map)

    return cleaned_df


# ---------------------------------------------------------------------------
# Spatial weights
# ---------------------------------------------------------------------------

def _create_custom_weights(data):
    """Build queen-contiguity spatial weights for a 2-D grid.

    NaN cells are excluded from the neighbour graph.

    Parameters
    ----------
    data : np.ndarray
        2-D array of values (may contain NaN).

    Returns
    -------
    libpysal.weights.W
        Row-standardised spatial weights matrix.
    """
    import libpysal as lps

    rows, cols = data.shape
    w = lps.weights.W(neighbors={})

    for row in range(rows):
        for col in range(cols):
            if np.isnan(data[row, col]):
                continue
            neighbors = []
            for i in range(max(0, row - 1), min(rows, row + 2)):
                for j in range(max(0, col - 1), min(cols, col + 2)):
                    if (i, j) != (row, col) and not np.isnan(data[i, j]):
                        neighbors.append((i, j))
            w.neighbors[(row, col)] = neighbors

    w.weights = {id: [1 for _ in w.neighbors[id]] for id in w.neighbors}
    w.transform = "r"
    return w


# ---------------------------------------------------------------------------
# Global Moran's I
# ---------------------------------------------------------------------------

def compute_moran(data, seed=DEFAULT_MORAN_SEED):
    """Compute global Moran's I for a 2-D spatial array.

    Parameters
    ----------
    data : np.ndarray
        2-D array (may contain NaN).
    seed : int or None, optional
        Seed for the permutation-test RNG.  ``None`` restores the
        previous non-deterministic behaviour.

    Returns
    -------
    esda.moran.Moran
        Moran's I result object.
    """
    import libpysal as lps
    from esda.moran import Moran

    w = _create_custom_weights(data)
    valid_data_indices = [
        (i, j)
        for i in range(data.shape[0])
        for j in range(data.shape[1])
        if not np.isnan(data[i, j])
    ]
    data_flattened = np.array([data[i, j] for i, j in valid_data_indices])

    reordered_weights = lps.weights.W(
        {idx: w.neighbors[idx] for idx in valid_data_indices}
    )
    reordered_weights.transform = "r"

    # esda.Moran has no `seed` kwarg; it draws via numpy's global RNG.
    if seed is not None:
        np.random.seed(seed)

    return Moran(data_flattened, reordered_weights)


# ---------------------------------------------------------------------------
# Local Moran's I
# ---------------------------------------------------------------------------

def _compute_moran_local_extended(data, seed=DEFAULT_MORAN_SEED, permutations=999):
    """Compute Local Moran's I (LISA) with HH/LL/HL/LH classification.

    Parameters
    ----------
    data : np.ndarray
        2-D array (may contain NaN).
    seed : int or None, optional
        Seed for the permutation-test RNG.  ``None`` restores the
        previous non-deterministic behaviour.
    permutations : int, optional
        Number of conditional permutations for the LISA p-value test.

    Returns
    -------
    p_values : np.ndarray
        P-values for each cell (1.0 for NaN cells).
    hh_map : np.ndarray (bool)
        High-High cluster map.
    ll_map : np.ndarray (bool)
        Low-Low cluster map.
    hl_map : np.ndarray (bool)
        High-Low cluster map.
    lh_map : np.ndarray (bool)
        Low-High cluster map.
    """
    import libpysal as lps
    from esda.moran import Moran_Local
    from libpysal.weights.spatial_lag import lag_spatial

    w = _create_custom_weights(data)
    valid_data_indices = [
        (i, j)
        for i in range(data.shape[0])
        for j in range(data.shape[1])
        if not np.isnan(data[i, j])
    ]
    data_flattened = np.array(
        [data[i, j] for i, j in valid_data_indices], dtype=np.float64
    )

    reordered_weights = lps.weights.W(
        {idx: w.neighbors[idx] for idx in valid_data_indices}
    )
    reordered_weights.transform = "r"

    local_moran = Moran_Local(
        data_flattened, reordered_weights, seed=seed, permutations=permutations
    )
    mean_value = np.mean(data_flattened)

    p_values = np.ones(data.shape, dtype=np.float64)
    hh_map = np.zeros(data.shape, dtype=bool)
    ll_map = np.zeros(data.shape, dtype=bool)
    hl_map = np.zeros(data.shape, dtype=bool)
    lh_map = np.zeros(data.shape, dtype=bool)

    spatial_lag = lag_spatial(reordered_weights, data_flattened)

    for loc, (i, j) in enumerate(valid_data_indices):
        p_values[i, j] = local_moran.p_sim[loc]
        value = data[i, j]
        lag = spatial_lag[loc]

        if value > mean_value and lag > mean_value:
            hh_map[i, j] = True
        elif value < mean_value and lag < mean_value:
            ll_map[i, j] = True
        elif value > mean_value and lag < mean_value:
            hl_map[i, j] = True
        elif value < mean_value and lag > mean_value:
            lh_map[i, j] = True

    return p_values, hh_map, ll_map, hl_map, lh_map


# ---------------------------------------------------------------------------
# Moran scatterplot
# ---------------------------------------------------------------------------

def plot_moran(moran, ax=None, scatter_kwds=None, fit_kwds=None):
    """Plot a Moran scatterplot with linear regression fit.

    Parameters
    ----------
    moran : esda.moran.Moran
        Moran result object.
    ax : matplotlib.axes.Axes, optional
        Axes to plot on. Uses current axes if None.
    scatter_kwds : dict, optional
        Keyword arguments passed to ``ax.scatter``.
    fit_kwds : dict, optional
        Keyword arguments passed to ``ax.plot`` for the fit line.

    Returns
    -------
    matplotlib.axes.Axes
    """
    import matplotlib.pyplot as plt
    from libpysal.weights.spatial_lag import lag_spatial
    from scipy import stats

    if scatter_kwds is None:
        scatter_kwds = {}
    if fit_kwds is None:
        fit_kwds = {}

    if ax is None:
        ax = plt.gca()

    ax.spines["left"].set_position(("axes", -0.05))
    ax.spines["right"].set_color("none")
    ax.spines["bottom"].set_position(("axes", -0.05))
    ax.spines["top"].set_color("none")

    ax.set_xlabel("Attribute")
    ax.set_ylabel("Spatial Lag")

    lag = lag_spatial(moran.w, moran.z)

    slope, intercept, r_value, p_value, std_err = stats.linregress(moran.z, lag)

    ax.scatter(moran.z, lag, **scatter_kwds)
    ax.axvline(0, alpha=0.5, color="k", linestyle="--")
    ax.axhline(0, alpha=0.5, color="k", linestyle="--")

    x_vals = np.array(ax.get_xlim())
    y_vals = intercept + slope * x_vals
    fit_label = f"Linear fit\n$r$={r_value:.2f}, p={p_value:.2e}"
    ax.plot(x_vals, y_vals, **fit_kwds, label=fit_label)

    ax.set_title(f"Moran's diagram (I={np.round(moran.I, 2)})")
    ax.set_ylim((-2.5, 2.5))
    ax.set_xlim((-3, 3))

    ax.legend(fontsize="small")
    return ax


# ---------------------------------------------------------------------------
# LISA over 3-D array (time x y x x)
# ---------------------------------------------------------------------------

def compute_local_spatial_association(
    data_array, pval_threshold=0.01, seed=DEFAULT_MORAN_SEED, permutations=999,
):
    """Compute LISA (Local Indicators of Spatial Association) for a 3-D array.

    Parameters
    ----------
    data_array : np.ndarray
        3-D array with shape (time_points, y, x).
    pval_threshold : float
        Unused (kept for API compatibility). Filtering should be done
        on the returned p-values.
    seed : int or None, optional
        Seed for the permutation-test RNG, forwarded to
        :func:`_compute_moran_local_extended` for every frame.
        ``None`` restores the previous non-deterministic behaviour.
    permutations : int, optional
        Number of conditional permutations per cell for the LISA p-values.

    Returns
    -------
    p_values : np.ndarray
    hh_map : np.ndarray (bool)
    ll_map : np.ndarray (bool)
    hl_map : np.ndarray (bool)
    lh_map : np.ndarray (bool)
    """
    logger.info("Computing Local Indicators of Spatial Association...")

    p_values, hh_map, ll_map, hl_map, lh_map = [], [], [], [], []

    for i in range(data_array.shape[0]):
        if np.all(np.isnan(data_array[i])):
            tmp = np.empty_like(data_array[i])
            tmp[:] = np.nan
            p_values.append(tmp)
            hh_map.append(np.zeros_like(data_array[i]))
            ll_map.append(np.zeros_like(data_array[i]))
            hl_map.append(np.zeros_like(data_array[i]))
            lh_map.append(np.zeros_like(data_array[i]))
        else:
            pv, hh, ll, hl, lh = _compute_moran_local_extended(
                data_array[i], seed=seed, permutations=permutations,
            )
            p_values.append(pv)
            hh_map.append(hh)
            ll_map.append(ll)
            hl_map.append(hl)
            lh_map.append(lh)

    return (
        np.stack(p_values),
        np.stack(hh_map),
        np.stack(ll_map),
        np.stack(hl_map),
        np.stack(lh_map),
    )


# ---------------------------------------------------------------------------
# Diverging colorbar for LISA visualisation
# ---------------------------------------------------------------------------

def create_diverging_moran_colorbar(
    color_low, color_high, title, ll_label, hh_label, figsize=(0.25, 1.4)
):
    """Create a diverging colorbar for Local Moran statistics (LL <-> HH).

    Parameters
    ----------
    color_low : str
        Colour for LL (Low-Low) clusters.
    color_high : str
        Colour for HH (High-High) clusters.
    title : str
        Title text for the colorbar.
    ll_label : str
        Label for the LL end.
    hh_label : str
        Label for the HH end.
    figsize : tuple
        Figure size (width, height).

    Returns
    -------
    matplotlib.figure.Figure
    """
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap

    colors = [color_low, "white", color_high]
    cmap = LinearSegmentedColormap.from_list("diverging_moran", colors, N=256)

    fig, ax = plt.subplots(figsize=figsize)

    ax.set_xticks([])
    for spine in ["top", "right", "bottom", "left"]:
        ax.spines[spine].set_visible(False)

    norm = plt.Normalize(-3, 3)
    sm = plt.cm.ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])

    cb = plt.colorbar(sm, cax=ax, orientation="vertical")
    cb.set_ticks([-3, -2, -1, 0, 1, 2, 3])
    cb.set_ticklabels(["3", "2", "1", "0", "1", "2", "3"])
    cb.ax.tick_params(labelsize=5, length=2, width=0.5)

    cb.ax.set_title(title, fontsize=6, fontweight="bold", pad=6)

    cb.ax.text(
        0.5, -0.08, ll_label,
        transform=cb.ax.transAxes, ha="center", va="top",
        fontsize=5, fontstyle="italic",
    )
    cb.ax.text(
        0.5, 1.02, hh_label,
        transform=cb.ax.transAxes, ha="center", va="bottom",
        fontsize=5, fontstyle="italic",
    )

    cb.set_label(r"$-\mathrm{log}_{10}(p)$", rotation=270, labelpad=12, fontsize=7)

    for spine in cb.ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(0.5)
        spine.set_color("gray")

    fig.subplots_adjust(left=0.1, right=0.5, top=0.85, bottom=0.15)
    return fig


# ---------------------------------------------------------------------------
# ROI outline generation
# ---------------------------------------------------------------------------

def create_high_res_roi_outline(roi_mask, upscale_factor=10, outline_width=3):
    """Create a high-resolution outline from a boolean ROI mask.

    Upscales the mask with nearest-neighbour interpolation, extracts inner
    boundaries, optionally dilates, and returns a labelled outline array.

    Parameters
    ----------
    roi_mask : np.ndarray
        2-D boolean mask.
    upscale_factor : int
        Zoom factor for the upscale step.
    outline_width : int
        Outline thickness (applied as morphological dilation radius).

    Returns
    -------
    np.ndarray
        Labelled array where each connected boundary segment has a
        distinct integer label.  Background is 0.
    """
    from scipy.ndimage import label, zoom
    from skimage.morphology import binary_dilation, disk
    from skimage.segmentation import find_boundaries

    if not np.any(roi_mask):
        return np.zeros(
            (roi_mask.shape[0] * upscale_factor, roi_mask.shape[1] * upscale_factor),
            dtype=int,
        )

    roi_mask_high_res = zoom(roi_mask, upscale_factor, order=0)
    boundary = find_boundaries(roi_mask_high_res, mode="inner")

    if outline_width > 1:
        selem = disk(outline_width / 2)
        boundary = binary_dilation(boundary, selem)

    labels, _ = label(boundary)
    return labels


# ---------------------------------------------------------------------------
# Moran data masking and cropping
# ---------------------------------------------------------------------------

def mask_and_crop_moran(
    p_values,
    affine_transform,
    masks,
    image_size,
    frame_offset=0,
):
    """Mask noisy grid positions and crop Moran arrays to the tissue extent.

    Converts grid indices to image-space coordinates via the affine, then
    NaN-outs p-values at grid positions falling within each mask circle.
    Finally, crops to the grid positions whose image-space coordinates
    fall within *image_size* and adjusts the affine to match.

    Parameters
    ----------
    p_values : np.ndarray
        LISA p-values array ``(T, Ny, Nx)``.
    affine_transform : np.ndarray
        3x3 grid-to-image-space affine transformation.
    masks : list of dict
        Each dict has keys ``center`` ``[y, x]``, ``radius`` (pixels), and
        optional ``frames`` ``[start, end]`` (inclusive, in viewer coords).
    image_size : tuple
        ``(height, width)`` tissue image dimensions in pixels.
    frame_offset : int
        Offset to convert viewer frame numbers to array indices.

    Returns
    -------
    masked_cropped : np.ndarray
        Masked and cropped p-values ``(T, Ny_crop, Nx_crop)``.
    crop_y : slice
        Row slice for cropping companion arrays identically.
    crop_x : slice
        Column slice for cropping companion arrays identically.
    adjusted_affine : np.ndarray
        Affine adjusted for the crop offset.
    """
    from scipy.spatial.distance import cdist

    masked = p_values.copy()
    n_frames, ny, nx = masked.shape

    # Build image-space coordinates for every grid position
    jj, ii = np.meshgrid(np.arange(nx), np.arange(ny))
    ones = np.ones(ny * nx)
    grid_coords = np.stack(
        [ii.ravel(), jj.ravel(), ones],
        axis=1,
    )  # (Ny*Nx, 3)
    img_coords = (affine_transform @ grid_coords.T).T[:, :2]  # (Ny*Nx, 2)
    img_y = img_coords[:, 0].reshape(ny, nx)
    img_x = img_coords[:, 1].reshape(ny, nx)

    # Masking (circle masks)
    if masks:
        for mask in masks:
            center = np.array(mask["center"], dtype=float).reshape(1, 2)
            radius = float(mask["radius"])
            frame_range = mask.get("frames")

            dists = cdist(img_coords, center).ravel()
            spatial_mask = (dists <= radius).reshape(ny, nx)

            if not np.any(spatial_mask):
                continue

            if frame_range is not None:
                t_start = int(frame_range[0]) - frame_offset
                t_end = int(frame_range[1]) - frame_offset
                frame_slice = slice(
                    max(t_start, 0),
                    min(t_end + 1, n_frames),
                )
            else:
                frame_slice = slice(None)

            masked[frame_slice, spatial_mask] = np.nan

    # Crop to tissue extent
    h, w = image_size
    in_bounds = (img_y >= 0) & (img_y < h) & (img_x >= 0) & (img_x < w)

    rows_valid = np.any(in_bounds, axis=1)
    cols_valid = np.any(in_bounds, axis=0)

    if not np.any(rows_valid) or not np.any(cols_valid):
        return masked, slice(None), slice(None), affine_transform.copy()

    y_lo = int(np.argmax(rows_valid))
    y_hi = int(ny - 1 - np.argmax(rows_valid[::-1]))
    x_lo = int(np.argmax(cols_valid))
    x_hi = int(nx - 1 - np.argmax(cols_valid[::-1]))

    crop_y = slice(y_lo, y_hi + 1)
    crop_x = slice(x_lo, x_hi + 1)
    masked_cropped = masked[:, crop_y, crop_x]

    # Adjust affine: new index (0,0) maps to old index (y_lo, x_lo)
    offset = np.eye(3)
    offset[0, 2] = y_lo
    offset[1, 2] = x_lo
    adjusted_affine = affine_transform @ offset

    logger.info(
        "Moran mask+crop: (%d,%d) -> (%d,%d)",
        ny,
        nx,
        masked_cropped.shape[1],
        masked_cropped.shape[2],
    )
    return masked_cropped, crop_y, crop_x, adjusted_affine


# ---------------------------------------------------------------------------
# Per-animal ROI aggregation
# ---------------------------------------------------------------------------


def per_animal_mean_over_roi(
    backup,
    quantity,
    roi,
    *,
    n_animals=None,
    component="iso",
):
    """Per-animal mean of a tensor/vector quantity inside a spatial ROI.

    Reads *quantity* one animal at a time, keeps only grid positions where *roi*
    is truthy, and returns a per-animal summary. The reduction runs in float64:
    the stores are float16, and a direct float16 sum saturates for large-magnitude
    fields (e.g. velocity), corrupting the mean.

    Parameters
    ----------
    backup : zarr.hierarchy.Group
        Average-Over-Animals (AOA) backup; *quantity* carries a per-animal axis as
        its last dimension (index 0 = across-animals mean).
    quantity : str
        Field name inside *backup* (e.g. ``"EpsilonPIV"`` matrix, ``"UPIV"`` vector).
    roi : np.ndarray
        Boolean mask of shape ``(T, ny, nx)``; ``True`` where to include.
    n_animals : int, optional
        Number of individual animals; defaults to ``shape[-1] - 1``.
    component : {"iso", "dev"}
        - ``"iso"`` — isotropic scalar of a 2x2 matrix field, via the same
          decomposition the plotting path uses
          (:func:`~pyanimalprocessing.plotting.property_utils.create_vectors_values_matrix`):
          shape ``(n_animals,)``.
        - ``"dev"`` — the ``(y, x)`` components of a 2-component vector field
          (reversed to image order): shape ``(n_animals, 2)``.

    Returns
    -------
    np.ndarray
        ``(n_animals,)`` for ``"iso"``; ``(n_animals, 2)`` for ``"dev"``.
    """
    from .plotting.property_utils import create_vectors_values_matrix

    if component not in ("iso", "dev"):
        raise ValueError(f"component must be 'iso' or 'dev', got {component!r}")

    data = np.asarray(backup[quantity], dtype=np.float64)
    if data.ndim == 6:  # unified (T, 1, ny, nx, comp, animals) -> drop the channel axis
        data = data[:, 0]
    # data is now (T, ny, nx, comp, animals); animal axis last, index 0 = mean.
    if n_animals is None:
        n_animals = data.shape[-1] - 1

    if component == "iso":
        out = np.empty(n_animals)
        for i, idx in enumerate(range(1, n_animals + 1)):
            # Reuse the plotting decomposition so "isotropic" has one definition
            # across plotting and statistics.
            _, iso = create_vectors_values_matrix(data[..., idx].reshape(-1, 2, 2))
            iso = np.where(roi.reshape(-1), iso, np.nan)
            out[i] = np.nanmean(iso) if np.any(np.isfinite(iso)) else np.nan
        return out

    # component == "dev": a 2-component vector field, in image (y, x) order.
    if data.shape[-2] != 2:
        raise ValueError(
            f"component='dev' expects a 2-component vector, got {data.shape[-2]} components"
        )
    out = np.empty((n_animals, 2))
    for i, idx in enumerate(range(1, n_animals + 1)):
        vec = np.where(roi[..., None], data[..., ::-1, idx], np.nan)  # (T, ny, nx, 2)
        out[i] = np.nanmean(vec, axis=(0, 1, 2))
    return out


def per_animal_weighted_mean_in_roi(
    backup,
    quantity,
    roi_2d,
    t_idx,
    *,
    matrix_op=None,
    normalizer=None,
):
    """Area-weighted per-animal mean of a Lagrangian tensor at one time index.

    Restricts the computation to positions where *roi_2d* is ``True`` and
    weights each position by the per-animal ``AreaRatios`` entry.  Matches
    the pattern used in ``figure_morphodynamics_comparison``'s Lagrangian bar-plot helpers.  Reads in
    float64 (the stores are float16) and accepts both the compact
    ``(T, ny, nx, [comp,] animals)`` and unified
    ``(T, 1, ny, nx, comp, animals)`` layouts.

    Parameters
    ----------
    backup : zarr.hierarchy.Group
        Lagrangian AOA group (e.g. ``AOA_avgAnimals_vi_2h_0.96olap``) with
        per-animal axis as the last dimension on *quantity* and
        ``AreaRatios``.
    quantity : str
        Tensor name inside *backup* (e.g. ``"ER"``, ``"ES"``, ``"dnA"``).
    roi_2d : np.ndarray
        2-D boolean mask of shape ``(ny, nx)``.
    t_idx : int
        Lagrangian time index at which to evaluate.
    matrix_op : {"trace", "anisotropy"} or None
        For matrix-valued tensors (shape ``(T, ny, nx, 4, n_animals)``): how
        to reduce the 4-component axis.

        - ``"trace"`` — component 0 + component 3
        - ``"anisotropy"`` — eigenvalue difference ``sqrt((c0 − c3)² + 4 c1²)``

        ``None`` is for scalar tensors (shape ``(T, ny, nx, n_animals)``).
    normalizer : np.ndarray, optional
        Array broadcastable against the tensor; the tensor is divided by this
        before aggregation.  Typical use: per-animal nCoreRNS broadcast over
        space and time.

    Returns
    -------
    np.ndarray
        Shape ``(n_animals,)``.  NaN where no valid bins were found.
    """
    tensor = np.asarray(backup[quantity], dtype=np.float64)
    if tensor.ndim == 6:  # unified (T,1,ny,nx,comp,animals) -> drop channel axis
        tensor = tensor[:, 0]
    if tensor.ndim == 5 and tensor.shape[-2] == 1:  # unified scalar -> drop singleton comp
        tensor = tensor[..., 0, :]
    tensor = tensor[..., 1:]  # drop the across-animals mean (animal index 0)

    area_ratios = np.asarray(backup["AreaRatios"], dtype=np.float64)
    if area_ratios.ndim == 6:  # unified (T,1,ny,nx,1,animals) -> (T,ny,nx,animals)
        area_ratios = area_ratios[:, 0, :, :, 0, :]
    area_ratios = area_ratios[..., 1:]

    if normalizer is not None:
        tensor = tensor / normalizer

    indices = np.argwhere(roi_2d)
    n_animals = tensor.shape[-1]
    out = np.empty(n_animals)

    for a in range(n_animals):
        weights = area_ratios[t_idx, indices[:, 0], indices[:, 1], a]

        if tensor.ndim == 5:  # matrix (T, ny, nx, 4, n)
            mats = tensor[t_idx, indices[:, 0], indices[:, 1], :, a]
            if matrix_op == "trace":
                vals = mats[:, 0] + mats[:, 3]
            elif matrix_op == "anisotropy":
                vals = np.sqrt((mats[:, 0] - mats[:, 3]) ** 2 + 4 * mats[:, 1] ** 2)
            else:
                raise ValueError(
                    f"matrix_op is required for matrix tensors, got {matrix_op!r}"
                )
        else:  # scalar (T, ny, nx, n)
            vals = tensor[t_idx, indices[:, 0], indices[:, 1], a]

        valid = ~np.isnan(vals) & (weights > 0)
        out[a] = (
            np.average(vals[valid], weights=weights[valid]) if valid.any() else np.nan
        )
    return out
