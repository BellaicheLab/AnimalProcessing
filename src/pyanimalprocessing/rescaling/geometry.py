"""Grid-to-image coordinate transforms and rescaling."""

import napari
import numpy as np
import zarr
from joblib import Parallel, delayed
from skimage.transform import rescale


def get_coordinate_system_from_backup(backup: zarr.hierarchy.group):
    x_start = backup.attrs["xStart"]
    y_start = backup.attrs["yStart"]

    box_height = backup.attrs["boxHeight"]
    box_width = backup.attrs["boxWidth"]

    overlap = backup.attrs["Overlap"]
    x_start_grid = int(x_start / (box_width * (1 - overlap))) - 1
    y_start_grid = int(y_start / (box_height * (1 - overlap))) - 1

    start_movie = np.array([x_start, y_start, 0])
    start_grid = np.array([x_start_grid, y_start_grid, 0])
    boxsizes = np.array([box_width, box_height, 1])
    overlaps = np.array([overlap, overlap, 0])

    return start_movie, start_grid, boxsizes, overlaps


def box_centres_from_backup(backup, common_frame=False):
    """Grid box centres ``(Ny, Nx, 2)`` as ``(y, x)`` from a backup's box attrs.

    In the backup's own image frame by default; with ``common_frame=True`` the
    animal-specific origin is dropped (``xStart/yStart -> 0``) so the boxes land on the
    shared archetype grid (the form an averaged overlay uses, then mapped onto a movie by
    ``inv(reference_animal.matrix_transform)``).
    """
    start_movie, start_grid, boxsizes, overlaps = get_coordinate_system_from_backup(backup)
    if common_frame:
        start_movie = np.zeros(3)
    ny, nx = [int(s) for s in backup.attrs["Size"]]
    ii, jj = np.mgrid[0:ny, 0:nx]
    points = np.stack([jj.ravel(), ii.ravel(), np.zeros(ny * nx)], axis=1).astype(float)
    mapped = map_points_to_movie(points, start_grid, start_movie, overlaps, boxsizes)
    return mapped[:, 1:3].reshape(ny, nx, 2)  # drop the time column, keep (y, x)


def movie_frame_coordinate_system(backup, reference_animal=None):
    """Coordinate system that places ``backup``'s grid onto ``reference_animal``'s movie.

    ``backup`` supplies the grid start + overlap. When ``reference_animal`` (a registered
    animal store) is given, the origin becomes its ``xStart/yStart`` and each isotropic
    archetype box is squashed into that animal's pixel frame by its ``xFactor``/``yFactor``
    (the SAP anisotropy) — so any registered animal can host an averaged overlay from its
    own attrs. Otherwise the backup's own frame is used.
    """
    start_movie, start_grid, boxsizes, overlaps = get_coordinate_system_from_backup(backup)
    if reference_animal is not None:
        ra = reference_animal.attrs
        start_movie = np.array([ra["xStart"], ra["yStart"], 0])
        boxsizes = np.array(
            [backup.attrs["boxWidth"] / ra["xFactor"], backup.attrs["boxHeight"] / ra["yFactor"], 1]
        )
    return start_movie, start_grid, boxsizes, overlaps


def find_affine_transform(starts_maps, starts_movie, overlap, boxsize):
    """
    Calculate the affine transformation needed to map coordinates from map space to movie space.

    Parameters
    ----------
    starts_maps : ndarray
        Start of the pattern in the reference of map. Spatial units are in boxes.
    starts_movie : ndarray
        Start coordinates in the movie space.
    overlap : float or ndarray
        Overlap between boxes.
    boxsize : ndarray
        Size of each box in pixels.

    Returns
    -------
    ndarray
        3x3 affine transformation matrix that can be used with napari.
    """
    # Calculate scaling
    scale = (boxsize * (1 - overlap))[::-1]

    # Calculate translation
    # Since the affine transform applies scaling before translation,
    # we need to divide the translation by the scale factor
    raw_translation = -(starts_movie - (starts_maps * (1 - overlap)) * boxsize)[::-1]

    # Add half-box offset
    quarter_box = boxsize[::-1] / 4

    adjusted_translation = raw_translation - quarter_box

    # Create affine transformation matrix
    affine_matrix = np.array(
        [
            [scale[0], 0, -adjusted_translation[0]],
            [0, scale[1], -adjusted_translation[1]],
            [0, 0, 1],
        ]
    )

    return affine_matrix


def map_to_image(
    maps,
    starts_maps,
    starts_movie,
    overlap,
    boxsize,
    log_images=False,
    log_name="debug_image",
):
    """
    Upscales a map of a quantity (typically obtained by averaging a quantity alongside boxes) in boxes
    to match the characteristics of a specific movie or image.

    Parameters
    ----------
    maps : ndarray
        array to be fit to a movie. Spatial units are in boxes.
    starts_maps : ndarray
        Start of the pattern in the reference of map. Spatial units are in boxes.
    overlap : float
        Overlap of the boxes when computing the final pattern (corresponds to the same variable in the pipeline)
    boxsize : ndarray
        Size of each box in pixels.
    starts_movie : ndarray
        Start of the movie in x and y. This parameter is obtained from running the Rescale Animals
        function in the pipeline. The pattern is rescaled with the same archetype.
    log_images : bool, optional
        Flag indicating whether to log images onto a Napari viewer for visualization. Default is False.
    log_name : str, optional
        Name to be assigned to the logged images in the Napari viewer. Default is "debug_image".

    Returns
    -------
    ndarray
        The rescaled gene expression pattern.
    """

    new_coords = (
        -(starts_movie - (starts_maps * (1 - overlap)) * boxsize).astype(int)
    )[::-1]

    # viewer.add_points(new_coords, face_color="red",size=300)
    # viewer.add_points(starts_movie[::-1], face_color="blue", size=300)
    # viewer.add_points((starts_maps * (1 - overlap) * boxsize), face_color="green", size=300)

    if maps.ndim == 3:
        rescaled_pattern = _rescale_xyt_maps_to_movie(maps, boxsize, overlap)
    elif maps.ndim == 2:
        rescaled_pattern = _rescale_xy_maps_to_movie(maps, boxsize, overlap)

    else:
        raise ValueError("Boxsize must either have 2 or 3 dimensions")

    bounds = np.array(
        [
            [new_coords[dim], max([0, new_coords[dim]]) + rescaled_pattern.shape[dim]]
            for dim in range(len(maps.shape))
        ]
    )

    shape = np.diff(bounds, axis=1).astype(int).ravel()

    final_array = np.empty(shape, dtype=np.float16)
    final_array[:] = np.nan

    # We define the cropping boundaries of the array
    slices = []
    slices_host = []
    for dim in range(len(maps.shape)):
        start_host = max(0, -new_coords[dim])
        stop_host = (
            max(0, -new_coords[dim])
            + rescaled_pattern.shape[dim]
            - max(0, new_coords[dim])
        )

        start = max(0, new_coords[dim])
        stop = rescaled_pattern.shape[dim]

        slices.append(slice(start, stop))
        slices_host.append(slice(start_host, stop_host))

    final_array[tuple(slices_host)] = rescaled_pattern[tuple(slices)]

    if log_images:
        viewer = napari.current_viewer()
        if viewer is None:
            viewer = napari.Viewer()

        viewer.add_image(final_array, name=log_name)

    return final_array


def _rescale_xy_maps_to_movie(maps, boxsize, overlaps):
    """
    Rescale given maps based on box size and overlap.

    A private function to rescale the provided maps according to a defined box size and overlap,
    used for image rescaling tasks in microscopy data processing.

    Parameters
    ----------
    maps : ndarray
        Input maps to be rescaled.
    boxsize : tuple
        Dimensions of the box in the format (height, width).
    overlap : float
        Overlap ratio between boxes. Should be between 0 and 1.

    Returns
    -------
    ndarray
        The rescaled maps.

    Raises
    ------
    ValueError
        If the dimensions of the maps do not match with the dimensions specified by the boxsize.
    """

    if maps.ndim != len(boxsize):
        raise ValueError(
            f"maps has {maps.ndim} dimensions and boxsize is {boxsize}, their dimensions must match"
        )

    return rescale(maps, (boxsize * (1 - overlaps))[::-1], order=0, clip=False).astype(
        np.float16
    )


def _rescale_xyt_maps_to_movie(maps, boxsize, overlap):
    """
    Rescale given maps based on box size and overlap for time series data.

    A private function for image rescaling tasks in time series microscopy data processing. It uses parallel
    processing to speed up the rescaling process.

    Parameters
    ----------
    maps : ndarray
        Input maps to be rescaled.
    boxsize : tuple
        Dimensions of the box in the format (height, width, time).
    overlap : float
        Overlap ratio between boxes. Should be between 0 and 1.

    Returns
    -------
    ndarray
        The rescaled maps.

    Raises
    ------
    ValueError
        If the dimensions of the maps do not match with the dimensions specified by the boxsize, or the
        time dimension of the box size is not 1.
    """

    if maps.ndim != len(boxsize):
        raise ValueError(
            f"maps has {maps.ndim} dimensions and boxsize is {boxsize}, their dimensions must match"
        )

    if boxsize[2] != 1:
        raise ValueError("t of boxsize must have a value of 1 (for now)")

    boxsize_xy = boxsize[:-1]
    overlap_xy = overlap[:-1]

    jobs = [
        delayed(_rescale_xy_maps_to_movie)(maps[i], boxsize_xy, overlap_xy)
        for i in range(maps.shape[0])
    ]
    results = Parallel(n_jobs=-1, verbose=0)(jobs)
    results = np.stack(results)

    return results


def map_points_to_movie(
    points,
    starts_map,
    starts_movie,
    overlap,
    boxsize,
    log_images=False,
    log_name="debug_image",
):
    """
    Rescale points (spatial landmarks) in an array to fit a specific movie given its characteristics.

    This function modifies the input macrochaete positions to fit a movie, adjusting for
    specific characteristics including overlap, box size, scale and starting coordinates.

    Parameters
    ----------
    points : ndarray
        SOP landmarks to be rescaled. Shape is (samples, 2) for x and y.
    starts_map : ndarray
        Start of the pattern in the reference of the map. Spatial units are in boxes.
    overlap : float or ndarray
        Overlap of pattern.
    boxsize : float
        Size of each box in micrometers.
    starts_movie : ndarray
        Start of the movie in x and y. This parameter is obtained from running the Rescale Animals
        function in the pipeline. The pattern is rescaled with the same archetype.
    log_images : bool, optional
        Flag indicating whether to log images onto a Napari viewer for visualization. Default is False.
    log_name : str, optional
        Name to be assigned to the logged images in the Napari viewer. Default is "debug_image".

    Returns
    -------
    ndarray
        The rescaled macrochaete (SOP landmarks) positions.
    """

    starts_map_len = len(starts_map)
    starts_movie_len = len(starts_movie)
    points_shape = points.shape[1]

    if not all(
        [
            starts_map_len == starts_movie_len,
            starts_map_len == points_shape,
            starts_movie_len == points_shape,
        ]
    ):
        raise ValueError(
            f"The dimensions of starts_map ({starts_map_len}), starts_movie_len ({starts_movie_len}) and second dimension of points ({points_shape}) must match!"
        )

    if isinstance(overlap, np.ndarray):
        if not all(
            [
                starts_map_len == len(overlap),
                starts_movie_len == len(overlap),
                points_shape == len(overlap),
            ]
        ):
            raise ValueError(
                f"If overlap is an ndarray, it should have the same dimensionality ({len(overlap)}) "
                f"as starts_map ({starts_map_len}), starts_movie_len ({starts_movie_len}) "
                f"and second dimension of points ({points_shape})"
            )

    # Offset centers origins in the middle of each box
    offset = (
        starts_movie
        - starts_map * boxsize * (1 - overlap)
        - boxsize * (1 - overlap) / 2
    )

    # [:, ::-1] swaps (x, y) → (y, x) for matrix/image indexing
    rescaled_macro = (points * boxsize * (1 - overlap) + offset)[:, ::-1]

    if log_images:
        viewer = napari.current_viewer()
        if viewer is None:
            viewer = napari.Viewer()
        viewer.add_points(rescaled_macro, name=log_name, size=50)

    return rescaled_macro


def export_roi_to_image_space(
    roi_grid, xy_starts_grid, xy_starts, overlap, boxsizes, image_shape
):
    """Convert a grid-space boolean ROI mask to full-resolution image space.

    Maps each ``True`` cell in the grid to its corresponding pixel bounding
    box in image coordinates.

    Parameters
    ----------
    roi_grid : np.ndarray
        2-D boolean ROI mask in grid coordinates ``(Ny, Nx)``.
    xy_starts_grid : array-like
        Grid origin ``[xStart_grid, yStart_grid]``.
    xy_starts : array-like
        Image-space origins, shape ``(N_animals, 2)`` — uses ``[0]``.
    overlap : array-like
        Overlap fractions ``[overlap_x, overlap_y, ...]``.
    boxsizes : array-like
        Box dimensions, shape ``(N_animals, 2)`` — uses ``[0]``.
    image_shape : tuple
        ``(height, width)`` of the output image.

    Returns
    -------
    np.ndarray
        Boolean mask in full-resolution image space ``(height, width)``.
    """
    boxsize = boxsizes[0]
    xy_start_img = xy_starts[0]
    overlap_xy = overlap[:2]

    step_x = boxsize[0] * (1 - overlap_xy[0])
    step_y = boxsize[1] * (1 - overlap_xy[1])

    roi_image = np.zeros(image_shape, dtype=bool)
    grid_ny, grid_nx = roi_grid.shape

    for i in range(grid_ny):
        for j in range(grid_nx):
            if not roi_grid[i, j]:
                continue

            x_center = (
                xy_start_img[0] + (j - xy_starts_grid[0]) * step_x + boxsize[0] / 2
            )
            y_center = (
                xy_start_img[1] + (i - xy_starts_grid[1]) * step_y + boxsize[1] / 2
            )

            x_min = max(0, int(x_center - boxsize[0] / 2))
            x_max = min(image_shape[1], int(x_center + boxsize[0] / 2))
            y_min = max(0, int(y_center - boxsize[1] / 2))
            y_max = min(image_shape[0], int(y_center + boxsize[1] / 2))

            roi_image[y_min:y_max, x_min:x_max] = True

    return roi_image
