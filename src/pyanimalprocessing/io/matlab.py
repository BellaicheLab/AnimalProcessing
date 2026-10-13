"""MATLAB data loading and extraction into zarr groups."""

import os
import re
import warnings
from copy import deepcopy
from datetime import datetime
from glob import glob
from logging import warn

import numpy as np
import scipy.io as spio
import zarr
from scipy.io.matlab import mat_struct

from pyanimalprocessing.rescaling.timings import time_dec_to_str, time_str_to_dec
from pyanimalprocessing.transformation.tensors import get_unbiased_weighted_std_matrix_aoa
from pyanimalprocessing.transformation.tracking import get_mapping_dicts, relabel_movie
from pyanimalprocessing.utils.conversions import (
    QUANTITIES_ATTRIBUTES,
    _field_formatted,
    _harmonize_shape,
    _todict,
)


def _grid_type_from_name(grid_name: str) -> str:
    """Infer the ``grid_type`` from a MATLAB grid folder name (EGrid/LGrid)."""
    if grid_name.startswith("LGrid"):
        return "lagrangian_tracking"
    return "eulerian"


def stamp_grid_geometry(
    grid_properties, box_width, box_height, overlap, scaling, x_factor, y_factor, image_shape
):
    """Stamp the frame-independent grid metadata on a ``GRID_PROPERTIES`` group.

    Only the geometry that MATLAB output fully determines is written:
    ``box_size_microns`` (box size in the common frame), ``overlap``, ``scaling``,
    ``image_shape``. The archetype-frame geometry — ``matrix_transform``,
    ``centroids``, ``X``/``Y``, ``box_corners``, ``mask_positions``,
    ``lagrangian_grid`` — is NOT reconstructable from a single MATLAB movie store
    (the target/archetype landmarks it was registered against are not stored), so it
    is left to ``rescaling.registration.generate_common_grid`` to regenerate.
    """
    grid_properties.attrs["box_size_microns"] = [
        float(box_height * scaling * y_factor),
        float(box_width * scaling * x_factor),
    ]
    grid_properties.attrs["overlap"] = float(overlap)
    grid_properties.attrs["scaling"] = float(scaling)
    grid_properties.attrs["image_shape"] = [int(s) for s in image_shape]


def stamp_time_metadata(backup):
    """Mirror pyap's time metadata on a converted backup.

    Native pyap backups (``average_over_time``) carry ``time_array`` (bytes "HHhMM")
    and ``frame_array`` (int) as ``(T, 2)`` datasets, plus ``time_start``/``time_stop``/
    ``time_window``/``time_step`` attrs. The MATLAB conversion only stores
    ``TimeArray``/``FrameArray`` as attrs, so add the datasets + summary attrs here so
    both schemas expose the same thing. ``time_start``/``time_stop``/``time_window`` come
    from the ``Average_<W>h_<start>_to_<stop>`` group name when present (falling back to
    the interval boundaries), and ``time_step`` is the median stride between successive
    interval starts, in minutes.
    """
    attrs = backup.attrs
    if "TimeArray" not in attrs or "FrameArray" not in attrs:
        return
    # Guard the boundary: single-frame / 0olap backups can carry a degenerate
    # TimeArray that isn't a clean list of [start, end] "HHhMM" pairs -> skip.
    def _is_time(v):
        return isinstance(v, str) and len(v) >= 4 and "h" in v

    rows = attrs["TimeArray"]
    if not (len(rows) and all(len(r) == 2 and _is_time(r[0]) and _is_time(r[1]) for r in rows)):
        return
    if "time_array" not in backup:
        backup.create_dataset("time_array", data=np.asarray(attrs["TimeArray"], dtype="S5"))
    if "frame_array" not in backup:
        backup.create_dataset("frame_array", data=np.asarray(attrs["FrameArray"], dtype=int))

    name = os.path.basename(backup.name)
    starts = [row[0] for row in attrs["TimeArray"]]
    stops = [row[1] for row in attrs["TimeArray"]]

    window_match = re.search(r"_(\d+)h(?:_|olap|$)", name)
    if window_match:
        time_window = f"{int(window_match.group(1)):02d}h00"
    else:
        # No window token (e.g. noAverage): the window is the per-interval span,
        # end - start, which is 0 (== "00h00") for instantaneous backups.
        time_window = time_dec_to_str(
            time_str_to_dec(stops[0]) - time_str_to_dec(starts[0])
        )

    span_match = re.search(r"_(\d+h\d+)_to_(\d+h\d+)", name)
    if span_match:
        time_start, time_stop = span_match.group(1), span_match.group(2)
    else:
        time_start, time_stop = starts[0], stops[-1]

    if len(starts) > 1:
        diffs = np.diff([time_str_to_dec(s) for s in starts]) * 60.0
        time_step = int(round(float(np.median(diffs))))
    else:
        time_step = 0

    backup.attrs["time_start"] = time_start
    backup.attrs["time_stop"] = time_stop
    backup.attrs["time_window"] = time_window
    backup.attrs["time_step"] = time_step


def stamp_aoa_std(group):
    """Precompute pyap-style ``<quantity>_std`` maps for an across-animal backup.

    Native pyap AOA backups (``average_over_animals``) store a ``<quantity>_std``
    dataset — the unbiased weighted std across animals — beside each averaged property.
    The MATLAB AOA carries the per-animal samples (the trailing animal axis, index 0 =
    mean, 1.. = individual animals), so compute the same std here so both schemas expose
    it. Requires the ``weights`` dataset (area-ratio weights with the animal axis).
    """
    if "weights" not in group:
        return
    weights = np.asarray(group["weights"], dtype=np.float64)  # (T, 1, Ny, Nx, 1, A)
    if weights.ndim < 6 or weights.shape[-1] < 2:
        return
    skip = {"weights", "time_array", "frame_array", "Macrocaetes"}
    for name in list(group.array_keys()):
        if name in skip or name.endswith("_std") or name.startswith("AreaRatios"):
            continue
        arr = np.asarray(group[name], dtype=np.float64)  # float64 avoids float16 overflow
        if arr.ndim != weights.ndim or arr.shape[-1] != weights.shape[-1]:
            continue
        std = get_unbiased_weighted_std_matrix_aoa(
            arr[..., 1:], arr[..., 0], weights[..., 1:]
        )
        if f"{name}_std" not in group:
            group.create_dataset(
                f"{name}_std", data=std.astype(np.float16), dtype=np.float16
            )


def stamp_aoa_centroids(group):
    """Materialize ``grid_centroids`` ``(Ny, Nx, 2)`` ``(y, x)`` on an AOA/DBA backup.

    Gives the MATLAB-converted AOA the same stored-centroid contract as a native pyap
    AOA, so ``read_property`` reads box origins directly (archetype/common frame) instead
    of recomputing them. float64 keeps it bit-identical to the on-the-fly ``_box_centres``.
    No-op if the box geometry attrs are absent.
    """
    box_attrs = ("Size", "xStart", "yStart", "boxWidth", "boxHeight", "Overlap")
    if "grid_centroids" in group or not all(a in group.attrs for a in box_attrs):
        return
    from pyanimalprocessing.rescaling.geometry import box_centres_from_backup

    centroids = box_centres_from_backup(group, common_frame=True)  # archetype frame
    group.create_dataset("grid_centroids", data=centroids, chunks=centroids.shape)


def stamp_registration_affine(animal):
    """Store the geometric registration affine on the animal's root attrs.

    The MATLAB rescaling maps raw movie coordinates onto the common (archetype)
    frame independently per axis: ``coord_common = factor * (coord_raw - origin)``
    (the isotropic ``scale1D`` lives separately in ``scaling``). The single-animal
    AOT grid is built on that common frame so animals are directly comparable, so
    this affine is applied when plotting. It is a per-animal property stored beside
    ``xFactor``/``yFactor``/``xStart``/``yStart``; the display affine is composed
    from it and the timing attrs at plot time (never stored per backup). Written in
    pyap's (y, x) axis order.
    """
    attrs = animal.attrs
    if not all(k in attrs for k in ("xFactor", "yFactor", "xStart", "yStart")):
        return
    x_factor, y_factor = float(attrs["xFactor"]), float(attrs["yFactor"])
    x_start, y_start = float(attrs["xStart"]), float(attrs["yStart"])
    animal.attrs["matrix_transform"] = [
        [y_factor, 0.0, -y_factor * y_start],
        [0.0, x_factor, -x_factor * x_start],
        [0.0, 0.0, 1.0],
    ]


def extract_AOT_results_folder(
    animal: zarr.hierarchy.Group, SAP_results_folder, quantities, verbose=True
):
    """
    Extracts information from .mat files in the AveragesOverTime (AOT) folder and stores them in a zarr group.

    This function iterates over all .mat files present in the AOT folder (excluding any file that contains "alltime"
    in its name), extracts the quantities of interest, and stores them in the zarr hierarchy.
    The function creates subgroups in the zarr group to match the file structure in the AOT folder.

    Parameters
    ----------
    group : zarr.hierarchy.Group
        The zarr group where the extracted datasets will be stored.
    SAP_results_folder : str
        The path to the SAP results folder.
    quantities : list
        The list of quantities to be extracted from the .mat files.
    verbose : bool, optional
        If True, the function will print warnings when a quantity is not found in the backup file.

    Raises
    ------
    IOError
        If there are more than one or no AOT folders in the SAP results folder.

    Returns
    -------
    None
        This function doesn't return anything. It modifies the provided zarr group in-place.

    """
    AOT_folder = find_AOT_folder(SAP_results_folder)
    if AOT_folder is None:
        return
    traverse_and_extract_AOT(animal, AOT_folder, quantities, verbose=True)


def find_AOT_folder(SAP_results_folder):
    """
    Find the AOT folder within the given SAP results directory.

    Parameters
    ----------
    SAP_results_folder : str
        The path to the SAP results directory.

    Returns
    -------
    str
        The path to the AOT folder within the SAP results directory.

    Raises
    ------
    IOError
        If there is more than one or no AOT folder detected.

    Notes
    -----
    The function expects a single AOT folder to exist within the SAP results folder.
    """
    path_AOT = os.path.join(SAP_results_folder, "AOT*")
    AOT_folder = glob(path_AOT)

    if len(AOT_folder) > 1:
        warn(
            f"There should only be an AOT folder in the analysis, right now you have {AOT_folder}"
        )
        return

    if len(AOT_folder) == 0:
        warn(f"There is not AOT folder detected in {path_AOT}")
        return

    return AOT_folder[0]


def traverse_and_extract_AOT(animal, AOT_folder, quantities, verbose=True):
    """
    Traverse the AOT folder and extract each grid's time backups.

    The AOT folder mirrors ``<grid>/<Average_...>/backup.mat``. Each ``<grid>`` gets
    ``GRID/<grid>/GRID_PROPERTIES`` stamped with its ``grid_type``, and each
    ``<Average_...>`` backup lands at the canonical top-level location
    ``TIME_AVERAGE/<grid>/D2/<Average_...>`` (the same layout ``average_over_time``
    writes and every reader consumes).

    Parameters
    ----------
    animal : zarr.hierarchy.Group
        The animal root group where ``GRID`` and ``TIME_AVERAGE`` are written.
    AOT_folder : str
        The path to the AOT folder containing MATLAB `.mat` files.
    quantities : list
        A list of quantities that need to be extracted from the AOT files.
    verbose : bool, optional
        Whether to display verbose messages. Default is True.
    """
    for root, _, files in os.walk(AOT_folder):
        for file in files:
            if file.endswith(".mat") and "alltime" not in file:
                fullpath = os.path.join(root, file)
                index = fullpath.find(AOT_folder)
                parts = fullpath[index + len(AOT_folder) + 1 :].split(os.path.sep)[:-1]
                if not parts:
                    continue

                grid_name = parts[0]
                grid_group = animal.require_group("GRID").require_group(grid_name)
                grid_group.require_group("GRID_PROPERTIES").attrs["grid_type"] = (
                    _grid_type_from_name(grid_name)
                )

                backup = (
                    animal.require_group("TIME_AVERAGE")
                    .require_group(grid_name)
                    .require_group("D2")
                )
                for part in parts[1:]:
                    backup = backup.require_group(part)

                extract_AOT(
                    backup, os.path.join(root, file), quantities, verbose=verbose
                )
                stamp_time_metadata(backup)

                # Frame-independent grid metadata (best-effort): box params are on the
                # backup after extract_AOT; scale/factors + image live on the root.
                has_image = (
                    "IMAGE" in animal
                    and "D2" in animal["IMAGE"]
                    and "raw" in animal["IMAGE"]["D2"]
                )
                if "boxWidth" in backup.attrs and "scale1D" in animal.attrs and has_image:
                    stamp_grid_geometry(
                        grid_group["GRID_PROPERTIES"],
                        box_width=backup.attrs["boxWidth"],
                        box_height=backup.attrs["boxHeight"],
                        overlap=backup.attrs.get("Overlap", 0.5),
                        scaling=animal.attrs["scale1D"],
                        x_factor=animal.attrs.get("xFactor", 1.0),
                        y_factor=animal.attrs.get("yFactor", 1.0),
                        image_shape=animal["IMAGE"]["D2"]["raw"].shape[-2:],
                    )


def check_keys(matlab_dict):
    """
    Convert any mat_struct objects in a dictionary to standard Python dictionaries.

    Parameters
    ----------
    matlab_dict : dict
        A dictionary potentially containing mat_struct objects.

    Returns
    -------
    dict
        The updated dictionary with mat_struct objects converted to Python dictionaries.

    Notes
    -----
    This function is specific to handling MATLAB `.mat` files.
    """
    for key in matlab_dict:
        if isinstance(matlab_dict[key], mat_struct):
            matlab_dict[key] = _todict(matlab_dict[key])
    return matlab_dict


def loadmat(filename):
    """
    Load a MATLAB `.mat` file and convert it to a Python dictionary.

    Parameters
    ----------
    filename : str
        The path to the `.mat` file.

    Returns
    -------
    dict
        A Python dictionary containing the data from the `.mat` file.
    """
    data = spio.loadmat(filename, struct_as_record=False, squeeze_me=True)
    return check_keys(data)


def load_and_update_backup(path_AOT):
    """
    Load a backup MATLAB `.mat` file and update its structure.

    Parameters
    ----------
    path_AOT : str
        The path to the `.mat` file.

    Returns
    -------
    dict
        The updated backup dictionary.

    Notes
    -----
    If the key "REG" exists in the backup, its contents will be moved to the root level of the backup dictionary.
    """
    backup = loadmat(path_AOT)
    if "REG" in backup.keys():
        if "Macrocaetes" in backup["REG"]:
            backup["Macrocaetes"] = backup["REG"]["Macrocaetes"]
        reg_dict = deepcopy(backup["REG"])
        del backup["REG"]
        backup.update(reg_dict)

    return backup


def update_zarr_group(group, quantity, value, has_animal_axis=False, n_times=None):
    """
    Update a Zarr group with a given quantity and value.

    Parameters
    ----------
    group : zarr.hierarchy.Group
        The Zarr group to be updated.
    quantity : str
        The quantity name that needs to be updated or added.
    value : various
        The value associated with the quantity.
    has_animal_axis : bool, optional
        Whether the value carries a trailing animal axis (across-animal AOA stack).
    n_times : int, optional
        Number of time windows in the backup (rows of its ``FrameArray``).

    Notes
    -----
    1. If the quantity already exists in the group, no action is taken.
    2. The function supports specialized formatting for quantities listed in `QUANTITIES_ATTRIBUTES`.
    3. The values are either pickled or harmonized based on their nature.
    """

    # Handle special quantities listed in QUANTITIES_ATTRIBUTES
    if quantity in QUANTITIES_ATTRIBUTES:
        results = _field_formatted(quantity, value)
        for key, formatted_value in results:
            # Handle NumPy array by converting it to list
            if isinstance(formatted_value, np.ndarray):
                formatted_value = list(formatted_value)
            group.attrs[key] = formatted_value
    else:
        # Harmonize the shape of the value
        harmonized_value = _harmonize_shape(
            value, quantity_name=quantity, has_animal_axis=has_animal_axis, n_times=n_times
        )
        if quantity not in group:
            # float32, not float16: at cell-area magnitudes (~30 um^2) the float16
            # step is 1.6e-2, which is enough to move bins between domains in the
            # finest morphodynamic clustering. These averages are small, so the
            # extra storage is cheap next to a partition that shifts on rounding.
            group.create_dataset(quantity, data=harmonized_value, dtype=np.float32)
            group.attrs["creation_time"] = datetime.now().isoformat()
            # pyap-native backups weight by area RATIO SQUARED (average_over_time.py);
            # write `weights` = AreaRatios**2 so the std matches the native convention,
            # keeping the linear `AreaRatios` dataset as the area^1 alias.
            if quantity == "AreaRatios" and "weights" not in group:
                group.create_dataset(
                    "weights", data=np.square(harmonized_value), dtype=np.float32
                )


def extract_AOA_results_folder(
    group: zarr.hierarchy.Group, SAP_results_folder, quantities, verbose=True
):
    """
    Extracts information from .mat files in the AveragesOverTime (AOT) folder and stores them in a zarr group.

    This function reads the ``AOA_backup.mat`` / ``DBA_backup.mat`` of every AOA/DBA folder (other .mat files, such
    as ``name_notum.mat``, are ignored), extracts the quantities of interest, and stores them in the zarr hierarchy.
    Each backup lands in ``<motion>/D2/<field>``: ``LAGRANGIAN_TRACKING`` when the backup carries
    ``excludeLostCells`` (only cell-tracking averages have it), ``EULERIAN`` otherwise.

    Parameters
    ----------
    group : zarr.hierarchy.Group
        The root of the output store.
    SAP_results_folder : str
        The path to the SAP results folder.
    quantities : list
        The list of quantities to be extracted from the .mat files.
    verbose : bool, optional
        If True, the function will print warnings when a quantity is not found in the backup file.

    Raises
    ------
    IOError
        If there are more than one or no AOT folders in the SAP results folder.

    Returns
    -------
    None
        This function doesn't return anything. It modifies the provided zarr group in-place.

    """
    # So far we are only interested in the AveragesOverTime
    path_AOA = os.path.join(SAP_results_folder, "AOA*")
    AOA_folders = glob(path_AOA)

    path_DBA = os.path.join(SAP_results_folder, "DBA*")
    DBA_folders = glob(path_DBA)

    # AOA stacks carry a trailing animal axis; DBA differences (already collapsed
    # across animals) do not -- flag them apart so _harmonize_shape places the axes right.
    labelled_folders = [(f, True) for f in AOA_folders] + [(f, False) for f in DBA_folders]

    if len(labelled_folders) == 0:
        raise IOError(f"There is no AOA/DBA folder detected in {SAP_results_folder}")

    group_tmp = None

    for average_folder, has_animal_axis in labelled_folders:
        for root, dirs, files in os.walk(average_folder):
            for file in files:
                # only the AOA_/DBA_backup.mat: gene folders also hold a name_notum.mat
                if file.endswith("_backup.mat") and "alltime" not in file:
                    fullpath = os.path.join(root, file)

                    # only Lagrangian (cell-tracking) backups carry the lost-cell exclusion
                    names = {name for name, _, _ in spio.whosmat(fullpath)}
                    motion = "LAGRANGIAN_TRACKING" if "excludeLostCells" in names else "EULERIAN"
                    d2 = group.require_group(motion).require_group("D2")

                    field = fullpath.split(os.path.sep)[-2]
                    if field not in d2:
                        group_tmp = d2.create_group(field)
                    if group_tmp is None:
                        continue

                    extract_AOT(
                        group_tmp,
                        os.path.join(root, file),
                        quantities,
                        verbose=verbose,
                        has_animal_axis=has_animal_axis,
                    )
                    stamp_time_metadata(group_tmp)
                    stamp_aoa_std(group_tmp)  # self-guards: no-op for DBA (no animal axis)
                    stamp_aoa_centroids(group_tmp)  # materialize grid_centroids
                    group_tmp = None


def extract_AOT(group, path_AOT, quantities, verbose=False, has_animal_axis=False):
    """
    Extracts given quantities from the backup file and stores them in a zarr group.

    This function reads quantities from a MATLAB backup file and stores each quantity either as
    a dataset or attribute in the provided zarr group. The storage method depends on the quantity itself.
    Some quantities are positioned differently depending on their name and some belong to attributes
    instead of arrays. Some of the axes are also moved to correct their positions.

    Parameters
    ----------
    group : zarr.hierarchy.Group
        The zarr group where the extracted datasets and attributes will be stored.
    path_AOT : str
        The path to the MATLAB backup file.
    quantities : list
        The list of quantities that are to be extracted from the backup file.
    verbose : bool, optional
        If True, the function will print warnings when a quantity is not found in the backup file.

    Returns
    -------
    None
        This function doesn't return anything. It modifies the provided zarr group in-place.

    """
    backup = load_and_update_backup(path_AOT)

    # squeeze_me flattens the single row of a single-window backup; restore (T, 2)
    for key in ("TimeArray", "FrameArray"):
        if key in backup:
            backup[key] = np.reshape(backup[key], (-1, 2))
    n_times = len(backup["FrameArray"]) if "FrameArray" in backup else None

    if "REG" in backup.keys():
        reg_dict = deepcopy(backup["REG"])
        del backup["REG"]
        backup.update(reg_dict)

    for quantity in quantities:
        if quantity not in backup.keys() and verbose:
            warnings.warn(f"{quantity} not found in {path_AOT}")

        elif quantity in backup.keys():
            update_zarr_group(
                group,
                quantity,
                backup[quantity],
                has_animal_axis=has_animal_axis,
                n_times=n_times,
            )


def extract_SAP_info(
    SAA: zarr.hierarchy.Group, SAP_info_path: str, quantities: list = []
):
    """
    Extracts the information from a SAP_info file and adds them as attributes to a zarr group.
    This function reads the SAP_info file line by line, extracts the key-value pairs that match the quantities
    provided and adds them as attributes to the provided zarr group. It also reformats the fields and converts
    the values to appropriate data types if necessary.
    Parameters
    ----------
    SAA : zarr.hierarchy.Group
        The zarr group where the extracted key-value pairs will be added as attributes.
    SAP_info_path : str
        The path to the SAP_info file.
    quantities : list, optional
        The list of quantities to be extracted from the SAP_info file, by default an empty list.
    Returns
    -------
    None
        This function doesn't return anything. It modifies the provided zarr group in-place.
    """
    # Reading the SAP info
    with open(SAP_info_path, "r") as SAP_info_file:
        SAP_info_lines = SAP_info_file.readlines()

    # create a dictionary to hold the key-value pairs
    dictionary_final = {}

    # create regex pattern
    # pattern = r"(?P<key>{})\s*=\s*(?P<value>.*?);".format("|".join(quantities))
    pattern = r"^[^\%]*?(?P<key>{})\s*=\s*(?P<value>.*?);".format("|".join(quantities))

    # go through each line in the input
    for line in SAP_info_lines:
        match = re.search(pattern, line)
        # if match found

        if match:
            # We reformat the field
            key_tmp = match.group("key")
            value_tmp = match.group("value").strip()
            results = _field_formatted(key_tmp, value_tmp)

            for key, value in results:
                # check if value is a list
                if value.startswith("[") and value.endswith("]"):
                    # remove brackets and split on comma
                    if value[
                        1:-1
                    ].strip():  # if there are any characters between the brackets
                        value = [float(x) for x in value[1:-1].split(",")]
                    else:  # if there aren't any characters between the brackets, set value as an empty list
                        value = []

                # MATLAB cell array of names, e.g. {'Cad', 'Myo'} -> ['Cad', 'Myo']
                elif value.startswith("{") and value.endswith("}"):
                    value = re.findall(r"'([^']*)'", value)

                # check if value is a string (surrounded by quotes)
                elif value.startswith("'") and value.endswith("'"):
                    value = value[1:-1]

                # check if value is an int or float
                elif value:
                    try:
                        value = int(value)
                    except ValueError:
                        try:
                            value = float(value)
                        except ValueError:
                            pass

                # if there is a value after the "=" sign
                else:
                    continue  # skip to the next iteration if the value is empty

                # store in the zarr array
                SAA.attrs[key] = value

    return None


def extract_tracking_results_folder(
    group: zarr.hierarchy.Group, results_folder: str, gridsize: str = "LGrid"
):
    """
    Extracts tracking results from CellTracking and appends it to the provided zarr group.
    This tracking is used to obtain the effect of advection onto the spatial transcriptome

    Parameters
    ----------
    group : zarr.hierarchy.Group
        The Zarr group to which the tracking results will be appended. It should contain
        an 'IMAGE' field with 'outlines' data.

    SAP_results_folder : str
        Path to the folder containing the results from the single animal processing. This folder
        should contain cell tracking outputs from the CellTracking process.

    gridsize : str, optional
        The name of the grid size. By default, it is set to "Lgrid".

    Raises
    ------
    KeyError:
        If the provided group does not have an 'IMAGE' field or if the 'IMAGE' field
        lacks the 'outlines' data.
    """

    if "IMAGE" not in group.keys():
        raise KeyError("There is not IMAGE field in the group")

    if "outlines" not in group["IMAGE"]["D2"].keys():
        raise KeyError("There are not OUTLINES in the IMAGE/D2 field of the group")

    results_folder = os.path.normpath(results_folder)
    animal_name = os.path.basename(results_folder)

    cell_tracking_path = os.path.join(
        results_folder, f"SAP_{animal_name}", f"CT_{animal_name}", gridsize
    )

    # Generate a division agnostic Relative, Absolute mapping
    mapping_dict = get_mapping_dicts(
        cell_tracking_path, group.IMAGE.D2.raw, ignore_divisions=True
    )
    mapping_dict = [
        {int(k): [int(i) for i in v] for k, v in d.items()} for d in mapping_dict
    ]

    labels_img = relabel_movie(group["IMAGE"]["D2"]["outlines"], mapping_dict)

    group["TRACKING"].create_dataset(
        "masks_division_agnostic", data=labels_img, dtype=labels_img.dtype
    )




