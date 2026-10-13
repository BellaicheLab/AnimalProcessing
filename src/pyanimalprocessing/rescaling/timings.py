"""Frame-time conversion, temperature correction, and temporal averaging intervals."""

import numpy as np


def find_frame(initial_frame_refs, initial_time_ref, temperature, target_time, dt):
    """
    Calculates the corresponding frame(s) at a target time given a reference time and temperature.

    This function first adjusts the time interval 'dt' based on the temperature, converts the time
    references to minutes, then calculates the offset between the target time and the initial time
    reference. The offset is then applied to the frame references to find the corresponding frames
    at the target time.

    Parameters
    ----------
    initial_frame_refs : int or iterable of int
        The frame reference(s) at the initial time. Can be a single integer or an iterable of integers.
    initial_time_ref : str
        The initial time reference, must be in the format 'HHhMM'.
    temperature : int
        The temperature in degrees Celsius. If the temperature is 29, 'dt' is adjusted accordingly.
    target_time : str
        The target time to find the corresponding frames, must be in the format 'HHhMM'.
    dt : float
        The time interval in minutes between each frame.

    Returns
    -------
    list of int
        The corresponding frames at the target time.

    Raises
    ------
    TypeError
        If the initial_frame_refs is not iterable and is not an integer.

    Notes
    -----
    If the temperature is 29 degrees Celsius, the time interval 'dt' is divided by 0.9 to adjust for
    faster developmental speed at higher temperatures. The returned list might be longer than the
    input 'initial_frame_refs' list due to this adjustment.
    """

    if temperature == 29:
        dt = dt / 0.9

    initial_time_ref = int(initial_time_ref.split("h")[0]) * 60 + int(
        initial_time_ref.split("h")[1]
    )
    target_time = int(target_time.split("h")[0]) * 60 + int(target_time.split("h")[1])

    offset = np.round((target_time - initial_time_ref) / dt).astype(int)

    try:
        iterator = iter(initial_frame_refs)
    except TypeError:
        initial_frame_refs = [initial_frame_refs]

    target_frames = []
    for frame in initial_frame_refs:
        target_frames.append(frame + offset)

    return target_frames


def update_time_step(dt, temperature):
    """Correct time step for temperature-dependent development speed.

    At 29 degrees C, development is faster by a factor of 0.9.

    Parameters
    ----------
    dt : float
        Time step in minutes.
    temperature : int
        Experimental temperature (25 or 29).

    Returns
    -------
    float
        Adjusted time step.
    """
    temperature = int(temperature)
    if temperature == 29:
        dt = dt / 0.9
        # to compare velocities, constriction rates... between 25 and 29 movies, dt must be corrected
    elif temperature != 25:
        raise ValueError(f"temperature must be 25 or 29, got {temperature}")
    return dt


def time_str_to_dec(time_str):
    """
    Returns decimal time from string time.
    NB: "time_str" must begin with 'HH:MM' (or 'HHhMM') and can be followed by anything ('HH:MM hAPF',...)

    Parameters:
    time_str (str): String representation of time in 'HH:MM' or 'HHhMM' format.

    Returns:
    time_dec (float): Decimal representation of time. Raises ValueError on a malformed string.

    version 1.1
    Boris Guirao

    History:
    25/02/2014: 1.1
    - now also checks "isempty(time_str)" right at beginning (similarly to "Time_dec2str")

    16/07/2013: creation
    """

    # Check
    if not time_str or not isinstance(time_str, str):
        raise ValueError(f"time_str_to_dec: expected a string, got {time_str!r}")

    # Extracting time and checking format
    try:
        HH = int(time_str[0:2])
        separator = time_str[2]
        MM = int(time_str[3:5])
    except ValueError:
        raise ValueError(f"time_str_to_dec: {time_str!r} does not follow 'HH:MM' or 'HHhMM'")

    # Check format follows "HH:MM" or "HHhMM"
    if separator not in [":", "h"]:
        raise ValueError(f"time_str_to_dec: {time_str!r} does not follow 'HH:MM' or 'HHhMM'")

    # Conversion to decimal format
    MM = MM / 60  # fraction of hours
    time_dec = HH + MM

    return time_dec


def time_to_frame(time, time_ref, frame_ref, dt):
    """
    Returns "frame" (rounded to nearest tenth if non-integer) corresponding to "time".

    Parameters:
    time (float or str): Current time to be turned into frame number (can be decimal or string ('HH:MM' format))
    time_ref (float or str): Reference time (can be decimal or string ('HH:MM' format))
    frame_ref (int): Reference frame corresponding to time_ref
    dt (float): Corrected time between two frames in minutes, namely adjusted according to temperature

    Returns:
    frame (float): Frame number corresponding to time, rounded to nearest tenth if non-integer

    version 1.1
    Boris Guirao
    Mathieu Riviere

    History:
    28/04/2016: 1.1
    - removed argument "temp" since dt is now corrected at "AIA_parameter" stage

    16/09/2014: creation
    """

    # Turn "time" into decimal format if needed
    if isinstance(time, str):
        time = time_str_to_dec(time)

    # Turn "time_ref" into decimal format if needed
    if isinstance(time_ref, str):
        time_ref = time_str_to_dec(time_ref)

    # Determine "frame"
    frame = int(frame_ref) + (time - time_ref) * (60 / dt)

    # frame = np.floor(frame)  # rounds up to 1 digit

    return frame


def time_dec_to_str(time_dec, separator="h"):
    """
    Returns time as string 'HHhMM' (default) or 'HH:MM' from decimal time.
    "separator" can only be ':' or 'h'.

    Parameters:
    time_dec (float): Decimal representation of time.
    separator (str, optional): Character to separate hours and minutes. Default is 'h'.

    Returns:
    time_str (str): String representation of time, or None if there's an error.

    version 1.2
    Boris Guirao

    History:
    01/03/2016: 1.2
    - fixed case where MM rounding yields 60 and strings like 35h60 => now 36h00

    18/09/2014: 1.1
    - added optional argument "separator" that can be 'h' or ':'
    - changed default separator to 'h' from ':' since the latter creates many
    problems in the code or when naming files.

    16/07/2013: creation
    """

    # Check
    if separator not in [":", "h"]:
        separator = "h"  # override wrong separators

    # Vectorized path for array inputs (needed by the unified plotting layer).
    if np.ndim(time_dec) > 0:
        time_dec = np.asarray(time_dec, dtype=float)
        HH = time_dec.astype(np.int16)
        MM = np.round((time_dec - HH) * 60).astype(np.int16)
        HH = HH + (MM == 60)
        MM = np.where(MM == 60, 0, MM)
        return np.vectorize(lambda h, m: f"{int(h):02d}{separator}{int(m):02d}")(HH, MM)

    # Scalar path (original behavior). 0 is a valid time (00h00), so check for None,
    # not falsiness.
    if time_dec is None or not isinstance(time_dec, (int, float)):
        raise ValueError(f"time_dec_to_str: expected a number, got {time_dec!r}")

    HH = int(time_dec)
    MM = round((time_dec - HH) * 60)

    # Case where MM rounding up yields exactly 60 (1.2)
    if MM == 60:
        HH += 1
        MM = 0

    return f"{HH:02d}{separator}{MM:02d}"


def median_time(start_str, end_str):
    """Return the midpoint of two times in 'HHhMM' format.

    Parameters
    ----------
    start_str, end_str : str or bytes
        Start and end times in ``"HHhMM"`` format (e.g. ``"18h30"``).
        Bytes are decoded automatically (zarr sometimes stores as bytes).

    Returns
    -------
    str
        Median time in ``"HHhMM"`` format (e.g. ``"20h30"``).
    """

    def _to_minutes(t):
        if isinstance(t, bytes):
            t = t.decode("utf-8")
        parts = t.split("h")
        return int(parts[0]) * 60 + int(parts[1])

    median_minutes = (_to_minutes(start_str) + _to_minutes(end_str)) // 2
    return f"{median_minutes // 60:02d}h{median_minutes % 60:02d}"


def frame_to_time(frame, time_ref, frame_ref, dt, fmt="dec"):
    """
    Returns time (decimal or string format hh:mm) corresponding to frame.
    NB: frame can be matrix, format is forced to "dec" in that case

    Parameters:
    frame (int or list or np.array): current frame number(s) to be turned into time
    time_ref (str or float): reference time (can be decimal or string ('HH:MM' format))
    frame_ref (int): reference frame corresponding to time_ref
    dt (float): corrected time between two frames in minutes, namely adjusted according to temperature
    fmt (str): output format: 'dec' or 'str'

    Returns:
    time (float or str or list): time in desired format corresponding to frame

    version 1.2
    Boris Guirao
    Mathieu Riviere
    """

    # Turn time_ref into decimal format if needed
    frame_ref = int(frame_ref)
    if isinstance(time_ref, str):
        time_ref = time_str_to_dec(time_ref)

    # Determine time in decimal format (scalar preserves original int(frame) behavior;
    # arrays are supported for the unified plotting layer).
    if np.ndim(frame) > 0:
        time = time_ref + (np.asarray(frame, dtype=float) - frame_ref) * (dt / 60)
    else:
        time = time_ref + (int(frame) - frame_ref) * (dt / 60)

    return time_dec_to_str(time)


def find_closest_time_index(target_time, time_list):
    """Find the index of the closest time point to *target_time*.

    Both *target_time* and every element of *time_list* must be in
    ``"HHhMM"`` format (e.g. ``"16h47"``).

    Parameters
    ----------
    target_time : str
        Target time string in ``"HHhMM"`` format.
    time_list : list of str
        Available time points in ``"HHhMM"`` format.

    Returns
    -------
    int
        Index into *time_list* of the closest time point.
    """

    def _time_to_minutes(time_str):
        hours, minutes = time_str.split("h")
        return int(hours) * 60 + int(minutes)

    target_minutes = _time_to_minutes(target_time)
    time_differences = [abs(_time_to_minutes(t) - target_minutes) for t in time_list]
    return time_differences.index(min(time_differences))


def require_timing_attrs(animal, step):
    """Assert the animal carries the frame↔time reference attrs, with an actionable message.

    Time-dependent steps need ``frame_ref``/``time_ref`` to map frames to developmental
    time. They are animal-specific with no sensible default, so this raises a clear
    error (rather than a bare ``KeyError`` or, worse, silently assuming a wrong value)
    when they were never set.
    """
    missing = [a for a in ("time_ref", "frame_ref") if a not in animal.attrs]
    if missing:
        name = animal.attrs.get("name", "<unnamed>")
        raise KeyError(
            f"Animal '{name}' has no {'/'.join(missing)}. These map frames to "
            f"developmental time and must be set for {step}. Pass frame_ref/time_ref to "
            f"instantiate_animal(...), or set animal.attrs['time_ref'] and "
            f"animal.attrs['frame_ref'] before running it."
        )
