# test_extract_aot.py
#
# extract_AOT on a synthetic single-window mean_AOT backup: MATLAB drops the trailing
# T=1 axis and loadmat(squeeze_me=True) flattens the 1x2 TimeArray/FrameArray rows.
import numpy as np
import scipy.io as sio
import zarr

from pyanimalprocessing.io.matlab import extract_AOT, stamp_time_metadata


def test_single_window_backup_keeps_time_axis_and_labels(tmp_path):
    ea = np.arange(5 * 6 * 4, dtype=float).reshape(5, 6, 4)
    time_array = np.empty((1, 2), dtype=object)
    time_array[0, 0], time_array[0, 1] = "15h58", "38h00"
    mat = tmp_path / "mean_AOT_animal.mat"
    sio.savemat(mat, {"EA": ea, "AreaRatios": np.ones((5, 6)),
                      "TimeArray": time_array, "FrameArray": np.array([[1, 239]])})

    backup = zarr.open_group(str(tmp_path / "out.zarr"), mode="w").create_group(
        "Average_22h_16h00_to_38h00_olap_0")
    extract_AOT(backup, str(mat), ["EA", "AreaRatios", "TimeArray", "FrameArray"])
    stamp_time_metadata(backup)

    assert backup["EA"].shape == (1, 1, 5, 6, 4)
    np.testing.assert_array_equal(backup["EA"][0, 0], ea)
    assert backup["AreaRatios"].shape == (1, 1, 5, 6, 1)
    assert backup.attrs["TimeArray"] == [["15h58", "38h00"]]
    assert backup.attrs["FrameArray"] == [[1, 239]]
    assert backup["time_array"][:].tolist() == [[b"15h58", b"38h00"]]
