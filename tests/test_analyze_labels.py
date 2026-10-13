# test_analyze_labels.py
#
# Exercises EVERY property analyze_labels integrates (imported from the registry
# so the test stays in sync), on the 2D animal fixtures. 3D fixtures omitted
# (dropped epithelial_surface module).
#
# Every registry property computes and stores. "slice" was pruned from the registry:
# regionprops returns python slice objects, which are not array-storable, and "bbox_tuple"
# already stores the same bounds. It is kept below so requesting it stays a hard error.
import numpy as np
import pytest

from pyanimalprocessing.analyze_labels import CUSTOM_PROPERTIES, analyze_labels

# prop -> reason it is not part of the registry.
KNOWN_BROKEN = {
    "slice": "pruned from the registry: python slice objects, superseded by bbox_tuple",
}

ALL_PROPERTIES = list(dict.fromkeys(CUSTOM_PROPERTIES))
WORKING_PROPERTIES = [p for p in ALL_PROPERTIES if p not in KNOWN_BROKEN]

FIXTURES = [
    "animal_single_channel_single_timepoint",
    "animal_multiple_channels_single_timepoint",
    "animal_single_channel_multiple_timepoints",
    "animal_multiple_channels_multiple_timepoints",
]


@pytest.mark.parametrize("animal_fixture", FIXTURES)
def test_analyze_labels_all_working_properties(request, animal_fixture):
    """Every working property computes, is stored under CELL/D2 and reads back per cell."""
    animal = request.getfixturevalue(animal_fixture)
    analyze_labels(
        animal,
        analysis_type="cell",
        properties=WORKING_PROPERTIES,
        dimension="D2",
        n_jobs=1,
    )
    n_cells = np.shape(animal["CELL"]["D2"]["area"][0, 0])[0]
    for prop in WORKING_PROPERTIES:
        assert prop in animal["CELL"]["D2"], f"Property {prop} not found in CELL/D2"
        dataset = animal["CELL"]["D2"][prop]
        # ragged properties have no channel axis
        stored = dataset[0] if dataset.ndim == 1 else dataset[0, 0]
        assert (
            np.shape(stored)[0] == n_cells
        ), f"Property {prop} did not read back one entry per cell"


@pytest.mark.parametrize(
    "prop", [pytest.param(p, marks=pytest.mark.xfail(reason=r, strict=True)) for p, r in KNOWN_BROKEN.items()]
)
def test_analyze_labels_known_broken_properties(
    animal_single_channel_single_timepoint, prop
):
    """Properties pruned from the registry: requesting one must fail (xfail)."""
    animal = animal_single_channel_single_timepoint
    analyze_labels(
        animal, analysis_type="cell", properties=[prop], dimension="D2", n_jobs=1,
        overwrite=True,
    )
    assert prop in animal["CELL"]["D2"]
