"""CLI entry points for converting MATLAB SAP/MAP folders to zarr."""

from pyanimalprocessing.io.zarr import convert_SAP_to_zarr, convert_MAP_to_zarr
import argparse
import os


def zarrify_SAP():
    """Entry point for the `zarrify_SAP` command-line script."""

    # Initialize the argument parser
    parser = argparse.ArgumentParser(
        description="Zarrification of the single animal pipeline folder"
    )

    # Changed to nargs='+' to accept multiple paths
    parser.add_argument(
        "animal_path",
        type=str,
        nargs='+',
        help="Paths to the single animal pipeline folder dataset containing all the images, outlines, SAP"
    )

    # Changed to nargs='*' to accept multiple or no paths
    parser.add_argument(
        "--SAP_info_path",
        type=str,
        default=None,
        nargs='*',
        help="Paths to the SAP info of the animal"
    )

    # Changed to nargs='*' to accept multiple or no paths
    parser.add_argument(
        "--output_path",
        type=str,
        default=None,
        nargs='*',
        help="Output paths of the zarrs"
    )

    parser.add_argument(
        "--gridsize",
        type=str,
        default="LGrid",
        help="Size of the grid of the tracking, ex:LGrid"
    )

    # Parse the command-line arguments
    args = parser.parse_args()

    # Validate the lengths of the lists
    if args.SAP_info_path is not None and len(args.SAP_info_path) != len(args.animal_path):
        raise ValueError(
            "The number of SAP info paths must match the number of animal paths.")

    # Handle single output_path pointing to a folder
    if args.output_path is not None and len(args.output_path) == 1 and os.path.isdir(args.output_path[0]):
        base_output_path = args.output_path[0]
        args.output_path = [os.path.join(base_output_path, os.path.basename(
            input_path)) for input_path in args.animal_path]

    if args.output_path is not None and len(args.output_path) != len(args.animal_path):
        raise ValueError(
            "The number of output paths must match the number of animal paths.")

    # Loop through the paths and perform the zarrification
    for animal, sap_info, output in zip(
        args.animal_path,
        args.SAP_info_path or [None] * len(args.animal_path),
        args.output_path or [None] * len(args.animal_path)
    ):
        convert_SAP_to_zarr(
            project_folder=animal,
            sap_info=sap_info,
            output_zarr=output,
            gridsize=args.gridsize
        )


def zarrify_MAP():
    """
    Entry point for the 'convert_MAP_to_zarr' command-line script.

    This script converts an average of animals (Whether AOA or DBA) into a zarr folder to be later used in python


    Example:
        To execute this script from the command line, run:
        zarrify_MAP '../avg_vi_Tolloi' where ../avg_vi_Tolloi contains multiple time intervals and grid resolutions 
    """

    # Initialize the argument parser
    parser = argparse.ArgumentParser(
        description="Zarrification of the average of multiple animals averages (AOA or DBA)"
    )

    # Changed to nargs='+' to accept multiple paths
    parser.add_argument(
        "average_path",
        type=str,
        nargs='+',
        help="Paths to the average folders containing all AOA/DBA"
    )

    # Changed to nargs='*' to accept multiple or no output paths
    parser.add_argument(
        "--output_path",
        type=str,
        default=None,
        nargs='*',
        help="Output paths of the zarrs"
    )

    # Parse the command-line arguments
    args = parser.parse_args()

    # Check if the number of output paths matches the number of average paths
    if args.output_path is not None:
        if len(args.output_path) != len(args.average_path):
            raise ValueError(
                "The number of output paths must match the number of average paths.")

    # Loop over each average folder and corresponding output folder
    for avg_path, out_path in zip(args.average_path, args.output_path or [None] * len(args.average_path)):

        # Zarrify the folder
        convert_MAP_to_zarr(average_result_folder=avg_path,
                            output_zarr=out_path)
