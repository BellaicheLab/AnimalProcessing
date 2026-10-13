# test_python_route.py
#
# End-to-end test of the pure-Python route and its convergence onto the shared
# schema: instantiate -> analyze_labels (CELL) -> space_registrate ->
# generate_common_grid (GRID_PROPERTIES) -> average_over_space (CELL->GRID).
# Unlike test_analyze_labels (which only checks property presence), this asserts
# the CELL arrays READ BACK, and that the gridded per-box quantities are produced
# in the layout the downstream (average_over_time / plotting) consumers expect.
import numpy as np
import pytest

CELL_PROPERTIES = ["area", "centroid", "axial_polarity"]
FEATURE_WIDTH = {"area": 1, "centroid": 2, "axial_polarity": 4}


@pytest.mark.parametrize(
    "setup_cell_field",
    [
        {
            "animals": ["animal_single_channel_single_timepoint"],
            "analyze_labels": True,
            "space_registrate": True,
            "rescale_animals": True,
            "average_over_space": True,
        },
        {
            "animals": [
                "animal_single_channel_single_timepoint",
                "animal_multiple_channels_multiple_timepoints",
            ],
            "analyze_labels": True,
            "space_registrate": True,
            "rescale_animals": True,
            "average_over_space": True,
        },
    ],
    indirect=True,
)
def test_python_route_reaches_shared_schema(setup_cell_field):
    animals = setup_cell_field
    for animal in animals:
        # CELL properties exist AND read back (guards against malformed storage).
        for prop in CELL_PROPERTIES:
            assert prop in animal["CELL"]["D2"]
            block = animal["CELL"]["D2"][prop][:]
            assert block is not None

        # generate_common_grid populated the full GRID geometry.
        gp = animal["GRID/EULERIAN/GRID_PROPERTIES"]
        for field in ("X", "Y", "area_ratios", "centroids", "mask_positions"):
            assert field in gp

        # average_over_space wrote the gridded per-box quantities the
        # time-averaging / plotting layers consume.
        gridded = animal["GRID/EULERIAN/CELL/D2"]
        assert "cell_number" in gridded
        for prop in CELL_PROPERTIES:
            name = f"{prop}_mean_per_cell"
            assert name in gridded, f"{name} not written by average_over_space"
            arr = gridded[name]
            # (t, c, gy, gx, feature)
            assert arr.ndim == 5
            assert arr.shape[-1] == FEATURE_WIDTH[prop]


@pytest.mark.parametrize(
    "setup_cell_field",
    [
        {
            "animals": ["animal_single_channel_single_timepoint"],
            "analyze_labels": True,
            "space_registrate": True,
            "rescale_animals": True,
            "average_over_space": True,
        }
    ],
    indirect=True,
)
def test_gridded_quantity_matches_grid_shape(setup_cell_field):
    animal = setup_cell_field[0]
    area_ratios = animal["GRID/EULERIAN/GRID_PROPERTIES/area_ratios"]
    area_grid = animal["GRID/EULERIAN/CELL/D2/area_mean_per_cell"]
    # Averaged quantity lives on the same (gy, gx) grid as the area ratios.
    assert area_grid.shape[2:4] == area_ratios.shape[2:4]
