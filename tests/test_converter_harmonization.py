"""Unit tests for the MATLAB->zarr converter shape harmonization.

Checks that `_harmonize_shape` produces the pyap-native layout
`(T, channel, Ny, Nx, components[, animals])` with the channel axis at position 1
and an always-present component axis (scalars get a trailing singleton), and that
having an animal axis is driven by the explicit `has_animal_axis` flag (not a
group-name heuristic). DBA differences have no animal axis, like single-animal AOTs.
"""

import numpy as np
import pytest
import zarr

from pyanimalprocessing.io.matlab import (
    extract_SAP_info,
    stamp_aoa_centroids,
    stamp_aoa_std,
    stamp_registration_affine,
    stamp_time_metadata,
)
from pyanimalprocessing.utils.conversions import _harmonize_shape

NY, NX, T, A = 5, 7, 3, 6  # distinct sizes to catch axis mistakes


@pytest.mark.parametrize(
    "raw_shape, has_animal_axis, expected",
    [
        # No animal axis (single-animal AOT, or DBA difference): raw (Ny, Nx, comp, T)
        # -> (T, 1, Ny, Nx, comp)
        ((NY, NX, 4, T), False, (T, 1, NY, NX, 4)),  # tensor
        ((NY, NX, 2, T), False, (T, 1, NY, NX, 2)),  # vector
        ((NY, NX, T), False, (T, 1, NY, NX, 1)),  # scalar -> trailing singleton
        # AOA (across-animal): raw (Ny, Nx, comp, T, A) -> (T, 1, Ny, Nx, comp, A)
        ((NY, NX, 4, T, A), True, (T, 1, NY, NX, 4, A)),  # tensor
        ((NY, NX, 2, T, A), True, (T, 1, NY, NX, 2, A)),  # vector
        ((NY, NX, 1, T, A), True, (T, 1, NY, NX, 1, A)),  # scalar with explicit comp=1
        ((NY, NX, T, A), True, (T, 1, NY, NX, 1, A)),  # scalar -> singleton before animals
        # 0olap keeps all frames in a mid axis; they become the leading T axis.
        ((NY, NX, 4, T, A), True, (T, 1, NY, NX, 4, A)),  # frames == T here
    ],
)
def test_harmonize_shape_layout(raw_shape, has_animal_axis, expected):
    out = _harmonize_shape(
        np.zeros(raw_shape), quantity_name="EA", has_animal_axis=has_animal_axis
    )
    assert out.shape == expected


def test_macrocaetes_untouched_no_channel_axis():
    raw = np.zeros((2, 8))
    out = _harmonize_shape(raw, quantity_name="Macrocaetes", has_animal_axis=True)
    assert out.shape == (2, 8)


def test_has_animal_axis_flag_drives_layout():
    """Same array + name; only the explicit flag decides whether an animal axis exists.

    A DBA difference (no animal axis) and an AOA stack can share the same on-disk comp
    count -- the flag, not the name, keeps the animal axis out of the DBA.
    """
    aoa = _harmonize_shape(
        np.zeros((NY, NX, 4, T, A)), quantity_name="EA", has_animal_axis=True
    )
    dba = _harmonize_shape(
        np.zeros((NY, NX, 4, T)), quantity_name="EA", has_animal_axis=False
    )
    assert aoa.shape == (T, 1, NY, NX, 4, A)
    assert dba.shape == (T, 1, NY, NX, 4)


def test_registration_affine_from_factors_and_origins(tmp_path):
    g = zarr.open_group(str(tmp_path / "a.zarr"), mode="w")
    g.attrs.update(xFactor=1.2411, yFactor=1.0887, xStart=1259.5, yStart=612.25)
    stamp_registration_affine(g)
    M = np.array(g.attrs["matrix_transform"])
    assert M.shape == (3, 3)
    # pyap (y, x) order: diag(yFactor, xFactor), translation -factor*origin, no scale1D.
    assert M[0, 0] == pytest.approx(1.0887)
    assert M[1, 1] == pytest.approx(1.2411)
    assert M[0, 2] == pytest.approx(-1.0887 * 612.25)
    assert M[1, 2] == pytest.approx(-1.2411 * 1259.5)
    assert M[2].tolist() == [0.0, 0.0, 1.0]


def test_registration_affine_skipped_when_factors_absent(tmp_path):
    g = zarr.open_group(str(tmp_path / "b.zarr"), mode="w")
    g.attrs["xStart"] = 10.0  # factors missing -> nothing stamped
    stamp_registration_affine(g)
    assert "matrix_transform" not in g.attrs


def test_time_metadata_datasets_and_attrs(tmp_path):
    root = zarr.open_group(str(tmp_path / "t.zarr"), mode="w")
    backup = (
        root.require_group("TIME_AVERAGE")
        .require_group("grid")
        .require_group("D2")
        .require_group("Average_5h_16h00_to_38h00_olap_0.98")
    )
    backup.attrs["TimeArray"] = [["16h00", "21h00"], ["16h05", "21h05"], ["16h10", "21h10"]]
    backup.attrs["FrameArray"] = [[1, 61], [2, 62], [3, 63]]
    stamp_time_metadata(backup)

    assert backup["time_array"].shape == (3, 2)
    assert backup["time_array"].dtype.kind == "S"
    assert backup["time_array"][0].tolist() == [b"16h00", b"21h00"]
    assert backup["frame_array"][0].tolist() == [1, 61]
    # start/stop from the group name; window from the "5h" token; step = 5 min stride.
    assert backup.attrs["time_start"] == "16h00"
    assert backup.attrs["time_stop"] == "38h00"
    assert backup.attrs["time_window"] == "05h00"
    assert backup.attrs["time_step"] == 5


def test_aoa_std_from_samples(tmp_path):
    g = zarr.open_group(str(tmp_path / "s.zarr"), mode="w")
    Tn, Ny, Nx, comp, A = 2, 3, 4, 4, 5  # A = mean + 4 animals
    data = np.random.default_rng(0).random((Tn, 1, Ny, Nx, comp, A))
    g.create_dataset("EA", data=data)
    g.create_dataset("AreaRatios", data=np.ones((Tn, 1, Ny, Nx, 1, A)))
    g.create_dataset("weights", data=np.ones((Tn, 1, Ny, Nx, 1, A)))
    stamp_aoa_std(g)
    # std has the mean's shape (animal axis reduced away); weights/AreaRatios skipped.
    assert g["EA_std"].shape == (Tn, 1, Ny, Nx, comp)
    assert "weights_std" not in g
    assert "AreaRatios_std" not in g


def test_aoa_centroids_materialized(tmp_path):
    Ny, Nx = 3, 4
    g = zarr.open_group(str(tmp_path / "c.zarr"), mode="w")
    g.attrs.update(
        Size=[Ny, Nx], xStart=100.0, yStart=200.0,
        boxWidth=40.0, boxHeight=40.0, Overlap=0.5,
    )
    stamp_aoa_centroids(g)
    assert g["grid_centroids"].shape == (Ny, Nx, 2)
    # No-op without the box attrs.
    g2 = zarr.open_group(str(tmp_path / "c2.zarr"), mode="w")
    stamp_aoa_centroids(g2)
    assert "grid_centroids" not in g2


@pytest.mark.parametrize(
    "line, expected",
    [
        ("signalName = {'Cad'};   % \"Cad\", \"Myo\"...\n", ["Cad"]),
        ("signalName = {'Cad', 'Myo'};\n", ["Cad", "Myo"]),
    ],
)
def test_signalname_extracted_as_channels(tmp_path, line, expected):
    info = tmp_path / "SAP_info.m"
    info.write_text(line)
    g = zarr.open_group(str(tmp_path / "c.zarr"), mode="w")
    extract_SAP_info(g, str(info), quantities=["signalName"])
    assert list(g.attrs["channels"]) == expected
