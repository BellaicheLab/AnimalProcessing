"""The unified reader (read_property) on both MATLAB-converted and native stores.

Headless (no napari Viewer -- offscreen napari segfaults): checks that read_property
returns a consistent plot_property bundle from all three unified-schema stores, that
AOA animal selection works, and that MATLAB box origins reproduce the
get_coordinate_system_from_backup + map_points_to_movie arithmetic. A gui-gated case
exercises the actual render.

Gated on the reference stores being on disk under $AP_TEST_DATA (skipped otherwise).
"""
import os
from pathlib import Path

import numpy as np
import pytest
import zarr

from pyanimalprocessing.plotting.property_plotting import read_property
from pyanimalprocessing.rescaling.geometry import get_coordinate_system_from_backup

DATA = Path(os.environ.get("AP_TEST_DATA", ".")) / "data" / "zarr"
AOT = DATA / "210507_vi_pupa1.zarr"
AOA = DATA / "averages_v3" / "241002_eulerian"
PYAP = AOT

pytestmark = pytest.mark.skipif(
    not (AOT.exists() and AOA.exists() and PYAP.exists()),
    reason="unified-schema reference stores not on disk",
)


def _matlab_aot_backup():
    a = zarr.open_group(str(AOT), "r")
    grid = next(g for g in a["TIME_AVERAGE"].group_keys() if g.startswith("EGrid"))
    name = next(n for n in a["TIME_AVERAGE"][grid]["D2"].group_keys() if n.startswith("Average"))
    return a["TIME_AVERAGE"][grid]["D2"][name]


def _pyap_backup():
    return zarr.open_group(str(PYAP), "r")["TIME_AVERAGE"]["EULERIAN"]["D2"]["default"]


def _aoa_backup():
    d2 = zarr.open_group(str(AOA), "r")["EULERIAN"]["D2"]
    return d2["AOA_avgAnimals_vi_4h_0.98olap"]


def test_matlab_aot_bundle():
    b = read_property(_matlab_aot_backup(), "EpsilonPIV")
    data, origin, affine = b["property_data"], b["property_origin"], np.array(b["affine_transform"])
    assert data.ndim == 5 and data.shape[1] == 1 and data.shape[-1] == 4  # (T,1,Ny,Nx,4)
    assert origin.shape == (data.shape[2], data.shape[3], 2)
    assert affine.shape == (4, 4)
    # Anisotropic geometric block sits at [1:, 1:] (from xFactor/yFactor).
    assert affine[1, 1] == pytest.approx(1.089, abs=1e-3)
    assert affine[2, 2] == pytest.approx(1.241, abs=1e-3)


def test_every_matlab_aot_backup_is_readable():
    # Includes the single-window backups (Average_22h_..._olap_0, time_step == 0).
    a = zarr.open_group(str(AOT), "r")["TIME_AVERAGE"]
    for grid in [g for g in a.group_keys() if g.startswith(("EGrid", "LGrid"))]:
        for name in a[grid]["D2"].group_keys():
            backup = a[grid]["D2"][name]
            for quantity in set(backup.array_keys()) - {"time_array", "frame_array", "weights"}:
                read_property(backup, quantity)


def test_pyap_bundle_origins_from_centroids():
    b = read_property(_pyap_backup(), "epsilonpiv")
    data, origin = b["property_data"], b["property_origin"]
    assert data.ndim == 5 and data.shape[1] == 1
    # pyap origins come straight from the stored grid centroids.
    gp = zarr.open_group(str(PYAP), "r")["GRID"]["EULERIAN"]["GRID_PROPERTIES"]
    np.testing.assert_allclose(origin, np.asarray(gp["centroids"]))


def test_aoa_mean_and_animal_selection():
    backup = _aoa_backup()
    raw = np.asarray(backup["EpsilonPIV"])  # (T,1,Ny,Nx,4,animals); animal axis last, index 0 = mean
    mean = read_property(backup, "EpsilonPIV", animal_number=0)["property_data"]
    animal2 = read_property(backup, "EpsilonPIV", animal_number=2)["property_data"]
    assert mean.shape == raw.shape[:-1]  # animal axis dropped
    np.testing.assert_array_equal(mean, raw[..., 0])
    np.testing.assert_array_equal(animal2, raw[..., 2])


def test_matlab_origins_match_box_arithmetic():
    """Regression guard: box (0,0) centre reproduces map_points_to_movie by hand."""
    backup = _matlab_aot_backup()
    origin = read_property(backup, "EpsilonPIV")["property_origin"]
    start_movie, start_grid, boxsizes, overlaps = get_coordinate_system_from_backup(backup)
    offset = start_movie - start_grid * boxsizes * (1 - overlaps) - boxsizes * (1 - overlaps) / 2
    # points reversed (x,y,t)->(t,y,x); box (0,0) centre is (offset_y, offset_x).
    np.testing.assert_allclose(origin[0, 0], [offset[1], offset[0]])


@pytest.mark.gui
def test_plot_property_from_reader_builds_layers():
    import napari
    from pyanimalprocessing.plotting.property_plotting import plot_property

    viewer = napari.Viewer(show=False)
    try:
        plot_property(**read_property(_matlab_aot_backup(), "EpsilonPIV"), viewer=viewer)
        assert len(viewer.layers) > 0
    finally:
        viewer.close()
