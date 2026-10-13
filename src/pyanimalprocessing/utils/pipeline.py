"""Low-level helpers shared by the registration / label-analysis / averaging
pipeline: slice extension, custom-property machinery, and polygon area.
"""

import inspect
from functools import partial
from typing import Callable, List, Tuple, Union

import numpy as np
from skimage.draw import polygon2mask


def _extend_slices(
    slices: Tuple[slice], shape: Tuple[int], extension_value: int = 1
) -> Tuple[slice]:
    """Grow each slice by ``extension_value`` pixels, clamped to ``shape`` (neighbour access)."""
    return tuple(
        slice(max(0, s.start - extension_value), min(shape[i], s.stop + extension_value))
        for i, s in enumerate(slices)
    )


def set_data_properties(
    animal,
    current_frame,
    selected_properties,
    custom_properties_names,
    custom_properties,
    intensity_image,
    kwargs_analyze_labels,
):
    """Bind per-frame data arguments onto the custom-property callables for this frame."""
    function_kwargs_map = {}
    for key, element in kwargs_analyze_labels.items():
        if key[-5:] == "_data":
            matchs = np.array([prop in key for prop in selected_properties])
            for prop in np.array(selected_properties)[matchs]:
                # arg must be "<propname>_<argname>_data"; strip the leading propname.
                function_kwargs_map[prop] = {
                    prop.join(key.split(prop)[1:])[1:]: element[current_frame]
                }

    new_custom_properties = []
    for i in range(len(custom_properties_names)):
        property_kwargs = function_kwargs_map.get(custom_properties_names[i], {})
        new_custom_properties.append(
            _function_to_property(custom_properties[i], **property_kwargs)
        )
    return new_custom_properties


def _function_to_property(func: Callable, **kwargs) -> partial:
    """Adapt ``func(regionprop, ...)`` into a skimage regionprops extra-property.

    The first parameter must be named ``regionprop``; the rest are fixed to their
    defaults (or to ``kwargs`` overrides).
    """
    sig = inspect.signature(func)
    params = list(sig.parameters.values())

    if params[0].name != "regionprop":
        raise ValueError("The first parameter must be named 'regionprop'.")

    params_defaults = {}
    for param in params[1:]:
        if param.name in kwargs:
            params_defaults[param.name] = kwargs[param.name]
        elif "data" not in param.name:
            params_defaults[param.name] = param.default
    for param in params[1:]:
        if param.name not in kwargs and param.default is inspect.Parameter.empty:
            raise ValueError(
                f"Parameter '{param.name}' must have a default value or be specified in kwargs."
            )

    return partial(func, **params_defaults)


def _smart_round(arr, fun=np.ceil, tol=1e-2):
    """Round to nearest integer when within ``tol``, else apply ``fun`` (default ceil)."""
    arr = np.asarray(arr)
    rounded = np.round(arr)
    return np.where(np.abs(arr - rounded) < tol, rounded, fun(arr).astype(int))


def _approximate_polygon_area(corners: Union[np.ndarray, List[List[float]]]) -> int:
    """Rasterize a polygon from its ``[y, x]`` corners and count the filled pixels."""
    rounded_corners = np.round(corners, decimals=2)
    min_y, min_x = np.min(rounded_corners, axis=0)
    max_y, max_x = np.max(rounded_corners, axis=0)
    dimensions = (int(max_y - min_y) + 1, int(max_x - min_x) + 1)
    adjusted_corners = rounded_corners - [min_y, min_x]
    return int(np.sum(polygon2mask(dimensions, adjusted_corners)))
