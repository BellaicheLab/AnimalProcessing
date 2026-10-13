"""Image stack I/O: load/save TIF/PNG sequences and create zarr datasets."""

import os
import re
import warnings

import numpy as np
from skimage.io import imread, imsave
from tqdm import tqdm

from ..utils.conversions import _format_n_decimals


def save_stack(folder_path, base_name, stack, number_of_digits=4, extension="png"):
    """
    Save a 3D image stack as individual 2D image files.

    This function iterates through each 2D slice of a given 3D image stack and saves
    them as separate image files in the specified folder. The filenames are constructed
    by combining the provided base name with a zero-padded frame number.

    Parameters
    ----------
    folder_path : str
        Path to the destination folder where the 2D image files will be saved.

    base_name : str
        Base name to be used for the saved image files. Each file will be named in the format:
        {base_name}_{frame_number}.png, where frame_number is a zero-padded four-digit number
        starting from 0001.

    stack : numpy.ndarray
        3D image stack where the first dimension represents the number of 2D slices.

    number_of_digits: int
        number of digits for the numbering of the saved files

    extension:str
        extension of the saved files

    """
    for i in tqdm(range(stack.shape[0])):
        frame_number = _format_n_decimals(i + 1, n=number_of_digits)
        filename = f"{base_name}_{frame_number}.{extension}"
        output_file = os.path.join(folder_path, filename)

        with warnings.catch_warnings():
            warnings.simplefilter("ignore", category=UserWarning)
            imsave(output_file, stack[i], dtype=stack.dtype)


def load_stack(folder_path: str, motif: str, expected_size=None, as_stack=True) -> (list, np.array):
    """
    Load a sequence of image files into a stack (3D array) or a list of 2D arrays.

    This function is primarily used for loading frames of a movie or slices of a 3D volume.

    Parameters
    ----------
    folder_path : str
        The path to the directory containing the image files.
    motif : str
        A string that specifies the pattern to match files.
        For example, ``*.png`` would match all PNG files in the specified directory.
    expected_size : tuple, optional
        The expected size of each image. If provided, only images of this size will be included in the output.
        Default is None.
    as_stack : bool, optional
        Whether to return the images as a 3D array (True) or as a list of 2D arrays (False). Default is True.

    Returns
    -------
    list
        A list containing the paths to the image files that were loaded.
    np.array
        If ``as_stack`` is True, a 3D numpy array containing the image data.
        If ``as_stack`` is False, a list of 2D numpy arrays with each element representing an individual image.

    """
    # Fetching paths
    # Compile the regular expression from the motif
    regex = re.compile(motif)

    # List all files and filter with the regex
    all_files = os.listdir(folder_path)
    files = sorted([file for file in all_files if regex.match(file)])

    pbar = tqdm(files, position=0, leave=True)
    frames = []

    for i, file in enumerate(pbar):  # Add enumerate to get index i
        img = np.array(imread(os.path.join(folder_path, file)))
        if expected_size and img.shape == expected_size:
            frames.append(img)
        else:
            frames.append(img)

    if as_stack:
        movie = np.stack(frames, axis=0)
    else:
        movie = frames

    return [files, movie]


def create_group_from_image_folder(
    image_folder, images_motif, group_name, parent_group, image_height, image_width
):
    """
    Load and store data from a specified path into a zarr group.

    Parameters
    ----------
    image_folder : str
        Path to the folder containing data files.
    images_motif: str
        Motif of the images inside the folder
    group_name : str
        Name of the dataset to create in the zarr group.
    parent_group : zarr.hierarchy.Group
        Zarr group where the dataset will be stored.
    image_height : int
        Height of the images.
    image_width : int
        Width of the images.

    Returns
    -------
    data : np.ndarray
        Loaded and processed data.
    """
    data = load_stack(image_folder, motif=images_motif, as_stack=True)[
        1
    ].astype(np.uint8)
    parent_group.create_dataset(
        group_name, data=data, dtype=data.dtype, chunks=(
            1, image_height, image_width)
    )
    return data

