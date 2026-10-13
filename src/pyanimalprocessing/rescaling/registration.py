"""Landmark-based spatial registration and grid construction: fit affine transforms
from clicked landmarks, build the archetype/common grid across animals, instantiate
per-animal meshgrids, and compute grid area ratios.
"""

from pathlib import Path
from typing import List, Literal, Tuple

import numpy as np
import skimage
from numpy.typing import ArrayLike, NDArray
from scipy.optimize import minimize
from skimage.draw import polygon2mask, polygon_perimeter
from skimage.measure import find_contours
from tqdm import tqdm

import zarr
from pyanimalprocessing.rescaling.timings import require_timing_attrs, time_to_frame
from pyanimalprocessing.utils.pipeline import _approximate_polygon_area
from pyanimalprocessing.utils import _vprint


def generate_grid_numbers(t_y_x_shape: Tuple[int, int, int]) -> np.ndarray:
    """Generate grid indices numbered from 1..(y*x) over time.

    Returns an array of shape (t, 1, y, x, 1) with dtype uint16.
    """
    t, y, x = t_y_x_shape
    base_array_int = np.arange(1, y * x + 1).reshape(y, x)
    grid_numbers_t_y_x_int = np.broadcast_to(base_array_int, (t, y, x))
    return grid_numbers_t_y_x_int[:, np.newaxis, :, :, np.newaxis].astype(np.uint16)


def _transform_points(theta, sy, sx, ty, tx, reference_landmarks):
    cos_theta = np.cos(theta)
    sin_theta = np.sin(theta)
    rotation_matrix = np.array(
        [
            [cos_theta, -sin_theta, 0],
            [sin_theta, cos_theta, 0],
            [0, 0, 1],
        ]
    )
    scaling_matrix = np.array(
        [
            [sy, 0, 0],
            [0, sx, 0],
            [0, 0, 1],
        ]
    )

    translation_matrix = np.array(
        [
            [1, 0, ty],
            [0, 1, tx],
            [0, 0, 1],
        ]
    )
    affine_transform = translation_matrix @ scaling_matrix @ rotation_matrix
    return _apply_matrix_transform_to_points(
        np.hstack((reference_landmarks, np.ones((reference_landmarks.shape[0], 1)))),
        affine_transform,
    )[:, :2]


def _objective_function(params, reference_landmarks, target_landmarks):
    theta, sy, sx, ty, tx = params
    transformed_points = _transform_points(theta, sy, sx, ty, tx, reference_landmarks)
    return np.sum((transformed_points[:, :2] - target_landmarks) ** 2)


def _objective_function_fixed_angle(
    params, reference_landmarks, target_landmarks, theta
):
    sy, sx, ty, tx = params
    transformed_points = _transform_points(theta, sy, sx, ty, tx, reference_landmarks)
    return np.sum((transformed_points[:, :2] - target_landmarks) ** 2)


def _objective_function_isotropic(params, reference_landmarks, target_landmarks, flip):
    theta, s, ty, tx = params
    if flip:
        sx = -s
    else:
        sx = s
    transformed_points = _transform_points(theta, s, sx, ty, tx, reference_landmarks)
    return np.sum((transformed_points[:, :2] - target_landmarks) ** 2)


def _objective_function_isotropic_fixed_angle(
    params, reference_landmarks, target_landmarks, theta, flip
):
    s, ty, tx = params
    if flip:
        sx = -s
    else:
        sx = s
    transformed_points = _transform_points(theta, s, sx, ty, tx, reference_landmarks)
    return np.sum((transformed_points[:, :2] - target_landmarks) ** 2)


class Grid:
    """
    Creates a Grid object for averaging quantities and rescaling grids.

    :param box_size: A tuple specifying the width and height of each grid compartment in microns.
    :type box_size: Tuple[float, float]
    :param scaling: A scalar value for resizing the compartments according to the image acquisition.
    :type scaling: float
    :param overlap: The fraction of overlap between adjacent compartments, ranging from 0 to 1.
    :type overlap: float
    :param image_shape: A tuple indicating the shape (height, width) of the image to overlay the grid on.
    :type image_shape: Tuple[int, int]
    :param reference_landmarks: An optional numpy array of shape (n, 2) providing reference points for matrix transformation.
    :type reference_landmarks: ArrayLike, optional
    :param target_landmarks: An optional numpy array of shape (n, 2) providing target points for matrix transformation.
    :type target_landmarks: ArrayLike, optional
    :param transform_type: The type of matrix transformation to apply: "isotropic_similarity" (rotation + isotropic scaling) or "xyscale_translation" (independent x/y scaling + translation, no rotation, the default).
    :type transform_type: Literal["isotropic_similarity", "xyscale_translation"], optional
    :meta private:
    """

    def __init__(
        self,
        image_shape: Tuple[int, int],
        reference_landmarks: ArrayLike = None,
        target_landmarks: ArrayLike = None,
        angle: float = None,
        transform_type: Literal[
            "isotropic_similarity", "xyscale_translation"
        ] = "xyscale_translation",
        grid_type: Literal["eulerian"] = "eulerian",
        grid_name: str = None,
        frame_grid_definition: int = 5,
        tissue=None,
        roi=None,
        ndil=10,
        matrix_transform=None,
        verbose=False,
        n_jobs=-1,
    ):
        # Grid parameters
        self.image_shape = np.array(image_shape)
        # grid_type is the semantic kind ("eulerian"/"lagrangian_tracking"/...); grid_name is the
        # GRID/<name> group key (defaults to grid_type.upper() for back-compat). Multiple grids
        # of the same type coexist under distinct names.
        self.grid_type = grid_type
        self.grid_name = grid_name if grid_name is not None else grid_type.upper()

        # Scaling parameters
        self.reference_landmarks = reference_landmarks
        self.target_landmarks = target_landmarks
        self.matrix_transform = np.eye(3)
        self.transformed_corners = np.array(
            [
                [0, 0],
                [image_shape[0], 0],
                [0, image_shape[1]],
                [image_shape[0], image_shape[1]],
            ]
        )

        self.angle = angle

        self.mask_positions: np.ndarray = np.array([], dtype=object)

        self.box_corners: np.ndarray = np.array([])
        self.centroids: np.ndarray = np.array([])

        # Meshgrid parameters
        self.Y: np.ndarray = np.array([])
        self.X: np.ndarray = np.array([])

        if matrix_transform is not None:
            self.matrix_transform = matrix_transform
        elif transform_type == "isotropic_similarity":
            self._update_similarity_transform()
            self.flip = self.matrix_transform[0, 0] * self.matrix_transform[1, 1] < 0
            self._update_isotropic_similarity_transform()
        elif transform_type == "xyscale_translation":
            self._update_xyscale_translation_transform()
        else:
            raise KeyError(
                "Invalid transform type. Must be 'isotropic_similarity' (rotation + isotropic scaling, preserves angles) or 'xyscale_translation' (independent x/y scaling + translation, no rotation)."
            )

        self.verbose = verbose
        self.n_jobs = n_jobs

    def find_timepoints(self, animal):
        self.time_points = animal.IMAGE.D2.raw.shape[0]

    def _validate_inputs(self) -> None:
        """
        Validates the input parameters for the Grid object.
        """
        if (
            self.reference_landmarks is not None
            and self.reference_landmarks.shape[1] != 2
        ):
            raise ValueError(
                "Reference landmarks must have shape (n, 2), got shape {}".format(
                    self.reference_landmarks.shape
                )
            )
        if self.target_landmarks is not None and self.target_landmarks.shape[1] != 2:
            raise ValueError(
                "Target landmarks must have shape (n, 2), got shape {}".format(
                    self.target_landmarks.shape
                )
            )
        if np.any(self.box_size_microns <= 0):
            raise ValueError("All dimensions of box size must be positive.")
        if not 0 <= self.overlap < 1:
            raise ValueError("Overlap must be within the range [0, 1[.")

    def _update_xyscale_translation_transform(self) -> None:
        """
        Calculates a diagonal transform (independent x/y scaling + translation, no
        rotation or shear) mapping the reference landmarks onto the target landmarks.

        This reproduces the MATLAB atlas registration, whose x and y scaling factors
        are two independent 1-D least-squares fits (one per axis); the rotational
        component is dropped by construction.
        """
        if self.reference_landmarks is not None and self.target_landmarks is not None:
            valid_rows = ~np.isnan(self.reference_landmarks).any(axis=1) & ~np.isnan(
                self.target_landmarks
            ).any(axis=1)
            src_valid = self.reference_landmarks[valid_rows]
            dst_valid = self.target_landmarks[valid_rows]

            if len(src_valid) < 2:
                raise ValueError("At least two pairs of non-NaN points are required.")

            # Independent 1-D least squares per axis -> no cross terms -> no rotation.
            sy, ty = np.polyfit(src_valid[:, 0], dst_valid[:, 0], 1)
            sx, tx = np.polyfit(src_valid[:, 1], dst_valid[:, 1], 1)

            self.matrix_transform = np.array(
                [
                    [sy, 0, ty],
                    [0, sx, tx],
                    [0, 0, 1],
                ]
            )

    def _update_similarity_transform(self):
        if self.reference_landmarks is not None and self.target_landmarks is not None:
            valid_rows = ~np.isnan(self.reference_landmarks).any(axis=1) & ~np.isnan(
                self.target_landmarks
            ).any(axis=1)
            src_valid = self.reference_landmarks[valid_rows]
            dst_valid = self.target_landmarks[valid_rows]

            if self.angle is not None:
                if len(src_valid) < 2:
                    raise ValueError(
                        "At least two pairs of non-NaN points are required."
                    )
                initial_guess = [
                    1,
                    1,
                    0,
                    0,
                ]  # Initial guess for [sy, sx, ty, tx]
                result = minimize(
                    _objective_function_fixed_angle,
                    initial_guess,
                    args=(src_valid, dst_valid, self.angle),
                )
                sy, sx, ty, tx = result.x

                theta = self.angle
            else:
                if len(src_valid) < 3:
                    raise ValueError(
                        "At least three pairs of non-NaN points are required."
                    )
                initial_guess = [
                    0,
                    1,
                    1,
                    0,
                    0,
                ]  # Initial guess for [theta, sy, sx, ty, tx]
                bounds = [
                    (-np.pi, np.pi),
                    (None, None),
                    (None, None),
                    (None, None),
                    (None, None),
                ]  # Bounds for parameters
                result = minimize(
                    _objective_function,
                    initial_guess,
                    args=(src_valid, dst_valid),
                    bounds=bounds,
                )
                theta, sy, sx, ty, tx = result.x
            cos_theta = np.cos(theta)
            sin_theta = np.sin(theta)
            rotation_matrix = np.array(
                [
                    [cos_theta, -sin_theta, 0],
                    [sin_theta, cos_theta, 0],
                    [0, 0, 1],
                ]
            )
            scaling_matrix = np.array(
                [
                    [sy, 0, 0],
                    [0, sx, 0],
                    [0, 0, 1],
                ]
            )
            translation_matrix = np.array(
                [
                    [1, 0, ty],
                    [0, 1, tx],
                    [0, 0, 1],
                ]
            )

            self.matrix_transform = (
                translation_matrix @ scaling_matrix @ rotation_matrix
            )

    def _update_isotropic_similarity_transform(self):
        if self.reference_landmarks is not None and self.target_landmarks is not None:
            valid_rows = ~np.isnan(self.reference_landmarks).any(axis=1) & ~np.isnan(
                self.target_landmarks
            ).any(axis=1)
            src_valid = self.reference_landmarks[valid_rows]
            dst_valid = self.target_landmarks[valid_rows]

            if self.angle is not None:
                if len(src_valid) < 2:
                    raise ValueError(
                        "At least two pairs of non-NaN points are required."
                    )
                initial_guess = [
                    1,
                    0,
                    0,
                ]  # Initial guess for [s, ty, tx]
                result = minimize(
                    _objective_function_isotropic_fixed_angle,
                    initial_guess,
                    args=(src_valid, dst_valid, self.angle, self.flip),
                )
                s, ty, tx = result.x

                theta = self.angle
            else:
                if len(src_valid) < 3:
                    raise ValueError(
                        "At least three pairs of non-NaN points are required."
                    )
                initial_guess = [
                    0,
                    1,
                    0,
                    0,
                ]  # Initial guess for [theta, s, ty, tx]
                bounds = [
                    (-np.pi, np.pi),
                    (None, None),
                    (None, None),
                    (None, None),
                ]  # Bounds for parameters
                result = minimize(
                    _objective_function_isotropic,
                    initial_guess,
                    args=(src_valid, dst_valid, self.flip),
                    bounds=bounds,
                )
                theta, s, ty, tx = result.x
            if self.flip:
                sx = -s
            else:
                sx = s
            cos_theta = np.cos(theta)
            sin_theta = np.sin(theta)
            rotation_matrix = np.array(
                [
                    [cos_theta, -sin_theta, 0],
                    [sin_theta, cos_theta, 0],
                    [0, 0, 1],
                ]
            )
            scaling_matrix = np.array(
                [
                    [s, 0, 0],
                    [0, sx, 0],
                    [0, 0, 1],
                ]
            )
            translation_matrix = np.array(
                [
                    [1, 0, ty],
                    [0, 1, tx],
                    [0, 0, 1],
                ]
            )

            self.matrix_transform = (
                translation_matrix @ scaling_matrix @ rotation_matrix
            )

    def set_grid_size(self) -> None:
        """
        Finds the new origin and extents of the transformed image by the matrix transformation. We use this information
        to define the meshgrid for the grid compartments. (All the image must fit in the grid compartments after transformation.)
        """
        corners = np.array(
            [
                [0, 0, 1],
                [self.image_shape[0], 0, 1],
                [0, self.image_shape[1], 1],
                [self.image_shape[0], self.image_shape[1], 1],
            ]
        )

        # This is the shape of the transformed image, we need to create a meshgrid which will fit the whole image
        transformed_corners = _apply_matrix_transform_to_points(
            corners, self.matrix_transform
        )[:, :2]

        min_y, min_x = transformed_corners.min(axis=0)
        max_y, max_x = transformed_corners.max(axis=0)

        self.transformed_corners = np.rint(
            [[min_y, min_x], [max_y, min_x], [min_y, max_x], [max_y, max_x]]
        ).astype(int)

        return self.transformed_corners

    def set_masks(self, grid_group, animal) -> None:
        """
        Generates and sets a single mask array for the grid compartments based on their transformed corner points.
        """
        self._set_masks_eulerian()

    def _set_masks_eulerian(self):
        self.box_corners = np.zeros((self.X.shape[0], self.X.shape[1], 4, 2))
        self.centroids = np.zeros((self.X.shape[0], self.X.shape[1], 2))
        self.mask_positions = np.zeros((self.X.shape[0], self.X.shape[1]), dtype=object)

        # Progress bar for mask generation
        if self.verbose:
            total_masks = self.X.shape[0] * self.X.shape[1]
            pbar = tqdm(total=total_masks, desc="Processing masks", leave=False)
        else:
            pbar = None

        for i in range(self.X.shape[0]):
            for j in range(self.X.shape[1]):
                # The 1 in points is for the translation of the matrix transform;
                # points are (y, x, 1), matching the landmark convention the transform was fit on.
                points = np.array(
                    [
                        [self.Y[i, j], self.X[i, j], 1],
                        [self.Y[i, j] + self.box_size[0], self.X[i, j], 1],
                        [
                            self.Y[i, j] + self.box_size[0],
                            self.X[i, j] + self.box_size[1],
                            1,
                        ],
                        [self.Y[i, j], self.X[i, j] + self.box_size[1], 1],
                    ]
                )

                transformed_pts = _apply_matrix_transform_to_points(
                    points, np.linalg.inv(self.matrix_transform)
                )[:, :2]

                self.box_corners[i, j] = transformed_pts
                self.centroids[i, j] = np.mean(transformed_pts, axis=0)

                # Calculate the bounding box of the transformed points
                min_y, min_x = np.floor(transformed_pts.min(axis=0)).astype(int)
                max_y, max_x = np.ceil(transformed_pts.max(axis=0)).astype(int)

                # Ensure the bounding box stays within the image dimensions
                min_y = max(min_y, 0)
                min_x = max(min_x, 0)
                max_y = min(max_y, self.image_shape[0])
                max_x = min(max_x, self.image_shape[1])

                # Calculate the dimensions of the mask array
                mask_height = max_y - min_y
                mask_width = max_x - min_x

                # Initialize mask_positions with an empty tuple
                self.mask_positions[i, j] = (
                    np.array([], dtype=int),
                    np.array([], dtype=int),
                )

                # Skip the current iteration if the mask dimensions are <= 0
                if mask_height <= 0 or mask_width <= 0:
                    if pbar is not None:
                        pbar.update(1)
                    continue

                # Create a mask for the bounding box region
                mask = np.zeros((mask_height, mask_width), dtype=bool)

                # Adjust the transformed points to be relative to the bounding box
                transformed_pts_relative = transformed_pts - np.array([min_y, min_x])

                # Generate the mask using the adjusted points
                mask = polygon2mask(mask.shape, transformed_pts_relative)
                interest_region = self.roi
                mask = mask * interest_region[min_y:max_y, min_x:max_x]

                # Store the mask positions relative to the original image
                mask_indices = np.where(mask)
                self.mask_positions[i, j] = (
                    mask_indices[0] + min_y,
                    mask_indices[1] + min_x,
                )

                if pbar is not None:
                    pbar.update(1)

        if pbar is not None:
            pbar.close()


    def set_meshgrid(self) -> None:
        """
        Generate the meshgrid based on the transformed image extents.
        """

        dy, dx = self.box_size

        # Calculate the range of y-coordinates
        y_start = self.transformed_corners[0, 0]
        y_end = self.transformed_corners[3, 0]
        y_step = dy * (1 - self.overlap)
        y_range = np.arange(y_start, y_end, y_step)

        # Calculate the range of x-coordinates
        x_start = self.transformed_corners[0, 1]
        x_end = self.transformed_corners[3, 1]
        x_step = dx * (1 - self.overlap)
        x_range = np.arange(x_start, x_end, x_step)

        # Generate the meshgrid
        Y, X = np.meshgrid(y_range, x_range, indexing="xy")

        self.Y, self.X = Y, X

    def _compute_compartment_size(self) -> ArrayLike:
        """
        Computes the size of each compartment in the grid based on the box size and overlap.

        :return: A tuple containing the width and height of each compartment.
        """

        box_size = self.box_size_microns / self.scaling

        self.box_size = np.array(box_size)

    def __getitem__(self, item: Tuple[int, int]) -> np.ndarray:
        i, j = item
        mask = np.zeros(self.image_shape, dtype=bool)
        mask[self.mask_positions[i, j]] = True
        return mask

    @property
    def shape(self):
        """
        Returns the shape of the meshgrid.

        :return: The shape of the X (and Y) meshgrid arrays.
        """
        return self.X.shape

    @property
    def contour_mask(self):
        """
        Generates contour masks for the grid compartments based on the masks.
        """
        canvas = np.zeros(self.image_shape, dtype=np.uint8)

        for i in range(self.mask_positions.shape[0]):
            for j in range(self.mask_positions.shape[1]):
                mask = self[i, j]
                contours = find_contours(mask, 0.5)
                for contour in contours:
                    rr, cc = polygon_perimeter(
                        contour[:, 0], contour[:, 1], canvas.shape
                    )
                    canvas[rr, cc] = 255

        return canvas

    @property
    def label_mask(self):
        """
        Generates label masks for the grid compartments based on the masks.
        """
        canvas = np.zeros(self.image_shape, dtype=np.uint16)

        for i in range(self.mask_positions.shape[0]):
            for j in range(self.mask_positions.shape[1]):
                mask = self[i, j]
                canvas[mask] = (i * self.mask_positions.shape[1]) + j + 1

        return canvas

    def store_rescaling_info(
        self, animal: zarr.hierarchy.Group, reference_animal_parameter: str
    ) -> None:
        """
        Stores the rescaling information in the animal group.
        """
        # Create or get the 'GRID' and 'GRID_PROPERTIES' groups
        grid_group = animal.require_group("GRID")
        grid_group = animal.GRID.require_group(self.grid_name)
        properties_group = grid_group.require_group("GRID_PROPERTIES")

        properties_group.attrs["grid_type"] = self.grid_type
        properties_group.attrs["image_shape"] = self.image_shape.tolist()
        properties_group.attrs["matrix_transform"] = self.matrix_transform.tolist()
        properties_group.attrs["reference_animal_parameter"] = (
            reference_animal_parameter  # Storing the reference animal parameter
        )

    def store_meshgrid_info(
        self, animal: zarr.hierarchy.Group, reference_animal_parameter: str
    ) -> None:
        """
        Stores the grid and its properties, including the transformation matrix, in a Zarr group under the provided animal group.
        Additionally stores a reference animal parameter as an attribute. Overwrites any existing data.

        :param animal: Zarr group where the Grid properties will be stored.
        :param reference_animal_parameter: A string parameter for referencing the animal associated with this grid.
        """

        # Create or get the 'GRID' and 'GRID_PROPERTIES' groups
        grid_group = animal.require_group("GRID")
        grid_group = animal.GRID.require_group(self.grid_name)
        properties_group = grid_group.require_group("GRID_PROPERTIES")

        properties_group.attrs["grid_type"] = self.grid_type
        properties_group.attrs["frame_grid_definition"] = self.frame_grid_definition

        # Store simple properties and the reference animal parameter as attributes
        properties_group.attrs["box_size_microns"] = self.box_size_microns.tolist()
        properties_group.attrs["overlap"] = self.overlap
        properties_group.attrs["scaling"] = self.scaling
        # Persist the overall grid box corners (largest common grid), whether provided or computed
        if getattr(self, "transformed_corners", None) is not None:
            properties_group.attrs["grid_box_corners"] = (
                self.transformed_corners.tolist()
            )

        # Storing numerical arrays directly, overwriting if they exist
        properties_group.array("X", data=self.X, chunks=True, overwrite=True)
        properties_group.array("Y", data=self.Y, chunks=True, overwrite=True)
        properties_group.array(
            "box_corners", data=self.box_corners, chunks=True, overwrite=True
        )
        properties_group.array(
            "centroids", data=self.centroids, chunks=True, overwrite=True
        )

        # Store mask_positions as a Zarr dataset without flattening
        properties_group.create_dataset(
            "mask_positions",
            data=self.mask_positions,
            shape=self.mask_positions.shape,
            dtype=object,
            object_codec=zarr.codecs.Pickle(),
            chunks=(1, self.mask_positions.shape[1]),
            overwrite=True,
        )

        # Storing the grid numbers in the grid properties group for ease of plotting afterwards
        # and the calling sequence in generate_meshgrids is followed.
        if (
            hasattr(self, "time_points")
            and self.time_points is not None
            and hasattr(self, "X")
            and self.X is not None
            and self.X.size > 0
        ):
            t = self.time_points
            y, x = self.X.shape
            final_grid_numbers = generate_grid_numbers((t, y, x))

            properties_group.create_dataset(
                "grid_numbers",
                data=final_grid_numbers,
                dtype=np.uint16,
                overwrite=True,
            )

        # Store or overwrite reference and target landmarks datasets
        if self.reference_landmarks is not None:
            properties_group.array(
                "reference_landmarks", data=self.reference_landmarks, overwrite=True
            )
        if self.target_landmarks is not None:
            properties_group.array(
                "target_landmarks", data=self.target_landmarks, overwrite=True
            )
            animal.GRID[self.grid_name].require_group("D2")
            animal.GRID[self.grid_name].require_group("D3")

    def cleanup(self) -> None:
        """
        Releases heavy data attributes to free memory.
        """
        self.X = None
        self.Y = None
        self.box_corners = None
        self.centroids = None
        self.mask_positions = None
        self.transformed_corners = None
        self.area_ratios = None


def generate_archetype(
    output_path: str,
    animals: List[zarr.hierarchy.Group] = None,
    landmarks: np.ndarray = None,
    registration_name: str = "default",
    n_anchor_macros: int = 4,
    n_macros: int = None,
    grid_frame: Tuple[float, float, float, float] = None,
    name: str = "archetype",
) -> zarr.hierarchy.Group:
    """
    Persists a landmark reference (an "archetype") that the grid API accepts directly as
    ``reference_animal``.

    The archetype landmarks are either supplied directly (``landmarks``, in microns -- e.g. a
    published archetype reproduced from its coordinates) or derived from a cohort (``animals``):
    each animal's landmarks are origin-referenced to the barycenter of its first
    ``n_anchor_macros`` macrochaetae, converted to microns via its ``scaling`` attribute, and
    averaged per landmark. Only a translation and an isotropic micron conversion enter the
    archetype -- the anisotropic x/y rescaling and rotation belong to the second-stage fit onto
    it. When derived from animals, they must share the same half-notum.

    ``grid_frame`` stipulates a fixed grid extent ``(y_min, y_max, x_min, x_max)`` in microns:
    when set it is stored on the archetype so ``generate_common_grid`` tiles this exact frame for
    every animal (one common grid, as MATLAB does) instead of the per-animal image-bounds union.

    :param output_path: Path of the zarr store the archetype is written to.
    :param animals: Cohort whose landmarks define the archetype (ignored if ``landmarks`` given).
    :param landmarks: Explicit archetype landmarks as ``(n, 2)`` ``(y, x)`` rows in microns.
    :param registration_name: Space-registration group holding ``landmarks`` as (t, y, x) rows.
    :param n_anchor_macros: Number of leading macrochaetae averaged into the per-animal origin.
    :param n_macros: Keep only the first ``n_macros`` landmarks (e.g. to drop a trailing neck point).
    :param grid_frame: Fixed grid extent ``(y_min, y_max, x_min, x_max)`` in microns.
    :param name: Value written to the archetype's ``name`` attribute.
    :return: The archetype as a zarr group, usable as ``reference_animal``.
    """
    if landmarks is None:
        referenced_landmarks = []
        for animal in animals:
            landmarks_tyx = animal.SPACE_REGISTRATION[registration_name].landmarks[:]
            yx = landmarks_tyx[:, 1:]
            anchor = yx[:n_anchor_macros]
            anchor = anchor[~np.isnan(anchor).any(axis=1)]
            if len(anchor) == 0:
                continue  # animal without a usable space registration
            origin = anchor.mean(axis=0)
            referenced_landmarks.append((yx - origin) * animal.attrs["scaling"])  # microns

        if not referenced_landmarks:
            raise ValueError("No animal has enough valid landmarks to build an archetype.")

        # NaN-pad to a common length, then average per landmark row (ragged availability -> nanmean).
        max_rows = max(arr.shape[0] for arr in referenced_landmarks)
        stacked = np.full((len(referenced_landmarks), max_rows, 2), np.nan)
        for i, arr in enumerate(referenced_landmarks):
            stacked[i, : arr.shape[0]] = arr
        landmarks = np.nanmean(stacked, axis=0)  # (max_rows, 2), microns

    landmarks = np.asarray(landmarks, dtype=float)
    if n_macros is not None:
        landmarks = landmarks[:n_macros]

    ref = zarr.open_group(output_path, mode="w")
    ref.attrs["name"] = name
    ref.attrs["scaling"] = 1.0  # archetype coordinates are already in microns
    reg = ref.require_group("SPACE_REGISTRATION").require_group(registration_name)
    reg.attrs["angle"] = None
    reg.create_dataset(
        "landmarks", data=np.column_stack([np.zeros(len(landmarks)), landmarks])
    )
    reg.create_dataset("lines", data=np.empty((0,), dtype=float))
    reg.create_dataset("rois", data=np.empty((0, 2), dtype=float))
    if grid_frame is not None:
        y_min, y_max, x_min, x_max = grid_frame
        reg.attrs["grid_box_corners"] = [
            [y_min, x_min], [y_max, x_min], [y_min, x_max], [y_max, x_max]
        ]
    return ref


def generate_common_grid(
    animals: List[zarr.hierarchy.Group],
    boxsize: List[float],
    overlap: float,
    registration_name: str = "default",
    reference_animal: zarr.hierarchy.Group = None,
    transform_type: Literal[
        "isotropic_similarity", "xyscale_translation"
    ] = "xyscale_translation",
    grid_type: Literal["eulerian"] = "eulerian",
    grid_name: str = None,
    time_def_grid: str = None,
    number_background_dilation=10,
    grid_box_corners=None,
    verbose: bool = False,
    use_attrs_matrix_transform=False,
    n_jobs=-1,
) -> None:
    """
    Determines the rescaling parameters and generates a common grid for multiple animals.

    :param animals: A list of Zarr groups representing the animals.
    :type animals: List[zarr.hierarchy.Group]
    :param boxsize: A list of floats representing the size of each grid compartment.
    :type boxsize: List[float]
    :param overlap: A float representing the overlap between grid compartments.
    :type overlap: float
    :param registration_name: A string representing the name for the registration process. Defaults to "default".
    :type registration_name: str, optional
    :param reference_animal: A Zarr group representing the reference animal. If not provided, the first animal in the list will be used as the reference.
    :type reference_animal: zarr.hierarchy.Group, optional
    :param transform_type: The type of matrix transformation to apply: "isotropic_similarity" (rotation + isotropic scaling) or "xyscale_translation" (independent x/y scaling + translation, no rotation). Default is "xyscale_translation".
    :type transform_type: Literal["isotropic_similarity", "xyscale_translation"], optional
    :param grid_type: The type of grid. Only "eulerian" is supported.
    :type grid_type: Literal["eulerian"], optional
    :param grid_name: Name of the GRID/<grid_name> group to write. Defaults to grid_type.upper() (i.e. "EULERIAN"), so several grids can coexist on one animal.
    :type grid_name: str, optional
    :param time_def_grid: A time string used to define the grid.
    :type time_def_grid: str, optional
    :param number_background_dilation: Number of background dilation iterations.
    :type number_background_dilation: int, optional
    :param grid_box_corners: A list of tuples representing the corners of the largest commong grid, is used to align a grid with previous analysis grids.
    :type grid_box_corners: list, optional
    :param verbose: If True, prints additional progress messages.
    :type verbose: bool, optional
    :param use_attrs_matrix_transform: Whether to use a matrix transform stored in attributes.
    :type use_attrs_matrix_transform: bool, optional
    :param n_jobs: The number of jobs to run in parallel. Defaults to -1 (use all processors).
    :type n_jobs: int, optional

    :return: None

    **Example:**

    .. code-block:: python

        import zarr
        from pyanimalprocessing.rescaling.registration import generate_common_grid

        # Load your Zarr data
        animals = [zarr.open("path/to/animal1"), zarr.open("path/to/animal2")]

        # Generate a common grid
        generate_common_grid(
            animals=animals,
            boxsize=[40, 40],
            overlap=0.5,
            registration_name="example_registration",
            grid_type="eulerian",
            verbose=True
        )
    """
    grid_name = grid_name if grid_name is not None else grid_type.upper()

    grids, transformed_corners = prepare_grids(
        animals=animals,
        registration_name=registration_name,
        reference_animal=reference_animal,
        transform_type=transform_type,
        grid_type=grid_type,
        grid_name=grid_name,
        use_attrs_matrix_transform=use_attrs_matrix_transform,
        verbose=verbose,
    )

    # A reference archetype may carry a fixed grid frame (generate_archetype's grid_frame): honor
    # it so every animal is tiled onto one common grid instead of the per-animal image-bounds union.
    if grid_box_corners is None and reference_animal is not None:
        grid_box_corners = reference_animal.SPACE_REGISTRATION[
            registration_name
        ].attrs.get("grid_box_corners")
    if grid_box_corners is not None:
        transformed_corners = np.array(grid_box_corners)

    generate_meshgrids(
        animals=animals,
        grids=grids,
        boxsize=boxsize,
        overlap=overlap,
        transformed_corners=transformed_corners,
        time_def_grid=time_def_grid,
        registration_name=registration_name,
        reference_animal=reference_animal,
        grid_type=grid_type,
        grid_name=grid_name,
        number_background_dilation=number_background_dilation,
        verbose=verbose,
        n_jobs=n_jobs,
    )


def prepare_grids(
    animals: List[zarr.hierarchy.Group],
    registration_name: str = "default",
    reference_animal: zarr.hierarchy.Group = None,
    transform_type: Literal[
        "isotropic_similarity", "xyscale_translation"
    ] = "xyscale_translation",
    grid_type: Literal["eulerian"] = "eulerian",
    grid_name: str = None,
    use_attrs_matrix_transform: bool = False,
    verbose: bool = False,
) -> Tuple[List[Grid], np.ndarray, List[int]]:
    """
    Calculates rescaling parameters and creates Grid objects for a list of animals.

    Also returns the transformed corners of the largest grid that will fit all animals.

    :meta private:
    :param animals: A list of Zarr groups representing the animals.
    :param boxsize: A list of floats representing the size of each grid compartment.
    :param overlap: A float representing the overlap between grid compartments.
    :param registration_name: The name of the registration to use. Default is "default".
    :param reference_animal: A Zarr group representing the reference animal. If not provided, the first animal in the list will be used as the reference.
    :param transform_type: The type of matrix transformation to apply ("isotropic_similarity" or "xyscale_translation"). Default is "xyscale_translation".
    :param use_attrs_matrix_transform: Whether to use a matrix transform stored in attributes.
    :param verbose: If True, prints additional progress messages.
    :return: A tuple containing the list of Grid objects, transformed corners
    """
    if not isinstance(animals, list):
        animals = [animals]

    if reference_animal is None:
        reference_animal = animals[0]

    landmarks = _generate_landmark_arrays(
        animals + [reference_animal], registration_name=registration_name
    )[..., 1:]

    landmarks_target = landmarks[-1]
    landmarks = landmarks[:-1]

    grids = []
    for i, animal in enumerate(
        tqdm(
            animals,
            desc="Generating Grids objects and rescaling",
            unit="animal",
        )
    ):
        if use_attrs_matrix_transform:
            matrix_transform = animal.attrs["matrix_transform"]
        else:
            matrix_transform = None
        if "angle" in animal.SPACE_REGISTRATION[registration_name].attrs:
            angle = animal.SPACE_REGISTRATION[registration_name].attrs["angle"]
        else:
            angle = None

        try:
            grid = Grid(
                image_shape=animal.IMAGE.D2.raw[0, 0].shape,
                reference_landmarks=landmarks[i],
                target_landmarks=landmarks_target,
                transform_type=transform_type,
                angle=angle,
            )

            grid.grid_type = grid_type
            grid.grid_name = grid_name if grid_name is not None else grid_type.upper()
            grid.store_rescaling_info(animal, reference_animal.attrs["name"])
        # To identify the animal name that does not have enough points registered in the space registration
        except ValueError as e:

            animal_name = animal.attrs.get("name", "Unknown animal")
            raise ValueError(
                f"{e} for animal {animal_name} position {i} in the list of animals"
            ) from e
        grids.append(grid)

    _vprint("Defining the largest image shape", verbose)
    transformed_corners = _define_largest_image_shape(grids)

    return grids, transformed_corners


def generate_meshgrids(
    animals: List[zarr.hierarchy.Group],
    grids: List[Grid],
    boxsize: List[float],
    overlap: float,
    transformed_corners: np.ndarray,
    time_def_grid: str = None,
    registration_name: str = "default",
    reference_animal: zarr.hierarchy.Group = None,
    grid_type: Literal["eulerian"] = "eulerian",
    grid_name: str = None,
    number_background_dilation: int = 10,
    verbose: bool = False,
    n_jobs: int = -1,
) -> None:
    """
    Generates meshgrids for a list of animals using pre-calculated Grid objects.

    :meta private:
    :param animals: A list of Zarr groups representing the animals.
    :param grids: A list of Grid objects with rescaling parameters.
    :param transformed_corners: The corners of the transformed image that will fit all animals.
    :param frame_def_grid: A list of frame indices for grid definition.
    :param registration_name: The name of the registration to use. Default is "default".
    :param grid_type: The type of grid. Default is "eulerian".
    :param number_background_dilation: Number of background dilation iterations.
    :param verbose: If True, prints additional progress messages.
    :param n_jobs: Number of parallel jobs to run.
    """
    if not isinstance(animals, list):
        animals = [animals]

    if reference_animal is None:
        reference_animal = animals[0]

    if time_def_grid is None:
        frame_def_grid = [0 for _ in animals]
    else:
        for animal in animals:
            require_timing_attrs(animal, "grid definition at a fixed time (time_def_grid)")
        frame_def_grid = [
            round(
                time_to_frame(
                    time_def_grid,
                    animal.attrs["time_ref"],
                    animal.attrs["frame_ref"],
                    animal.attrs["dt"],
                )
            )
            for animal in animals
        ]

    total_animals = len(animals)
    for i, (grid, animal) in enumerate(zip(grids, animals)):
        animal_name = animal.attrs.get("name", f"animal_{i}")
        _vprint(f"Processing animal {animal_name} ({i + 1}/{total_animals})", verbose)

        if (
            "rois" in animal.SPACE_REGISTRATION[registration_name]
            and animal.SPACE_REGISTRATION[registration_name].rois.shape[0] > 0
        ):
            masks = [
                skimage.draw.polygon2mask(
                    animal.IMAGE.D2.raw.shape[2:],
                    animal.SPACE_REGISTRATION[registration_name].rois[i],
                )
                for i in range(
                    animal.SPACE_REGISTRATION[registration_name].rois.shape[0]
                )
            ]
            roi = np.logical_or.reduce(masks)
        else:
            roi = np.ones(animal.IMAGE.D2.raw.shape[2:], bool)

        if "mask" in animal.IMAGE.D2:
            tissue = animal.IMAGE.D2.mask[:]
        else:
            tissue = np.ones(
                (animal.IMAGE.D2.raw.shape[0], *animal.IMAGE.D2.raw.shape[2:]), bool
            )

        # Setting all grid attributes necessary for the meshgrid generation
        grid.grid_type = grid_type
        grid.grid_name = grid_name if grid_name is not None else grid_type.upper()
        grid.frame_grid_definition = frame_def_grid[i]
        grid.roi = roi
        grid.tissue = tissue
        grid.ndil = number_background_dilation
        grid.box_size_microns = np.array(boxsize)
        grid.overlap = overlap

        grid.scaling = reference_animal.attrs["scaling"]
        grid.verbose = verbose
        grid.n_jobs = n_jobs
        grid._compute_compartment_size()
        grid._validate_inputs()
        grid.find_timepoints(animal)

        grid.transformed_corners = transformed_corners
        _vprint("Generating meshgrid", verbose)
        grid.set_meshgrid()
        grid_group = animals[i].require_group("GRID")
        grid_group = grid_group.require_group(grid.grid_name)
        properties_group = grid_group.require_group("GRID_PROPERTIES")
        _vprint("Setting the masks", verbose)
        grid.set_masks(properties_group, animals[i])
        grid.store_meshgrid_info(
            animals[i], Path(reference_animal.store.dir_path()).name
        )
        animals[i].GRID[grid.grid_name].GRID_PROPERTIES.attrs[
            "registration_name"
        ] = registration_name

        # Cleaning up the grid to release memory
        grid.cleanup()

        generate_area_ratios(
            animals[i], grid_type, grid.tissue, verbose, grid_name=grid.grid_name
        )
        del grid


def generate_area_ratios(animal, grid_type, mask, verbose=False, grid_name=None):
    """
    Generates the area ratios for each grid compartment based on the label mask.

    :meta private:
    :param animal: zarr group of the animal
    :param grid_name: GRID/<name> group key (defaults to grid_type.upper()).
    :return: A 2D numpy array containing the area ratios for each grid compartment.
    """
    grid_name = grid_name if grid_name is not None else grid_type.upper()
    grid_properties = animal.GRID[grid_name].GRID_PROPERTIES

    animal.GRID[grid_name].require_group("D2")
    animal.GRID[grid_name].require_group("D3")
    # I put half the size of the grid in chunks to avoid memory issues for very large images (ex : (1, 2, 5376, 10871))
    if grid_type == "eulerian":
        backup_grid_with_time = grid_properties.create_dataset(
            "lagrangian_grid",
            shape=(animal.IMAGE.D2.raw.shape[0], *grid_properties.X.shape),
            dtype=object,
            chunks=(1, *(dim // 2 for dim in grid_properties.X.shape)),
            object_codec=zarr.codecs.Pickle(),
            overwrite=True,
        )
    else:
        backup_grid_with_time = None
    area_ratios = _generate_area_ratios(
        mask,
        grid_type,
        grid_properties,
        backup_grid_with_time=backup_grid_with_time,
    )
    grid_properties.array("area_ratios", data=area_ratios, overwrite=True)


def _generate_area_ratios(
    label_mask: np.ndarray,
    grid_type,
    grid_properties: zarr.hierarchy.group,
    backup_grid_with_time=None,
) -> np.ndarray:
    """
    Generates the area ratios for each grid compartment based on the label mask.
    :param label_mask: A 2D numpy array representing the label mask.
    :param grid: A Grid object representing the grid compartments.
    :return: A 2D numpy array containing the area ratios for each grid compartment.
    """
    area_ratios = _generate_area_ratios_eulerian(
        label_mask, grid_properties, backup_grid_with_time
    )

    # Clip the values above 1 to 1
    area_ratios = np.clip(area_ratios, 0, 1)

    return area_ratios


def _generate_area_ratios_eulerian(
    label_mask: np.ndarray, grid_properties: zarr.hierarchy.group, bu_zarr_mask
) -> np.ndarray:
    time_points = label_mask.shape[0]
    grid_height, grid_width = grid_properties.X.shape
    grid_shape = [time_points, grid_height, grid_width]
    area_ratios = np.zeros(grid_shape, np.float16)

    # Finding the number of pixels within a grid compartment
    box_pixel_number = _approximate_polygon_area(grid_properties.box_corners[1, 1])

    # Pre-compute mask indices for each grid cell
    mask_pos = grid_properties.mask_positions[:]

    # For each time point
    for t in tqdm(range(time_points)):
        indices_per_time_point = np.zeros(bu_zarr_mask.shape[1:], object)

        # Get the label mask for this time point
        current_label_mask = label_mask[t]

        # For each grid cell
        for i in range(grid_height):
            for j in range(grid_width):
                # Get mask positions for this grid cell
                mask_positions = mask_pos[i, j]
                y_indices, x_indices = mask_positions

                # Apply the mask to the current label mask
                # Get only values where both the grid mask and label mask are True
                valid_points = current_label_mask[y_indices, x_indices]

                # Count valid points and calculate area ratio
                valid_count = np.sum(valid_points)
                area_ratios[t, i, j] = valid_count / float(box_pixel_number)

                # Store the valid indices
                if valid_count > 0:
                    # Get indices where valid_points is True
                    valid_indices = np.where(valid_points)[0]
                    y_valid = y_indices[valid_indices]
                    x_valid = x_indices[valid_indices]
                    indices_per_time_point[i, j] = (y_valid, x_valid)
                else:
                    indices_per_time_point[i, j] = (
                        np.empty(0, dtype=int),
                        np.empty(0, dtype=int),
                    )

        # Store results for this time point
        bu_zarr_mask[t] = indices_per_time_point

    return area_ratios[:, np.newaxis, ..., np.newaxis]


def _apply_matrix_transform_to_points(
    points: ArrayLike, transform_matrix: NDArray
) -> NDArray:
    """
    Applies a matrix transformation to a set of points.

    :param points: An array of points to transform. Shape should be (N, 3) for homogeneous coordinates.
    :param transform_matrix: The transformation matrix.
    :return: The transformed points in homogeneous coordinates.
    """
    shape = points.shape
    flattened = points.reshape(-1, shape[-1])
    transformed_points = (transform_matrix @ flattened.T).T
    return transformed_points.reshape(shape)


def _generate_landmark_arrays(
    animals: List[zarr.hierarchy.Group], registration_name: str = "default"
) -> np.ndarray:
    """
    Generates arrays of landmarks and lines from a list of animals with landmark data.

    :param animals: A list of Zarr groups representing the animals.
    :param registration_name: The name of the registration to use. Default is "default".
    :return: A numpy array representing the concatenated landmarks and extra projected points.
    """
    landmark_arrays = []
    line_arrays = []
    for animal in animals:
        animal_name = animal.attrs.get('name', 'unknown')
        if (
            "SPACE_REGISTRATION" not in animal
            or registration_name not in animal.SPACE_REGISTRATION
        ):
            raise ValueError(
                f"Space registration '{registration_name}' not found in animal {animal_name}"
            )
        reg_group = animal.SPACE_REGISTRATION[registration_name]
        if "landmarks" not in reg_group:
            raise ValueError(
                f"Animal '{animal_name}' does not have 'landmarks' in registration '{registration_name}'. "
                f"Available keys: {list(reg_group.keys())}"
            )
        if "lines" not in reg_group:
            raise ValueError(
                f"Animal '{animal_name}' does not have 'lines' in registration '{registration_name}'. "
                f"Available keys: {list(reg_group.keys())}"
            )
        landmarks = reg_group.landmarks[:]
        lines = reg_group.lines[:]

        landmark_arrays.append(landmarks)
        line_arrays.append(lines)

    # Pad landmark arrays to have the same length along the first axis
    max_length = max(len(arr) for arr in landmark_arrays)
    landmark_arrays = np.array(
        [
            np.pad(arr, ((0, max_length - len(arr)), (0, 0)), constant_values=np.nan)
            for arr in landmark_arrays
        ]
    )

    # Ensure that every element in line_arrays has shape (n, 2, 3)
    formatted_line_arrays = []
    for arr in line_arrays:
        if arr.ndim != 3:
            # Reshape empty arrays to have shape (0, 2, 3)
            arr = arr.reshape(0, 2, 3)
        formatted_line_arrays.append(arr)

    # Determine the maximum number of lines among all animals.
    max_line_length = max(arr.shape[0] for arr in formatted_line_arrays)
    if max_line_length == 0:
        # Create an empty array with the expected shape
        padded_line_arrays = np.empty((len(formatted_line_arrays), 0, 2, 3))
    else:
        padded_line_arrays = [
            np.pad(
                arr,
                ((0, max_line_length - arr.shape[0]), (0, 0), (0, 0)),
                mode="constant",
                constant_values=np.nan,
            )
            for arr in formatted_line_arrays
        ]
    line_arrays = np.array(padded_line_arrays)

    extra_points = _convert_lines_to_landmarks(line_arrays, landmark_arrays)
    landmark_arrays = np.concatenate((landmark_arrays, extra_points), axis=1)

    return landmark_arrays


def _convert_lines_to_landmarks(
    line_arrays: np.ndarray, landmark_arrays: np.ndarray
) -> np.ndarray:
    """
    Converts line arrays to landmark arrays by projecting a common point onto the lines.
    For each line in line_arrays, projects (via orthogonal projection) the corresponding common landmark.
    If a line is missing (i.e. padded with NaNs) or no common landmark exists for that time point, returns a NaN landmark.

    :param line_arrays: A NumPy array of shape (num_animals, max_lines, 2, 3) representing line segments.
    :param landmark_arrays: A NumPy array of shape (num_animals, num_landmarks, 3)
                            representing landmark data.
    :return: A NumPy array of shape (num_animals, max_lines, 3) representing the projected landmarks.
    """
    # Determine common landmarks that exist (i.e. are not NaN) across all animals.
    common_landmarks_mask = np.all(~np.isnan(landmark_arrays), axis=0)
    common_landmarks = landmark_arrays[:, common_landmarks_mask].reshape(
        landmark_arrays.shape[0], -1, 3
    )

    if common_landmarks.shape[1] == 0:
        # Fallback: if no completely common landmarks are found, we use the most common landmark from each animal.
        non_nan_counts = np.sum(~np.isnan(landmark_arrays), axis=0)
        best_idx = np.argmax(non_nan_counts, axis=0)[0]
        common_landmarks = landmark_arrays[:, best_idx].reshape(
            landmark_arrays.shape[0], 1, 3
        )

    # Initialize the array to store the extra (projected) landmark points.
    extra_points_list = np.empty((line_arrays.shape[0], line_arrays.shape[1], 3))

    # For all animals, process each line segment.
    for animal_idx in range(line_arrays.shape[0]):
        animal_landmarks = common_landmarks[animal_idx]
        animal_segments = line_arrays[animal_idx]
        for i, segment in enumerate(animal_segments):
            # Check if the line segment has been padded (i.e. is invalid).
            if np.any(np.isnan(segment)):
                extra_points_list[animal_idx, i] = np.array([np.nan, np.nan, np.nan])
                continue
            # Extract the time coordinate from the segment (assumed to be stored in the first element)
            t_pos = segment[0, 0]
            # Retrieve the common landmarks corresponding to the same time point.
            common_landmarks_t = animal_landmarks[animal_landmarks[:, 0] == t_pos]
            if common_landmarks_t.size == 0:
                extra_points_list[animal_idx, i] = np.array([np.nan, np.nan, np.nan])
                continue
            # Project (orthogonally) the chosen common landmark onto the line segment.
            proj_point = _orthogonal_projection(
                common_landmarks_t[0, 1:], segment[..., 1:]
            )
            proj_point = np.insert(proj_point, 0, t_pos)
            extra_points_list[animal_idx, i] = proj_point

    return extra_points_list


def _define_largest_image_shape(grids: List[Grid]) -> NDArray:
    """
    Defines the largest image shape that will encompass all the animals.

    :param grids: A list of Grid objects representing the grids of the animals.
    :return: An array representing the largest image shape that encompasses all the animals.
    """
    min_x, min_y, max_x, max_y = np.inf, np.inf, -np.inf, -np.inf

    for grid in grids:
        transformed_corners = grid.set_grid_size()

        min_y = min(min_y, transformed_corners[0, 0])
        min_x = min(min_x, transformed_corners[0, 1])
        max_y = max(max_y, transformed_corners[3, 0])
        max_x = max(max_x, transformed_corners[3, 1])

    return np.array(
        [
            [min_y, min_x],
            [max_y, min_x],
            [min_y, max_x],
            [max_y, max_x],
        ]
    )


def _orthogonal_projection(point, segment):
    A, B = segment
    v = B - A
    w = point - A

    proj = A + np.dot(w, v) / np.dot(v, v) * v

    return proj


