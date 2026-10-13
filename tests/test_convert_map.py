# test_convert_map.py
#
# Integration test for the MATLAB across-animal (MAP/AOA) converter on a real,
# small MATLAB object: data/gep_results/.../AOA_egr_0h_0olap/AOA_backup.mat
# (~88 KB gene-expression AOA). Skips when the data is not under $AP_TEST_DATA.
import os
import shutil
from pathlib import Path

import numpy as np
import pytest
import zarr

from pyanimalprocessing.io.zarr import convert_MAP_to_zarr

AOA_BACKUP = (
    Path(os.environ.get("AP_TEST_DATA", ".")) / "data" / "gep_results"
    / "AOA_40um_olap0.5" / "AOA_egr_0h_0olap" / "AOA_backup.mat"
)
FIELD = "AOA_egr_0h_0olap"
MOTION = "EULERIAN"  # gene atlas backups carry no excludeLostCells

pytestmark = pytest.mark.skipif(
    not AOA_BACKUP.exists(), reason="real MAP/AOA backup not on disk"
)


@pytest.fixture(scope="module")
def converted_map(tmp_path_factory):
    # copy the whole folder: next to AOA_backup.mat it holds a name_notum.mat that must be ignored
    src = tmp_path_factory.mktemp("map_src")
    shutil.copytree(AOA_BACKUP.parent, src / FIELD)
    out = tmp_path_factory.mktemp("map_out") / "store"
    convert_MAP_to_zarr(str(src), output_zarr=str(out))
    return zarr.open_group(str(out), mode="r")


def _field(store):
    return store[MOTION]["D2"][FIELD]


def test_map_top_level_schema(converted_map):
    # MAP path writes the nested <motion>/D2/<field> tree (symmetric with the native AOA road).
    assert MOTION in converted_map
    assert "D2" in converted_map[MOTION]
    assert FIELD in converted_map[MOTION]["D2"]


def test_map_quantities_extracted(converted_map):
    arrays = set(_field(converted_map).array_keys())
    # The egr gene-expression AOA carries the area-fraction map + bristle positions.
    assert "AreaRatios" in arrays
    assert "Macrocaetes" in arrays


def test_map_grid_centroids_materialized(converted_map):
    field = _field(converted_map)
    assert "grid_centroids" in set(field.array_keys())
    ny, nx = field.attrs["Size"]
    assert field["grid_centroids"].shape == (ny, nx, 2)


def test_map_weights_are_area_squared(converted_map):
    # weights = AreaRatios**2 (area^2, native convention); AreaRatios kept as the area^1 alias.
    # (float32 tolerance: the converter squares the float64 ratios before truncating.)
    field = _field(converted_map)
    w = np.asarray(field["weights"], dtype=np.float32)
    ar2 = np.square(np.asarray(field["AreaRatios"], dtype=np.float32))
    finite = np.isfinite(w) & np.isfinite(ar2)
    assert finite.sum() > 0
    assert np.allclose(w[finite], ar2[finite], atol=1e-2)


def test_map_arearatios_shape_matches_size_attr(converted_map):
    ar = _field(converted_map)["AreaRatios"]
    assert ar.dtype == np.float32
    # Size attr is [ny, nx]; AreaRatios is (t, channel, ny, nx, components, animals).
    ny, nx = _field(converted_map).attrs["Size"]
    assert ar.shape[2] == ny
    assert ar.shape[3] == nx


def test_map_arearatios_values_are_nonnegative_fractions(converted_map):
    ar = _field(converted_map)["AreaRatios"][:].astype(np.float32)
    finite = ar[np.isfinite(ar)]
    assert finite.size > 0
    assert np.all(finite >= 0.0)


def test_map_scalar_metadata_stored_as_attrs(converted_map):
    field = _field(converted_map)
    attr_keys = set(field.attrs.keys())
    # These quantities are registered as attributes, not datasets.
    for key in ("Overlap", "Size", "FrameArray", "TimeArray", "ULCs"):
        assert key in attr_keys
        assert key not in set(field.array_keys())
    assert field.attrs["Overlap"] == 0.5
