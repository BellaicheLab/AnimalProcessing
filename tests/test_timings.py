# test_timings.py
#
# Unit tests for the frame<->developmental-time conversions used across the
# averaging and converter paths. Pure functions; no fixtures.
import numpy as np
import pytest

from pyanimalprocessing.rescaling.timings import (
    find_closest_time_index,
    frame_to_time,
    median_time,
    time_dec_to_str,
    time_str_to_dec,
    time_to_frame,
    update_time_step,
)


@pytest.mark.parametrize(
    "s, dec",
    [("16h30", 16.5), ("16:30", 16.5), ("00h15", 0.25), ("23h45", 23.75)],
)
def test_time_str_to_dec(s, dec):
    assert time_str_to_dec(s) == pytest.approx(dec)


@pytest.mark.parametrize(
    "dec, s",
    [(16.5, "16h30"), (0.25, "00h15"), (23.75, "23h45")],
)
def test_time_dec_to_str(dec, s):
    assert time_dec_to_str(dec) == s


def test_time_dec_to_str_separator_and_minute_rounding():
    assert time_dec_to_str(16.5, separator=":") == "16:30"
    # 35.999h rounds MM up to 60 -> should carry to 36h00, not 35h60.
    assert time_dec_to_str(35.999) == "36h00"


@pytest.mark.parametrize("s", ["16h30", "01h05", "20h00", "23h45"])
def test_str_dec_roundtrip(s):
    assert time_dec_to_str(time_str_to_dec(s)) == s


def test_time_to_frame():
    # 1 hour after the reference at dt=5 min/frame -> 12 frames.
    assert time_to_frame("17h00", "16h00", 0, 5) == pytest.approx(12.0)
    assert time_to_frame("16h00", "16h00", 3, 5) == pytest.approx(3.0)


def test_frame_to_time_inverts_time_to_frame():
    assert frame_to_time(12, "16h00", 0, 5) == "17h00"
    assert frame_to_time(3, "16h00", 3, 5) == "16h00"


def test_update_time_step_temperature_correction():
    assert update_time_step(10, 25) == 10
    assert update_time_step(10, 29) == pytest.approx(10 / 0.9)


def test_median_time():
    assert median_time("18h30", "20h30") == "19h30"
    assert median_time("16h00", "17h00") == "16h30"


def test_median_time_accepts_bytes():
    assert median_time(b"18h30", b"20h30") == "19h30"


def test_find_closest_time_index():
    times = ["16h00", "16h50", "17h00"]
    assert find_closest_time_index("16h47", times) == 1
    assert find_closest_time_index("16h05", times) == 0
    assert find_closest_time_index("17h10", times) == 2
