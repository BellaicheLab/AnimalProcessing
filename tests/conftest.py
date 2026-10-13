# conftest.py — shared 2D fixtures for the pyanimalprocessing test suite.

from pathlib import Path

import numpy as np
import pytest

from pyanimalprocessing.preprocessing.instantiate_animal import instantiate_animal
from pyanimalprocessing.average_over_space import average_over_space
from pyanimalprocessing.rescaling.registration import generate_common_grid
from pyanimalprocessing.analyze_labels import analyze_labels

HERE = Path(__file__).resolve().parent
DATA = HERE / "data" / "animals" / "2D"

run_viewer = False


def _make_animal(store_dir, name, **kwargs):
    animal = instantiate_animal(
        output_zarr=str(store_dir / name),
        overwrite=True,
        dt=5,
        scaling=0.161,
        temperature=25,
        **kwargs,
    )
    animal.attrs["time_ref"] = "17h00"
    animal.attrs["frame_ref"] = 3
    return animal


@pytest.fixture(scope="session")
def animal_single_channel_single_timepoint(tmp_path_factory):
    return _make_animal(
        tmp_path_factory.mktemp("scst"),
        "single_channel_single_timepoint",
        raw_image_2d=str(DATA / "single_channel_single_timepoint/raw"),
        raw_image_2d_order="yx",
        labels_2d=str(DATA / "single_channel_single_timepoint/label"),
        labels_2d_order="yx",
        channel_names=["ECad"],
    )


@pytest.fixture(scope="session")
def animal_multiple_channels_single_timepoint(tmp_path_factory):
    return _make_animal(
        tmp_path_factory.mktemp("mcst"),
        "multiple_channels_single_timepoint",
        raw_image_2d=str(DATA / "multiple_channels_single_timepoint/raw"),
        raw_image_2d_order="c(yx)",
        labels_2d=str(DATA / "multiple_channels_single_timepoint/label"),
        labels_2d_order="yx",
        channel_names=["ECad", "Myosin"],
    )


@pytest.fixture(scope="session")
def animal_single_channel_multiple_timepoints(tmp_path_factory):
    return _make_animal(
        tmp_path_factory.mktemp("scmt"),
        "single_channel_multiple_timepoints",
        raw_image_2d=str(DATA / "single_channel_multiple_timepoints/raw"),
        raw_image_2d_order="t(yx)",
        labels_2d=str(DATA / "single_channel_multiple_timepoints/label"),
        labels_2d_order="t(yx)",
        channel_names=["ECad"],
    )


@pytest.fixture(scope="session")
def animal_multiple_channels_multiple_timepoints(tmp_path_factory):
    return _make_animal(
        tmp_path_factory.mktemp("mcmt"),
        "multiple_channels_multiple_timepoints",
        raw_image_2d=str(DATA / "multiple_channels_multiple_timepoints/raw"),
        raw_image_2d_order="ct(yx)",
        labels_2d=str(DATA / "multiple_channels_multiple_timepoints/label"),
        labels_2d_order="t(yx)",
        channel_names=["ECad", "Myosin"],
    )


@pytest.fixture(scope="function")
def setup_cell_field(request):
    """Run the CELL→GRID pipeline on requested 2D animal fixtures.

    request.param = {"animals": [<fixture names>], + any of
    "space_registrate", "analyze_labels", "rescale_animals", "average_over_space"}.
    """
    animals = [request.getfixturevalue(a) for a in request.param["animals"]]
    properties = ["area", "centroid", "axial_polarity", "contours", "coords"]

    if "space_registrate" in request.param:
        for animal in animals:
            create_space_registration(animal)

    if "analyze_labels" in request.param:
        for animal in animals:
            analyze_labels(
                animal,
                analysis_type="cell",
                properties=properties,
                dimension="D2",
                overwrite=True,
            )

    if "rescale_animals" in request.param:
        generate_common_grid(animals, boxsize=[5, 5], overlap=0.5)

    if "average_over_space" in request.param:
        non_averageable = ["contours", "coords"]
        average_properties = [p for p in properties if p not in non_averageable]
        average_over_space(
            animals,
            average_properties,
            global_spatial_type="eulerian",
            local_spatial_type="cell",
            dimension="D2",
        )

    return animals


def create_space_registration(animal):
    space_registration = animal.require_group("SPACE_REGISTRATION").require_group(
        "default"
    )
    landmarks = np.array([[0.0, 0, 0], [0.0, 0, 90], [0.0, 90, 0], [0.0, 90, 90]])
    lines = np.array([])
    space_registration.create_dataset("landmarks", data=landmarks, overwrite=True)
    space_registration.create_dataset("lines", data=lines, overwrite=True)
    space_registration.attrs["angle"] = None
