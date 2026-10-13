"""Averaging over animals (AOA): rescale each animal's time-averaged backups into
the common-grid frame and combine them into a weighted-mean output store whose
stacks carry a trailing animal axis (index 0 = mean, then per-animal samples).
"""

import warnings
from pathlib import Path
from typing import List, Literal
import numpy as np
import zarr
from natsort import natsorted

from pyanimalprocessing.utils import (
    _vprint,
    _correct_matrix,
    _extract_rotation_and_scaling,
)
from pyanimalprocessing.rescaling.registration import _apply_matrix_transform_to_points
from pyanimalprocessing.transformation.tensors import get_unbiased_weighted_std_matrix_aoa


def average_over_animals(
    animals: List[zarr.hierarchy.Group],
    output_path: str,
    animal_reference: zarr.hierarchy.Group,
    rescale: Literal["Full", "Rotation", "Iso_scaling"] = "Rotation",
    grid_name: str = None,
    verbose: bool = False,
) -> zarr.hierarchy.Group:
    """
    Perform averaging of properties over multiple animals.

    :param animals: A list of zarr groups representing the animals to be averaged.
    :type animals: List[zarr.hierarchy.Group]
    :param output_path: The path to store the output zarr group containing the averages.
    :type output_path: str
    :param animal_reference: A reference zarr group representing the animal used for alignment.
    :type animal_reference: zarr.hierarchy.Group
    :param rescale: A string indicating the type of rescaling to apply to the properties:
                    - 'Full': Apply full rescaling including rotation and scaling.
                    - 'Rotation': Apply only rotation without the scaling part.
                    - 'Iso_scaling': Apply the full rotation corrected from the isotopic_scaling only.
    :type rescale: Literal['Full', 'Rotation', 'Iso_scaling'], optional
    :param verbose: Whether to print verbose output. Defaults to False.
    :type verbose: bool, optional

    :return: The output zarr group containing the averaged properties.
    :rtype: zarr.hierarchy.Group

    :raises ValueError: If the number of tensors and weights do not match during averaging.

    **Example:**

    .. code-block:: python

        import zarr
        from pyanimalprocessing.average_over_animals import average_over_animals

        # Load your zarr data
        animals = [zarr.open("path/to/animal1"), zarr.open("path/to/animal2")]

        # Perform averaging
        output_group = average_over_animals(
            animals=animals,
            output_path="path/to/average_output",
            animal_reference=animals[0],
            rescale='Full',
            verbose=True
        )
    """

    if not isinstance(output_path, Path):
        output_path = Path(output_path)

    # Create the output zarr group
    output_group = zarr.group(output_path)
    output_group.attrs["animals"] = [
        animal.attrs.get("name", i) for i, animal in enumerate(animals)
    ]
    output_group.attrs["name"] = output_path.name

    # Collect all possible paths from all animals
    all_paths = set()
    for animal in animals:
        if "TIME_AVERAGE" in animal:
            paths = _collect_all_zarr_paths(animal.TIME_AVERAGE)
            all_paths.update(paths)
            _vprint(f"Found {len(all_paths)} unique paths to average", verbose)

    # Organize paths into a nested structure by grid_name -> timing -> property
    organized_paths = organize_paths(all_paths, grid_name=grid_name)
    # First loop: iterate over grid names
    for grid_key in organized_paths:

        # Skip grids that are not present in the reference animal
        if grid_key not in animal_reference.GRID:
            _vprint(
                f"The reference animal {animal_reference.attrs['name']} doesn't have the grid {grid_key}, skipping it",
                verbose,
            )
            continue

        # Skip grids without centroids in the reference animal
        if "centroids" not in animal_reference.GRID[grid_key].GRID_PROPERTIES:
            _vprint(
                f"The reference animal {animal_reference.attrs['name']} doesn't have centroids for {grid_key}, skipping it",
                verbose,
            )
            continue
        _vprint(f"Processing grid: {grid_key}", verbose)

        # Get transforms once per grid
        animal_transforms = get_transforms(animals, grid_key, rescale)
        reference_centroids = animal_reference.GRID[grid_key].GRID_PROPERTIES[
            "centroids"
        ][:]

        # Second loop: iterate over time backups
        for timing_path, properties in organized_paths[grid_key].items():
            timing_parts = timing_path.split("/")

            _vprint(f"Processing timing: {timing_parts}", verbose)
            # Create time backup if all animals have this path
            average_time_backup, animals_present = construct_time_backup(
                animals, output_group, timing_parts, reference_centroids
            )

            if not animals_present:
                continue

            # Get weights once per time backup
            weights = []
            frame_arrays = []
            time_backups = []
            for animal in animals:
                backup = animal.TIME_AVERAGE[timing_path]
                time_backups.append(backup)
                weights.append(backup.weights[:])
                frame_arrays.append(backup.frame_array[:])

            weights = np.stack(weights, axis=0)
            average_weight = np.mean(weights, axis=0)
            average_time_backup.create_dataset(
                "frame_array",
                data=np.stack(frame_arrays, axis=0),
                chunks=(1, *frame_arrays[0].shape),
                overwrite=True,
            )
            weights_data = np.moveaxis(
                np.concatenate((average_weight[np.newaxis], weights), axis=0), 0, -1
            )
            average_time_backup.create_dataset(
                "weights",
                data=weights_data,
                chunks=(1, *average_weight.shape[1:], 1),
                overwrite=True,
            )
            # area^1 alias: ROI/grid-mask readers key off `AreaRatios`, not `weights`.
            average_time_backup.create_dataset(
                "AreaRatios",
                data=np.sqrt(weights_data),
                chunks=(1, *average_weight.shape[1:], 1),
                overwrite=True,
            )

            # Third loop: iterate over properties
            for property_name in properties:
                # Skip special properties
                if property_name in ["weights", "frame_array", "time_array"]:
                    continue

                # Check if all animals have this property
                property_to_average = True
                for backup in time_backups:
                    if property_name not in backup:
                        property_to_average = False
                        break

                if property_to_average:
                    # Collect data from all animals
                    tensors = []
                    for i, backup in enumerate(time_backups):
                        property_data = backup[property_name][:]
                        prop_shape = property_data.shape

                        # Correct vectors and tensors
                        is_vector = prop_shape[-1] == 2 or prop_shape[-1] == 3
                        is_matrix_2D = prop_shape[-1] == 4

                        if is_vector:
                            property_data[..., -2:] = _apply_matrix_transform_to_points(
                                property_data[..., -2:], animal_transforms[i][:2, :2]
                            )

                        elif is_matrix_2D:
                            property_data = _correct_matrix(
                                property_data,
                                animal_transforms[i][:2, :2],
                            )

                        tensors.append(property_data)

                    # Stack and average the property data
                    tensors = np.stack(tensors, axis=0)
                    averaged_property = _average_over_animals(tensors, weights)

                    std_property = get_unbiased_weighted_std_matrix_aoa(
                        np.moveaxis(tensors, 0, -1),
                        averaged_property,
                        np.moveaxis(weights, 0, -1),
                    )

                    # Store the averaged property
                    prop_array = average_time_backup.create_dataset(
                        property_name,
                        data=np.moveaxis(
                            np.concatenate(
                                (averaged_property[np.newaxis], tensors), axis=0
                            ),
                            0,
                            -1,
                        ),
                        chunks=(1, *averaged_property.shape[1:], 1),
                        dtype=averaged_property.dtype,
                        overwrite=True,
                    )

                    # Store the standard deviation for that property
                    std_array = average_time_backup.create_dataset(
                        f"{property_name}_std",
                        data=std_property,
                        chunks=(1, *std_property.shape[1:]),
                        overwrite=True,
                    )

                    # Copy attributes from reference animal
                    prop_array.attrs.update(
                        animal_reference.TIME_AVERAGE[timing_path][property_name].attrs.asdict()
                    )

    return output_group


def _collect_all_zarr_paths(group, current_path=""):
    """
    Recursively collect all paths in a zarr group.

    :param group: The zarr group to traverse
    :param current_path: The current path prefix
    :return: A set of all paths in the group
    """
    paths = set()

    for key in group.keys():
        item = group[key]
        item_path = f"{current_path}/{key}" if current_path else key

        if isinstance(item, zarr.hierarchy.Group):
            # Recurse into subgroups
            sub_paths = _collect_all_zarr_paths(item, item_path)
            paths.update(sub_paths)
        else:
            # Add the array path
            paths.add(item_path)

    return paths


def _average_over_animals(stacked_tensors, stacked_weights):
    """
    Average tensors across animals, handling missing data.

    :param tensors: List of tensors from each animal (None for missing)
    :param weights: List of weights for each tensor (None if no weights)
    :param total_animals: Total number of animals (to properly normalize)
    :return: Averaged tensor
    """

    # Calculate weighted sum
    weighted_sum = np.nansum(stacked_weights * stacked_tensors, axis=0)

    # Sum of weights
    sum_weights = np.nansum(stacked_weights, axis=0)

    # Handle division by zero
    with np.errstate(divide="ignore", invalid="ignore"):
        averaged_tensor = np.where(sum_weights > 0, weighted_sum / sum_weights, np.nan)

    return averaged_tensor


def construct_time_backup(animals, output_group, path_parts, ref_centroids):
    animals_present = []
    for animal in animals:
        try:
            one_final_group = animal.TIME_AVERAGE["/".join(path_parts)]
            animals_present.append(animal)
        except (KeyError, ValueError):
            warnings.warn(
                f"the animal {animal.attrs['name']} doesn't have the backup {'/'.join(path_parts)}, skipping this time_backup"
            )
            return None, False
    intermediate_groups = output_group.require_group(path_parts[0])
    for zarr_group in path_parts[1:]:
        intermediate_groups = intermediate_groups.require_group(zarr_group)

    intermediate_groups.attrs["animals"] = [animal.attrs["name"] for animal in animals]
    ref_attrs = one_final_group.attrs.asdict()
    intermediate_groups.attrs.update(ref_attrs)
    # Store reference centroids
    intermediate_groups.array(
        "grid_centroids", data=ref_centroids, overwrite=True, chunks=ref_centroids.shape
    )
    intermediate_groups.array(
        "time_array",
        data=one_final_group.time_array[:],
        overwrite=True,
        chunks=one_final_group.time_array.chunks,
    )
    return intermediate_groups, animals_present


def get_transforms(animals, grid_type, rescale):
    """Get transformation matrices for each animal."""
    transforms = []
    for animal in animals:
        try:
            # Get transformation matrix for the animal
            affine_transform = np.array(
                animal.GRID[grid_type].GRID_PROPERTIES.attrs["matrix_transform"]
            )
            affine_transform = affine_transform[-3:-1, -3:-1]
            if rescale == "Rotation":
                affine_transform, _ = _extract_rotation_and_scaling(
                    affine_transform, side="right"
                )
            elif rescale == "Iso_scaling":
                affine_transform /= np.sqrt(np.abs(np.linalg.det(affine_transform)))
            transforms.append(affine_transform)
        except (KeyError, AttributeError):
            transforms.append(None)
    return transforms


def organize_paths(all_paths, grid_name=None):
    """
    Organize flat TIME_AVERAGE paths into a nested structure by grid -> timing -> properties.

    Only the target grid is kept: ``grid_name`` if given, else the default ``"EULERIAN"``
    (average-over-animals is eulerian-only). ``path_parts[0]`` is the grid group name,
    written consistently by ``average_over_time``.
    """
    accepted_grid = grid_name if grid_name is not None else "EULERIAN"
    organized = {}

    for path in natsorted(list(all_paths)):
        path_parts = path.split("/")

        if len(path_parts) < 3:
            continue

        grid_key = path_parts[0]
        if grid_key == accepted_grid:
            property_name = path_parts[-1]
            timing_path = "/".join(path_parts[:-1])

            organized.setdefault(grid_key, {}).setdefault(timing_path, []).append(
                property_name
            )

    return organized
