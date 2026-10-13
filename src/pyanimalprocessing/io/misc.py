"""Miscellaneous I/O helpers: YAML loading and filename parsing."""

import re

import yaml


def load_yml(path: str):
    """
    Load a YAML file from the given path.

    Parameters
    ----------
    path : str
        The path to the YAML file.

    Returns
    -------
    dict
        The data from the YAML file.
    """
    with open(path, 'r') as stream:
        return yaml.safe_load(stream)

def extract_digit_number(name: str):
    """
    extract the number of digits from a standard pipeline image name
    (ex : Cad_001.tif -> 3)
    """

    motif = re.compile(r"([0-9]+)\.tif")
    matches = re.search(motif, name)
    return len(matches.group(1))

    