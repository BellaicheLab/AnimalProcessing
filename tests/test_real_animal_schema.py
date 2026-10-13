# test_real_animal_schema.py
#
# Validates the canonical zarr schema on the two real "simple animals": a movie
# (TolloGFP_28h, has developmental timing + an EULERIAN grid) and a fixed-image
# atlas (svp). Atlas builds add GRID/TIME_AVERAGE and timing attrs to the atlas
# stores in place, so only the converter-owned parts are checked there. Also checks
# that require_timing_attrs rejects a store without a frame<->time reference.
# Read-only; skips when the data is not under $AP_TEST_DATA.
import os
from pathlib import Path

import pytest
import zarr

from pyanimalprocessing.rescaling.timings import require_timing_attrs

DATA = Path(os.environ.get("AP_TEST_DATA", ".")) / "data"
MOVIE = DATA / "tollo_gfp" / "TolloGFP_28h.zarr"
ATLAS = DATA / "zarr_atlases" / "protein" / "201217_svp_s1l.zarr"


@pytest.fixture(scope="module")
def movie():
    if not MOVIE.exists():
        pytest.skip("real movie store not on disk")
    return zarr.open_group(str(MOVIE), mode="r")


@pytest.fixture(scope="module")
def atlas():
    if not ATLAS.exists():
        pytest.skip("real atlas store not on disk")
    return zarr.open_group(str(ATLAS), mode="r")


def test_movie_canonical_schema(movie):
    assert movie["IMAGE/D2/raw"].shape == (1, 2, 686, 1780)
    assert movie["IMAGE/D2/raw"].dtype == "uint8"
    assert movie["IMAGE/D2/mask"].dtype == bool
    assert "CELL" in movie and "D2" in movie["CELL"]
    assert "GRID/EULERIAN/GRID_PROPERTIES" in movie
    assert "SPACE_REGISTRATION/tollo_gfp_28h/landmarks" in movie
    for key in ("channels", "dt", "scaling", "temperature"):
        assert key in movie.attrs


def test_movie_has_timing_and_passes_require(movie):
    assert movie.attrs["frame_ref"] == 0
    assert movie.attrs["time_ref"] == "28h00"
    # Movie carries the frame<->time reference, so this must not raise.
    require_timing_attrs(movie, "a time-dependent step")


def test_atlas_canonical_schema(atlas):
    assert atlas["IMAGE/D2/raw"].shape == (1, 2, 956, 1608)
    assert atlas["IMAGE/D2/raw"].dtype == "uint8"
    assert atlas["IMAGE/D2/mask"].dtype == bool
    assert "SPACE_REGISTRATION/atlas_sr/landmarks" in atlas
    assert atlas.attrs["gene"] == "svp"
    assert atlas.attrs["modality"] == "protein"


def test_require_timing_raises_without_frame_reference():
    # A store without frame_ref/time_ref cannot map frames to developmental time.
    store = zarr.group()
    store.attrs.update({"dt": 5, "temperature": 25})
    with pytest.raises(KeyError):
        require_timing_attrs(store, "a time-dependent step")
