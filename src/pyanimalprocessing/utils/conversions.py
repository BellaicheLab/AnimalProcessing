"""MATLAB data format conversion, array harmonization, and segmentation utilities."""

import re

import numpy as np
from scipy.io.matlab import mat_struct

MAPPING_KEY = {
    "xyStart": ["xStart", "yStart"],
    "xywh": ["xStart", "yStart", "boxWidth", "boxHeight"],
    "Coordinates": ["grid_xStart", "grid_yStart"],
    "FrameArray": ["FrameArray"],
    "TimeArray": ["TimeArray"],
    "Size": ["Size"],
    "ULCs": ["ULCs"],
    "signalName": ["channels"],
}


QUANTITIES_ATTRIBUTES = [
    "xywh",
    "Overlap",
    "Coordinates",
    "TimeArray",
    "FrameArray",
    "Size",
    "ULCs",
]


def _format_n_decimals(num, n=4):
    # Calculate the maximum number that can be formatted
    max_value = int("9" * n)
    if 0 <= num <= max_value:
        # Create the dynamic format string
        format_string = "{:0" + str(n) + "}"
        return format_string.format(num)
    else:
        raise ValueError(
            f"Number out of range. Please provide a number between 0 and {max_value}."
        )


def _format_xyStart_values(value):
    """
    Parse and format 'xyStart' values from a given string.

    Parameters
    ----------
    value : str
        The string containing 'xyStart' values.

    Returns
    -------
    list
        A list of two integers representing 'xStart' and 'yStart'.
        If the value is not valid, returns [None, None].

    Notes
    -----
    The input string is expected to be enclosed in brackets and the values can be separated either by a comma or space.
    """
    values = []
    # Check if the string between brackets is not empty
    if value[1:-1].strip():
        # Split the values based on either comma or space
        if "," in value[1:-1]:
            value = [x for x in value[1:-1].split(",")]
        elif " " in value[1:-1]:
            value = [x for x in value[1:-1].split(" ")]

        # Append integer values for xStart and yStart
        values.append(str(float(value[0])))
        values.append(str(float(value[1])))
    else:
        # Append None values if the string is invalid
        values.append(None)
        values.append(None)
    return values


def _convert_coordinates_to_numpy(coordinates_matlab):
    """
    Converts a 2D MATLAB array of coordinates into a 3D NumPy array.

    The function reshapes the original MATLAB array, transposes it to match NumPy's indexing order,
    and returns the transformed array.

    Parameters
    ----------
    coordinates_matlab : np.array
        The 2D MATLAB array to be converted. It should be of shape (w, h) where w and h represent width and height respectively.

    Returns
    -------
    coordinates_numpy : np.array
        The converted 3D NumPy array. It is of shape (2, w, h) where 2 represents the x and y coordinates.

    Notes
    -----
    This function is specifically designed to work with a 2D array of coordinates from MATLAB. The input is assumed
    to have a specific structure (array of arrays of coordinates). Deviations from this structure may result in unexpected outcomes.
    """
    # Calculate the dimensions based on the input
    w, h = coordinates_matlab.shape

    # Convert the array of arrays to a 3D numpy array
    coordinates_numpy = np.array(
        [coordinate for row in coordinates_matlab for coordinate in row]
    )

    # Reshape the 3D array to the original shape (w, h, 2)
    coordinates_numpy = coordinates_numpy.reshape(w, h, 2)

    # Transpose the axes to get the desired shape (2, w, h)
    coordinates_numpy = np.transpose(coordinates_numpy, (2, 0, 1))

    return coordinates_numpy


def _format_coordinates_values(coordinates):
    """
    Extract the coordinates where all values are zero.

    Parameters
    ----------
    coordinates : numpy.ndarray
        The array containing coordinate information.

    Returns
    -------
    list
        A list of two integers representing the coordinates where all values are zero.

    Notes
    -----
    This function assumes that the array is transformed into a NumPy array before being passed in.
    """
    values = []
    # Convert coordinates to NumPy array

    coordinates = _convert_coordinates_to_numpy(coordinates)

    # Find the indices where all elements along the axis are zero
    indices = np.all(coordinates == 0, axis=0)
    y, x = np.where(indices)

    try:
        values.append(int(x[0]))
        values.append(int(y[0]))
    except:
        values.append(30)
        values.append(15)
    return values


def _format_frame_array_values(frame_array):
    """
    Format a frame array based on its dimensionality.

    Parameters
    ----------
    frame_array : numpy.ndarray
        The array containing frames.

    Returns
    -------
    list
        A list containing the formatted frame array.
    """
    values = []
    if frame_array.ndim == 1:
        values.append(list(frame_array))
    else:
        values.append([list(frames) for frames in frame_array])
    return values


def _format_ucl_array_values(ucls_array):
    """
    Format a ucls array based on its dimensionality.

    Parameters
    ----------
    ucls_array : numpy.ndarray
        The array containing uclss.

    Returns
    -------
    list
        A list containing the formatted ucls array.
    """
    ucls_array = ucls_array.flatten()
    values = [list(sublist) for sublist in ucls_array]
    return values


def _format_xywh_values(xywh_array):
    return xywh_array.tolist()


def _format_time_array_values(time_array):
    """
    Format a time array into a list of string pairs.

    Parameters
    ----------
    time_array : numpy.ndarray
        The array containing time values.

    Returns
    -------
    list
        A list containing pairs of strings representing time values.
    """
    values = []
    time_list = [[str(time_arr[0]), str(time_arr[1])] for time_arr in time_array]
    values.append(time_list)
    return values


def _format_values(key, value):
    """
    Format values based on their key.

    Parameters
    ----------
    key : str
        The key representing the type of value.
    value : various
        The value to be formatted.

    Returns
    -------
    list
        A list containing the formatted value(s).

    Notes
    -----
    This function acts as a dispatcher that calls the appropriate function to format the value based on its key.
    """
    if key == "xyStart":
        return _format_xyStart_values(value)
    elif key == "Coordinates":
        return _format_coordinates_values(value)
    elif key == "FrameArray":
        return _format_frame_array_values(value)
    elif key == "TimeArray":
        return _format_time_array_values(value)
    elif key == "xywh":
        return _format_xywh_values(value)
    elif key == "Size":
        return [_format_xywh_values(value)]
    elif key == "ULCs":
        return [_format_ucl_array_values(value)]
    else:
        return [value]


def _field_formatted(key: str, value):
    """
    Homogenizes variable annotations according to a predefined list.

    The function converts a key-value pair into a homogenized list of tuples according to a hard-coded list of keys.
    This is useful in standardizing variables annotated in different ways.

    Parameters
    ----------
    key : str
        The key to be formatted.

    value : str
        The corresponding value to be formatted.

    Returns
    -------
    formatted_key_value : list
        A list of tuples where each tuple is a pair of formatted key-value.

    Notes
    -----
    The keys are formatted as follows: 'xyStart' into 'xStart' and 'yStart',
    'xywh' into 'xStart', 'yStart', 'boxWidth', and 'boxHeight',
    'Overlap' into 'Overlap', 'Coordinates' into 'grid_xStart' and 'grid_yStart',
    'FrameArray' and 'TimeArray' are retained as is, all others are added without formatting.

    This function is designed to work with a specific set of keys and may not work as expected with
    a different set of keys.
    """

    keys = MAPPING_KEY.get(key, [key])
    values = _format_values(key, value)

    return list(zip(keys, values))


def _todict(matobj):
    """
    Convert a mat_struct object to a Python dictionary.

    Parameters
    ----------
    matobj : scipy.io.matlab.mat_struct
        The mat_struct object to be converted.

    Returns
    -------
    dict
        A Python dictionary representation of the mat_struct object.
    """
    python_dict = {}
    for field in matobj._fieldnames:
        elem = matobj.__dict__[field]
        if isinstance(elem, mat_struct):
            python_dict[field] = _todict(elem)
        else:
            python_dict[field] = elem
    return python_dict


def _harmonize_shape(quantity_value, quantity_name=None, has_animal_axis=False, n_times=None):
    """
    Move the time axis to the front and add the channel (and, for scalars, the
    component) axis so every backup shares the ``(T, 1, Ny, Nx, components[, animals])``
    layout of the pyap-native backups.

    MATLAB stores grid properties as ``(Ny, Nx, [components], T[, animals])``. The time
    axis is second-to-last for across-animal stacks (which carry a trailing animal axis)
    and last otherwise -- both single-animal AOTs and across-animal DBA differences have
    no animal axis. ``has_animal_axis`` selects between the two; the caller passes it
    explicitly (AOA -> True, AOT/DBA -> False) rather than sniffing the group name.

    ``loadmat(squeeze_me=True)`` may have dropped a singleton component axis (scalars) and
    a singleton time axis (single-window backups). ``n_times`` (the number of rows of the
    backup's ``FrameArray``) tells a missing time axis apart from a component axis; it is
    re-inserted before the axes are moved. Without ``n_times``, a squeezed scalar with no
    axis left beyond ``(Ny, Nx[, animals])`` is taken as single-window.

    Parameters
    ----------
    quantity_value : np.ndarray
        The input array whose dimensions need to be reformatted.
    quantity_name : str, optional
        Name of the quantity represented by the array. Used in error messages.
    has_animal_axis : bool, optional
        Whether the array carries a trailing animal axis (across-animal AOA stack).
    n_times : int, optional
        Number of time windows in the backup.

    Returns
    -------
    np.ndarray
        The reformatted array with time first and the channel/component axes added.

    Raises
    ------
    ValueError
        If the input array has less than two dimensions.
    """

    if quantity_value.ndim < 2:
        raise ValueError(f"There should be at least two dimensions in {quantity_name}")

    # Macrocaetes are landmark coordinates (xy, n_landmarks) -> no grid/time axes.
    if quantity_name == "Macrocaetes":
        return quantity_value

    squeezed_flat = 3 if has_animal_axis else 2  # (Ny, Nx[, animals]), comp and T gone
    time_axis = -2 if has_animal_axis else -1
    if n_times == 1 or quantity_value.ndim == squeezed_flat:  # squeezed T=1 -> restore it
        quantity_value = np.expand_dims(
            quantity_value, axis=quantity_value.ndim + time_axis + 1
        )
    harmonized = np.moveaxis(quantity_value, time_axis, 0)

    # Guarantee an always-present component axis (scalars get a trailing singleton),
    # placed just before the animal axis for AOA stacks. Then insert the image-channel
    # axis at position 1.
    if has_animal_axis and harmonized.ndim == 4:  # (T, Ny, Nx, animals) -> scalar
        harmonized = np.expand_dims(harmonized, axis=-2)
    elif not has_animal_axis and harmonized.ndim == 3:  # (T, Ny, Nx) -> scalar
        harmonized = np.expand_dims(harmonized, axis=-1)

    return np.expand_dims(harmonized, axis=1)
