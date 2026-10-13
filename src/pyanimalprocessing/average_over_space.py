"""Averaging over space (AOS): aggregate quantities measured on a local spatial
domain (cells, regions, grid boxes) into a global one using polygon-intersection
weights, writing the results back into each animal zarr store.
"""

from typing import Dict, List, Literal, Optional, Tuple, Union

import numpy as np
from joblib import Parallel, delayed
from scipy.sparse import lil_matrix
from shapely import MultiPolygon
from shapely.geometry import Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree
from tqdm import tqdm

import zarr
from pyanimalprocessing import JOBLIB_BACKEND
from pyanimalprocessing.utils import _tqdm_joblib, _vprint


def _get_contours_from_spatial_type(spatial_type, grid=None, cells=None, regions=None):
    """Helper function to get contours based on spatial type and data source."""
    if cells is not None and spatial_type == "cell":
        return cells.contours[:]
    if regions is not None and spatial_type == "regions":
        return regions.contours[:]
    return None


def _retrieve_contours_from_box_corners(grid, n_frames):
    """Helper function to retrieve contours from box corners."""
    grid = grid["eulerian"]
    box_corners = grid.GRID_PROPERTIES.box_corners[:]
    # need to change the order of the box corners to be (x,y) instead of (y,x) for shapely polygon
    box_corners_repeated = np.repeat(box_corners[np.newaxis, :], n_frames, axis=0)
    return box_corners_repeated


def _reshape_contours(contours):
    """Helper function to reshape 3D contours array."""
    y_compartiment, x_compartiment = None, None
    if contours.ndim == 3:
        time_points, y_compartiment, x_compartiment = contours.shape
        contours = contours.reshape(time_points, -1)

    elif contours.ndim == 4:
        time_points, _, y_compartiment, x_compartiment = contours.shape
        contours = contours.reshape(time_points, -1)
    elif contours.ndim == 5:  # box compartiment eulerian case
        time_points, y_compartiment, x_compartiment, _, _ = contours.shape
        contours = contours.reshape(time_points, -1, 4, 2)

    return contours, (y_compartiment, x_compartiment)


def _compute_sparse_matrix(
    global_spatial_type: Literal["regions", "cell", "eulerian"],
    local_spatial_type: Literal["regions", "cell", "eulerian"],
    cells=None,
    regions=None,
    grid=None,
    method: Literal["per_membership", "per_cell", "per_area"] = "per_cell",
    n_frames: int = None,
    n_jobs: int = -1,
):
    """Helper function to compute sparse matrices for averaging over space.

    method semantics:
      - "per_membership": binary membership; contributors weigh 1
      - "per_cell": fraction-of-local-area weighting (|G ∩ L| / |L|)
      - "per_area": absolute intersection area weighting (|G ∩ L|)
    """

    if global_spatial_type != "eulerian":
        global_contours = _get_contours_from_spatial_type(
            global_spatial_type, grid, cells, regions
        )
    else:
        global_contours = _retrieve_contours_from_box_corners(grid, n_frames)
    if global_contours is None:
        raise KeyError("No global spatial type provided")

    if local_spatial_type != "eulerian":
        local_contours = _get_contours_from_spatial_type(
            local_spatial_type, grid, cells, regions
        )
    else:
        local_contours = _retrieve_contours_from_box_corners(grid, n_frames)
    if local_contours is None:
        raise KeyError("No local spatial type provided")

    # Reshape contours and get compartment dimensions
    global_contours, global_dims = _reshape_contours(global_contours)
    local_contours, local_dims = _reshape_contours(local_contours)

    valid_global_polygons, valid_global_indices, tree = None, None, None
    if global_spatial_type == "eulerian":
        valid_global_polygons, valid_global_indices, tree = _prepare_global_polygons(
            global_contours[0]
        )

    with _tqdm_joblib(
        tqdm(total=len(global_contours), desc="Computing sparse matrices")
    ) as progress_bar:
        sparse_matrices = Parallel(n_jobs=n_jobs, backend=JOBLIB_BACKEND)(
            delayed(_get_sparse_matrix_correspondence)(
                global_contours[t],
                local_contours[t],
                method,
                valid_global_polygons,
                valid_global_indices,
                tree,
            )
            for t in range(len(global_contours))
        )

    return (
        sparse_matrices,
        global_dims,
        local_dims,
    )


def _average_over_space(
    quantities: List[zarr.core.Array],
    global_spatial_type: Literal["eulerian", "regions", "cell"],
    local_spatial_type: Literal["eulerian", "regions", "cell"],
    operation_type: Literal["mean", "sum", "median"],
    weight_calculation_method: Literal["per_membership", "per_cell", "per_area"],
    cells=None,
    regions=None,
    grid: Optional[Dict[str, zarr.hierarchy.Group]] = None,
    n_frames: int = None,
    compute_self_quantity: bool = False,
    n_jobs: int = -1,
):
    """Helper function to average or sum quantities over different spatial domains."""
    sparse_matrices, global_dims, local_dims = _compute_sparse_matrix(
        global_spatial_type,
        local_spatial_type,
        cells,
        regions,
        grid,
        weight_calculation_method,
        n_frames,
        n_jobs,
    )

    self_quantity = np.zeros((n_frames, sparse_matrices[0].shape[0]), object)

    if compute_self_quantity:
        # we need to compute the self quantity for each timepoint

        for t in range(len(quantities[0])):
            for pos in range(sparse_matrices[t].shape[1]):
                self_quantity[t][pos] = {
                    j: quantities[0][t][0][pos]
                    for j in range(sparse_matrices[t].shape[0])
                    if sparse_matrices[t][j, pos] > 0
                }
        self_quantity = self_quantity.reshape(self_quantity.shape[0], *global_dims)

    # Calculate the number of local elements contributing to each global element per timepoint

    raw_counts_per_timepoint = [
        np.sum(sm.toarray() > 1e-9, axis=1).astype(np.int32)[..., np.newaxis]
        for sm in sparse_matrices
    ]
    all_time_counts = np.array(
        raw_counts_per_timepoint
    )  # Shape (T, num_global_elements_flat)

    # Reshape counts to match the structure of other aggregated quantities
    # Target intermediate shape: (T, 1 (channel), num_global_elements_flat, 1 (feature_dim))
    if all_time_counts.size > 0:  # Proceed if there are counts to reshape
        if global_dims[0] is not None:
            num_timepoints_counts = all_time_counts.shape[0]
            num_global_elements_flat_counts = all_time_counts.shape[1]

            counts_intermediate_shape = all_time_counts.reshape(
                num_timepoints_counts,
                1,  # Channels = 1 for counts
                num_global_elements_flat_counts,
                1,  # Feature dimension = 1 for counts
            )
            # Reshape using global_dims: (T, 1, *global_dims, 1)
            final_counts_array = counts_intermediate_shape.reshape(
                num_timepoints_counts,
                1,  # Channels
                *global_dims,
                1,  # Feature dimension
            )
        else:

            # If global_dims is None (e.g., for 'cell' or 'regions' global_spatial_type),
            # the intermediate shape is effectively the final structure.
            final_counts_array = all_time_counts.reshape(-1, 1)
    else:  # Handle case of no timepoints or no global elements
        # Attempt to create an empty array with a plausible structure if possible, otherwise leave as empty
        ref_shape_for_empty = (
            (0, 1, 0, 1) if global_dims is None else (0, 1, *global_dims, 1)
        )
        if (
            quantities and len(quantities) > 0 and quantities[0].ndim == 5
        ):  # use a reference quantity if available
            ref_shape_for_empty = list(quantities[0].shape)
            ref_shape_for_empty[1] = 1  # channel = 1
            ref_shape_for_empty[4] = 1  # feature_dim = 1
            if (
                global_dims is not None
                and len(global_dims) == len(ref_shape_for_empty) - 3
            ):  # T,C, G1, G2, D
                for i, dim_val in enumerate(global_dims):
                    ref_shape_for_empty[i + 2] = dim_val
            elif (
                global_dims is None and len(ref_shape_for_empty) == 4
            ):  # T, C, N_Global_flat, D
                ref_shape_for_empty[2] = (
                    0  # N_Global_flat = 0 if all_time_counts is empty
                )

            final_counts_array = np.empty(tuple(ref_shape_for_empty), dtype=np.int32)
        else:  # Fallback if no reference quantity is available
            final_counts_array = np.empty(
                (
                    (0, 1, 0, 1)
                    if global_dims is None
                    else (0, 1, *([0] * len(global_dims) if global_dims else [0]), 1)
                ),
                dtype=np.int32,
            )

    aggregated_quantities = []
    for quantity in quantities:
        aggregated_quantity = []
        if local_spatial_type == "eulerian":
            # t, c, y, x, d -> t, c, y*x, d (flatten along the grid)
            quantity = quantity.reshape(
                quantity.shape[0], quantity.shape[1], -1, quantity.shape[-1]
            )

        # Handle different input shapes

        for t in tqdm(range(len(quantity)), desc="Aggregating over space", leave=False):
            time_slice = quantity[t]
            weights = sparse_matrices[t].toarray()
            channels = []
            for c in range(time_slice.shape[0]):
                channel_slice = time_slice[c]
                aggregated_value = _average_quantities_in_contours(
                    weights, channel_slice, operation_type
                )
                channels.append(aggregated_value)
            aggregated_channel_data = np.stack(channels, axis=0)

            aggregated_quantity.append(aggregated_channel_data)

        if global_dims[0] is not None:
            aggregated_quantity = np.array(aggregated_quantity)
            # Reshape preserving channel dimension
            aggregated_quantity = aggregated_quantity.reshape(
                aggregated_quantity.shape[0],
                aggregated_quantity.shape[1],
                *global_dims,
                quantity[0, 0].shape[-1],  # dimension of the property
            )
        else:
            inhomogeneous_quantity = np.empty((len(aggregated_quantity), 1), object)
            for time_idx in range(len(aggregated_quantity)):
                inhomogeneous_quantity[time_idx, 0] = aggregated_quantity[time_idx][0]
            aggregated_quantity = inhomogeneous_quantity

        aggregated_quantities.append(aggregated_quantity)

    return aggregated_quantities, final_counts_array, self_quantity


def average_over_space(
    animals: List[zarr.hierarchy.Group],
    quantities: List[str],
    global_spatial_type: Literal["eulerian", "regions", "cell"],
    local_spatial_type: Literal["eulerian", "regions", "cell"],
    dimension: str = "D2",
    aggregation_operation: Literal[
        "mean_per_membership",
        "mean_per_cell",
        "mean_per_area",
        "sum_per_membership",
        "sum_per_cell",
        "sum_per_area",
        "median_per_membership",
        "median_per_cell",
        "median_per_area",
    ] = "mean_per_cell",
    verbose: bool = False,
    overwrite: bool = True,
    n_jobs: int = -1,
    grid_name: str = None,
) -> List[List[np.ndarray]]:
    """
    Aggregate specified quantities over multiple animals in a given spatial context.

    :param animals: A list of zarr groups representing the animals.
    :type animals: List[zarr.hierarchy.Group]
    :param quantities: A list of property names to aggregate.
    :type quantities: List[str]
    :param global_spatial_type: Type of spatial domain to aggregate into:
        - "eulerian": Regular grid
        - "regions": User-defined regions
        - "cell": Individual cells
    :type global_spatial_type: Literal["eulerian", "regions", "cell"]
    :param local_spatial_type: Type of spatial domain containing the input quantities. Same options as global_spatial_type.
    :type local_spatial_type: Literal["eulerian", "regions", "cell"]
    :param dimension: The dimension of the data, defaults to "D2".
    :type dimension: str, optional
    :param aggregation_operation: Method for aggregation (operation_weighting):
        - ``*_per_membership``: Unweighted/binary membership of locals contributing to each global domain.
        - ``*_per_cell``: Fraction-of-local-area weighting (weight = ``|G ∩ L| / |L|``).
        - ``*_per_area``: Absolute intersection-area weighting (weight = ``|G ∩ L|``).
    :type aggregation_operation: Literal[
        "mean_per_membership", "mean_per_cell", "mean_per_area",
        "sum_per_membership", "sum_per_cell", "sum_per_area",
        "median_per_membership", "median_per_cell", "median_per_area"
        ], optional
    :param verbose: Whether to print verbose output. Defaults to False.
    :type verbose: bool, optional
    :param overwrite: Whether existing output datasets may be overwritten; if False, writing over an existing dataset raises. Defaults to True.
    :type overwrite: bool, optional
    :param n_jobs: Number of jobs to run in parallel. Defaults to -1 (all processors).
    :type n_jobs: int, optional
    :param grid_name: Name of the GRID/<grid_name> group used when a spatial type is "eulerian". Defaults to "EULERIAN".
    :type grid_name: str, optional
    :return: Per-animal aggregated results: one list per input animal, each holding one array per input quantity with shape
         (time, [channels], global_domain_dimensions, features_dim)
    :rtype: List[List[np.ndarray]]

    :raises KeyError: If an invalid local spatial type is provided.
    :raises ValueError: If an invalid aggregation_operation is provided.

    **Example:**

    .. code-block:: python

        import zarr
        from pyanimalprocessing.average_over_space import average_over_space

        # Load your zarr data
        animals = [zarr.open("path/to/animal1"), zarr.open("path/to/animal2")]

        # Perform aggregation
        median_data = average_over_space(
            animals=animals,
            quantities=["area"],
            global_spatial_type="eulerian",
            local_spatial_type="cell",
            aggregation_operation="median_per_cell",
            dimension="D2",
            verbose=True
        )

    """

    # The eulerian spatial domain maps to a named GRID/<grid_name> group (default "EULERIAN");
    # cell/regions map to their fixed CELL/REGIONS groups.
    grid_key = grid_name if grid_name is not None else "EULERIAN"

    def _spatial_key(spatial_type):
        return grid_key if spatial_type == "eulerian" else spatial_type.upper()

    # Sanity checks
    if not isinstance(animals, list):
        animals = [animals]
    list_n_frames = [animal.IMAGE.D2.raw.shape[0] for animal in animals]
    if not isinstance(quantities, list):
        quantities = [quantities]
    if "self" in quantities:
        quantities.remove("self")
        compute_self_quantity = True
    else:
        compute_self_quantity = False

    # Parse aggregation_operation (supports legacy and new tokens)
    # Parse aggregation_operation: expected form "<op>_per_<method>"
    valid_ops = ["mean", "sum", "median"]
    valid_methods = ["membership", "cell", "area"]

    if "_per_" not in aggregation_operation:
        raise ValueError(
            f"Invalid aggregation_operation: {aggregation_operation}. Expected '<op>_per_<method>'"
        )

    op_part, method_part = aggregation_operation.split("_per_", 1)

    if op_part not in valid_ops:
        raise ValueError(f"Invalid operation: {op_part}. Use one of: {valid_ops}")

    if method_part not in valid_methods:
        raise ValueError(f"Invalid method: {method_part}. Use one of: {valid_methods}")

    operation_type: Literal["mean", "sum", "median"] = op_part  # type: ignore[assignment]
    weight_calculation_method: Literal["per_membership", "per_cell", "per_area"] = f"per_{method_part}"  # type: ignore[assignment]

    _vprint("Aggregating over spatial domains", verbose)
    all_animals_aggregated_data = []

    for i, animal in enumerate(
        tqdm(animals, total=len(animals), desc="Processing animals")
    ):
        _vprint(f"Aggregating: {animal.attrs['name']}", verbose)
        if local_spatial_type == "eulerian":
            local_subgroup_quantity = "GRID"
        elif local_spatial_type == "regions":
            local_subgroup_quantity = "REGIONS"
        elif local_spatial_type == "cell":
            local_subgroup_quantity = "CELL"
        else:
            raise KeyError(f"Invalid local spatial type: {local_spatial_type}")

        local_group_path_parts = [local_subgroup_quantity]
        if local_spatial_type not in ["cell", "regions"]:
            local_group_path_parts.append(_spatial_key(local_spatial_type))
        local_group_path_parts.append(dimension)

        current_group = animal
        try:
            for part in local_group_path_parts:
                current_group = current_group[part]
            local_group = current_group
        except KeyError as e:
            raise KeyError(
                f"Could not find path {'/'.join(local_group_path_parts)} in animal {animal.attrs.get('name', 'N/A')}: {e}"
            )

        quantity_list = []
        for property_name in quantities:
            try:
                quantity_data = local_group[property_name][:]
                quantity_list.append(quantity_data)
            except KeyError:
                raise KeyError(
                    f"Property '{property_name}' not found in {local_group.pathstr} for animal {animal.attrs.get('name', 'N/A')}"
                )

        aggregated_quantities_for_animal, animal_counts_data, self_quantity = (
            _average_over_space(
                quantity_list,
                global_spatial_type,
                local_spatial_type,
                operation_type=operation_type,
                weight_calculation_method=weight_calculation_method,
                cells=(
                    animal.CELL[dimension]
                    if local_spatial_type == "cell" or global_spatial_type == "cell"
                    else None
                ),
                regions=(
                    animal.REGIONS[dimension]
                    if local_spatial_type == "regions"
                    or global_spatial_type == "regions"
                    else None
                ),
                grid={
                    key: animal.GRID[grid_key]
                    for key in ["eulerian"]
                    if grid_key in animal.GRID
                },
                n_frames=list_n_frames[i],
                n_jobs=n_jobs,
                compute_self_quantity=compute_self_quantity,
            )
        )

        if global_spatial_type == "eulerian":
            parent_group_for_saving = animal.require_group("GRID")
        else:
            parent_group_for_saving = animal

        # Path for saving: parent_group_for_saving / _spatial_key(global_spatial_type) / dimension / dataset_name
        # Example for global_spatial_type="eulerian", local_spatial_type="cell", dimension="D2", property="area", operation="sum_per_cell":
        # animal.GRID / EULERIAN / CELL / D2 / area_sum_per_cell
        # Example for global_spatial_type="cell", local_spatial_type="cell", dimension="D2", property="area", operation="mean_per_area":
        # animal / CELL / CELL / D2 / area_mean_per_area

        # Get the group for the global spatial type (e.g., animal.GRID.EULERIAN or animal.CELL)
        target_group = (
            parent_group_for_saving.require_group(_spatial_key(global_spatial_type))
            .require_group(_spatial_key(local_spatial_type))
            .require_group(dimension)
        )

        if compute_self_quantity:

            animal.GRID[_spatial_key(global_spatial_type)].GRID_PROPERTIES.create_dataset(
                local_spatial_type,
                data=self_quantity,
                shape=(self_quantity.shape),
                dtype=object,
                object_codec=zarr.codecs.Pickle(),
                chunks=(1, *self_quantity.shape[1:]),
                overwrite=overwrite,
            )

        for property_name, agg_quantity_data in zip(
            quantities, aggregated_quantities_for_animal
        ):
            new_dataset_name = f"{property_name}_{aggregation_operation.lower()}"

            if global_spatial_type == "eulerian":
                target_group.array(
                    new_dataset_name, data=agg_quantity_data, overwrite=overwrite
                )
            else:
                target_group.array(
                    new_dataset_name,
                    data=agg_quantity_data,
                    overwrite=overwrite,
                    object_codec=zarr.codecs.Pickle(),
                )

        # Save the counts array
        counts_dataset_name = f"{local_spatial_type.lower()}_number"
        if global_spatial_type == "eulerian":
            target_group.array(
                counts_dataset_name, data=animal_counts_data, overwrite=overwrite
            )
        else:
            target_group.array(
                counts_dataset_name,
                data=animal_counts_data,
                overwrite=overwrite,
                object_codec=zarr.codecs.Pickle(),
            )

        all_animals_aggregated_data.append(aggregated_quantities_for_animal)

    return all_animals_aggregated_data


def _contours_to_polygons(
    contours: List[np.ndarray],
) -> List[Union[Polygon, MultiPolygon, None]]:
    """Convert contours to shapely Polygon/MultiPolygon objects.

    This function takes a list of contours and converts each one into either a Polygon
    or MultiPolygon shapely object. Empty or invalid contours are converted to None.

    Parameters
    ----------
    contours : List[np.ndarray]
        List of contours, where each contour is a numpy array of points defining a shape.

    Returns
    -------
    List[Polygon | MultiPolygon | None]
        List of shapely geometry objects, with None values for invalid contours.
        Each valid contour is converted to either:
        - Polygon: For simple single-part contours
        - MultiPolygon: For complex multi-part contours
        - None: For empty or invalid contours
    """
    polygons: List[Polygon | MultiPolygon | None] = []

    # Handle case where translation coordinates are provided
    if len(contours) > 0:
        for i, contour in enumerate(contours):
            # Skip empty contours
            if contour.shape[0] == 0:
                polygons.append(None)
                continue

            # Handle complex multi-part contours
            # Potential issue with the contours generation when disjointed so we need to check the shape of the contour
            # if the contour is a 1D array it is probably inhomogeneous and we need to convert loop over it to access the different parts of the polygon
            # same if the contour is a nD (n>2) array but the first shape is 2 or more
            elif contour.ndim < 2 or (contour.shape[0] > 1 and contour.ndim > 2):
                multipolygons = []
                for sub_contour in contour:
                    try:
                        multipolygons.append(Polygon(sub_contour.squeeze()))
                    except:
                        for sub_sub_contour in sub_contour:
                            multipolygons.append(Polygon(sub_sub_contour))
                try:
                    poly = unary_union(multipolygons)
                except:
                    print(f"Error creating MultiPolygon for contour {i}")
                    polygons.append(None)
                    continue

            # Handle simple multi-point contours
            # if the contour is a 2D array and the first shape is 2 we can directly create a polygon
            elif contour.ndim == 2 and contour.shape[0] > 1:
                try:
                    poly = Polygon(contour)
                except:
                    print(f"Error creating Polygon for contour {i}")
                    polygons.append(None)
                    continue

            # Handle single-part contours
            else:
                try:
                    poly = Polygon(contour[0])
                except:
                    print(f"Error creating Polygon for contour {i}")
                    polygons.append(None)
                    continue

            polygons.append(poly)
            continue

    return polygons


def _prepare_global_polygons(
    global_contours: List[np.ndarray],
) -> Tuple[List[Union[Polygon, MultiPolygon]], List[int], Optional[STRtree]]:
    """Prepare global polygons for correspondence calculation."""
    # Convert contours to polygons
    global_polygons: List[Union[Polygon, MultiPolygon, None]] = _contours_to_polygons(
        global_contours
    )

    # Filter out invalid polygons
    valid_global_polygons: List[Union[Polygon, MultiPolygon]] = []
    valid_global_indices: List[int] = []
    for i, poly in enumerate(global_polygons):
        if poly is not None and poly.is_valid:
            valid_global_polygons.append(poly)
            valid_global_indices.append(i)

    # Create spatial index if we have valid polygons
    tree = STRtree(valid_global_polygons) if valid_global_polygons else None

    return valid_global_polygons, valid_global_indices, tree


def _fill_corespondance(
    sparse_matrix,
    valid_global_polygons,
    valid_global_indices,
    tree,
    local_polygons,
    method,
):
    """Fill the sparse matrix with overlap-based weights between global and local polygons.

    Weight semantics by method:
      - "per_membership": 1 if polygons intersect, else 0
      - "per_cell": fraction of local area covered: |G ∩ L| / |L|
      - "per_area": absolute intersection area: |G ∩ L|
    """
    # Process each local polygon
    for j, local_poly in enumerate(local_polygons):
        if local_poly is None or not local_poly.is_valid:
            continue

        if valid_global_polygons:
            # Intersection-based membership/weights
            potential_matches: List[int] = tree.query(local_poly)
            for match_idx in potential_matches:
                i: int = valid_global_indices[match_idx]
                global_poly: Union[Polygon, MultiPolygon] = valid_global_polygons[
                    match_idx
                ]
                intersection: float = global_poly.intersection(local_poly).area
                if intersection == 0:
                    continue
                if method == "per_membership":
                    weight_value: float = 1.0
                elif method == "per_cell":
                    local_area = local_poly.area
                    if local_area <= 0:
                        raise ValueError(
                            f"Local polygon at index {j} has non-positive area: {local_area}"
                        )
                    weight_value = intersection / local_area
                elif method == "per_area":
                    weight_value = intersection
                else:
                    raise ValueError(f"Unknown method: {method}")

                if weight_value > 1e-12:
                    sparse_matrix[i, j] = weight_value
    return sparse_matrix


def _get_sparse_matrix_correspondence(
    global_contours: List[np.ndarray],
    local_contours: List[np.ndarray],
    method: Literal["per_membership", "per_cell", "per_area"] = "per_cell",
    valid_global_polygons: Optional[List[Union[Polygon, MultiPolygon]]] = None,
    valid_global_indices: Optional[List[int]] = None,
    tree: Optional[STRtree] = None,
) -> lil_matrix:
    """Calculate a sparse matrix of overlap-based weights between global and local coordinate sets.

    Uses an STRtree spatial index to efficiently find overlapping polygons.

    Parameters
    ----------
    global_contours : List[np.ndarray]
        List of contours defining global polygons.
    local_contours : List[np.ndarray]
        List of contours defining local polygons.
    method : {"per_membership", "per_cell", "per_area"}, optional
        Method to calculate overlap weights, by default "per_cell"
        - "per_membership": assigns 1 for any overlap
        - "per_cell": assigns fraction of local area |G ∩ L| / |L|
        - "per_area": assigns absolute intersection area |G ∩ L|
    valid_global_polygons : Optional[List[Union[Polygon, MultiPolygon]]], optional
        Pre-computed valid global polygons, by default None
    valid_global_indices : Optional[List[int]], optional
        Indices of valid global polygons, by default None
    tree : Optional[STRtree], optional
        Pre-computed spatial index tree, by default None

    Returns
    -------
    lil_matrix
        Sparse matrix where element (i,j) represents the overlap between global polygon i and local polygon j.
        Values follow the selected method's semantics.
    """
    # Don't need to prepare global polygons if we have valid ones
    if valid_global_polygons is None or valid_global_indices is None or tree is None:
        valid_global_polygons, valid_global_indices, tree = _prepare_global_polygons(
            global_contours
        )

    # Initialize sparse matrix
    n_global: int = len(global_contours)
    n_local: int = len(local_contours)
    sparse_matrix: lil_matrix = lil_matrix((n_global, n_local), dtype=float)
    local_polygons: List[Union[Polygon, MultiPolygon, None]] = _contours_to_polygons(
        local_contours
    )

    return _fill_corespondance(
        sparse_matrix,
        valid_global_polygons,
        valid_global_indices,
        tree,
        local_polygons,
        method,
    )


def _average_quantities_in_contours(
    weights: np.ndarray,
    local_values: np.ndarray,
    operation: Literal["mean", "sum", "median"],
) -> np.ndarray:
    """
    Aggregate quantities from local contours into global contours using the correspondence matrix.

    Args:
        weights: Dense matrix of correspondences between global and local contours.
                       Values depend on the method used (e.g., 1 for per_cell, area ratio for per_area).
        local_values: Array of values for each local contour to be aggregated.
        operation: The type of aggregation to perform ("mean", "sum", or "median").

    Returns:
        global_values: Array of aggregated values for each global contour.
    """
    original_local_ndim = local_values.ndim
    if original_local_ndim == 1:
        if local_values.shape[0] == 0:  # Handle empty 1D array before reshape
            local_values = np.empty((0, 1), dtype=local_values.dtype)
        else:
            local_values = local_values[
                :, np.newaxis
            ]  # Ensure 2D for consistent processing

    # Filter out local_values rows that contain any NaNs
    if local_values.shape[0] > 0:
        valid_local_mask = ~np.isnan(local_values).any(axis=1)
    else:
        valid_local_mask = np.array([], dtype=bool)

    if not np.any(valid_local_mask) or local_values.shape[0] == 0:
        num_global_contours = weights.shape[0]
        num_features = local_values.shape[1]
        empty_result = np.full((num_global_contours, num_features), np.nan)
        return (
            empty_result.squeeze()
            if original_local_ndim == 1 and num_features == 1
            else empty_result
        )

    local_values_cleaned = local_values[valid_local_mask, :]
    weights_for_op = weights[:, valid_local_mask]

    n_global = weights_for_op.shape[0]
    n_features_cleaned = local_values_cleaned.shape[1]
    global_values = np.full((n_global, n_features_cleaned), np.nan)

    if operation == "median":
        if (
            local_values_cleaned.shape[0] == 0
        ):  # No valid local values to take median from
            # global_values is already all NaNs, which is correct.
            pass  # Explicitly doing nothing, result is already NaN array
        else:
            # Compute weighted median per global row and per feature using the
            # weighted-median interval method (no interpolation). We interpret
            # correspondence matrix entries as weights:
            # - per_membership: binary weights (1 for any overlap)
            # - per_cell: fractional weights |G ∩ L| / |L|
            # - per_area: absolute overlap area |G ∩ L|
            # The weighted median is any value m such that the weight at or
            # below m and the weight at or above m are each at least half the
            # total weight. We return the midpoint of the interval [m_low, m_high]
            # that satisfies this, which matches the usual even-sample median.
            for i in range(n_global):
                row_weights = weights_for_op[i, :]
                contributing_mask = row_weights > 1e-9
                if not np.any(contributing_mask):
                    continue
                w = row_weights[contributing_mask].astype(float)
                if w.sum() <= 0:
                    continue
                # Compute per-feature weighted median
                for feature_idx in range(n_features_cleaned):
                    v = local_values_cleaned[contributing_mask, feature_idx].astype(
                        float
                    )
                    if v.size == 0:
                        continue
                    if v.size == 1:
                        global_values[i, feature_idx] = v[0]
                        continue
                    order = np.argsort(v)
                    v_sorted = v[order]
                    w_sorted = w[order]
                    total_w = float(np.sum(w_sorted))
                    if total_w <= 0:
                        continue
                    half_total_weight = 0.5 * total_w
                    cumulative_weight_from_left = np.cumsum(w_sorted)
                    idx_low = int(
                        np.searchsorted(
                            cumulative_weight_from_left, half_total_weight, side="left"
                        )
                    )
                    cumulative_weight_from_right = np.cumsum(w_sorted[::-1])
                    idx_high_reversed = int(
                        np.searchsorted(
                            cumulative_weight_from_right, half_total_weight, side="left"
                        )
                    )
                    idx_high = w_sorted.size - 1 - idx_high_reversed
                    m_low = v_sorted[idx_low]
                    m_high = v_sorted[idx_high]
                    global_values[i, feature_idx] = (m_low + m_high) / 2.0
    else:  # Mean or Sum operations
        row_sum_of_weights = np.sum(weights_for_op, axis=1)
        has_contribution_mask = row_sum_of_weights > 1e-9

        if np.any(has_contribution_mask):
            active_weights = weights_for_op[has_contribution_mask, :]

            if operation == "mean":
                active_row_sums = row_sum_of_weights[has_contribution_mask, np.newaxis]
                normalized_weights_for_dot = np.divide(
                    active_weights,
                    active_row_sums,
                    out=np.zeros_like(active_weights),
                    where=active_row_sums != 0,
                )
                computed_values = np.dot(
                    normalized_weights_for_dot, local_values_cleaned
                )
                global_values[has_contribution_mask, :] = computed_values

            elif operation == "sum":
                computed_values = np.dot(active_weights, local_values_cleaned)
                global_values[has_contribution_mask, :] = computed_values

    return (
        global_values.squeeze()
        if original_local_ndim == 1 and global_values.shape[1] == 1
        else global_values
    )


