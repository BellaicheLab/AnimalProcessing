"""Create an animal zarr store from raw images, masks, labels, and regions (single
stacks or per-frame image files), setting up the canonical IMAGE/CELL hierarchy
and the timing/scaling attributes used downstream.
"""

import re
import warnings
from pathlib import Path
from typing import Any, List, Optional, Union

import numpy as np
from joblib import Parallel, delayed
from pyanimalprocessing import JOBLIB_BACKEND
from natsort import natsorted
from numpy.typing import NDArray
from skimage.io import imread
import skimage

import zarr
from pyanimalprocessing.utils import (
    _set_warning_filters,
    _vprint,
)

__all__ = ["instantiate_animal"]


def instantiate_animal(
    output_zarr: Union[str, Path],
    raw_image_2d: Optional[Union[str, Path, NDArray]] = None,
    raw_image_2d_order: List[str] = "tcyx",
    raw_image_3d: Optional[Union[str, Path, NDArray]] = None,
    raw_image_3d_order: List[str] = "tczyx",
    mask_2d: Optional[Union[str, Path, NDArray]] = None,
    mask_2d_order: List[str] = "tyx",
    zmap: Optional[Union[str, Path, NDArray]] = None,
    zmap_order: List[str] = "tyx",
    labels_2d: Optional[Union[str, Path, NDArray]] = None,
    labels_2d_order: List[str] = "tyx",
    labels_3d: Optional[Union[str, Path, NDArray]] = None,
    labels_3d_order: List[str] = "tzyx",
    region_2d: Optional[Union[str, Path, NDArray]] = None,
    region_2d_order: List[str] = "tyx",
    region_3d: Optional[Union[str, Path, NDArray]] = None,
    region_3d_order: List[str] = "tzyx",
    additional_elements: List[tuple] = [],
    channel_names: Optional[List[str]] = ["Cad"],
    overwrite: bool = False,
    temperature: float = 25.0,
    dt: float = 5.0,
    scaling: float = 0.161,
    frame_ref: Optional[int] = None,
    time_ref: Optional[str] = None,
    n_jobs=-1,
    verbose: bool = False,
) -> zarr.hierarchy.Group:
    """
    Initialize a Zarr store for an animal dataset with support for 2D/3D images and various data types.

    This function creates a standardized hierarchical structure for storing biological imaging data,
    facilitating downstream analysis. The Zarr store is organized into two main groups:

      - ``IMAGE``: Contains raw images, labels, and regions in both 2D and 3D.
      - ``CELL``: Reserved for cell-specific processed data.

    **Dimension Ordering:**

    Two methods are supported to specify the dimension order of input data:

    1. **Single Image Files**:
       Use a simple string (without parentheses) to define dimensions.

       Supported dimensions:
         - ``t``: time
         - ``c``: channel
         - ``z``: z-stack (depth)
         - ``y``: vertical axis
         - ``x``: horizontal axis

       **Examples:**
         - ``"tcyx"``: 2D time series with channels.
         - ``"tczyx"``: 3D time series with channels.

    2. **Multiple Image Files**:
       Use a compound notation with inner and outer orders. The inner dimensions (in parentheses) describe
       the shape of each file, while the outer dimensions describe the organization of the file sequence.

       **Examples:**
         - ``"t,c,(yx)"``: Multiple 2D images organized by time and channel.
         - ``"t,(zyx)"``: Multiple 3D images organized by time.
         - ``"c,(yx)"``: Single timepoint with multiple channels.

       **Note:**
       For folders with a single image file, use the simple notation without parentheses.

    :param output_zarr: Path for the output Zarr store (str or Path).
    :param raw_image_2d: 2D raw image data (file path, directory, or numpy array).
    :param raw_image_2d_order: Dimension order for 2D raw images.
    :param raw_image_3d: 3D raw image data.
    :param raw_image_3d_order: Dimension order for 3D raw images.
    :param mask_2d: binary mask of the tissue.
    :param mask_2d_order: Dimension order for the mask.
    :param zmap: Z-projection map data.
    :param zmap_order: Dimension order for the zmap.
    :param labels_2d: 2D label image data.
    :param labels_2d_order: Dimension order for 2D labels.
    :param labels_3d: 3D label image data.
    :param labels_3d_order: Dimension order for 3D labels.
    :param region_2d: 2D region image data.
    :param region_2d_order: Dimension order for 2D regions.
    :param region_3d: 3D region image data.
    :param region_3d_order: Dimension order for 3D regions.
    :param additional_elements: List of tuples in the format
                                (group_name with relative path to animal, path to data, order, target_order, channels_number)
                                for additional data elements.
    :param channel_names: List of channel names.
    :param overwrite: If True, overwrite existing data.
    :param temperature: Temperature value in degrees Celsius.
    :param dt: Time step interval in minutes.
    :param scaling: Pixel size scaling factor in microns.
    :param n_jobs: Number of parallel jobs (-1 uses all available cores).
    :param verbose: If True, output verbose information.
    :return: A Zarr Group object containing the animal dataset.

    **Examples:**

    Basic usage with a single 2D time series::

        animal = instantiate_animal(
            "path/to/animal_name.zarr",
            raw_image_2d="path/to/single_image.tif",
            raw_image_2d_order="tcyx"
        )

    Using multiple 2D images from a folder::

        animal = instantiate_animal(
            "path/to/animal_name.zarr",
            raw_image_2d="path/to/image_folder",
            raw_image_2d_order="t,c,(yx)",
            channel_names=["DAPI", "GFP"]
        )

    Processing 3D data with corresponding labels::

        animal = instantiate_animal(
            "path/to/animal_name.zarr",
            raw_image_3d="path/to/3d_image.tif",
            raw_image_3d_order="tczyx",
            labels_3d="path/to/labels.tif",
            labels_3d_order="tzyx"
        )
    """
    # Set warning filters
    _set_warning_filters(verbose)

    if not isinstance(output_zarr, Path):
        output_zarr = Path(output_zarr)

    # First we create or access the zarr structure
    animal = _create_zarr_structure(output_zarr, verbose)

    # FOR THE ATTRIBUTES WE NOW ALWAYS OVERWRITE (TO AVOID MISTAKES DURING THE ANALYSIS)
    # Store channel names in the root group attributes
    _store_attribute_if_not_exists(
        animal, "channels", channel_names, overwrite=overwrite
    )
    _store_attribute_if_not_exists(
        animal, "temperature", temperature, overwrite=overwrite
    )
    _store_attribute_if_not_exists(animal, "dt", dt, overwrite=overwrite)
    _store_attribute_if_not_exists(animal, "scaling", scaling, overwrite=overwrite)
    _store_attribute_if_not_exists(
        animal, "name", output_zarr.name, overwrite=overwrite
    )
    # Timing is animal-specific: store only if provided (never a bogus default). The
    # time-dependent steps raise a clear error if it is missing when they need it.
    if frame_ref is not None:
        _store_attribute_if_not_exists(animal, "frame_ref", frame_ref, overwrite=overwrite)
    if time_ref is not None:
        _store_attribute_if_not_exists(animal, "time_ref", time_ref, overwrite=overwrite)

    number_of_channels = len(channel_names)

    orders = _prepare_orders(
        raw_image_2d,
        raw_image_2d_order,
        raw_image_3d,
        raw_image_3d_order,
        mask_2d,
        mask_2d_order,
        zmap,
        zmap_order,
        labels_2d,
        labels_2d_order,
        labels_3d,
        labels_3d_order,
        region_2d,
        region_2d_order,
        region_3d,
        region_3d_order,
        additional_elements,
        number_of_channels,
    )

    return _instantiate_animal(
        animal=animal,
        orders=orders,
        overwrite=overwrite,
        n_jobs=n_jobs,
        verbose=verbose,
    )


def _prepare_orders(
    raw_image_2d,
    raw_image_2d_order,
    raw_image_3d,
    raw_image_3d_order,
    mask_2d,
    mask_2d_order,
    zmap,
    zmap_order,
    labels_2d,
    labels_2d_order,
    labels_3d,
    labels_3d_order,
    region_2d,
    region_2d_order,
    region_3d,
    region_3d_order,
    additional_elements,
    number_of_channels,
) -> tuple[List[str], List[str], List[str], List[str], List[int]]:
    output_paths, inputs, orders, target_orders, channels_numbers = [], [], [], [], []
    if raw_image_2d is not None:
        output_paths.append("IMAGE/D2/raw")
        inputs.append(raw_image_2d)
        orders.append(raw_image_2d_order)
        target_orders.append("tcyx")
        channels_numbers.append(number_of_channels)
    if raw_image_3d is not None:
        output_paths.append("IMAGE/D3/raw")
        inputs.append(raw_image_3d)
        orders.append(raw_image_3d_order)
        target_orders.append("tczyx")
        channels_numbers.append(number_of_channels)
    if mask_2d is not None:
        output_paths.append("IMAGE/D2/mask")
        inputs.append(mask_2d)
        orders.append(mask_2d_order)
        target_orders.append("tyx")
        channels_numbers.append(1)
    if zmap is not None:
        output_paths.append("IMAGE/D2/zmap")
        inputs.append(zmap)
        orders.append(zmap_order)
        target_orders.append("tyx")
        channels_numbers.append(1)
    if labels_2d is not None:
        output_paths.append("IMAGE/D2/label")
        inputs.append(labels_2d)
        orders.append(labels_2d_order)
        target_orders.append("tyx")
        channels_numbers.append(1)
    if labels_3d is not None:
        output_paths.append("IMAGE/D3/label")
        inputs.append(labels_3d)
        orders.append(labels_3d_order)
        target_orders.append("tzyx")
        channels_numbers.append(1)
    if region_2d is not None:
        output_paths.append("IMAGE/D2/region")
        inputs.append(region_2d)
        orders.append(region_2d_order)
        target_orders.append("tyx")
        channels_numbers.append(1)
    if region_3d is not None:
        output_paths.append("IMAGE/D3/region")
        inputs.append(region_3d)
        orders.append(region_3d_order)
        target_orders.append("tzyx")
        channels_numbers.append(1)
    if additional_elements:
        for (
            group_name,
            path,
            order,
            target_order,
            channels_number,
        ) in additional_elements:
            output_paths.append(group_name)
            inputs.append(path)
            orders.append(order)
            target_orders.append(target_order)
            channels_numbers.append(channels_number)
    return output_paths, inputs, orders, target_orders, channels_numbers


def _instantiate_animal(
    animal: Union[str, Path],
    orders: List[tuple],
    overwrite: bool = False,
    n_jobs=-1,
    verbose: bool = False,
) -> zarr.hierarchy.Group:
    """
    Process and store multiple datasets in a Zarr structure according to specified orders and parameters.
    """

    output_paths, inputs, dim_orders, target_orders, channels_numbers = orders

    # Process and store raw and label images if they do not already exist in the Zarr store
    for output_path, input, dim_order, target_order, channels_number in zip(
        output_paths, inputs, dim_orders, target_orders, channels_numbers
    ):

        group_path = "/".join(output_path.split("/")[:-1])
        group_name = output_path.split("/")[-1]

        _dump_image_in_zarr(
            animal[group_path],
            group_name,
            input,
            dim_order,
            target_order,
            channels_number,
            overwrite=overwrite,
            n_jobs=n_jobs,
            verbose=verbose,
        )

    mask_not_present = "mask" not in animal.IMAGE.D2
    mask_not_provided = "IMAGE/D2/mask" not in output_paths
    image_2D_present = "raw" in animal.IMAGE.D2

    if (mask_not_present or (mask_not_provided and overwrite)) and image_2D_present:
        animal.IMAGE.D2.create_dataset(
            "mask",
            shape=(animal.IMAGE.D2.raw.shape[0], *animal.IMAGE.D2.raw.shape[2:]),
            dtype=bool,
            chunks=(1, *animal.IMAGE.D2.raw.shape[2:]),
            overwrite=True,
        )

        if "label" in animal.IMAGE.D2:
            _vprint(
                "Mask not provided, using label to create mask (using binary closing)",
                verbose,
            )
            for t in range(animal.IMAGE.D2.raw.shape[0]):
                label = animal.IMAGE.D2.label[t]
                label_t = label > 0
                binary_labels = label_t.astype(bool)
                binary_labels_filled = skimage.morphology.remove_small_holes(binary_labels, 10)
                animal.IMAGE.D2.mask[t] = binary_labels_filled
        else:
            _vprint("No label provided, using all True mask", verbose)
            animal.IMAGE.D2.mask[:] = True

    return animal


def _store_attribute_if_not_exists(
    group: zarr.hierarchy.Group, key: str, value: Any, overwrite: bool = False
):
    """
    Store an attribute in a Zarr group if it doesn't exist or if overwrite is True.
    """
    if key not in group.attrs or overwrite:
        group.attrs[key] = value


def _create_zarr_structure(
    output_zarr: Union[str, Path], verbose: bool = True
) -> zarr.hierarchy.Group:
    """
    Create a hierarchical Zarr structure with IMAGE and CELL groups, each containing D2 and D3 subgroups.
    """
    output_zarr_path = Path(output_zarr)

    # If a group already exists, open it in read-write mode
    zarr_store = zarr.open_group(str(output_zarr_path), mode="a")

    # Define the structure with first-level groups and their respective subgroups
    structure = {
        "IMAGE": ["D2", "D3"],
        "CELL": ["D2", "D3"],
    }

    for group_name, subgroups in structure.items():
        # Check if the group already exists
        if group_name in zarr_store:
            warnings.warn(
                f"Group '{group_name}' already exists in the Zarr store at {output_zarr_path}."
            )
        else:
            # Create the group
            group = zarr_store.create_group(group_name)

            # Create subgroups if any are specified
            if subgroups:
                for subgroup_name in subgroups:
                    if subgroup_name in group:
                        warnings.warn(
                            f"Subgroup '{subgroup_name}' already exists in group '{group_name}'."
                        )
                    else:
                        group.create_group(subgroup_name)

    _vprint(f"Zarr structure created at {output_zarr_path}.", verbose)

    return zarr_store


def _dump_image_in_zarr(
    group: zarr.Group,
    dataset_name: str,
    input: Union[str, Path, list, NDArray],
    order: str,
    target_order: str,
    channels_number: int,
    overwrite: bool = False,
    n_jobs=-1,
    verbose: bool = False,
) -> None:
    """
    Load and store image data in a Zarr dataset, handling single images, multiple images, and arrays.
    """

    # Immediately return if the dataset already exists, avoiding unnecessary loading and processing
    if dataset_name in group and overwrite is False:
        _vprint(f"Dataset '{dataset_name}' already exists. No action taken.", verbose)
        return

    if isinstance(input, list):
        _instantiate_from_multiple_images(
            group,
            dataset_name,
            input,
            order,
            target_order,
            channels_number,
            overwrite,
            n_jobs,
        )

    elif isinstance(input, np.ndarray):
        return _instantiate_from_array(
            group,
            dataset_name,
            input,
            order,
            target_order,
            overwrite,
        )

    elif isinstance(input, Path) or isinstance(input, str):
        input = Path(input)

        if input.is_dir():
            all_files = list(input.glob("*[tTp][iIn][fFg]*"))
            _vprint("all_files:", verbose)
            _vprint("\n".join([str(f) for f in all_files]), verbose)
            all_files = natsorted(all_files)
            _vprint("all_files:", verbose)
            _vprint("\n".join([str(f) for f in all_files]), verbose)

            if len(all_files) == 1:
                image = imread(str(all_files[0]))
                return _instantiate_from_array(
                    group,
                    dataset_name,
                    image,
                    order,
                    target_order,
                    overwrite,
                )

            else:
                _instantiate_from_multiple_images(
                    group,
                    dataset_name,
                    all_files,
                    order,
                    target_order,
                    channels_number,
                    overwrite,
                    n_jobs,
                )
        else:
            image = imread(str(input))
            return _instantiate_from_array(
                group,
                dataset_name,
                image,
                order,
                target_order,
                overwrite,
            )


def _instantiate_from_array(
    group: zarr.Group,
    dataset_name: str,
    image: np.ndarray,
    order: str,
    target_order: str,
    overwrite=True,
):
    """
    Create a Zarr dataset from a numpy array with proper dimension ordering.
    """
    try:
        image = _reorder_dims_array(image, order, target_order)
    except ValueError as e:
        raise ValueError(
            f"Error processing dataset '{dataset_name}' in _instantiate_from_array: {e}"
        ) from e

    group.create_dataset(
        dataset_name,
        data=image,
        chunks=tuple([1 for _ in image.shape[:-2]] + [*image.shape[-2:]]),
        overwrite=overwrite,
    )


def _parse_order(order: str) -> tuple[str, str]:
    """
    Parse dimension order string into outer and inner components for multiple image processing.
    """
    m = re.search(r"\((.*?)\)", order)
    if not m:
        raise ValueError(
            "For multiple images, the ordering string must contain inner dimensions enclosed in ()"
        )
    inner_order = m.group(1).replace(",", "").replace(" ", "")
    # Everything outside the parentheses composes the outer order.
    outer_order = (
        (order[: m.start()] + order[m.end() :]).replace(",", "").replace(" ", "")
    )
    if not inner_order:
        raise ValueError(
            "Ordering must include at least one outer dimension in the parentheses."
        )
    if not outer_order:
        raise ValueError(
            "Ordering must include at least one outer dimension outside parentheses."
        )
    return outer_order, inner_order


def _compute_outer_shape(n_files: int, outer_order: str, channels_number: int) -> tuple:
    """
    Calculate the shape of outer dimensions based on file count and channel number.
    """
    if len(outer_order) == 1:
        # Single outer axis: size equals number of files.
        outer_shape = (n_files,)
        if outer_order == "c" and n_files != channels_number:
            raise ValueError(
                "If the outer dimension is channels, there should be the same number of channels and files"
            )
    elif len(outer_order) == 2:
        # When two outer dimensions are specified, we expect that one of them is the channel dimension.
        if "c" in outer_order:
            # Get channel axis position.
            if n_files % channels_number != 0:
                raise ValueError("Number of files is not divisible by channels_number.")
            if outer_order[0] == "c":
                outer_shape = (channels_number, n_files // channels_number)
            else:
                outer_shape = (n_files // channels_number, channels_number)
        else:
            raise ValueError("Expected one outer dimension to be 'c' for channels.")
    else:
        raise ValueError(
            "Unsupported outer ordering: only one or two outer dimensions are allowed."
        )
    return outer_shape


def _instantiate_from_multiple_images(
    group: zarr.Group,
    dataset_name: str,
    image_paths: List[Path],
    order: str,
    target_order: str,
    channels_number,
    overwrite=True,
    n_jobs=-1,
):
    """
    Create a dataset from multiple image files using specified inner/outer dimension ordering.
    """
    # Outer shape is the shape before the parenthesis and inner shape is the shape inside the parenthesis
    outer_order, inner_order = _parse_order(order)
    n_files = len(image_paths)
    outer_shape = _compute_outer_shape(n_files, outer_order, channels_number)
    # Determine the inner target order from the overall target_order.
    #    The inner target order consists of those dimensions from target_order that are not in the outer order.
    inner_target_order = [d for d in target_order if d not in outer_order]
    if not set(inner_order).issubset(set(inner_target_order)):
        raise ValueError(
            f"Inner dimensions specified by order ({inner_order}) must be a subset of the inner dimensions "
            f"derived from target_order ({''.join(inner_target_order)})."
        )

    # Read the first image to obtain the inner shape
    first_image = imread(str(image_paths[0]))
    if first_image.ndim != len(inner_order):
        first_image = first_image.squeeze()
        if first_image.ndim != len(inner_order):
            raise ValueError(
                f"First image has {first_image.ndim} dimensions but inner order specifies {len(inner_order)}."
            )
    try:
        if inner_order != "".join(inner_target_order):
            first_image_reordered = _reorder_dims_array(
                first_image, inner_order, "".join(inner_target_order)
            )
        else:
            first_image_reordered = first_image
    except ValueError as e:
        raise ValueError(
            f"Error processing dataset '{dataset_name}' (first image) in _instantiate_from_multiple_images: {e}"
        ) from e

    inner_shape = first_image_reordered.shape

    # Determine the final dataset shape.
    #    The full (combined) current ordering is outer_order + inner_order.
    #    For each axis in the target_order, we assign its size from the outer or inner shapes.
    final_shape = []
    for char in target_order:
        if char in outer_order:
            # The dimension from outer_order: find its position and use the corresponding size.
            idx = outer_order.index(char)
            final_shape.append(outer_shape[idx])
        elif char in inner_target_order:
            idx = inner_target_order.index(char)
            final_shape.append(inner_shape[idx])
        else:
            raise ValueError(
                f"Dimension '{char}' in target_order not found in outer or inner orders."
            )
    final_shape = tuple(final_shape)

    # Set the chunk shape.
    # We'll use a chunk size of 1 for each outer dimension and full idiom for the inner dimensions.
    n_inner = len(inner_target_order)
    chunk_shape = (
        tuple(1 for _ in range(len(final_shape) - n_inner)) + final_shape[-n_inner:]
    )

    # Determine which dimension in outer_order is the channel ('c')
    if "c" in outer_order:
        c_dim = outer_order.index("c")
        channel_indices = []
        for c in range(outer_shape[c_dim]):
            idx = [0] * len(outer_shape)
            idx[c_dim] = c
            linear_idx = np.ravel_multi_index(idx, outer_shape)
            channel_indices.append(linear_idx)
    else:
        channel_indices = [0]

    # Collect dtypes from the first image of each channel
    dtypes = [first_image.dtype]
    for idx in channel_indices[1:]:  # Skip first index (0) since we already have it
        if idx >= len(image_paths):
            continue
        img = imread(str(image_paths[idx]))
        dtypes.append(img.dtype)
    dtype = np.result_type(*dtypes)
    # Create the dataset with the determined dtype

    if dataset_name == "mask":
        dtype = bool

    dataset = group.create_dataset(
        dataset_name,
        shape=final_shape,
        dtype=dtype,
        chunks=chunk_shape,
        overwrite=overwrite,
    )

    # Populate the dataset: write the first image (already processed) and then process remaining files.
    # For the first image:
    outer_idx0 = np.unravel_index(0, outer_shape)
    full_index_first = tuple(
        outer_idx0[outer_order.index(char)] if char in outer_order else slice(None)
        for char in target_order
    )
    dataset[full_index_first] = first_image_reordered

    # Process the remaining images (in parallel).
    if n_files > 1:
        Parallel(n_jobs=n_jobs, backend=JOBLIB_BACKEND)(
            delayed(_populate_frame_file)(
                i,
                path,
                outer_shape,
                inner_order,
                inner_target_order,
                target_order,
                outer_order,
                dataset,
                dataset_name,
            )
            for i, path in enumerate(image_paths[1:], start=1)
        )

    return dataset


def _populate_frame_file(
    frame_number,
    path,
    outer_shape,
    inner_order,
    inner_target_order,
    target_order,
    outer_order,
    dataset,
    dataset_name,
):
    """
    Load and store a single image file in the correct position within a Zarr dataset.
    """
    # Compute outer multi-index based on outer_shape.
    outer_idx = np.unravel_index(frame_number, outer_shape)
    # Load the image.
    img = imread(str(path))
    if img.ndim != len(inner_order):
        img = img.squeeze()
        if img.ndim != len(inner_order):
            raise ValueError(
                f"Image {path} has {img.ndim} dimensions but expected {len(inner_order)} as per the inner order."
            )
    try:
        if inner_order != "".join(inner_target_order):
            img_reordered = _reorder_dims_array(
                img, inner_order, "".join(inner_target_order)
            )
        else:
            img_reordered = img
    except ValueError as err:
        raise ValueError(
            f"Error processing dataset '{dataset_name}' in _populate_frame_file for file {path}: {err}"
        ) from err

    # Build the full index tuple for the dataset.
    # For each dimension in target_order, use a scalar for outer dims or slice(None) for inner ones.
    full_index = []
    for char in target_order:
        if char in outer_order:
            # Use the value from the corresponding outer_idx.
            full_index.append(outer_idx[outer_order.index(char)])
        elif char in inner_target_order:
            full_index.append(slice(None))
        else:
            raise ValueError(f"Dimension '{char}' not found in outer or inner orders.")
    full_index = tuple(full_index)

    # Write the reordered image to the correct slab in the dataset.
    dataset[full_index] = img_reordered


def _reorder_dims_array(
    array: NDArray,
    current_order: Union[str, List[str]],
    target_order: Union[str, List[str]],
) -> NDArray:
    """
    Reorder and expand the axes of an array to match the target dimension order.
    """
    # Ensure current_order and target_order are lists of characters
    if isinstance(current_order, str):
        current_order = list(current_order)
    if isinstance(target_order, str):
        target_order = list(target_order)

    # Validate that every axis specified in current_order is also in target_order.
    missing_axes = set(current_order) - set(target_order)
    if missing_axes:
        raise ValueError(
            f"The current_order contains axes {missing_axes} which are not present in the target_order {target_order}."
        )

    # Validate that the array's number of dimensions matches the length of current_order.
    if array.ndim != len(current_order):
        raise ValueError(
            f"The input array has {array.ndim} dimensions but current_order specifies {len(current_order)} axes."
        )

    # Work on a copy/reference to the input array and update a list representing its axis labels.
    new_array = array
    current_axes = current_order.copy()

    # Insert missing axes as singleton dimensions at the correct positions.
    for pos, axis in enumerate(target_order):
        if axis not in current_axes:
            new_array = np.expand_dims(new_array, axis=pos)
            current_axes.insert(pos, axis)

    # Calculate the permutation required to transform the (now complete) current_axes into the target order.
    permutation = [current_axes.index(axis) for axis in target_order]
    # If the permutation is not the identity, then reorder the axes.
    if permutation != list(range(len(permutation))):
        new_array = new_array.transpose(permutation)

    return new_array
