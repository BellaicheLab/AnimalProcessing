import numpy as np
import pytest
from pyanimalprocessing.transformation.tensors import (
    get_unbiased_weighted_std_matrix_aoa,
)


def test_std_manual_calculation():
    """
    Test 1: Simple Manual Calculation.

    Verifies the fundamental calculation with a small, simple dataset where
    the expected output can be computed by hand, confirming the implementation
    matches the formula from the paper.
    """
    # Setup a simple case: 1 timepoint, 1 channel, 1x1 grid, 1 property, 3 animals
    samples = np.array([10.0, 12.0, 15.0]).reshape(1, 1, 1, 1, 1, 3)
    weights = np.array([1.0, 0.5, 1.0]).reshape(1, 1, 1, 1, 1, 3)

    # The weighted mean must be pre-computed, as the function expects it.
    # weighted mean = (10*1 + 12*0.5 + 15*1) / (1 + 0.5 + 1) = 12.4
    mean = np.array([12.4]).reshape(1, 1, 1, 1, 1)

    # Manually calculated expected standard deviation based on Equation 12:
    # weighted_sum_sq_diffs = 1*(10-12.4)² + 0.5*(12-12.4)² + 1*(15-12.4)² = 12.6
    # sum_weights = 2.5
    # sum_weights_sq = 1² + 0.5² + 1² = 2.25
    # bias = 2.5 / (2.5² - 2.25) = 0.625
    # expected_std = sqrt(0.625 * 12.6) = sqrt(7.875)
    expected_std = np.sqrt(7.875)

    # Run the function
    result = get_unbiased_weighted_std_matrix_aoa(samples, mean, weights)

    # Verify the output
    assert result.shape == (1, 1, 1, 1, 1)
    np.testing.assert_allclose(result[0, 0, 0, 0, 0], expected_std)


def test_std_unit_weights_equivalence():
    """
    Test 2: Equivalence to Standard Deviation (Unit Weights).

    Verifies that when all weights are 1, the function's output is
    equivalent to the standard unbiased sample standard deviation (ddof=1).
    """
    # Setup a simple case: 1 timepoint, 1 channel, 1x1 grid, 1 property, 5 animals
    samples = np.array([10.0, 12.0, 15.0, 8.0, 9.0]).reshape(1, 1, 1, 1, 1, 5)
    weights = np.ones_like(samples)  # All weights are 1

    # The weighted mean is just the standard mean when weights are 1
    mean = np.mean(samples, axis=-1)

    # Expected result from numpy's standard deviation (unbiased)
    expected_std = np.std(samples, axis=-1, ddof=1)

    # Run the function
    result = get_unbiased_weighted_std_matrix_aoa(samples, mean, weights)

    # Verify the output
    np.testing.assert_allclose(result, expected_std)


def test_std_constant_weight_scale_invariance():
    """
    Test 3: Independence from Constant Weight Scale.

    Verifies that the result does not change if all weights are multiplied
    by the same constant factor, as the scaling should cancel out.
    """
    samples = np.array([10.0, 12.0, 15.0, 8.0, 9.0]).reshape(1, 1, 1, 1, 1, 5)

    # Calculate with unit weights
    weights1 = np.ones((1, 1, 1, 1, 1, 5))
    # Manually compute weighted average, which is just the mean for unit weights
    mean1 = np.mean(samples, axis=-1)
    result1 = get_unbiased_weighted_std_matrix_aoa(samples, mean1, weights1)

    # Calculate with scaled weights
    k = 2.0
    weights2 = np.full((1, 1, 1, 1, 1, 5), k)
    # The mean is identical since the constant weight scales cancel out
    mean2 = np.average(samples.flatten(), weights=weights2.flatten())
    result2 = get_unbiased_weighted_std_matrix_aoa(
        samples, mean2.reshape(1, 1, 1, 1, 1), weights2
    )

    # The results should be identical
    np.testing.assert_allclose(result1, result2)


def test_std_zero_weight_exclusion():
    """
    Test 4: Handling of Zero Weights.

    Verifies that a sample with a weight of 0 is completely ignored by the
    calculation, having no influence on the final standard deviation.
    """
    # Base case with 4 animals
    samples1 = np.array([10.0, 12.0, 15.0, 8.0]).reshape(1, 1, 1, 1, 1, 4)
    weights1 = np.array([1.0, 0.5, 1.0, 1.0]).reshape(1, 1, 1, 1, 1, 4)
    mean1 = np.average(samples1.flatten(), weights=weights1.flatten())
    result1 = get_unbiased_weighted_std_matrix_aoa(
        samples1, mean1.reshape(1, 1, 1, 1, 1), weights1
    )

    # Case with a 5th animal that has a weight of 0
    samples2 = np.array([10.0, 12.0, 15.0, 8.0, 99.0]).reshape(1, 1, 1, 1, 1, 5)
    weights2 = np.array([1.0, 0.5, 1.0, 1.0, 0.0]).reshape(1, 1, 1, 1, 1, 5)
    # The mean should be identical to the first case
    mean2 = np.average(samples2.flatten(), weights=weights2.flatten())
    result2 = get_unbiased_weighted_std_matrix_aoa(
        samples2, mean2.reshape(1, 1, 1, 1, 1), weights2
    )

    # The results should be identical
    np.testing.assert_allclose(result1, result2)


def test_std_multiple_properties():
    """
    Test 5: Broadcasting Over Multiple Properties.

    Verifies that the function works correctly when the input tensors
    have multiple properties (property_dimension > 1).
    """
    # Two properties, three animals
    samples = np.array(
        [
            [[10.0, 100.0]],  # Animal 1, Prop1=10, Prop2=100
            [[12.0, 110.0]],  # Animal 2, Prop1=12, Prop2=110
            [[15.0, 125.0]],  # Animal 3, Prop1=15, Prop2=125
        ]
    ).reshape(1, 1, 1, 1, 3, 2)
    samples = np.transpose(
        samples, (0, 1, 2, 3, 5, 4)
    )  # Reshape to (t,c,y,x,prop,animal)

    weights = np.array([1.0, 0.5, 1.0]).reshape(1, 1, 1, 1, 1, 3)

    # Pre-compute the mean for each property
    mean_prop1 = np.average(samples[..., 0, :].flatten(), weights=weights.flatten())
    mean_prop2 = np.average(samples[..., 1, :].flatten(), weights=weights.flatten())
    mean = np.array([mean_prop1, mean_prop2]).reshape(1, 1, 1, 1, 2)

    # Run the function
    result = get_unbiased_weighted_std_matrix_aoa(samples, mean, weights)

    # Manually calculate expected result for each property
    result1 = get_unbiased_weighted_std_matrix_aoa(
        samples[..., 0, :][..., np.newaxis, :], mean[..., 0][..., np.newaxis], weights
    )
    result2 = get_unbiased_weighted_std_matrix_aoa(
        samples[..., 1, :][..., np.newaxis, :], mean[..., 1][..., np.newaxis], weights
    )
    expected = np.array([result1, result2]).reshape(1, 1, 1, 1, 2)

    assert result.shape == (1, 1, 1, 1, 2)
    np.testing.assert_allclose(result, expected)


def test_std_nan_handling():
    """
    Test 6: Handling of NaN Values.

    Verifies that NaN values in the input samples are correctly ignored by
    the function, as expected from using `np.nansum`.
    """
    # Case with a NaN value in the samples
    samples_with_nan = np.array([10.0, 12.0, np.nan, 8.0]).reshape(1, 1, 1, 1, 1, 4)
    weights_with_nan = np.array([1.0, 0.5, 1.0, 1.0]).reshape(1, 1, 1, 1, 1, 4)

    # Calculate mean, ignoring NaNs
    nan_mask = np.isnan(samples_with_nan)
    mean_with_nan = np.average(
        samples_with_nan[~nan_mask], weights=weights_with_nan[~nan_mask]
    )

    result_with_nan = get_unbiased_weighted_std_matrix_aoa(
        samples_with_nan, mean_with_nan.reshape(1, 1, 1, 1, 1), weights_with_nan
    )

    # Equivalent case with the NaN value removed
    samples_no_nan = np.array([10.0, 12.0, 8.0]).reshape(1, 1, 1, 1, 1, 3)
    weights_no_nan = np.array([1.0, 0.5, 1.0]).reshape(1, 1, 1, 1, 1, 3)
    mean_no_nan = np.average(samples_no_nan.flatten(), weights=weights_no_nan.flatten())
    expected_result = get_unbiased_weighted_std_matrix_aoa(
        samples_no_nan, mean_no_nan.reshape(1, 1, 1, 1, 1), weights_no_nan
    )

    np.testing.assert_allclose(result_with_nan, expected_result)
