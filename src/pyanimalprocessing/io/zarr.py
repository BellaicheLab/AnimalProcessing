"""Zarr conversion pipeline for MATLAB SAP/MAP analysis outputs.

Orchestrates the conversion of Single Animal Processing (SAP) and
Multiple Animal Processing (MAP) folder structures into structured
zarr hierarchies suitable for downstream Python analysis and napari
visualization.
"""

import os
import re
import warnings
from glob import glob
from pathlib import Path

import numpy as np
import zarr

from pyanimalprocessing.io.image import (
    create_group_from_image_folder,
    load_stack,
    save_stack,
)
from pyanimalprocessing.io.matlab import (
    extract_AOA_results_folder,
    extract_AOT_results_folder,
    extract_SAP_info,
    extract_tracking_results_folder,
    stamp_registration_affine,
)
from pyanimalprocessing.io.misc import load_yml, extract_digit_number

# Config directory lives inside the package
_CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"


def convert_SAP_to_zarr(
    project_folder, sap_info=None, output_zarr=None, gridsize="LGrid"
):
    """Convert a SAP project folder (raw images + SEG/SAP results) to a nested zarr store.

    Parameters
    ----------
    project_folder : str
        Path to the SAP project folder to convert; its basename is used as the animal name.
    sap_info : str, optional
        Path to the ``SAP_info_<name>.m`` file; its metadata is stored as root attrs.
    output_zarr : str, optional
        Folder that will contain the new zarr store. Defaults to ``project_folder``.
    gridsize : str, optional
        Name of the tracking grid subfolder under ``CT_<name>/``. Defaults to "LGrid".
    """

    # Setting paths
    project_folder = Path(project_folder)
    animal_name = project_folder.name

    if output_zarr is None:
        output_zarr = project_folder

    convert_animal_to_zarr(
        project_folder, animal_name, output_zarr, sap_info=sap_info, gridsize=gridsize
    )


def convert_animal_to_zarr(
    input_folder: str,
    animal_name: str,
    output_folder: str,
    sap_info=None,
    gridsize="LGrid",
):
    """Convert a single animal's SAP results to a structured zarr hierarchy.

    Orchestrates the full conversion: raw images, outlines, masks, SAP
    metadata, time-averaged tensor quantities (AOT), and cell-tracking
    results.

    Parameters
    ----------
    input_folder : str
        Root folder containing ``SEG_<name>/`` and ``SAP_<name>/``.
    animal_name : str
        Animal identifier (e.g. ``"210507_vi_pupa1"``).
    output_folder : str
        Path for the output zarr directory.
    sap_info : str, optional
        Path to the ``SAP_info_<name>.m`` metadata file.
    gridsize : str, optional
        Cell-tracking grid size subfolder name. Default ``"LGrid"``.
    """
    # Setting Path objects
    output_folder, input_folder = Path(output_folder), Path(input_folder)

    # Loading config file for quantities to load
    path_yml = _CONFIG_DIR / "extract_SAP.yml"
    quantities_config = load_yml(path_yml)

    # # Construct paths related to SEG and SAP folders
    seg_folder_name = f"SEG_{animal_name}"
    sap_folder_name = f"SAP_{animal_name}"
    seg_dir = input_folder / seg_folder_name
    sap_folder = input_folder / sap_folder_name

    # Construct mask and outline paths
    masks_path = seg_dir / f"roi_{animal_name}"
    outlines_path = seg_dir / f"results_{animal_name}"

    # Convert all the raw images
    convert_project_folder_to_zarr(
        output_folder,
        input_folder,
        outlines_path,
        masks_path,
        sap_folder,
        sap_info_path=sap_info,
        metadata=quantities_config["METADATA"],
    )

    animal = zarr.open(output_folder, "a")

    # Convert the AOT folder into the canonical top-level TIME_AVERAGE/<grid>/D2/<backup>
    # (+ stamp grid_type on GRID/<grid>/GRID_PROPERTIES).
    extract_AOT_results_folder(
        animal,
        sap_folder,
        quantities=quantities_config["TENSORS"],
        verbose=True,
    )

    # Store the per-animal registration affine (built from xFactor/yFactor + origins)
    # on the root attrs; it is applied when plotting the common-frame AOT grid.
    stamp_registration_affine(animal)

    # Convert the cell-tracking results into a "division-agnostic" mask used
    # downstream by the morphodomains advection / lagrangian analyses
    # (animal["TRACKING"]["masks_division_agnostic"]).
    try:
        extract_tracking_results_folder(animal, input_folder, gridsize=gridsize)
    except Exception as e:
        warnings.warn(
            f"Failed to extract tracking results for {animal_name}: {e}"
        )


def convert_project_folder_to_zarr(
    output_zarr,
    raw_image_path,
    outlines_path,
    masks_path,
    sap_folder,
    sap_info_path=None,
    metadata=None,
):
    """
    Initialize a zarr store and write ``IMAGE/D2/{raw,outlines,mask}`` plus root metadata.

    Parameters
    ----------
    output_zarr : str
        Path to the zarr store to create (or open in append mode if it exists).
    raw_image_path : str
        Path to the folder containing raw images (channel tiffs ``c1_*``, ... are stacked).
    outlines_path : str
        Path to the folder containing segmentation outline images.
    masks_path : str
        Path to the folder containing ROI mask images.
    sap_folder : str
        Path to the ``SAP_<name>/`` results folder (used to locate metadata).
    sap_info_path : str, optional
        Path to ``SAP_info_<name>.m``; its fields are stored as root attrs.
    metadata : dict, optional
        Extra root attrs to store as-is.
    """

    # Create the output folder
    try:
        # Attempt to create the output folder
        animal = zarr.open_group(output_zarr, mode="w-")
    except zarr.errors.ContainsGroupError:
        # If a group already exists, open it in read-write mode
        animal = zarr.open_group(output_zarr, mode="a")

    animal_name = os.path.basename(os.path.normpath(output_zarr))

    # Create the first-level nested structure if it doesn't exist
    groups = ["IMAGE", "GRID", "TRACKING"]
    for group in groups:
        if group not in animal:
            animal.create_groups(group)
    image_d2 = animal.require_group("IMAGE").require_group("D2")

    # Identify unique channels ('raw' = segmentation channel, plus cX fluorescence)
    all_files = sorted(glob(os.path.join(raw_image_path, "*.tif")))
    unique_channels = set()
    for file in all_files:
        match = re.search(r"(c\d+)_", os.path.basename(file))
        unique_channels.add(match.group(1) if match else "raw")

    # 'raw' first, then c1, c2, … — stacked into IMAGE/D2/raw as (t, c, y, x)
    channel_order = (["raw"] if "raw" in unique_channels else []) + sorted(
        c for c in unique_channels if c != "raw"
    )
    channel_stacks = []
    for channel in channel_order:
        if channel == "raw":
            # Exclude files starting with c[0-9]+_
            motif = r"^(?!c\d+_).*\.tif$"
        else:
            motif = rf"{channel}.*\.tif$"

        names, images = load_stack(
            os.path.abspath(raw_image_path), motif=motif, as_stack=True
        )
        animal.attrs["ndigits"] = extract_digit_number(names[0])
        channel_stacks.append(images)  # keep native bit depth

        if os.path.abspath(output_zarr) != os.path.abspath(raw_image_path):
            name = animal_name if channel == "raw" else f"{channel}{animal_name}"
            save_stack(output_zarr, name, channel_stacks[-1], extension="tif")

    height, width = channel_stacks[0].shape[1:3]
    if "raw" not in image_d2:
        raw = np.stack(channel_stacks, axis=1)  # (t, c, y, x)
        image_d2.create_dataset(
            "raw", data=raw, dtype=raw.dtype, chunks=(1, 1, height, width)
        )

    # Load and store segmentation outlines and ROI mask under IMAGE/D2
    if "outlines" not in image_d2:
        try:
            create_group_from_image_folder(
                outlines_path, "seg.*.png", "outlines", image_d2, height, width
            )
        except Exception:
            warnings.warn(f"The results folder appears to be empty at {outlines_path}")
    if "mask" not in image_d2:
        try:
            create_group_from_image_folder(
                masks_path, "roi.*.png", "mask", image_d2, height, width
            )
        except Exception:
            warnings.warn(f"The masks folder appears to be empty at {masks_path}")

    # Extract animal-level metadata (frameRef, xFactor, dt, timeRef, ...) from
    # the SAP_info.m file if provided. These attributes are required by downstream
    # consumers (e.g. the morphodomains figure framework reads animal.attrs["frameRef"],
    # animal.attrs["dt"], animal.attrs["xFactor"], etc.).
    if sap_info_path is not None and metadata is not None:
        try:
            extract_SAP_info(animal, sap_info_path, quantities=metadata)
        except Exception as e:
            warnings.warn(
                f"Failed to extract SAP_info metadata from {sap_info_path}: {e}"
            )

    # Canonical attr names (readers use frame_ref/time_ref); old names kept as-is.
    if "frameRef" in animal.attrs and "frame_ref" not in animal.attrs:
        animal.attrs["frame_ref"] = animal.attrs["frameRef"]
    if "timeRef" in animal.attrs and "time_ref" not in animal.attrs:
        animal.attrs["time_ref"] = animal.attrs["timeRef"]
    # Canonical attrs downstream consumers require (name/scaling). `channels` is left
    # to the semantic source (SAP_info / manual — the raw channel is not self-describing),
    # and IMAGE/D2/label is produced by the Python analyze_labels / tracking path.
    if "name" not in animal.attrs:
        animal.attrs["name"] = animal_name
    if "scaling" not in animal.attrs and "scale1D" in animal.attrs:
        animal.attrs["scaling"] = animal.attrs["scale1D"]


def convert_MAP_to_zarr(average_result_folder, output_zarr=None, verbose=False):
    """Convert MAP (AOA or DBA) averages into a structured zarr file.

    Emits the nested ``<motion>/D2/<field>`` schema — structurally symmetric with the
    pure-Python across-animal-average road — with materialized ``grid_centroids``. The motion
    (``EULERIAN`` / ``LAGRANGIAN_TRACKING``) is read from each backup.

    Parameters
    ----------
    average_result_folder : str
        Path to the folder containing AOA or DBA averages.
    output_zarr : str, optional
        Output zarr path. Defaults to ``average_result_folder``.
    verbose : bool, optional
        Print warnings for missing quantities. Default False.
    """

    # Setting paths
    average_result_folder = Path(average_result_folder)

    if output_zarr is None:
        output_zarr = average_result_folder
    elif os.path.isdir(output_zarr):
        output_zarr = os.path.join(output_zarr, os.path.basename(average_result_folder))

    # Create the output folder
    try:
        # Attempt to create the output folder
        animal = zarr.open_group(output_zarr, mode="w-")
    except zarr.errors.ContainsGroupError:
        # If a group already exists, open it in read-write mode
        animal = zarr.open_group(output_zarr, mode="a")

    # find the quantities to fetch
    path_yml = _CONFIG_DIR / "extract_MAP.yml"
    data = load_yml(path_yml)

    extract_AOA_results_folder(
        animal,
        average_result_folder,
        quantities=data["TENSORS"],
        verbose=verbose,
    )
