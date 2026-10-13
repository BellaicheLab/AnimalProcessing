"""Per-frame region-property measurement on segmented labels: scikit-image
regionprops plus custom properties, computed on cells, user regions, or Eulerian
grid boxes, and stored as backups in the animal zarr store.
"""

import inspect
import pathlib
import re
import warnings
from typing import Callable, Dict, List, Literal, Tuple, Union

import numpy as np
import scipy.ndimage as ndi
from joblib import Parallel, delayed
from numpy import array, moveaxis, newaxis, zeros
from numpy.typing import NDArray
from tqdm import tqdm

import zarr
from pyanimalprocessing import JOBLIB_BACKEND
from pyanimalprocessing._regionprops_clone import _RegionProperties
from pyanimalprocessing.analyze_labels_properties import (
    axial_polarity,
    background,
    contours,
    directional_polarity,
    object_offset,
    property_decorator,
    weighted_directional_polarity,
)
from pyanimalprocessing.utils.pipeline import (
    _extend_slices,
    _function_to_property,
    set_data_properties,
)
from pyanimalprocessing.utils import _tqdm_joblib, _vprint

# These ones belong to skimage out of the box.
# "slice" is deliberately absent: regionprops returns python slice objects, which are not
# array-storable, and "bbox_tuple" already stores the same bounds (starts then stops).
BASE_PROPERTY_REGISTRY = [
    "background",
    "object_offset",
    "area",
    "area_bbox",
    "area_convex",
    "area_filled",
    "axis_major_length",
    "axis_minor_length",
    "bbox_tuple",
    "centroid",
    "centroid_local",
    "centroid_weighted",
    "centroid_weighted_local",
    "coords_scaled",
    "coords",
    "eccentricity",
    "equivalent_diameter_area",
    "euler_number_int",
    "extent",
    "feret_diameter_max",
    "image",
    "image_convex",
    "image_filled",
    "inertia_tensor",
    "inertia_tensor_eigvals",
    "intensity_max",
    "intensity_mean",
    "intensity_min",
    "label_int",
    "moments",
    "moments_central",
    "moments_hu",
    "moments_normalized",
    "moments_weighted",
    "moments_weighted_central",
    "moments_weighted_hu",
    "moments_weighted_normalized",
    "num_pixels_int",
    "orientation",
    "perimeter",
    "perimeter_crofton",
    "solidity",
]

# These ones rely on the skimage region props to function
EXTRA_PROPERTIES_REGISTRY: List[Callable] = [
    background,
    object_offset,
    contours,
    axial_polarity,
    directional_polarity,
    weighted_directional_polarity,
]

CUSTOM_PROPERTIES_DTYPE = {
    "background": np.uint16,
    "object_offset": np.uint16,
    "area": np.float64,
    "area_bbox": np.uint16,
    "area_convex": np.uint16,
    "area_filled": np.uint16,
    "axis_major_length": np.float16,
    "axis_minor_length": np.float16,
    # integer valued, but the dense backup is NaN filled: float32 keeps labels,
    # bounding boxes and pixel counts exact where float16 would round them
    "bbox_tuple": np.float32,
    "centroid": np.float16,
    "centroid_local": np.float16,
    "centroid_weighted": np.float16,
    "centroid_weighted_local": np.float16,
    "coords_scaled": np.float16,
    "coords": np.uint16,
    "eccentricity": np.float16,
    "equivalent_diameter_area": np.float16,
    "euler_number_int": np.float32,
    "extent": np.float16,
    "feret_diameter_max": np.float16,
    "image": np.uint16,
    "image_convex": np.uint16,
    "image_filled": np.uint16,
    "inertia_tensor": np.float32,
    "inertia_tensor_eigvals": np.float16,
    "intensity_max": np.float16,
    "intensity_mean": np.float16,
    "intensity_min": np.float16,
    "label_int": np.float32,
    # raw moments overflow float16 (max 65504) and Hu moments underflow it
    "moments": np.float32,
    "moments_central": np.float32,
    "moments_hu": np.float32,
    "moments_normalized": np.float32,
    "moments_weighted": np.float32,
    "moments_weighted_central": np.float32,
    "moments_weighted_hu": np.float32,
    "moments_weighted_normalized": np.float32,
    "num_pixels_int": np.float32,
    "orientation": np.float16,
    "perimeter": np.float16,
    "perimeter_crofton": np.float16,
    "solidity": np.float16,
    "contours": object,  # np.uint16,
    "axial_polarity": np.float16,
    "directional_polarity": np.float16,
    "weighted_directional_polarity": np.float16,
}

CUSTOM_PROPERTIES_SHAPE = {
    "background": (0,),
    "object_offset": ("dimension",),
    "area": (),
    "area_bbox": (),
    "area_convex": (),
    "area_filled": (),
    "axis_major_length": (),
    "axis_minor_length": (),
    # The bounding box holds a start and a stop for each dimension
    "bbox_tuple": ("bbox_length",),
    "centroid": ("dimension",),
    "centroid_local": ("dimension",),
    "centroid_weighted": ("dimension", "nchannels"),
    "centroid_weighted_local": ("dimension", "nchannels"),
    # Assuming scaled coordinates return a list of arrays, with array shape dependent on object dimensionality
    "coords_scaled": (0, "dimension"),
    # List of coordinates, where each coordinate's length depends on the object's dimensionality
    "coords": (0, "dimension"),
    "eccentricity": (),
    "equivalent_diameter_area": (),
    "euler_number_int": (),
    "extent": (),
    "feret_diameter_max": (),
    # The image may be a binary mask, with its shape dependent on the dimensionality of the object
    "image": (0, "dimension"),
    "image_convex": (0, "dimension"),  # Same reasoning as for "image"
    "image_filled": (0, "dimension"),  # Same reasoning as for "image"
    # Assuming this refers to the intensity image within the region, with its shape dependent on the object's dimensionality
    # The shape of the inertia tensor depends on the dimensionality (2x2 for 2D, 3x3 for 3D)
    "inertia_tensor": ("dimension", "dimension"),
    # The number of eigenvalues corresponds to the dimensionality of the object
    "inertia_tensor_eigvals": ("dimension",),
    "intensity_max": ("nchannels",),
    "intensity_mean": ("nchannels",),
    "intensity_min": ("nchannels",),
    "label_int": (),
    # Spatial moments; one axis of "moment_axes" coefficients per dimension of the object
    "moments": ("moment_axes",),
    "moments_central": ("moment_axes",),
    "moments_hu": (7,),  # Hu moments are invariant to image transformations, 7 values (2D only)
    "moments_normalized": ("moment_axes",),
    "moments_weighted": ("moment_axes", "nchannels"),
    "moments_weighted_central": ("moment_axes", "nchannels"),
    "moments_weighted_hu": (7, "nchannels"),  # Weighted Hu moments, similar to Hu moments (2D only)
    "moments_weighted_normalized": ("moment_axes", "nchannels"),
    "num_pixels_int": (),
    "orientation": (),
    "perimeter": ("nchannels",),
    "perimeter_crofton": (),
    "solidity": ("nchannels",),
    "contours": (0, 2),
    "axial_polarity": (4, "nchannels"),
    "directional_polarity": (2, "nchannels"),
    "weighted_directional_polarity": (2, "nchannels"),
}
# This is where we store the different properties that we will compute for the images.


# tuple() -> nCells
# (0, "dimensions") -> nCells, <variable number>, <number of dimensions>
# (0,) -> nCells, <variable number>
# dimensions -> nCells, <number-of-dimensions>
# a token resolving to a tuple ("moment_axes") is spliced in, so it spans several axes


CUSTOM_PROPERTIES = BASE_PROPERTY_REGISTRY + [
    func.__name__ for func in EXTRA_PROPERTIES_REGISTRY
]


def analyze_labels(
    animals: Union[List[Union[str, zarr.Group]], str, zarr.Group],
    analysis_type: Literal["cell", "regions", "eulerian"] = "cell",
    grid_name: str = None,
    properties: Union[str, List[str]] = ["area", "centroid", "coords", "contours"],
    user_properties: Union[Callable, List[Callable]] = [],
    user_properties_dtypes: Union[np.dtype, List[np.dtype]] = [],
    user_properties_shapes: Union[Tuple, List[Tuple]] = [],
    dimension: Literal["D2", "D3"] = "D2",
    intensity_image: Union[str, NDArray] = "raw",
    n_jobs: int = -1,
    overwrite: bool = True,
    verbose: bool = False,
    **kwargs,
) -> List[Union[str, zarr.Group]]:
    """
    Analyze segmented image data stored in Zarr groups, computing specified properties for each region.

    This function processes segmented image data and computes various properties for each identified region
    (e.g., cells or grid compartments). It supports both built-in properties from scikit-image and custom
    user-defined properties. Results are stored back in the Zarr hierarchy.

    :param animals: Path(s) to Zarr group(s) or Zarr group object(s) containing the image data
    :type animals: Union[List[Union[str, zarr.Group]], str, zarr.Group]
    :param analysis_type: Type of analysis to perform:
        - "cell": Analyze individual segmented regions
        - "regions": Analyze user-defined regions
        - "eulerian": Analysis in Eulerian (fixed) frame
    :type analysis_type: Literal["cell", "regions", "eulerian"]
    :param grid_name: Name of the GRID/<grid_name> group used for "eulerian" analysis, also the key of the output backup group. Defaults to analysis_type.upper().
    :type grid_name: str, optional
    :param properties: Names of properties to compute. Can include built-in scikit-image properties
                      and custom properties defined in analyze_labels_properties.py
    :type properties: Union[str, List[str]]
    :param user_properties: Custom property functions to compute additional features
    :type user_properties: Union[Callable, List[Callable]]
    :param user_properties_dtypes: Data types for custom properties' outputs
    :type user_properties_dtypes: Union[np.dtype, List[np.dtype]]
    :param user_properties_shapes: Output shapes for custom properties
    :type user_properties_shapes: Union[Tuple, List[Tuple]]
    :param dimension: Dimensionality of the analysis ("D2" for 2D or "D3" for 3D)
    :type dimension: Literal["D2", "D3"]
    :param intensity_image: Name of intensity image dataset in Zarr group or actual image data
    :type intensity_image: Union[str, NDArray]
    :param n_jobs: Number of parallel jobs for processing frames (-1 uses all available cores)
    :type n_jobs: int
    :param overwrite: Whether to overwrite existing results
    :type overwrite: bool
    :param verbose: Enable verbose output during processing
    :type verbose: bool
    :param kwargs: Additional keyword arguments for property calculations.

    :return: The input ``animals`` as a list (the computed properties are written into each animal's zarr store)
    :rtype: List[Union[str, zarr.Group]]

    :raises KeyError: If specified intensity image is not found in Zarr group
    :raises ValueError: If analysis_type is invalid

    **Example:**

    .. code-block:: python

        # Basic usage with default properties
        animal = analyze_labels("path/to/zarr", dimension="D2")

        # Custom property analysis
        def custom_prop(regionprop):
            return regionprop.area * 2

        animal = analyze_labels(
            "path/to/zarr",
            properties=["area", "centroid"],
            user_properties=[custom_prop],
            user_properties_dtypes=[np.float32],
            user_properties_shapes=[(1,)],
            dimension="D2"
        )

    """

    # Set up warning handling based on verbose flag
    if not verbose:
        warnings.filterwarnings("ignore")

    if not isinstance(properties, list):
        properties = [properties]
    if not isinstance(animals, list):
        animals = [animals]

    # centroid and coords are used by the other functions later so are added to the properties
    properties = list(set(properties) | set(("area", "centroid", "coords", "contours")))
    # create a list containing the names of the properties to compute
    selected_properties = properties + [func.__name__ for func in user_properties]
    if "outline_external_extension" not in kwargs:
        dilation_value = 2
    else:
        dilation_value = max(2, kwargs["outline_external_extension"])
    for animal in animals:
        if isinstance(animal, (str, pathlib.Path)):
            animal = zarr.open_group(str(animal), "a")
        # set a spacing when pixels are anisotropic.
        if dimension == "D3":
            if "zscale" in animal.attrs:
                spacing = (animal.attrs["zscale"], 1, 1)
            else:
                spacing = (2.31, 1, 1)
        else:
            spacing = None
        # change the newly defined functions to properties
        custom_properties = [
            _function_to_property(extra_property)
            for extra_property in EXTRA_PROPERTIES_REGISTRY
        ]
        user_properties_partial = [
            _function_to_property(custom_property)
            for custom_property in user_properties
        ]
        custom_properties += user_properties_partial
        custom_properties_names = [func.func.__name__ for func in custom_properties]
        # the user_properties_shapes_dictionnary allow to know if a user property is channelized
        user_properties_shapes_dictionnary = {}
        for i in range(len(user_properties)):
            user_properties_shapes_dictionnary[user_properties[i].__name__] = (
                user_properties_shapes[i]
            )
        merged_shape_dictionnary = {
            **CUSTOM_PROPERTIES_SHAPE,
            **user_properties_shapes_dictionnary,
        }
        if intensity_image in animal.IMAGE.D2:
            nframes, nchannels = animal.IMAGE.D2[intensity_image].shape[:2]
        elif intensity_image in animal.IMAGE.D3:
            nframes, nchannels = animal.IMAGE.D3[intensity_image].shape[:2]
        else:
            raise KeyError("There is no intensity image in the animal")
        # replace 'dimension' and 'channels of the shapes by their actual vales
        shapes_dictionnary, dtypes_dictionnary = _get_shapes_dtypes(
            user_properties,
            user_properties_dtypes,
            user_properties_shapes,
            dimension=int(dimension[-1]),
            nchannels=nchannels,
            dimension2=int(dimension[-1]) ** 2,
            # skimage computes moments up to order 3, i.e. 4 coefficients along each spatial axis
            moment_axes=(4,) * int(dimension[-1]),
            bbox_length=2 * int(dimension[-1]),
            **kwargs,
        )
        analyze_label_per_frame_kwargs = {}
        group_key = grid_name if grid_name is not None else analysis_type.upper()
        if analysis_type in ["cell", "regions"]:
            backup_zarr = _create_dataset_inhomogeneous(
                animal,
                selected_properties,
                dimension,
                nframes,
                overwrite,
                merged_shape_dictionnary,
                name=group_key,
                nchannels=nchannels,
            )
        elif analysis_type == "eulerian":
            backup_zarr = _create_dataset_grid(
                animal,
                analysis_type,
                selected_properties,
                dimension,
                nframes,
                overwrite,
                merged_shape_dictionnary,
                shapes_dictionnary,
                dtypes_dictionnary,
                grid_name=grid_name,
            )
            analyze_label_per_frame_kwargs["mask_positions"] = (
                animal.GRID[group_key].GRID_PROPERTIES.mask_positions[:].flatten()
            )
        else:
            raise ValueError("analysis_type must be either cell or grid type")

        with _tqdm_joblib(tqdm(total=nframes, desc="Analyzing frames")):
            Parallel(n_jobs=n_jobs, backend=JOBLIB_BACKEND)(
                delayed(_analyze_labels_per_frame)(
                    animal,
                    analysis_type,
                    backup_zarr,
                    frame,
                    selected_properties,
                    dimension,
                    merged_shape_dictionnary,
                    shapes_dictionnary,
                    dtypes_dictionnary,
                    custom_properties,
                    custom_properties_names,
                    dilation_value,
                    spacing,
                    intensity_image,
                    overwrite,
                    verbose,
                    grid_name=grid_name,
                    **analyze_label_per_frame_kwargs,
                    **kwargs,
                )
                for frame in range(nframes)
            )

            _write_attrs_dataset(
                backup_zarr,
                selected_properties,
                merged_shape_dictionnary,
            )

    return animals


def _store_element(dataset: zarr.core.Array, index: Tuple[int, ...], value: NDArray) -> None:
    """Store ``value`` as a single element of an object dataset.

    Since zarr 2.18.0 an integer index along a size 1 dimension counts as a whole chunk
    replacement (zarr-python#1730). The property chunks hold a single element, so
    ``dataset[frame, channel] = value`` writes the items of ``value`` over the chunk instead
    of ``value`` itself, and the dataset can no longer be read back. Writing a chunk shaped
    holder through a slice selection stores the array as one object on every zarr version.
    """
    holder = np.empty((1,) * len(index), dtype=object)
    holder[(0,) * len(index)] = value
    dataset[tuple(slice(i, i + 1) for i in index)] = holder


def _analyze_labels_per_frame(
    animal: Union[zarr.Group, zarr.hierarchy.Group],
    analysis_type: Literal["cell", "regions", "eulerian"],
    backup_zarr: Union[zarr.Group, Dict[str, np.ndarray]],
    current_frame: int,
    selected_properties: List[str],
    dimension: str,
    merged_shape_dictionnary: Dict[str, Dict],
    shapes_dictionnary: Dict[str, Tuple[int, ...]],
    dtypes_dictionnary: Dict[str, np.dtype],
    custom_properties: List[Callable],
    custom_properties_names: List[str],
    dilation_value: int,
    spacing: Tuple[float, ...],
    intensity_image: Union[NDArray, str],
    overwrite: bool,
    verbose: bool = False,
    grid_name: str = None,
    **kwargs,
) -> None:
    """
    Analyzes segmented images stored in a Zarr group on a per-frame basis, computing specified properties.

    :param animal: The Zarr group containing segmented image data.
    :type animal: Union[zarr.Group, zarr.hierarchy.Group]
    :param analysis_type: The type of analysis to perform. Options are "cell" for segmented regions,
                          "regions" for regions, or "eulerian" for grid-based analysis.
    :type analysis_type: Literal["cell", "regions", "eulerian"]
    :param backup_zarr: The Zarr group where analysis backups are stored.
    :type backup_zarr: zarr.Group
    :param current_frame: The index of the current frame to analyze.
    :type current_frame: int
    :param selected_properties: The list of properties to compute for each segment.
    :type selected_properties: List[str]
    :param dimension: The dimensionality of the image data ("D2" or "D3").
    :type dimension: str
    :param merged_shape_dictionnary: A dictionary containing the shapes of merged properties, used to check
                                     if the property is channelized.
    :type merged_shape_dictionnary: Dict[str, Dict]
    :param shapes_dictionnary: A dictionary mapping property names to their corresponding shapes.
    :type shapes_dictionnary: Dict[str, Tuple[int, ...]]
    :param dtypes_dictionnary: A dictionary mapping property names to their corresponding data types.
    :type dtypes_dictionnary: Dict[str, np.dtype]
    :param custom_properties: List of custom property functions to compute additional features for each segment.
    :type custom_properties: List[Callable]
    :param custom_properties_names: Names of the custom properties.
    :type custom_properties_names: List[str]
    :param dilation_value: Dilation value for expanding regions before analysis.
    :type dilation_value: int
    :param spacing: The spacing values for anisotropic pixels (for 3D data).
    :type spacing: Tuple[float, ...]
    :param intensity_image: The intensity image used for analysis, either as an array or a string specifying
                            its location in the Zarr hierarchy.
    :type intensity_image: Union[NDArray, str]
    :param overwrite: If True, existing results are overwritten; otherwise, existing results are preserved.
    :type overwrite: bool
    :param verbose: If True, enables verbose output during processing. Default is False.
    :type verbose: bool
    :return: None. Updates the Zarr group `backup_zarr` with computed properties.
    :rtype: None
    """

    # load the intensity image only once
    if not isinstance(intensity_image, str):
        intensity_image = moveaxis(intensity_image[current_frame], 0, -1)
    else:
        intensity_image = moveaxis(
            animal.IMAGE[dimension][intensity_image][current_frame], 0, -1
        )
    custom_properties = set_data_properties(
        animal,
        current_frame,
        selected_properties,
        custom_properties_names,
        custom_properties,
        intensity_image,
        kwargs,
    )
    _set_extra_properties(
        extra_props=custom_properties,
        props_names=custom_properties_names,
        animal=animal,
        frame=current_frame,
    )

    objects_type = "from_label"
    if analysis_type == "regions" and "region" in animal.IMAGE[dimension]:
        label_image = animal.IMAGE[dimension].region[current_frame]

    elif "label" in animal.IMAGE[dimension]:
        label_image = animal.IMAGE[dimension].label[current_frame]
    else:
        label_image = zeros(intensity_image.shape[:-1], np.uint8)

    if analysis_type == "cell":
        objects = ndi.find_objects(label_image)
    elif analysis_type == "regions":
        if "initial_coords" not in animal.REGIONS.D2:
            objects = ndi.find_objects(label_image)
        elif "initial_coords" in animal.REGIONS.D2:
            objects = animal.REGIONS.D2.initial_coords[current_frame]
            objects_type = "from_coords"
    else:
        grid_shape = backup_zarr[selected_properties[0]].shape[2:4]
        # create linearized backups for grid compartement analysis
        backup_shape = np.prod(array(list(grid_shape))) + 1
        # The objects contains directly the pixels forming the region, no need to go from a label.
        # It is usefull here cause the objects are overlapping while the labels can't

        if analysis_type == "eulerian":
            objects = kwargs["mask_positions"]
        else:
            objects = (
                animal.GRID[grid_name if grid_name is not None else analysis_type.upper()]
                .GRID_PROPERTIES.lagrangian_grid[current_frame]
                .flatten()
            )
        objects_type = "from_coords"
    region_properties = _analyze_regions(
        label_image,
        objects=objects,
        objects_type=objects_type,
        intensity_image=intensity_image,
        extension_value=dilation_value,
        spacing=spacing,
    )
    # create an emmpty cell for the background as well
    if analysis_type == "cell" or analysis_type == "regions":
        if len(region_properties) > 0:
            backup_shape = region_properties[-1].label + 1
        else:
            backup_shape = 1

    # Update the CELL back_ups for all the properties
    for prop in selected_properties:
        if overwrite or "channels" not in backup_zarr[prop].attrs:
            # update the backup if it is not filled yet

            # create an empty backup with the correct shape and dtype specified by the property
            # the property of the cell a is backup_prop[a]
            # if 0 in shape, it is an unhomogeneous object array

            if 0 in shapes_dictionnary[prop]:
                backup_prop = [
                    zeros(
                        shapes_dictionnary[prop],
                        dtype=dtypes_dictionnary[prop],
                    )
                    for _ in range(backup_shape)
                ]
                # Since the array is unhomogeneous, the dtype needs to be always changed
                for reg_prop in region_properties:
                    backup_prop[reg_prop.label] = (
                        reg_prop[prop].astype(dtypes_dictionnary[prop])
                        if not isinstance(reg_prop[prop], dict)
                        else reg_prop[prop]
                    )
                backup_prop = array(backup_prop, dtype=object)

            else:
                backup_prop = np.full(
                    (
                        backup_shape,  # backup shape is y,x for grids and n_cells or n_regions
                        *shapes_dictionnary[prop],  # dimension of the property
                    ),
                    np.nan,
                    dtype=(
                        dtypes_dictionnary[prop]
                        if np.issubdtype(dtypes_dictionnary[prop], np.floating)
                        else np.float16
                    ),
                )
                for reg_prop in region_properties:
                    backup_prop[reg_prop.label] = reg_prop[prop]

                # the channel axis, last when the property is channelized, becomes the leading one
                if "nchannels" in merged_shape_dictionnary[prop]:
                    backup_prop = moveaxis(backup_prop, -1, 0)
                else:
                    backup_prop = backup_prop[newaxis]
                if backup_prop.ndim == 2:
                    # scalar property, it still needs the dimension of the prop
                    backup_prop = backup_prop[..., newaxis]

            # loop over the grid compartment and restore the 2D shape of the grid
            if analysis_type == "eulerian":
                if 0 in shapes_dictionnary[prop]:
                    backup_prop = backup_prop[1:].reshape(
                        1, *grid_shape, *backup_prop.shape[1:]
                    )
                else:
                    backup_prop = backup_prop[:, 1:].reshape(
                        backup_prop.shape[0], *grid_shape, *backup_prop.shape[2:]
                    )

            # grids hold one object per compartment, cells and regions one array per frame
            if 0 in shapes_dictionnary[prop]:
                if analysis_type == "eulerian":
                    backup_zarr[prop][current_frame] = backup_prop
                else:
                    _store_element(backup_zarr[prop], (current_frame,), backup_prop)
                continue
            for channel in range(backup_prop.shape[0]):
                if analysis_type == "eulerian":
                    backup_zarr[prop][current_frame, channel] = backup_prop[channel]
                else:
                    _store_element(
                        backup_zarr[prop], (current_frame, channel), backup_prop[channel]
                    )

        else:
            _vprint(
                f"Property {prop} already exists, skipping property computation",
                verbose,
            )


def discover_properties(regex_filter: str = None) -> None:
    """
    Compiles and formats a comprehensive list of image properties, categorized into extra or base properties.

    Each property is listed with its name, type (extra or base), and a brief description. For extra
    properties, the description is extracted from the function's docstring. For base properties, a generic description
    is provided, indicating that they are standard properties calculated by `skimage.measure.regionprops`.

    Args:
        regex_filter (str, optional): A regular expression pattern to filter properties by name.

    Returns:
        None: The formatted property listing (sections for base and extra properties,
            each with name and description) is printed to stdout.

    Example::

        >>> discover_properties('centroid')
        Properties Discovery:

        Base Properties:
        - centroid
          Description: The centroid of the region.

        Extra Properties:
        - centroid_distance (Type: extra)
          Description: Computes the distance to the centroid.

    Notes:
        - The function relies on the `base_property_registry` and `extra_properties_registry` to
          compile the list of properties.
        - Extra properties descriptions are fetched from their function docstrings, while base
          properties have a generic description or are retrieved from the function documentation.
    """
    discovery_info: str = "Properties Discovery:\n\n"

    # Base Properties
    discovery_info += "Base Properties:\n"
    for name in BASE_PROPERTY_REGISTRY:
        # Attempt to fetch the docstring for base properties
        base_func = getattr(_RegionProperties, name, None)
        if base_func:
            docstring_base = (
                inspect.getdoc(base_func)
                or "Standard property calculated by skimage.measure.regionprops."
            )
        else:
            docstring_base = (
                "Standard property calculated by skimage.measure.regionprops."
            )

        # Check if the property name matches the regex filter
        if regex_filter is None or re.search(regex_filter, name):
            discovery_info += f"- {name}\n  Description: {docstring_base}\n\n"

    # Extra Properties
    discovery_info += "Extra Properties:\n"
    for func in EXTRA_PROPERTIES_REGISTRY:
        docstring_extra: str = inspect.getdoc(func) or "No documentation available."

        # Check if the function name matches the regex filter
        if regex_filter is None or re.search(regex_filter, func.__name__):
            discovery_info += (
                f"- {func.__name__} (Type: extra)\n  Description: {docstring_extra}\n\n"
            )

    print(discovery_info)


def _analyze_regions(
    label_image: NDArray,
    objects: NDArray = None,
    objects_type: Literal["from_label", "from_coords"] = "cell",
    intensity_image: NDArray = None,
    cache: bool = True,
    *,
    spacing: Tuple[float] = None,
    offset: Tuple[float] = None,
    extension_value: int = 1,
) -> List[_RegionProperties]:
    """
    Analyzes properties of labeled regions, allowing for extra properties.
    This function merges the functionality of `_cellprops` and `_object_properties`.

    :param label_image: An integer array where each unique label denotes a different region.
    :type label_image: NDArray
    :param objects: An array of object coordinates or slices for region extraction, defaults to None.
    :type objects: NDArray, optional
    :param analysis_type: Type of analysis, "cell" for cell-based analysis, or various grid-based options, defaults to "cell".
    :type analysis_type: str, optional
    :param intensity_image: An array of the same shape as `label_image` used for intensity measurements, defaults to None.
    :type intensity_image: NDArray, optional
    :param cache: Whether to cache properties for faster access, defaults to True.
    :type cache: bool, optional
    :param spacing: The physical spacing between pixels in each dimension, defaults to None.
    :type spacing: Tuple[float], optional
    :param offset: The physical offset of the image origin from the coordinate origin, defaults to None.
    :type offset: Tuple[float], optional
    :param extension_value: The number of pixels to extend the bounding box of each region, defaults to 1.
    :type extension_value: int, optional
    :raises TypeError: If the image is not of integer type or is of unsupported dimensionality.
    :raises ValueError: If the `offset` is not compatible with the image dimensions.
    :returns: A list of `_RegionProperties` objects containing the analyzed region properties.
    :rtype: List[_RegionProperties]
    """

    if label_image.ndim not in (2, 3):
        raise TypeError("Only 2-D and 3-D images supported.")
    if not np.issubdtype(label_image.dtype, np.integer):
        if np.issubdtype(label_image.dtype, bool):
            raise TypeError(
                "Non-integer image types are ambiguous: "
                "use skimage.measure.label to label the connected "
                "components of label_image, "
                "or label_image.astype(np.uint8) to interpret "
                "the True values as a single label."
            )
        else:
            raise TypeError("Non-integer label_image types are ambiguous")

    if offset is None:
        offset_arr = np.zeros((label_image.ndim,), dtype=int)
    else:
        offset_arr = np.asarray(offset)
        if offset_arr.ndim != 1 or offset_arr.size != label_image.ndim:
            raise ValueError(
                "Offset should be an array-like of integers "
                "of shape (label_image.ndim,); "
                f"{offset} was provided."
            )

    # find objects with the labelled image for the cells
    regions = []
    for i, obj in enumerate(objects):
        if not np.any(obj):
            continue
        if objects_type == "from_coords":
            # find the bounding boxes of the grid compartments
            obj_coords = np.array(obj).T
            mins = np.min(obj_coords, axis=0)
            maxs = np.max(obj_coords, axis=0)
            obj = tuple((slice(mins[j], maxs[j] + 1) for j in range(mins.shape[0])))

        # the label of the first cell or grid compartment is 1, not 0
        label = i + 1
        extended_slice = _extend_slices(
            obj, label_image.shape, extension_value=extension_value
        )
        effective_low_extension = np.array(
            [s.start - max(0, s.start - extension_value) for s in obj]
        )

        props = _RegionProperties(
            extended_slice,
            label,
            label_image,
            intensity_image,
            cache,
            spacing=spacing,
            offset=offset_arr,
        )

        if objects_type == "from_coords":
            # create a boolean image in the bounding box studied of where the object is present.
            # This is what is used for most regionprops properties. It is usually deduced from the
            # label while here it is given
            start_coords = np.array([sli.start for sli in extended_slice])
            stop_coords = np.array([sli.stop for sli in extended_slice])
            image = np.zeros((stop_coords - start_coords), bool)
            image[
                tuple(
                    obj_coords.T
                    - mins[:, np.newaxis]
                    + effective_low_extension[:, np.newaxis]
                )
            ] = True
            props.image = image
        elif objects_type == "from_label":
            props.image = label_image[extended_slice] == label
        regions.append(props)
    return regions


def _set_extra_properties(
    animal: Union[zarr.Group, zarr.hierarchy.Group],
    frame: int,
    extra_props: List[Callable],
    props_names: List[str],
) -> _RegionProperties:
    """
    Set extra properties as attributes of the `_RegionProperties` object using property decorators.

    :param animal: The zarr group representing the analyzed animal.
    :type animal: Union[zarr.Group, zarr.hierarchy.Group]
    :param frame: The current frame number for the analysis.
    :type frame: int
    :param extra_props: List of functions that define additional region properties.
    :type extra_props: List[Callable]
    :param props_names: List of names corresponding to the extra properties.
    :type props_names: List[str]
    :returns: The modified `_RegionProperties` class with added custom properties.
    :rtype: _RegionProperties
    """

    _RegionProperties.frame = frame
    _RegionProperties.animal = animal
    for func, name in zip(extra_props, props_names):
        setattr(_RegionProperties, name, property_decorator(func))
    return _RegionProperties


def _resolve_shape(shape: Tuple, animal_parameters: dict) -> Tuple[int, ...]:
    """Replace the tokens of a declared per-cell shape by their animal values.

    A token bound to a tuple (``moment_axes``) is spliced in, so it can span several axes.
    """
    resolved = []
    for shape_dim in shape:
        value = animal_parameters.get(shape_dim, shape_dim)
        if isinstance(value, tuple):
            resolved.extend(value)
        else:
            resolved.append(value)
    return tuple(resolved)


def _get_shapes_dtypes(
    user_properties: Union[Callable, List[Callable]] = [],
    user_properties_dtypes: Union[np.dtype, List[np.dtype]] = [],
    user_properties_shapes: Union[Tuple, List[Tuple]] = [],
    **kwargs,
) -> Tuple[dict, dict]:
    """
    Generate dictionaries of shapes and data types for properties, considering user-defined parameters.

    :param user_properties: User-defined functions representing additional properties, defaults to an empty list.
    :type user_properties: Union[Callable, List[Callable]], optional
    :param user_properties_dtypes: Data types for user-defined properties, defaults to an empty list.
    :type user_properties_dtypes: Union[np.dtype, List[np.dtype]], optional
    :param user_properties_shapes: Shapes for user-defined properties, defaults to an empty list.
    :type user_properties_shapes: Union[Tuple, List[Tuple]], optional
    :param kwargs: Additional parameters such as number of channels or analysis dimension.
    :type kwargs: dict
    :returns: Two dictionaries mapping property names to their shapes and data types.
    :rtype: Tuple[dict, dict]
    """

    if not isinstance(user_properties, list):
        user_properties = [user_properties]
    if not isinstance(user_properties_dtypes, list):
        user_properties_dtypes = [user_properties_dtypes]
    if not isinstance(user_properties_shapes, list):
        user_properties_shapes = [user_properties_shapes]

    shapes_dictionnary = CUSTOM_PROPERTIES_SHAPE.copy()
    dtypes_dictionnary = CUSTOM_PROPERTIES_DTYPE.copy()

    # animal_parameters contains all the values to replace in the shapes dictionnary
    animal_parameters = {}
    for kwarg_name, kwarg_value in kwargs.items():
        animal_parameters[kwarg_name] = kwarg_value
    for prop in shapes_dictionnary.keys():
        shapes_dictionnary[prop] = _resolve_shape(
            shapes_dictionnary[prop], animal_parameters
        )
    for i in range(len(user_properties)):
        shapes_dictionnary[user_properties[i].__name__] = _resolve_shape(
            user_properties_shapes[i], animal_parameters
        )
        dtypes_dictionnary[user_properties[i].__name__] = user_properties_dtypes[i]

    return shapes_dictionnary, dtypes_dictionnary


def _create_dataset_inhomogeneous(
    animal: Union[str, zarr.Group, zarr.hierarchy.Group],
    selected_properties: List[str],
    dimension: str,
    nframes: int,
    overwrite: bool,
    merged_shape_dictionnary: dict,
    name="CELL",
    nchannels: int = 1,
) -> zarr.Group:
    """
    Create Zarr datasets to store computed properties for cells.

    :param animal: The Zarr group where the datasets are created.
    :type animal: Union[str, zarr.Group, zarr.hierarchy.Group]
    :param selected_properties: Names of properties for analysis.
    :type selected_properties: List[str]
    :param dimension: The dimension for analysis, affecting storage location.
    :type dimension: str
    :param nframes: The number of frames in the analysis, determining dataset size.
    :type nframes: int
    :param overwrite: Whether to overwrite existing datasets with new analysis results, defaults to True.
    :type overwrite: bool
    :param merged_shape_dictionnary: Dictionary mapping properties to their shapes, used to identify channelized properties.
    :type merged_shape_dictionnary: dict
    :returns: The group where the datasets are created.
    :rtype: zarr.Group
    """
    animal.require_group(name)
    animal[name].require_group(dimension)
    for prop in selected_properties:
        if overwrite or prop not in animal[name][dimension]:
            if 0 in merged_shape_dictionnary[prop]:
                animal[name][dimension].create_dataset(
                    prop,
                    shape=(nframes),
                    dtype=object,
                    object_codec=zarr.codecs.Pickle(),
                    chunks=1,
                    overwrite=True,
                )
            else:
                channel = nchannels if "nchannels" in merged_shape_dictionnary[prop] else 1
                animal[name][dimension].create_dataset(
                    prop,
                    shape=(nframes, channel),
                    dtype=object,
                    object_codec=zarr.codecs.Pickle(),
                    chunks=(1, 1),
                    overwrite=True,
                )
    return animal[name][dimension]


def _create_dataset_grid(
    animal: Union[str, zarr.Group, zarr.hierarchy.Group],
    analysis_type: str,
    selected_properties: List[str],
    dimension: str,
    nframes: int,
    overwrite: bool,
    merged_shape_dictionnary: dict,
    shapes_dictionnary: dict,
    dtypes_dictionnary: dict,
    grid_name: str = None,
) -> zarr.Group:
    """
    Create Zarr datasets for storing properties related to grid compartments.

    :param animal: The Zarr group where the datasets are created.
    :type animal: Union[str, zarr.Group, zarr.hierarchy.Group]
    :param analysis_type: The grid analysis type.
    :type analysis_type: str
    :param selected_properties: List of property names for analysis.
    :type selected_properties: List[str]
    :param dimension: Dimension used in the analysis to determine storage.
    :type dimension: str
    :param nframes: Number of frames for the analysis.
    :type nframes: int
    :param overwrite: Flag for overwriting existing data, defaults to True.
    :type overwrite: bool
    :param merged_shape_dictionnary: Merged shape information for properties.
    :type merged_shape_dictionnary: dict
    :param shapes_dictionnary: Dictionary containing shape information for properties.
    :type shapes_dictionnary: dict
    :param dtypes_dictionnary: Dictionary containing data type information for properties.
    :type dtypes_dictionnary: dict
    :returns: Group with newly created datasets.
    :rtype: zarr.Group
    """

    group_key = grid_name if grid_name is not None else analysis_type.upper()
    animal.require_group("GRID")
    animal.GRID.require_group(group_key)
    animal.GRID[group_key].require_group(dimension)
    grid_shape = animal.GRID[group_key].GRID_PROPERTIES.lagrangian_grid.shape[-2:]
    for prop in selected_properties:
        if overwrite or prop not in animal.GRID[group_key][dimension]:
            # 0 are for properties of dtype object
            if 0 in shapes_dictionnary[prop]:
                animal.GRID[group_key][dimension].create_dataset(
                    prop,
                    shape=(nframes, 1, *grid_shape),
                    dtype=object,
                    chunks=(1, 1, *grid_shape),
                    overwrite=True,
                    object_codec=zarr.codecs.Pickle(),
                )
            else:
                # change the position of the channel
                if "nchannels" in merged_shape_dictionnary[prop]:
                    quantity_shape = (
                        shapes_dictionnary[prop][:-1]
                        if len(shapes_dictionnary[prop]) > 1
                        else (1,)
                    )
                    shape = (
                        nframes,
                        shapes_dictionnary[prop][-1],
                        *grid_shape,
                        *quantity_shape,
                    )
                else:
                    quantity_shape = (
                        shapes_dictionnary[prop]
                        if len(shapes_dictionnary[prop]) > 0
                        else (1,)
                    )
                    shape = (nframes, 1, *grid_shape, *quantity_shape)

                animal.GRID[group_key][dimension].create_dataset(
                    prop,
                    shape=shape,
                    dtype=(
                        dtypes_dictionnary[prop]
                        if np.issubdtype(dtypes_dictionnary[prop], np.floating)
                        else np.float16
                    ),
                    chunks=(1, 1, *shape[2:]),
                    overwrite=True,
                )

    return animal.GRID[group_key][dimension]


def _write_attrs_dataset(
    backup_zarr: Union[str, zarr.Group, zarr.hierarchy.Group],
    selected_properties: List[str],
    merged_shape_dictionnary: dict,
):
    """
    Add necessary attributes to datasets in the Zarr group based on property shape information.

    :param backup_zarr: Zarr group where datasets are stored.
    :type backup_zarr: Union[str, zarr.Group, zarr.hierarchy.Group]
    :param selected_properties: List of property names for analysis.
    :type selected_properties: List[str]
    :param merged_shape_dictionnary: Shape information to determine if a property is channelized.
    :type merged_shape_dictionnary: dict
    :returns: None
    :rtype: None
    """

    for prop in selected_properties:
        if "channels" not in backup_zarr[prop].attrs:
            backup_zarr[prop].attrs["channels"] = (
                "nchannels" in merged_shape_dictionnary[prop]
            )
