"""Extra region properties for :func:`analyze_labels`: cell outlines/cores and their
intensities, background intensity, intensity Fourier modes, and junctional polarity
measures, each registered via ``property_decorator``.
"""

from functools import wraps
from typing import Literal, Tuple, Union

import numpy as np
from numpy.typing import NDArray
from rasterio.features import shapes
from shapely import MultiPolygon
from shapely.geometry import shape
from pyanimalprocessing._regionprops_clone import _RegionProperties
from skimage.morphology import closing, dilation, erosion

# property utils


def _cached(f):
    """
    Decorator that caches the result of a function in the object's _cache dictionary.

    :param f: Function to cache
    :type f: callable
    :return: Wrapped function that checks/uses cache
    :rtype: callable
    """

    @wraps(f)
    def wrapper(obj):
        cache = obj._cache
        prop = f.__name__

        if not ((prop in cache) and obj._cache_active):
            cache[prop] = f(obj)

        return cache[prop]

    wrapper.__name__ = f.__name__

    return wrapper


def property_decorator(func):
    """
    Decorator that converts a function into a property.

    :param func: Function to convert to property
    :type func: callable
    :return: Property-decorated function
    :rtype: property
    :meta private:
    """

    @property
    @wraps(func)
    def wrapper(self):
        return func(self)

    return wrapper


def object_offset(regionprop: _RegionProperties) -> NDArray[np.int64]:
    """
    Get the starting offset for each dimension of the region.

    This function returns an array containing the starting positions for the region's slice in each
    dimension, providing the initial point for indexing or cropping operations.

    :param regionprop: Region properties object containing region information
    :type regionprop: _RegionProperties
    :return: Starting offsets for each dimension
    :rtype: NDArray[np.int64]
    """
    return np.array([regionprop.slice[i].start for i in range(regionprop._ndim)])


@_cached
def background(regionprop: _RegionProperties) -> NDArray[bool]:
    """
    Compute the background mask for the region.

    Uses morphological closing operations to identify background pixels. Returns a
    boolean array where True indicates background pixels.

    :param regionprop: Region properties object containing region information
    :type regionprop: _RegionProperties
    :return: Boolean mask identifying background pixels
    :rtype: NDArray[bool]
    """
    return closing(closing(regionprop._label_image[regionprop.slice])) == 0


def contours(regionprop: _RegionProperties) -> list[NDArray[np.float64]]:
    """
    Extract contour points from a labeled region mask using rasterization.

    This function converts the binary mask from a region properties object
    into a Shapely polygon (or MultiPolygon) and then returns the exterior coordinates of the contours.
    The mask is first processed with morphological closing to ensure connectivity.

    :param regionprop: Region properties object containing region information
    :type regionprop: _RegionProperties
    :return: List of arrays containing contour pixel coordinates
    :rtype: list[NDArray[np.float64]]
    """
    label_copy = regionprop.image.astype(np.uint8)  # Ensure correct data type
    label_copy = closing(label_copy)  # Close any small gaps in the mask
    contours_list = []
    object_offset = (
        np.array([regionprop.slice[i].start for i in range(regionprop._ndim)])
        + regionprop._offset
    )
    object_offset = object_offset[-2:]
    if regionprop.image.ndim > 2:
        label_copy = np.any(label_copy, axis=0).astype(np.uint8)
        mask = label_copy > 0
    else:
        mask = regionprop.image
    for geom, value in shapes(label_copy, mask=mask):  # Extract non-zero regions
        polygon = shape(geom)

        if isinstance(polygon, MultiPolygon):
            for sub_poly in polygon.geoms:
                if sub_poly.is_valid:
                    coords = np.array(sub_poly.exterior.coords)
                    # Swap x and y coordinates
                    coords = coords[:, ::-1]
                    contours_list.append(coords + object_offset)
                else:
                    coords = np.array(sub_poly.buffer(0).exterior.coords)
                    # Swap x and y coordinates
                    coords = coords[:, ::-1]
                    contours_list.append(
                        coords + object_offset
                    )  # Fix invalid polygons
        else:
            if polygon.is_valid:
                coords = np.array(polygon.exterior.coords)
                # Swap x and y coordinates
                coords = coords[:, ::-1]
                contours_list.append(coords + object_offset)
            else:
                coords = np.array(polygon.buffer(0).exterior.coords)
                # Swap x and y coordinates
                coords = coords[:, ::-1]
                contours_list.append(coords + object_offset)

    return np.array(contours_list, dtype=object)  # List of arrays (one per component)


def calculate_domain_avg_intensity(
    cell_outline_local: np.ndarray,
    centroid_local: np.ndarray,
    intensity_image: np.ndarray,
    number_of_domains: int,
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Calculate average intensity for angular domains around the cell.

    Divides the cell into angular domains centered at the centroid and computes
    the average intensity within each domain along the cell outline.

    :param cell_outline_local: Local coordinates of cell outline
    :type cell_outline_local: np.ndarray
    :param centroid_local: Local coordinates of cell centroid
    :type centroid_local: np.ndarray
    :param intensity_image: Image containing intensity values
    :type intensity_image: np.ndarray
    :param number_of_domains: Number of angular domains to create
    :type number_of_domains: int
    :return: Tuple of (domain average intensities, domain midpoint angles)
    :rtype: Tuple[np.ndarray, np.ndarray]
    """

    cell_outline_centered = cell_outline_local - centroid_local

    angles = np.arctan2(cell_outline_centered[:, 0], cell_outline_centered[:, 1])

    domain_angles = np.linspace(-np.pi, np.pi, number_of_domains + 1)
    domain_midpoints = (domain_angles[:-1] + domain_angles[1:]) / 2

    domain_avg_intensity = np.zeros((number_of_domains, intensity_image.shape[-1]))

    for i in range(number_of_domains):
        domain_mask = (angles >= domain_angles[i]) & (angles < domain_angles[i + 1])
        coords = cell_outline_local[domain_mask]
        if coords.size > 0:
            domain_intensities = intensity_image[tuple(coords.T)]
            domain_avg_intensity[i] = (
                np.nanmean(domain_intensities, axis=0)
                if domain_intensities.size
                else np.zeros(intensity_image.shape[-1])
            )

    return domain_avg_intensity, domain_midpoints


def cell_outline_local(
    regionprop: _RegionProperties,
    external_extension: int = 1,
    internal_extension: int = 1,
) -> NDArray[np.int64]:
    """Cell outline coordinates (local image space), the difference between a dilated and eroded mask."""
    outer_mask = regionprop.image.copy()
    for _ in range(external_extension):
        outer_mask = dilation(outer_mask)

    inner_mask = regionprop.image.copy()
    for _ in range(internal_extension):
        inner_mask = erosion(inner_mask)

    outline = outer_mask & ~inner_mask
    return np.array(np.where(outline)).T


def cell_core_local(regionprop: _RegionProperties, internal_extension: int = 1) -> np.ndarray:
    """Cell core coordinates (local image space) obtained by eroding the region mask."""
    inner_shell = erosion(regionprop.image)
    for _ in range(internal_extension - 1):
        inner_shell = erosion(inner_shell)
    return np.array(np.where(inner_shell)).T


def cell_core(regionprop: _RegionProperties) -> np.ndarray:
    """Cell core coordinates in the global image space."""
    offset = (
        np.array([regionprop.slice[i].start for i in range(regionprop._ndim)])
        + regionprop._offset
    )
    return cell_core_local(regionprop) + offset


def background_intensity(
    regionprop: _RegionProperties,
    background_intensity: Union[Literal["per_cell"], int] = 0,
) -> np.ndarray:
    """Per-channel background intensity: the cell-core mean when ``"per_cell"``, else a constant."""
    if isinstance(background_intensity, str) and background_intensity == "per_cell":
        background_intensity = np.nanmean(
            regionprop._intensity_image[tuple(cell_core(regionprop).T)], axis=0
        )
    if isinstance(background_intensity, (float, int)):
        background_intensity = np.array(
            [background_intensity] * regionprop._intensity_image.shape[-1]
        )
    return background_intensity


def intensity_fourier_modes(
    cell_outline_local: np.ndarray,
    centroid_local: np.ndarray,
    intensity_image: np.ndarray,
    slice_y: slice,
    slice_x: slice,
    background_intensity: NDArray[float] = 0,
):
    """First Fourier modes ``(A0, A1, B1, A2, B2)`` of the intensity distribution along the cell outline."""
    # Background subtraction can go negative, so widen unsigned dtypes to signed.
    dtype = intensity_image.dtype
    if np.issubdtype(dtype, np.unsignedinteger):
        bit_depth = np.iinfo(dtype).bits
        dtype = np.dtype(f"int{bit_depth * 2}" if bit_depth < 64 else "int64")

    sliced_intensity_image = intensity_image[slice_y, slice_x].astype(dtype)
    sliced_intensity_image = sliced_intensity_image - background_intensity

    number_of_domains = 18
    domain_avg_intensity, domain_midpoints = calculate_domain_avg_intensity(
        cell_outline_local, centroid_local, sliced_intensity_image, number_of_domains
    )

    dtheta = 2 * np.pi / number_of_domains
    A0 = np.mean(domain_avg_intensity, axis=0)
    A1 = (
        np.sum(domain_avg_intensity * np.cos(domain_midpoints)[..., np.newaxis], axis=0)
        * dtheta
        * (1 / np.pi)
    )
    B1 = (
        np.sum(domain_avg_intensity * np.sin(domain_midpoints)[..., np.newaxis], axis=0)
        * dtheta
        * (1 / np.pi)
    )
    A2 = (
        np.sum(
            domain_avg_intensity * np.cos(2 * domain_midpoints)[..., np.newaxis], axis=0
        )
        * dtheta
        * (1 / np.pi)
    )
    B2 = (
        np.sum(
            domain_avg_intensity * np.sin(2 * domain_midpoints)[..., np.newaxis], axis=0
        )
        * dtheta
        * (1 / np.pi)
    )
    return A0, A1, B1, A2, B2


def axial_polarity(regionprop: _RegionProperties) -> np.ndarray:
    """Nematic (axial) polarity tensor ``1/2 [A0-A2, B2, B2, A0+A2]`` from outline-intensity Fourier modes.

    See *PTEN Controls Junction Lengthening and Stability during Cell Rearrangement in Epithelial Tissue*.
    """
    A0, _, _, A2, B2 = intensity_fourier_modes(
        cell_outline_local(regionprop),
        regionprop.centroid_local,
        regionprop._intensity_image,
        regionprop.slice[0],
        regionprop.slice[1],
        background_intensity(regionprop),
    )
    return 1 / 2 * np.array([A0 - A2, B2, B2, A0 + A2])


def directional_polarity(regionprop: _RegionProperties) -> np.ndarray:
    """Directional (vectorial) polarity ``[B1, A1]`` from outline-intensity Fourier modes."""
    _, A1, B1, _, _ = intensity_fourier_modes(
        cell_outline_local(regionprop),
        regionprop.centroid_local,
        regionprop._intensity_image,
        regionprop.slice[0],
        regionprop.slice[1],
        background_intensity(regionprop),
    )
    return np.array([B1, A1])


def weighted_directional_polarity(regionprop: _RegionProperties) -> np.ndarray:
    """Intensity-weighted polarity vector ``(y, x)`` per channel, pointing toward the strongest-signal domain."""
    number_of_domains = 6

    dtype = regionprop._intensity_image.dtype
    if np.issubdtype(dtype, np.unsignedinteger):
        bit_depth = np.iinfo(dtype).bits
        dtype = np.dtype(f"int{bit_depth * 2}" if bit_depth < 64 else "int64")

    sliced_intensity = (
        regionprop._intensity_image[regionprop.slice[0], regionprop.slice[1]].astype(dtype)
        - background_intensity(regionprop)
    )

    domain_avg_intensity, domain_midpoints = calculate_domain_avg_intensity(
        cell_outline_local(regionprop),
        regionprop.centroid_local,
        sliced_intensity,
        number_of_domains,
    )

    unit_vec_y = np.sin(domain_midpoints)
    unit_vec_x = np.cos(domain_midpoints)
    vec_y = np.sum(domain_avg_intensity * unit_vec_y[:, None], axis=0)
    vec_x = np.sum(domain_avg_intensity * unit_vec_x[:, None], axis=0)
    return np.array([vec_y, vec_x])