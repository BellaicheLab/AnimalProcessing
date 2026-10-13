"""Support machinery for property plotting: grid/significance masks, weighted std,
tensor eigendecomposition (:func:`tensor_data`), plotting-vector construction, and
the origin/property enums and sanity checks used by :func:`plot_property`.
"""

import copy
import warnings
from enum import Enum
from typing import Tuple

import numpy as np

from pyanimalprocessing.transformation.tensors import (
    get_unbiased_weighted_std_matrix_aoa,
)


def generate_grid_mask(
    properties,
    weights,
    mean_property=None,
    mean_weights=None,
    min_sigma=None,
    min_weight=0.5,
):
    if mean_property is None and min_sigma is not None:
        raise ValueError("If min_sigma is not None, mean_property must be provided")

    mask = mean_weights > min_weight

    if min_sigma is not None:
        signif = _get_significance_map(
            sample_tensors=properties,
            mean_tensor=mean_property,
            weights=weights,
            significance=min_sigma,
        )
        # Here signif is t,y,x or t,y,x,2
        # (if there is a separation between iso and dev for the case of matrices)
        if mask.shape != signif.shape:
            mask = np.repeat(mask[..., np.newaxis], signif.shape[-1], axis=-1)

        mask = mask & signif

    return mask


def _get_significance_map(sample_tensors, mean_tensor, weights, significance=1):
    """Keep boxes whose mean norm is at least ``significance`` times the norm of the
    per-component inter-animal std (Guirao et al. 2015, eLife, Eqs. 12-14)."""
    if sample_tensors.shape[-2] == 4:
        # Rewrite T = [Txx, Txy, Tyx, Tyy] as [Txx + Tyy, Txy, Tyx, Txx - Tyy], samples and mean alike.
        Txx, Txy, Tyx, Tyy = [sample_tensors[:, :, :, i, :] for i in range(4)]
        temp_T = np.stack([Txx + Tyy, Txy, Tyx, Txx - Tyy], axis=3)

        Txx, Txy, Tyx, Tyy = [mean_tensor[:, :, :, i] for i in range(4)]
        temp_mean_T = np.stack([Txx + Tyy, Txy, Tyx, Txx - Tyy], axis=3)

        std_map = get_unbiased_weighted_std_matrix_aoa(
            sample_tensors=temp_T,
            mean_tensor=temp_mean_T,
            weights=weights[..., None, :],
        )

        # Deviator: sqrt((Txx - Tyy)^2 + 4 Txy^2) against sqrt(d(Txx - Tyy)^2 + 4 dTxy^2), Eq. 14.
        std_iso = std_map[:, :, :, 0]
        std_dev = np.sqrt(std_map[:, :, :, 3] ** 2 + 4 * std_map[:, :, :, 1] ** 2)

        mean_iso = np.abs(temp_mean_T[:, :, :, 0])
        mean_dev = np.sqrt(
            temp_mean_T[:, :, :, 3] ** 2 + 4 * temp_mean_T[:, :, :, 1] ** 2
        )

        significant_iso = mean_iso >= significance * std_iso
        significant_dev = mean_dev >= significance * std_dev

        significant = np.stack((significant_iso, significant_dev), axis=-1)

    elif sample_tensors.shape[-2] == 2 or sample_tensors.shape[-2] == 3:
        std_map = get_unbiased_weighted_std_matrix_aoa(
            sample_tensors=sample_tensors,
            mean_tensor=mean_tensor,
            weights=weights[..., None, :],
        )

        # Same criterion for vectors: |mean| against the norm of the component stds.
        mean_norm = np.linalg.norm(mean_tensor, axis=-1)
        std_norm = np.sqrt(np.sum(std_map**2, axis=-1))
        significant = mean_norm >= significance * std_norm

    else:
        std_map = get_unbiased_weighted_std_matrix_aoa(
            sample_tensors=sample_tensors[..., 0, :],
            mean_tensor=mean_tensor[..., 0],
            weights=weights,
        )

        significant_iso = np.abs(mean_tensor[..., 0]) >= significance * std_map[:, :, :]

        significant = significant_iso

    return significant


def _keep_intersecting_cells(
    property_data: np.ndarray, property_origin: np.ndarray, property_color
) -> np.ndarray:
    """
    Redimensions the backup to avoid mismatches between the property_data and the property_origins.

    :param animal: A zarr group the animal model data.
    :param properties: A str corresponding to the name of the property to reshape.
    :param dimension_to_keep: The dimension of the property to load.
    :param dimension_to_compare: The dimension of the property to compare (centroid with area for example).
    :returns: the property of the dimension to keep but with the correct number of cells
    """
    resized_property_data = []
    resized_property_origin = []
    resized_property_color = {key: [] for key in property_color.keys()}
    # Here we only keep the values that have their property data
    for i in range(property_data.shape[0]):

        number_of_indices = min(property_data[i].shape[0], property_origin[i].shape[0])

        resized_property_data.append(property_data[i][:number_of_indices])
        resized_property_origin.append(property_origin[i][:number_of_indices])
        for key, value in property_color.items():
            resized_property_color[key].append(value[i][:number_of_indices])

    # Convert the list of arrays to a numpy array object cause the dimension is inhomogeneous
    resized_property_data = np.array(resized_property_data, object)
    resized_property_origin = np.array(resized_property_origin, object)
    for key, value in resized_property_color.items():
        resized_property_color[key] = np.array(value, object)

    return resized_property_data, resized_property_origin, resized_property_color


def create_plotting_vectors(
    origins: np.ndarray, vectors: np.ndarray, scale: float = 1
) -> np.ndarray:
    """
    Prepare vectors for plotting by scaling and adjusting their origins.

    :param origins: The origins of the vectors.
    :param vectors: The vectors.
    :param scale: A scaling factor for the vectors.
    :return: A numpy array of adjusted vectors for plotting.
    """
    new_origins = origins.copy()
    new_vectors = vectors * scale
    new_origins[..., -2:] = origins[..., -2:] - (new_vectors[..., -2:] / 2)
    # new_origins[... ] = origins[... ] - (new_vectors[...] / 2)
    return np.stack([new_origins, new_vectors], axis=1)


def create_vectors_values_matrix(matrix: np.ndarray) -> tuple:
    """
    Create vectors and values from a 2x2 or 3x3 matrix using the adapted formalism.

    :param matrix: A numpy array representing a 2x2 or 3x3 matrix.
    :return: A tuple containing the vectors and iso values derived from the matrix.
    """

    # Determine the matrix dimensionality
    matrix_size = matrix.shape[-1]
    if matrix_size not in [2, 3]:
        raise ValueError("The matrix must be either 2x2 or 3x3.")

    iso_values, vectors = tensor_data(matrix)

    # Identify vectors containing NaNs
    nan_vectors = np.any(np.isnan(vectors), axis=-1)

    # Identify bad vectors and iso values
    nan_iso = np.any(np.isnan(iso_values[..., np.newaxis]), axis=-1)

    iso_values[nan_iso] = np.nan
    vectors[nan_vectors] = np.nan

    # vectors = add_dimension(
    #     vectors,
    #     n_dimensions=1,
    #     add_zeros=True,
    # )

    return vectors, iso_values


def tensor_data(T: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """
    Converts a tensor of multiple 2x2 or 3x3 matrices into its isotropic part and
    eigenvalue-scaled deviatoric eigenvectors.

    :param T: A numpy array representing a tensor of multiple 2x2 or 3x3 matrices.
    :returns: A tuple containing:

        - Eiso: Isotropic part (trace / matrix size) of each matrix.
        - vectors_sorted: Deviatoric eigenvectors scaled by their eigenvalues, sorted by
          eigenvalue, with the y-component flipped to napari's y-down display convention.
    """
    matrix_size = T.shape[-1]

    # Calculate isotropic part
    Eiso = np.trace(T.astype(float), axis1=-2, axis2=-1) / matrix_size

    # Calculate deviatoric part
    Tdev = T - Eiso[..., np.newaxis, np.newaxis] * np.eye(matrix_size)

    # We create a mask to find where there are NaNs in the input array
    nan_mask = np.isnan(Tdev)
    nan_mask = np.any(nan_mask, axis=-1)
    eig_mask = np.ones_like(nan_mask, dtype=float)
    eig_mask[nan_mask] = np.nan

    # We replace the NaNs by zeros to allow for the np.linalg function to work
    Tdev_tmp = copy.copy(Tdev)
    Tdev_tmp[np.isnan(Tdev_tmp)] = 0
    Tdev_tmp[np.isinf(Tdev_tmp)] = 0

    # Calculate eigenvectors and eigenvalues of deviatoric part
    Edevs, Vs = np.linalg.eig(Tdev_tmp.astype(float))
    Edevs = np.real(Edevs)
    Vs = np.real(Vs)
    mins = np.max(Edevs, axis=-1)
    rescaled_eigen = (Edevs - mins[:, np.newaxis])[..., np.newaxis, :]
    rescaled_eigen = Edevs[..., np.newaxis, :]
    vectors = Vs * rescaled_eigen
    # Get the sorted indices based on norms for each of the 5000 elements
    sorted_indices = np.argsort(Edevs, axis=1)
    # Use advanced indexing to reorder arr according to the sorted indices
    vectors_sorted = np.take_along_axis(
        vectors, sorted_indices[:, np.newaxis, :], axis=2
    )
    out_vectors = vectors_sorted.transpose(0, 2, 1)
    # napari's row axis (y) points down, so flip the eigenvectors' y-component to match
    # napari's y-down display orientation; magnitudes are unchanged.
    out_vectors[..., 0] *= -1
    return Eiso, out_vectors


def add_dimension(vectors, n_dimensions=1, add_zeros=True) -> np.ndarray:
    """
    add a component to the vectors of the centroids. It can be z or t. (shape of 2D before this function : (t,n,2) and  after : (tn, 3)

    :param vectors: vectors to plot
    :param n_dimension: number of columns to add per cell, defaults to 1
    :param add_zeros: if True the added columns will be a 0 (for vectors), if not it will
        add the time value (for the centroids), defaults to True
    """

    merged = []
    if add_zeros:
        mult = 0
    else:
        mult = 1

    if n_dimensions >= 1:
        for t, vector in enumerate(vectors):
            merged.append(
                np.concatenate(
                    (
                        mult * t * np.ones((vector.shape[0], n_dimensions)),
                        vector,
                    ),  # the vector carries a channel axis (from the centroids)
                    axis=1,
                )
            )

    elif n_dimensions == 0:
        for t, vector in enumerate(vectors):
            merged.append(vector)

    return np.concatenate(merged, axis=0)


def get_image_shape_coords_grid(coords):
    # Flatten all x and y coordinates into a single array for direct processing
    all_x_coords = np.concatenate(
        [
            x_coords.flatten()
            for time_point in coords
            for x_coords, y_coords in time_point
            if x_coords.size > 0
        ]
    )
    all_y_coords = np.concatenate(
        [
            y_coords.flatten()
            for time_point in coords
            for x_coords, y_coords in time_point
            if y_coords.size > 0
        ]
    )

    # Get the maximum values directly
    max_x, max_y = np.max(all_x_coords), np.max(all_y_coords)

    return (int(max_x) + 1, int(max_y) + 1)


def get_image_shape_coords_cell(coords):
    """
    Finds the boundary of the image based on the coordinates of the cells.
    """
    # 2 for the 2D case, 3 for the 3D case
    max_values = np.full(coords[0][1].shape[1], -np.inf)
    for coord in coords:
        stacked_coords = np.vstack(list(coord[1:]))

        current_max = np.max(stacked_coords, axis=0)
        max_values = np.maximum(max_values, current_max)

    return max_values.astype(int) + 1


def _coords_to_centroids(coords, axis=0):
    """
    Finds the centroid of a set of coords.
    Suppresses warnings about the mean of empty slices using the warnings library.
    """
    full_centroids = []
    # Use warnings.catch_warnings to suppress the RuntimeWarning about empty slices
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", category=RuntimeWarning)
        for time_coord in coords:
            centroids_time_point = []
            for cell_coord in time_coord:
                mean_value = np.mean(cell_coord, axis=axis)
                centroids_time_point.append(mean_value)

            centroids_time_point = np.array(centroids_time_point, dtype=object)
            full_centroids.append(centroids_time_point)

    full_centroids = np.array(full_centroids, dtype=object)
    return full_centroids


class PropertyType(Enum):
    """


    :param Enum: _description_
    :type Enum: _type_
    :meta private:
    """

    SCALAR = 1
    VECTOR = 2
    MATRIX = 3


class OriginSource(Enum):
    """


    :param Enum: _description_
    :type Enum: _type_
    :meta private:
    """

    CELL = 1
    GRID = 2


class OriginType(Enum):
    """_summary_

    :param Enum: _description_
    :type Enum: _type_
    :meta private:
    """

    CENTROID = 1
    COORD = 2


class OriginDimension(Enum):
    """_summary_

    :param Enum: _description_
    :type Enum: _type_
    :meta private:
    """

    TWO_DIMENSIONAL = 2
    THREE_DIMENSIONAL = 3


def _affine_transform_sanity_check(affine_transform, origin_dimension):
    shape_map = {
        OriginDimension.TWO_DIMENSIONAL: [(3, 3), (4, 4)],
        OriginDimension.THREE_DIMENSIONAL: [(3, 3), (4, 4), (5, 5)],
    }

    if origin_dimension not in shape_map:
        raise ValueError(
            "Invalid origin dimension. Expected either TWO_DIMENSIONAL or THREE_DIMENSIONAL."
        )

    if affine_transform is None:
        affine_transform = np.eye(shape_map[origin_dimension][-1][-1])
    else:
        if affine_transform.shape not in shape_map[origin_dimension]:
            raise ValueError(
                f"For {origin_dimension.name} data, the affine transform should be of shape {' or '.join(str(shape) for shape in shape_map[origin_dimension])}."
            )

        target_shape = shape_map[origin_dimension][-1]
        if affine_transform.shape != target_shape:
            affine_transform_shape = affine_transform.shape

            pad_width = [
                (target_shape[i] - affine_transform.shape[i], 0) for i in range(2)
            ]
            affine_transform = np.pad(
                affine_transform, pad_width, mode="constant", constant_values=0
            )
            for i in range(target_shape[0] - affine_transform_shape[0]):
                affine_transform[i, i] = 1

    return affine_transform


def _property_origin_sanity_checks(property_data, property_origin):
    # First we assess whether the data is cell or grid
    if property_data.ndim == 2:
        # cells and regions are (t,c)
        origin_source = OriginSource.CELL
    elif property_data.ndim > 2:
        origin_source = OriginSource.GRID
    else:
        raise NotImplementedError("The data is neither cell nor grid")

    # Then we assess whether the origins are cells or centroids

    if origin_source == OriginSource.CELL:
        if property_origin.ndim > 1:
            # centroid of cells is (t,c)
            origin_type = OriginType.CENTROID
        elif property_origin.ndim == 1:
            # centroid of cells is (t)
            origin_type = OriginType.COORD

    elif origin_source == OriginSource.GRID:
        if property_origin.dtype == "object":
            # it can be (t,y,x,)(inhomogen) or (y,x,)(inhomogen)
            origin_type = OriginType.COORD
        elif property_origin.ndim > 2:
            # it can be == 5 (t,c,y,x,2/3) or == 3 (y,x,2)
            origin_type = OriginType.CENTROID
        else:
            raise ValueError("The grid appears not to be 2D or 3D")

    # Finally we check is the data is 2D or 3D
    if origin_source == OriginSource.CELL and origin_type == OriginType.COORD:
        if property_origin[0][0].shape[-1] == 2:
            origin_dimension = OriginDimension.TWO_DIMENSIONAL
        else:
            origin_dimension = OriginDimension.THREE_DIMENSIONAL

    elif origin_source == OriginSource.CELL and origin_type == OriginType.CENTROID:
        if property_origin[0, 0].shape[-1] == 2:
            origin_dimension = OriginDimension.TWO_DIMENSIONAL
        else:
            origin_dimension = OriginDimension.THREE_DIMENSIONAL

    elif (
        origin_source == OriginSource.GRID
    ):  # We assume that the data is 2D if it is grid
        origin_dimension = OriginDimension.TWO_DIMENSIONAL

    else:
        raise ValueError("The data is neither 2D nor 3D")

    return origin_source, origin_dimension, origin_type


def _property_data_sanity_checks(property_data, origin_source):
    if property_data[0].shape[-1] == 1:
        property_type = PropertyType.SCALAR
    elif property_data[0].shape[-1] == 2 or property_data[0].shape[-1] == 3:
        property_type = PropertyType.VECTOR
    elif property_data[0].shape[-1] == 4 or property_data[0].shape[-1] == 9:
        property_type = PropertyType.MATRIX
    else:
        raise ValueError("Unknown property type")

    return property_type


def _extract_channel(property_data):
    property_splitted_by_channels = []
    channel_number = property_data.shape[1]

    for c in range(channel_number):
        property_splitted_by_channels.append(property_data[:, c])

    return property_splitted_by_channels


def _convert_matrix_to_scalars_and_vectors(property_data_flat):
    shape_matrix = property_data_flat.shape[-1]
    vectors, iso_values = create_vectors_values_matrix(property_data_flat)
    vectors = vectors.reshape(-1, shape_matrix, shape_matrix)

    return vectors, iso_values
