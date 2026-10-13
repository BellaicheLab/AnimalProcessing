# test_grid_geometry.py
#
# Unit tests for the MATLAB-converter grid helpers: stamp_grid_geometry (the
# frame-independent geometry the converter is allowed to fill) and
# _grid_type_from_name. These guard the single most fragile MATLAB<->Python
# boundary: exactly which GRID_PROPERTIES fields the converter writes, and which
# it deliberately leaves to generate_common_grid.
import numpy as np
import pytest
import zarr

from pyanimalprocessing.io.matlab import _grid_type_from_name, stamp_grid_geometry

# The archetype-frame geometry stamp_grid_geometry must NOT invent (only
# generate_common_grid can reconstruct these).
PARITY_EXCEPTION_FIELDS = [
    "matrix_transform",
    "centroids",
    "X",
    "Y",
    "box_corners",
    "mask_positions",
    "lagrangian_grid",
]


def _fresh_grid_properties():
    return zarr.group().create_group("GRID_PROPERTIES")


def test_stamp_grid_geometry_writes_exactly_the_geometry_attrs():
    gp = _fresh_grid_properties()
    stamp_grid_geometry(
        gp,
        box_width=20,
        box_height=20,
        overlap=0.5,
        scaling=0.161,
        x_factor=1,
        y_factor=1,
        image_shape=(512, 1024),
    )
    assert set(gp.attrs.keys()) == {
        "box_size_microns",
        "overlap",
        "scaling",
        "image_shape",
    }
    assert gp.attrs["overlap"] == 0.5
    assert gp.attrs["scaling"] == 0.161
    assert gp.attrs["image_shape"] == [512, 1024]


def test_stamp_grid_geometry_box_size_microns_formula():
    gp = _fresh_grid_properties()
    # box_size_microns = [box_height*scaling*y_factor, box_width*scaling*x_factor]
    stamp_grid_geometry(
        gp,
        box_width=248.447,
        box_height=248.447,
        overlap=0.5,
        scaling=0.161,
        x_factor=1.0,
        y_factor=1.0,
        image_shape=(100, 100),
    )
    box = gp.attrs["box_size_microns"]
    # ~40 microns, matching the atlas ground truth.
    np.testing.assert_allclose(box, [40.0, 40.0], atol=0.01)


def test_stamp_grid_geometry_respects_axis_factors():
    gp = _fresh_grid_properties()
    stamp_grid_geometry(
        gp,
        box_width=10,
        box_height=20,
        overlap=0.5,
        scaling=2.0,
        x_factor=3.0,
        y_factor=5.0,
        image_shape=(1, 1),
    )
    # [height*scaling*y_factor, width*scaling*x_factor]
    assert gp.attrs["box_size_microns"] == [20 * 2.0 * 5.0, 10 * 2.0 * 3.0]


def test_stamp_grid_geometry_does_not_invent_archetype_geometry():
    gp = _fresh_grid_properties()
    stamp_grid_geometry(
        gp,
        box_width=20,
        box_height=20,
        overlap=0.5,
        scaling=0.161,
        x_factor=1,
        y_factor=1,
        image_shape=(64, 64),
    )
    for field in PARITY_EXCEPTION_FIELDS:
        assert field not in gp.attrs
        assert field not in gp


@pytest.mark.parametrize(
    "name, expected",
    [
        ("LGrid_40um", "lagrangian_tracking"),
        ("LGrid", "lagrangian_tracking"),
        ("EGrid_40um", "eulerian"),
        ("EGrid", "eulerian"),
        ("something_else", "eulerian"),
    ],
)
def test_grid_type_from_name(name, expected):
    assert _grid_type_from_name(name) == expected
