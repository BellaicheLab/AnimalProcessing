"""Gene expression pattern advection through tracked cell movies."""

from joblib import Parallel, delayed
import numpy as np
from skimage.measure import regionprops
import napari

from pyanimalprocessing.rescaling.geometry import map_to_image


def attribute_label_to_movie(
    rescaled_pattern,
    relabelled_movie,
    reference_frame,
    log_images=False,
    log_name="debug_image",
    **kwargs
):
    """
    Matches a rescaled pattern onto a relabelled movie to track the evolution of the pattern onto that movie from pure advection.

    This function obtains the centers of mass for each label in the relabelled movie at the reference frame,
    then creates a mapping from label to gene expression values in the rescaled pattern. The relabelled movie is then converted to these values.

    Parameters
    ----------
    rescaled_pattern : ndarray
        The pattern after it has been rescaled using the `rescale_pattern_to_movie` function.
    relabelled_movie : ndarray
        The movie after all the labels have been harmonized, obtained using the relabel function.
        The CellTracking function must have been run prior to this.
    reference_frame : int
        The reference frame of the movie which corresponds to the pattern matched to it.
    log_images : bool, optional
        Flag indicating whether to log images onto a Napari viewer for visualization. Default is False.
    log_name : str, optional
        Name to be assigned to the logged images in the Napari viewer. Default is "debug_image".

    Returns
    -------
    ndarray
        The relabelled movie with labels converted to gene expression values. Each frame is processed separately and the results are stacked together.

    """

    # We first get the centers of mass for each label
    props = regionprops(relabelled_movie[reference_frame, :, :])

    labels = np.array([prop.label for prop in props])
    centroids = np.array([prop.centroid for prop in props], dtype=np.int32)

    x_values = centroids[:, 0]
    y_values = centroids[:, 1]

    # Check if centroids are within the rescaled pattern bounds
    valid_indices = (x_values < rescaled_pattern.shape[0]) & (y_values < rescaled_pattern.shape[1])

    values = np.zeros(len(labels))
    values[valid_indices] = rescaled_pattern[x_values[valid_indices], y_values[valid_indices]]

    # Then we create a mapping dictionary label -> expression value as well as a function to handle missing keys
    label_value_map = dict(zip(labels, values))

    def get_value(x):
        return label_value_map.get(x, np.nan)

    # Finally we convert labels to values
    def get_values(i):
        return np.vectorize(get_value)(relabelled_movie[i]).astype(np.float32)

    # This is the parallelization part
    expression = Parallel(n_jobs=-1)(
        delayed(get_values)(i) for i in range(relabelled_movie.shape[0])
    )

    expression = np.stack(expression)

    if log_images:
        viewer = napari.current_viewer()
        if viewer is None:
            viewer = napari.Viewer()

        viewer.add_image(expression, name=log_name, **kwargs)

    return expression


def advect_grid_to_movie(
    matrix_2d, xy_starts_grid, xy_start, overlap, boxsize, tracking_mask, frame_ref,
):
    """Rescale a 2-D grid matrix to image space and advect through time.

    Composes :func:`~pyanimalprocessing.rescaling.geometry.map_to_image` and
    :func:`attribute_label_to_movie` to go from a single grid-resolution
    map to a full-resolution advected movie.

    Parameters
    ----------
    matrix_2d : np.ndarray
        2-D matrix in grid coordinates.
    xy_starts_grid : array-like
        Grid origin ``[xStart, yStart]``.
    xy_start : array-like
        Image-space origin ``[xStart, yStart]``.
    overlap : float
        Overlap fraction (scalar, applied to x and y).
    boxsize : array-like
        Box dimensions ``[width, height]``.
    tracking_mask : np.ndarray
        Division-agnostic tracking masks ``(n_frames, H, W)``.
    frame_ref : int
        Reference frame index for advection.

    Returns
    -------
    np.ndarray
        Advected pattern ``(n_frames, H, W)``.
    """
    rescaled = map_to_image(
        matrix_2d, xy_starts_grid, xy_start, overlap, boxsize, log_images=False,
    )
    return attribute_label_to_movie(
        rescaled, tracking_mask, frame_ref, log_images=False,
    )
