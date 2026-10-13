# test_conversions.py
#
# Unit tests for the MAP-path MATLAB conversion helpers: _harmonize_shape
# (moves the time axis to the front) and _field_formatted (splits/renames
# compound MATLAB fields). Pure functions.
import numpy as np
import pytest

from pyanimalprocessing.utils.conversions import _field_formatted, _harmonize_shape


def test_harmonize_shape_requires_at_least_2d():
    with pytest.raises(ValueError):
        _harmonize_shape(np.zeros(5), quantity_name="x")


def test_harmonize_shape_aoa_tensor_moves_time_to_front():
    # AOA tensor: (ny, nx, comp, t, animals) -> (t, channel=1, ny, nx, comp, animals)
    arr = np.zeros((5, 6, 4, 3, 7))
    out = _harmonize_shape(arr, quantity_name="Epsilon", has_animal_axis=True)
    assert out.shape == (3, 1, 5, 6, 4, 7)


def test_harmonize_shape_aoa_scalar_keeps_component_singleton():
    # AOA scalar carrying an explicit comp=1: (ny, nx, 1, t, animals) stays a singleton.
    arr = np.zeros((5, 6, 1, 3, 7))
    out = _harmonize_shape(arr, quantity_name="CellArea", has_animal_axis=True)
    assert out.shape == (3, 1, 5, 6, 1, 7)


def test_harmonize_shape_aoa_scalar_without_component_gets_singleton():
    # AOA scalar with no comp axis: (ny, nx, t, animals) -> (t, 1, ny, nx, 1, animals)
    arr = np.zeros((5, 6, 3, 7))
    out = _harmonize_shape(arr, quantity_name="CellArea", has_animal_axis=True)
    assert out.shape == (3, 1, 5, 6, 1, 7)


def test_harmonize_shape_dba_tensor_has_no_animal_axis():
    # DBA / AOT tensor (no animal axis): (ny, nx, comp, t) -> (t, 1, ny, nx, comp)
    arr = np.zeros((5, 6, 4, 3))
    out = _harmonize_shape(arr, quantity_name="Epsilon", has_animal_axis=False)
    assert out.shape == (3, 1, 5, 6, 4)


def test_harmonize_shape_aot_scalar_gets_channel_and_component_axes():
    # AOT scalar: (ny, nx, t) -> (t, channel=1, ny, nx, component=1)
    arr = np.zeros((5, 6, 3))
    out = _harmonize_shape(arr, quantity_name="CellArea", has_animal_axis=False)
    assert out.shape == (3, 1, 5, 6, 1)


def test_harmonize_shape_0olap_time_becomes_leading_axis():
    # 0olap keeps all frames in a mid axis: (ny, nx, comp, frames, animals)
    # -> (frames, 1, ny, nx, comp, animals). No group-name special-casing.
    arr = np.zeros((5, 6, 4, 238, 7))
    out = _harmonize_shape(arr, quantity_name="Epsilon", has_animal_axis=True)
    assert out.shape == (238, 1, 5, 6, 4, 7)


def test_harmonize_shape_aoa_instantaneous_squeezed_time_prepended():
    # Instantaneous AOA scalar: loadmat(squeeze_me=True) drops comp=1 AND T=1, leaving
    # (ny, nx, animals). A leading time axis is prepended -> (1, 1, ny, nx, 1, animals).
    arr = np.zeros((5, 6, 7))
    out = _harmonize_shape(arr, quantity_name="AreaRatios", has_animal_axis=True)
    assert out.shape == (1, 1, 5, 6, 1, 7)


def test_harmonize_shape_dba_instantaneous_squeezed_time_prepended():
    # Same, no animal axis (DBA/AOT): squeezed to (ny, nx) -> (1, 1, ny, nx, 1).
    arr = np.zeros((5, 6))
    out = _harmonize_shape(arr, quantity_name="AreaRatios", has_animal_axis=False)
    assert out.shape == (1, 1, 5, 6, 1)


def test_field_formatted_passthrough_for_unmapped_key():
    assert _field_formatted("Epsilon", 42) == [("Epsilon", 42)]


def test_field_formatted_xywh_splits_into_named_bounds():
    # xywh arrives from loadmat as an ndarray.
    out = _field_formatted("xywh", np.array([1, 2, 3, 4]))
    keys = [k for k, _ in out]
    assert keys == ["xStart", "yStart", "boxWidth", "boxHeight"]
    assert [v for _, v in out] == [1, 2, 3, 4]


def test_harmonize_shape_single_window_tensor_keeps_components():
    # Single-window AOT (T=1): loadmat(squeeze_me=True) turns (ny, nx, comp, 1) into
    # (ny, nx, comp); n_times=1 says the missing axis is time, not the last one.
    arr = np.zeros((5, 6, 4))
    out = _harmonize_shape(arr, quantity_name="EA", has_animal_axis=False, n_times=1)
    assert out.shape == (1, 1, 5, 6, 4)


def test_harmonize_shape_single_window_aoa_tensor_keeps_components():
    arr = np.zeros((5, 6, 4, 7))
    out = _harmonize_shape(arr, quantity_name="Epsilon", has_animal_axis=True, n_times=1)
    assert out.shape == (1, 1, 5, 6, 4, 7)
