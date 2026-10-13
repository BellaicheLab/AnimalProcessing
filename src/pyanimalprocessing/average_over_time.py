"""Averaging over time (AOT): sliding-window time averaging of spatially-aggregated
properties into ``TIME_AVERAGE/<grid>[/<type>]/<dimension>/<backup>`` groups, with
matching area-ratio weights and per-window time arrays.
"""

from typing import List, Tuple, Literal
import numpy as np
from tqdm.auto import tqdm
import zarr
from numpy.typing import NDArray
from pyanimalprocessing.rescaling.timings import (
    require_timing_attrs,
    time_to_frame,
    update_time_step,
    time_str_to_dec as _time_str_to_dec,
    time_dec_to_str as _time_dec_to_str,
)
from pyanimalprocessing.utils.pipeline import _smart_round
from pyanimalprocessing.utils import _vprint


def average_over_time(
    animals: List[zarr.hierarchy.Group],
    properties: List[str],
    time_start: str = "16h00",
    time_stop: str = "38h00",
    time_window: str = "02h00",
    time_step: int = 5,
    grid_type: Literal["regions", "eulerian"] = "eulerian",
    grid_name: str = None,
    averaged_type: Literal["regions", "cell", "eulerian", None] = "cell",
    dimension: str = "D2",
    backup_name: str = "default",
    verbose: bool = False,
) -> List[zarr.hierarchy.Group]:
    """
    Perform time averaging of specified properties for multiple animals.

    :param animals: A list of zarr groups representing the animals.
    :type animals: List[zarr.hierarchy.Group]
    :param properties: A list of property names to be averaged over time.
    :type properties: List[str]
    :param time_start: The start time in the format "XXhYY" (default: "16h00").
    :type time_start: str, optional
    :param time_stop: The stop time in the format "XXhYY" (default: "38h00").
    :type time_stop: str, optional
    :param time_window: The time window for averaging in the format "XXhYY" (default: "02h00").
    :type time_window: str, optional
    :param time_step: The time step in minutes (default: 5).
    :type time_step: int, optional
    :param grid_type: The type of grid to use for averaging (default: "eulerian").
    :type grid_type: Literal["regions", "eulerian"], optional
    :param grid_name: Name of the GRID/<grid_name> group to read from and key TIME_AVERAGE by. Defaults to grid_type.upper().
    :type grid_name: str, optional
    :param averaged_type: The type of spatially-averaged data to average: "cell", "regions", "eulerian", or None to average the grid's own properties (default: "cell").
    :type averaged_type: Literal["regions", "cell", "eulerian", None], optional
    :param dimension: The dimension of the animal images (default: "D2").
    :type dimension: str, optional
    :param backup_name: The name for the backup of the averaged data (default: "default").
    :type backup_name: str, optional
    :param verbose: Whether to print verbose output. Defaults to False.
    :type verbose: bool, optional

    :return: The list of updated zarr groups representing the animals.
    :rtype: List[zarr.hierarchy.Group]

    **Example:**

    .. code-block:: python

        import zarr
        from pyanimalprocessing.average_over_time import average_over_time

        # Load your zarr data
        animal_1 = zarr.open("path/to/animal1")

        # Perform time averaging
        averaged_animals = average_over_time(
            animals=[animal_1],
            properties=["intensity_mean", "area"],
            time_start="16h00",
            time_stop="38h00",
            time_window="02h00",
            time_step=5,
            grid_type="eulerian",
            averaged_type="cell",
            dimension="D2",
            backup_name="default",
            verbose=True
        )
    """
    if not isinstance(animals, list):
        animals = [animals]
    if not isinstance(properties, list):
        properties = [properties]
    grid_key = grid_name if grid_name is not None else grid_type.upper()
    if averaged_type is not None:
        averaged_type = averaged_type.upper()
    use_progress = bool(verbose)
    outer_pbar = (
        tqdm(
            total=len(animals),
            desc="Animals",
            position=0,
            leave=False,
            dynamic_ncols=True,
        )
        if use_progress
        else None
    )

    for i, animal in enumerate(animals):
        try:
            if use_progress and outer_pbar is not None:
                try:
                    animal_name = animal.attrs.get("name", f"#{i+1}")
                except Exception:
                    animal_name = f"#{i+1}"
                outer_pbar.set_description(
                    f"Animal {i+1}/{len(animals)}: {animal_name}"
                )
            else:
                _vprint(
                    f"Averaging over time for animal: {animal.attrs['name']}", verbose
                )

            # Retrieve the necessary attributes from the animal's attributes
            require_timing_attrs(animal, "time-averaging (average_over_time)")
            delta_t = animal.attrs["dt"]
            temperature = animal.attrs["temperature"]
            time_ref = animal.attrs["time_ref"]
            frame_ref = animal.attrs["frame_ref"]

            # Create the group backup
            # Create the TIME_AVERAGE group if it doesn't exist
            time_average_group = animal.require_group("TIME_AVERAGE")
            grid_type_group = time_average_group.require_group(grid_key)
            if averaged_type is None:
                dim_group = grid_type_group.require_group(dimension)
            else:
                averaged_type_group = grid_type_group.require_group(averaged_type)
                dim_group = averaged_type_group.require_group(dimension)

            # Create a unique name for the averaging results based on the time parameters
            if backup_name in dim_group:
                del dim_group[backup_name]

            weights, time_array, frame_intervals = _calculate_weights(
                area_ratio=np.array(
                    animal.GRID[grid_key]["GRID_PROPERTIES"]["area_ratios"]
                ),
                delta_t=delta_t,
                temperature=temperature,
                time_ref=time_ref,
                frame_ref=frame_ref,
                time_start=time_start,
                time_stop=time_stop,
                time_window=time_window,
                time_step=time_step,
            )

            result_group = dim_group.require_group(backup_name)
            result_group.attrs["time_start"] = time_start
            result_group.attrs["time_stop"] = time_stop
            result_group.attrs["time_window"] = time_window
            result_group.attrs["time_step"] = time_step

            result_group.array("weights", data=weights, overwrite=True)
            result_group.array(
                "time_array", data=np.array(time_array, dtype="S"), overwrite=True
            )
            result_group.array(
                "frame_array", data=np.array(frame_intervals), overwrite=True
            )

            # Progress bar for properties within the current animal
            inner_pbar = (
                tqdm(
                    total=len(properties),
                    desc="Properties",
                    position=1,
                    leave=False,
                    dynamic_ncols=True,
                )
                if use_progress
                else None
            )

            for property_name in properties:
                if inner_pbar is not None:
                    inner_pbar.set_postfix_str(str(property_name))

                if averaged_type is None:
                    property_data = animal.GRID[grid_key][dimension][property_name][:]
                else:
                    property_data = animal.GRID[grid_key][averaged_type][dimension][
                        property_name
                    ][:]

                area_ratio = animal.GRID[grid_key]["GRID_PROPERTIES"]["area_ratios"][:]

                quantity_averaged = _average_over_time(
                    quantity=property_data,
                    area_ratio=area_ratio,
                    frame_intervals=frame_intervals,
                )

                # Finally we give its dimensions to the quantity_averaged
                quantity_averaged = _give_dimensions(
                    property_name=property_name,
                    property=quantity_averaged,
                    temperature=temperature,
                    scale=animal.attrs["scaling"],
                    dt=delta_t,
                )

                # Store the averaged quantity, weights, time array, and frame array
                result_group.array(
                    property_name, data=quantity_averaged, overwrite=True, dtype="float"
                )
                if inner_pbar is not None:
                    inner_pbar.update(1)

            if inner_pbar is not None:
                inner_pbar.close()
        finally:
            if outer_pbar is not None:
                outer_pbar.update(1)
    if outer_pbar is not None:
        outer_pbar.close()
    return animals


def _give_dimensions(property_name, property, temperature, scale, dt):
    if property_name == "displacement":
        # In um.h-1
        property = (property * scale) / (update_time_step(dt, temperature) / 60)

    return property


def _average_over_time(
    quantity: NDArray[np.float32],
    area_ratio: NDArray[np.float32],
    frame_intervals,
) -> Tuple[NDArray[np.float32], NDArray[np.float32], List[List[str]]]:
    """
    Calculate the weighted average of a quantity over time.

    :param quantity: The quantity to be averaged.
    :param area_ratio: The area ratio used for weighting.
    :param delta_t: The adjusted time step.
    :param temperature: The temperature value.
    :param time_ref: The reference time.
    :param frame_ref: The reference frame.
    :param time_start: The start time in the format "XXhYY".
    :param time_stop: The stop time in the format "XXhYY".
    :param time_window: The time window for averaging in the format "XXhYY".
    :param time_step: The time step in minutes.
    :return: The averaged quantity, the averaged weight, and a list of time intervals.
    """
    # convert property to array

    # Perform weighted average for each time interval
    quantity_averaged = np.empty(
        (len(frame_intervals), *quantity.shape[1:]), dtype=np.float32
    )

    quantity_averaged[:] = np.nan

    for t, (frame_min, frame_max) in enumerate(frame_intervals):
        # Adjust frame intervals to fit within the quantity's range
        valid_frame_min = max(frame_min, 0)
        valid_frame_max = min(frame_max, quantity.shape[0])

        # If there are valid frames within the interval
        if frame_min >= 0 and frame_max <= quantity.shape[0]:
            # Compute the weighted average for frames inside the bounds
            q_avg = _calculate_average_quantity(
                quantity, area_ratio, [valid_frame_min], [valid_frame_max]
            )
            quantity_averaged[t, ...] = q_avg[0]

        else:
            # Set NaN for intervals with no valid frames
            quantity_averaged[t, ...] = np.nan

    return quantity_averaged


def _calculate_average_quantity(
    quantity: NDArray[np.float32],
    area_ratio: NDArray[np.float32],
    frame_min: List[int],
    frame_max: List[int],
) -> Tuple[NDArray[np.float32], NDArray[np.float32]]:
    """
    Calculate the weighted average of a quantity using the provided area ratio as weights.

    :param quantity: The quantity to be averaged.
    :param area_ratio: The area ratio used for weighting.
    :param frame_min: The list of minimum frame indices for each averaging interval.
    :param frame_max: The list of maximum frame indices for each averaging interval.
    :return: Tuple[NDArray[np.float32], NDArray[np.float32]]: The averaged quantity and the averaged weight.
    """

    weights = area_ratio**2
    quantity_averaged = np.zeros_like(quantity, np.float32)
    weight_averaged = np.zeros_like(quantity, np.float32)

    quantity_averaged[:] = np.nan
    weight_averaged[:] = np.nan

    for t in range(len(frame_min)):
        t_start = frame_min[t]
        t_end = frame_max[t]

        weights_interval = weights[t_start:t_end, ...].astype(float)
        quantity_interval = quantity[t_start:t_end, ...].astype(float)

        sum_weights = np.nansum(weights_interval, axis=0)
        weighted_sum_quantity = np.nansum(weights_interval * quantity_interval, axis=0)

        # Avoid division by zero
        with np.errstate(divide="ignore", invalid="ignore"):
            q_current = np.where(
                sum_weights != 0, weighted_sum_quantity / sum_weights, np.nan
            )

            quantity_averaged[t, ...] = q_current

    return quantity_averaged.astype(np.float32)


def _calculate_average_weight(
    area_ratios: NDArray[np.float32],
    frame_min: List[int],
    frame_max: List[int],
):
    """
    Calculate the average weight for a given frame interval.

    :param area_ratios: The area ratios used for weighting.
    :param frame_min: The minimum frame index for the averaging interval.
    :param frame_max: The maximum frame index for the averaging interval.
    :return: The average weight for the given frame interval.
    """
    weights = np.square(area_ratios)
    weight_averaged = np.full(area_ratios.shape, np.nan, float)

    for t in range(len(frame_min)):
        t_start = frame_min[t]
        t_end = frame_max[t]

        weights_interval = weights[t_start:t_end, ...]

        sum_weights = np.nansum(weights_interval, axis=0)

        # Avoid division by zero
        with np.errstate(divide="ignore", invalid="ignore"):
            wa_current = np.where(sum_weights != 0, sum_weights / (t_end - t_start), 0)

            weight_averaged[t, ...] = wa_current

    return weight_averaged


def _calculate_weights(
    area_ratio: NDArray[np.float32],
    delta_t: float,
    temperature: int,
    time_ref: str,
    frame_ref: int,
    time_start: str,
    time_stop: str,
    time_window: str,
    time_step: int,
) -> Tuple[NDArray[np.float32], List[List[str]], List[Tuple[int, int]]]:
    """
    Calculate weights for time averaging.

    :param area_ratio: The area ratio used for weighting.
    :param delta_t: The adjusted time step.
    :param temperature: The temperature value.
    :param time_ref: The reference time.
    :param frame_ref: The reference frame.
    :param time_start: The start time in the format "XXhYY".
    :param time_stop: The stop time in the format "XXhYY".
    :param time_window: The time window for averaging in the format "XXhYY".
    :param time_step: The time step in minutes.
    :return: The calculated weights, a list of time intervals, and a list of frame intervals.
    """
    # Convert time_start, time_stop, and time_window to decimal hours
    start_hours = _time_str_to_dec(time_start)
    stop_hours = _time_str_to_dec(time_stop)
    window_hours = _time_str_to_dec(time_window)

    # Convert start and stop times to total minutes
    start_minutes = int(start_hours * 60)
    stop_minutes = int(stop_hours * 60)
    window_minutes = int(window_hours * 60)

    # Generate a list of time intervals in minutes
    time_intervals_minutes = list(np.arange(start_minutes, stop_minutes + 1, time_step))

    # Convert time intervals in minutes to frame intervals
    frame_intervals = np.zeros((len(time_intervals_minutes) - 1, 2), float)
    time_array = []

    for i in range(len(time_intervals_minutes) - 1):
        start_time_str = _time_dec_to_str(time_intervals_minutes[i] / 60)
        end_time_str = _time_dec_to_str(
            (time_intervals_minutes[i] + window_minutes) / 60
        )

        frame_min = time_to_frame(
            start_time_str, time_ref, frame_ref, update_time_step(delta_t, temperature)
        )
        frame_max = time_to_frame(
            end_time_str, time_ref, frame_ref, update_time_step(delta_t, temperature)
        )
        frame_intervals[i] = (frame_min, frame_max)
        time_array.append([start_time_str, end_time_str])
    frame_intervals[:, 0] = _smart_round(frame_intervals[:, 0], np.floor)
    frame_intervals[:, 1] = _smart_round(frame_intervals[:, 1], np.ceil)
    frame_intervals = frame_intervals.astype(int)

    # Calculate weights
    weights = np.zeros((len(frame_intervals), *area_ratio.shape[1:]), dtype=np.float32)

    for t, (frame_min, frame_max) in enumerate(frame_intervals):
        # Adjust frame intervals to fit within the area_ratio's range
        total_frames = frame_max - frame_min
        valid_frame_min = max(frame_min, 0)
        valid_frame_max = min(frame_max, area_ratio.shape[0])
        # Compute the weight ratio based on the number of valid frames
        valid_frames = valid_frame_max - valid_frame_min
        weight_ratio = valid_frames / total_frames

        # If there are valid frames within the interval
        if frame_min >= 0 and frame_max <= area_ratio.shape[0]:
            # Compute the weighted average for frames inside the bounds
            w_avg = (
                _calculate_average_weight(
                    area_ratio, [valid_frame_min], [valid_frame_max]
                )
                * weight_ratio
            )

            weights[t, ...] = w_avg[0]

    return weights, time_array, frame_intervals
