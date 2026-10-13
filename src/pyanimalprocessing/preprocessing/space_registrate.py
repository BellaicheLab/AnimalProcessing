"""Interactive napari UIs for spatial registration: click landmarks and reference
axes on an animal's movie (:func:`space_registrate`) and draw ROIs on rescaled
animals (:func:`create_roi`), storing the results in the animal zarr store.
"""

import warnings
from typing import Dict, List, Optional, Union

import dask.array as da
import napari
import numpy as np
from numpy.typing import NDArray
from qtpy.QtCore import Qt
from qtpy.QtWidgets import (
    QApplication,
    QVBoxLayout,
    QWidget,
)

import zarr
from pyanimalprocessing.plotting.property_plotting import plot_rescaling
from pyanimalprocessing.preprocessing.ui_template import AbstractWidgets
from pyanimalprocessing.rescaling.registration import (
    _apply_matrix_transform_to_points,
)
from pyanimalprocessing.rescaling.temporal_alignment import (
    create_time_matrix_transform_from_zarr,
)
from pyanimalprocessing.rescaling.timings import time_to_frame
from pyanimalprocessing.utils import _initialize_viewer, _set_warning_filters

__all__ = ["space_registrate"]


def space_registrate(
    animal: zarr.Group,
    registration_name: str = "default",
    click_time: Optional[Union[str, List[str]]] = None,
    viewer: Optional[napari.Viewer] = None,
    lazy_load: bool = True,
    verbose: bool = False,
) -> None:
    """
    Perform spatial registration on animal imaging data using the napari viewer.

    This function initializes a napari viewer to facilitate interactive spatial registration of biological imaging data. Users can specify particular time points (``click_time``) at which the registration process should begin. If no ``click_time`` is provided, registration defaults to the first frame.

    **Important:** To use the ``click_time`` argument, you must specify a reference time (``time_ref``) in the animal's attributes in the format "XXhYY" (e.g., "24h05").

    :param animal: A zarr group containing the animal's imaging data and attributes.
    :type animal: zarr.Group
    :param registration_name: A unique identifier for the registration session. Defaults to "default".
    :type registration_name: str, optional
    :param click_time: Specific time point(s) at which to start the registration. If None, registration starts at the first frame (frame 0). Can be a single string or a list of strings, each formatted as "XXhYY".
    :type click_time: Optional[Union[str, List[str]]], optional
    :param viewer: An existing napari viewer instance to display images and landmarks. If None, a new viewer will be initialized.
    :type viewer: Optional[napari.Viewer], optional
    :param lazy_load: If True enable the raw data to be lazy loaded. If False, the raw image will be entirely loaded in the memory. Defaults to True.
    :type lazy_load: bool, optional
    :param verbose: If True, enables verbose output for debugging purposes.
    :type verbose: bool, optional
    :raises ValueError: If the click frame is negative.

    **Usage Example:**

    .. code-block:: python

        import zarr
        from pyanimalprocessing.preprocessing.space_registrate import space_registrate

        animal = zarr.open("path/to/animal_data.zarr")
        animal.attrs["time_ref"] = "24h00"  # Reference time must be set
        animal.attrs["frame_ref"] = 0
        animal.attrs["dt"] = 5.0  # time interval in minutes

        space_registrate(
            animal=animal,
            registration_name="experiment_1",
            click_time=["24h05", "27h10"],
            verbose=True
        )

    **Notes:**
    - Ensure that the ``animal`` zarr group has the necessary attributes (``time_ref``, ``frame_ref``, and ``dt``) set correctly to use the ``click_time`` feature.
    - The napari viewer will display the images, allowing interactive landmark placement and optional reference axis drawing.
    - Upon closing the viewer, the registration data (landmarks, lines, angle, and ROIs) will be automatically stored in the animal's zarr group under the specified ``registration_name``.
    """
    _set_warning_filters(verbose)

    viewer = _initialize_viewer(viewer, title=animal.attrs["name"])
    app = QApplication.instance()

    if click_time is None:
        click_frames = [0]
    else:
        if isinstance(click_time, str):
            click_time = [click_time]

        click_frames = [
            time_to_frame(
                times,
                animal.attrs["time_ref"],
                animal.attrs["frame_ref"],
                animal.attrs["dt"],
            )
            for times in click_time
        ]

    for click_tmp in click_frames:
        if click_tmp < 0:
            raise ValueError(
                f"Click frame must be positive (current value: {click_tmp})"
            )

    space_reg = SpaceRegistration(
        animal=animal,
        registration_name=registration_name,
        viewer=viewer,
        click_frames=click_frames,
        lazy_load=lazy_load,
    )
    viewer.window.add_dock_widget(space_reg.ui_widget)
    # Connect the on_close function to the destroyed signal of the Napari viewer's Qt viewer
    viewer.window.qt_viewer.destroyed.connect(lambda: space_reg.store_registration())
    napari.run()


def create_roi(
    animals: Union[zarr.Group, List[zarr.Group]],  # Accept single or list
    registration_name: str = "default",
    click_time: Optional[Union[str, List[str]]] = None,
    viewer: Optional[napari.Viewer] = None,
    lazy_load: bool = True,
    verbose: bool = False,
    grid_type: str = "eulerian",
    grid_name: str = None,
) -> None:
    """
    Perform ROI creation on several already rescaled animals, needs to be run after the preparation of the grids (prepare_grids or generate_common_grid).

    Allows users to draw ROIs (Regions of Interest) on specific frames.

    :param animals: A zarr group or list of zarr groups containing the animals' imaging data and attributes.
    :param registration_name: A unique identifier for the registration session where ROIs will be stored. Defaults to "default".
    :param click_time: Specific time point(s) at which to view for ROI drawing. If None, defaults to the first frame (frame 0). Can be a single string or a list of strings, each formatted as "XXhYY". Requires 'time_ref', 'frame_ref', 'dt' attributes in the animal zarr group.
    :param viewer: An existing napari viewer instance. If None, a new viewer will be initialized.
    :param lazy_load: If True enable the raw data to be lazy loaded. Defaults to True.
    :param verbose: If True, enables verbose output.
    :param grid_type: The type of grid the animals were rescaled onto. Defaults to "eulerian".
    :param grid_name: Name of the GRID/<grid_name> group to use. Defaults to grid_type.upper().
    :raises ValueError: If the calculated click frame is negative.
    """
    _set_warning_filters(verbose)

    if not isinstance(animals, list):
        animals = [animals]

    viewer = _initialize_viewer(viewer, title="ROI Creation")
    group_key = grid_name if grid_name is not None else grid_type.upper()

    # Check that all required attributes exist for all animals
    for i, animal in enumerate(animals):
        animal_name = animal.attrs.get("name", "Unknown")
        required_attrs = ["time_ref", "frame_ref", "dt"]
        missing_attrs = [k for k in required_attrs if k not in animal.attrs]
        if missing_attrs:
            raise AttributeError(
                f"Animal {i} (name: {animal_name}) is missing required attributes: {', '.join(missing_attrs)}. "
                f"All animal zarr groups must contain 'time_ref', 'frame_ref', and 'dt' attributes to use 'click_time'."
            )

    # Any animal works as time reference: its raw click frame mapped through its
    # own transform lands on the same common-frame position for all animals.
    reference = animals[-1]
    matrix_transform = create_time_matrix_transform_from_zarr(
        reference, group_key, "00h00", dimension="D2"
    )
    plot_rescaling(
        animals, lazy_load=True, viewer=viewer, grid_type=grid_type, grid_name=grid_name
    )

    # Setting the position to the time fixed
    click_position_raw = time_to_frame(
        click_time,
        reference.attrs["time_ref"],
        reference.attrs["frame_ref"],
        reference.attrs["dt"],
    )

    click_position = (
        click_position_raw * matrix_transform[0, 0] + matrix_transform[0, -1]
    )
    viewer.dims.point = tuple([click_position] + list(viewer.dims.point[1:]))

    app = QApplication.instance()  # Ensure QApplication exists

    # Ensure necessary attributes exist for time conversion

    roi_reg = RoiRegistration(
        animals=animals,
        registration_name=registration_name,
        viewer=viewer,
        lazy_load=lazy_load,
        grid_type=grid_type,
        grid_name=grid_name,
    )
    viewer.window.add_dock_widget(roi_reg.ui_widget)
    # Connect the store_registration function to the destroyed signal of the viewer window
    viewer.window.qt_viewer.destroyed.connect(lambda: roi_reg.store_registration())
    napari.run()


class RoiRegistration(QWidget):
    """
    Handles the creation and storage of ROIs for an animal.

    :param animal: A zarr group containing animal images.
    :param registration_name: Identifier for the registration session.
    :param viewer: The napari viewer instance.
    :param click_frames: List of frame indices to view for ROI definition.
    :param lazy_load: Whether to lazy load image data.
    """

    viewer: napari.Viewer = None
    rois: NDArray[np.object_]

    def __init__(
        self,
        animals: List[zarr.Group],
        registration_name: str,
        viewer: napari.Viewer,
        lazy_load: bool = True,
        grid_type: str = "eulerian",
        grid_name: str = None,
    ):
        super().__init__()

        self.viewer = viewer
        self.animals = animals
        self.registration_name = registration_name
        self.current_frame_index = 0
        self.lazy_load = lazy_load
        self.grid_name = grid_name if grid_name is not None else grid_type.upper()
        self.setup_ui()
        self.retrieve_attrs()
        self.initialize_layers()

    def setup_ui(self):
        """Initializes the user interface components and connects signals."""
        self.ui_widget = RoiRegistrationUI()
        self.setup_text_overlay()

    def setup_text_overlay(self):
        """Setup the text overlay in the viewer."""
        self.viewer.text_overlay.visible = True
        self.viewer.text_overlay.text = "Draw ROIs using the polygon lasso tool."
        self.viewer.text_overlay.color = "cyan"
        self.viewer.text_overlay.position = "top_left"
        self.viewer.text_overlay.font_size = 20

    def remove_existing_layers(self):
        """Removes existing image and shape layers from the viewer."""
        layers_to_remove = [
            layer
            for layer in self.viewer.layers
            if isinstance(layer, (napari.layers.Image, napari.layers.Shapes))
        ]
        for layer in layers_to_remove:
            self.viewer.layers.remove(layer)

    def retrieve_attrs(self):
        """Retrieve existing ROIs from the animal's zarr group."""

        for animal in self.animals[:1]:
            space_registration = animal.require_group("SPACE_REGISTRATION")
            reg_group = space_registration.get(self.registration_name)

            if reg_group and "rois" in reg_group.keys():
                # Need to handle potential object array loading issues
                try:
                    self.rois = reg_group["rois"][:][0]
                    matrix_transform = animal.GRID[
                        self.grid_name
                    ].GRID_PROPERTIES.attrs["matrix_transform"]

                    # Convert ROI points from shape (n,2) to (n,3) by adding a column of ones
                    # This allows the matrix multiplication to work correctly
                    roi_points_3d = np.ones((self.rois.shape[0], 3))
                    roi_points_3d[:, :2] = self.rois

                    animal_roi = _apply_matrix_transform_to_points(
                        roi_points_3d, matrix_transform
                    )
                    self.rois = animal_roi[np.newaxis, :, :2]

                except (
                    Exception
                ):  # Fallback if direct slicing fails (e.g., older zarr/pickle)
                    self.rois = np.array(reg_group["rois"], dtype=object)

                # Ensure it's a numpy array of objects if loaded correctly
                if not isinstance(self.rois, np.ndarray):
                    self.rois = np.array(self.rois, dtype=object)

                # Handle case where it might be empty but not shaped correctly
                if self.rois.size == 0:
                    self.rois = np.empty(
                        (0, 2), dtype=object
                    )  # Assuming ROIs are Nx2 coordinate arrays

            else:
                self.rois = np.empty((0, 2), dtype=object)  # Default empty structure

    def initialize_layers(self):
        """Initializes the layers for ROI definition."""
        # self.remove_existing_layers()
        # self.viewer.dims.set_point(0, self.click_frames[self.current_frame_index])
        self.initialize_shape_layer()

    def initialize_shape_layer(self):
        """Initializes the shape layer for drawing and editing ROIs."""
        # Ensure self.rois is suitable for add_shapes
        if not isinstance(self.rois, (list, np.ndarray)):
            self.rois = np.empty((0, 2), dtype=object)
        elif (
            isinstance(self.rois, np.ndarray) and self.rois.ndim == 1
        ):  # Handle flat array case if needed
            # This might indicate an issue with how ROIs were saved/loaded
            # For now, reset to empty if shape is unexpected
            warnings.warn("ROIs array has unexpected shape, resetting.")
            self.rois = np.empty((0, 2), dtype=object)

        self.shape_layer = self.viewer.add_shapes(
            data=self.rois if len(self.rois) > 0 else None,  # Pass None if empty
            name="ROIs",
            edge_width=2,
            edge_color="cyan",
            opacity=0.5,
            shape_type="polygon",
        )

        self.shape_layer.mode = "ADD_POLYGON_LASSO"
        self.shape_layer.events.data.connect(self.on_shape_update)

    def on_shape_update(self, event=None):
        """Updates the ROIs when the shape layer is modified."""
        # Ensure data is stored as a list of arrays, suitable for object dtype zarr storage
        self.rois = np.array(self.shape_layer.data, dtype=object)

    def store_registration(self) -> None:
        """Stores the ROI data in the animal's zarr group."""

        # Commented lines correspond to finding the frame of the naimals where the roi was registered. Right now the rois don't use this aspect
        # but it could be useful to somebody for regions for isntance so I let it here

        # click_time_raw = self.viewer.dims.point[0]
        for animal in self.animals:

            # Finding where to store the roi in time
            matrix_transform_animal = create_time_matrix_transform_from_zarr(
                animal, self.grid_name, "00h00", dimension="D2"
            )
            geometric_transform = matrix_transform_animal[1:, 1:]

            # frame_to_store = (
            #     click_time_raw - matrix_transform_animal[0, -1]
            # ) / matrix_transform_animal[0, 0]

            # Finding where to store the roi in space

            # Convert ROI points from shape (n,2) to (n,3) by adding a column of ones
            # This allows the matrix multiplication to work correctly
            roi_points = self.rois[0]

            roi_points_3d = np.ones((roi_points.shape[0], 3))
            roi_points_3d[:, :2] = roi_points

            animal_roi = _apply_matrix_transform_to_points(
                roi_points_3d, np.linalg.inv(geometric_transform)
            )[:, :2]

            animal_roi = animal_roi

            # Storing the final roi
            reg_group = animal.require_group("SPACE_REGISTRATION").require_group(
                self.registration_name
            )

            if "rois" in reg_group.keys():
                del reg_group["rois"]
            reg_group.create_dataset(
                "rois", data=animal_roi[np.newaxis], object_codec=zarr.codecs.Pickle()
            )


class RoiRegistrationUI(AbstractWidgets):
    def setup_layout(self) -> None:
        """
        Sets up the layout for the space registration UI, including title, buttons, and layout configuration.
        """
        self.layout = QVBoxLayout(self)
        title = self.create_title_label("ROI Registration")
        self.layout.addWidget(title, alignment=Qt.AlignTop)


class SpaceRegistrationUI(AbstractWidgets):
    def setup_layout(self) -> None:
        """
        Sets up the layout for the space registration UI, including title, buttons, and layout configuration.
        """
        self.layout = QVBoxLayout(self)
        title = self.create_title_label("Space Registration")
        self.layout.addWidget(title, alignment=Qt.AlignTop)
        # self.layout.addWidget(title)

        group_box_button, button_list = self.create_group_box_with_buttons(
            "Action:",
            ["Undo", "Skip", "Previous Time Point", "Next Time Point"],
            orientation="vertical",
        )
        self.undo_button = button_list[0]
        self.skip_button = button_list[1]
        self.previous_time_point_button = button_list[2]
        self.next_time_point_button = button_list[3]
        self.layout.addWidget(group_box_button, alignment=Qt.AlignTop)
        self.layout.addStretch()


class SpaceRegistration(QWidget):
    """
    Performs the space registration on one animal.

    :param viewer: The napari viewer instance to display images and landmarks.
    :param animal_zarr: A zarr group containing animal images for registration.
    """

    viewer: napari.Viewer = None
    landmarks: Dict[int, NDArray[np.int16]]

    def __init__(
        self,
        animal: zarr.Group,
        registration_name: str,
        viewer: napari.Viewer = None,
        click_frames: Optional[int] = 0,
        lazy_load=True,
    ):
        super().__init__()

        self.viewer = viewer
        self.animal = animal
        self.registration_name = registration_name

        if isinstance(click_frames, int):
            click_frames = [click_frames]

        self.click_frames = click_frames
        self.current_frame_index = 0
        self.lazy_load = lazy_load

        self.setup_ui()
        self.retrieve_attrs()
        self.initialize_layers(click_frames)

    def setup_ui(self):
        """Initializes the user interface components and connects signals."""
        self.ui_widget = SpaceRegistrationUI()

        self.ui_widget.undo_button.clicked.connect(self.on_undo)
        self.ui_widget.skip_button.clicked.connect(self.on_skip)
        self.ui_widget.previous_time_point_button.clicked.connect(
            self.on_previous_time_point
        )
        self.ui_widget.next_time_point_button.clicked.connect(self.on_next_time_point)

        self.update_time_point_buttons()

        self.setup_text_overlay()

    def setup_text_overlay(self):
        """Setup the text overlay in the viewer."""
        self.viewer.text_overlay.visible = True
        self.viewer.text_overlay.text = (
            "1.Click on landmarks\n2.Draw a reference axis (optional)"
        )
        self.viewer.text_overlay.color = "magenta"
        self.viewer.text_overlay.position = "top_left"
        self.viewer.text_overlay.font_size = 20

    # def bind_viewer_keys(self):
    #     """Bind key events to the Napari viewer."""
    #     self.viewer.bind_key("z", self.on_undo, overwrite=True)
    #     self.viewer.bind_key("q", self.on_forward, overwrite=True)
    #     self.viewer.bind_key("d", self.on_skip, overwrite=True)

    def remove_existing_layers(self):
        """Removes existing image and shape layers from the viewer to prepare for new registration."""
        # Remove existing image layer if it exists
        existing_image_layers = [
            layer
            for layer in self.viewer.layers
            if isinstance(layer, napari.layers.Image)
        ]
        if existing_image_layers:
            self.viewer.layers.remove(existing_image_layers[0])

        # Remove existing shape layers except the one you want to keep
        existing_shape_layers = [
            layer
            for layer in self.viewer.layers
            if isinstance(layer, napari.layers.Shapes)
            or isinstance(layer, napari.layers.Points)
        ]

        for shape_layer in existing_shape_layers:
            self.viewer.layers.remove(shape_layer)

    def retrieve_attrs(self):
        """Retrieve attributes from the animal's zarr group for registration."""
        space_registration = self.animal.require_group("SPACE_REGISTRATION")

        if self.registration_name in space_registration.keys():
            retrieved_landmarks = (
                np.array(space_registration[self.registration_name]["landmarks"])
                if "landmarks" in space_registration[self.registration_name].keys()
                else np.empty((0, 3))
            )

            retrieved_lines = (
                list(np.array(space_registration[self.registration_name]["lines"]))
                if "lines" in space_registration[self.registration_name].keys()
                else []
            )

            angle = space_registration[self.registration_name].attrs.get("angle")
            rois = (
                space_registration[self.registration_name]["rois"][:]
                if "rois" in space_registration[self.registration_name].keys()
                else np.empty((0, 2))
            )

        else:
            retrieved_landmarks = np.empty((0, 3))
            retrieved_lines = []
            angle = None
            rois = np.empty((0, 2))

        self.landmarks = retrieved_landmarks
        self.lines = retrieved_lines
        self.angle = angle
        self.rois = rois

    def initialize_layers(self, click_frames: Optional[int] = 0):
        """Initializes the animal for registration, loading the image and resetting landmarks."""
        self.remove_existing_layers()

        # Add in the image
        if self.lazy_load:
            raw = da.from_zarr(self.animal.IMAGE.D2.raw)
        else:
            raw = self.animal.IMAGE.D2.raw
        self.viewer.add_image(raw, channel_axis=1)
        self.viewer.dims.set_point(0, click_frames[self.current_frame_index])

        self.initialize_angle_layer()
        self.initialize_line_layer()
        self.initialize_shape_layer()
        self.initialize_points_layer()

    def initialize_shape_layer(self):
        """Initializes the shape layer for drawing and editing ROIs."""
        self.shape_layer = self.viewer.add_shapes(
            data=self.rois,
            name="ROIs",
            edge_width=2,
            edge_color="cyan",
            opacity=0.5,
            shape_type="polygon",
        )

        self.shape_layer.mode = "ADD_POLYGON_LASSO"
        self.shape_layer.events.data.connect(self.on_shape_update)

    def initialize_points_layer(self):
        """Initializes the points layer for landmark placement."""
        self.point_properties = {
            "order_number": list(range(1, self.landmarks.shape[0] + 1))
        }

        point_text = {
            "text": "{order_number}",
            "size": 15,
            "color": "white",
            "anchor": "upper_left",
            "translation": [0, 5, 0],
        }

        self.points_layer = self.viewer.add_points(
            self.landmarks,
            name="landmarks",
            properties=self.point_properties,
            text=point_text,
            face_color="white",
            size=25,
            border_color="black",
            ndim=3,
            border_width=2,
            border_width_is_relative=False,
        )

        self.points_layer.mode = "ADD"
        self.points_layer.events.data.connect(lambda event: self.on_point_update(event))

    def initialize_angle_layer(self):
        """Initializes the angle layer for drawing reference lines."""
        self.angle_layer = self.viewer.add_shapes(
            name="Angle",
            edge_width=5,
            edge_color="yellow",
            face_color="transparent",
            opacity=0.8,
        )
        self.angle_layer.mode = "ADD_LINE"
        self.angle_layer.events.data.connect(self.on_angle_drawn)

    def initialize_line_layer(self):
        """Initializes the line layer for drawing lines."""
        self.line_properties = {"order_number": list(range(1, len(self.lines) + 1))}

        line_text = {
            "string": "{order_number}",
            "size": 25,
            "color": "red",
            "anchor": "upper_left",
            "translation": [0, 5, 0],
        }

        # Add a new shape layer for the angle line
        self.line_layer = self.viewer.add_shapes(
            self.lines,
            name="Lines",
            edge_width=10,
            edge_color="red",
            face_color="transparent",
            text=line_text,
            shape_type="line",
            opacity=0.8,
            ndim=3,
        )

        self.line_layer.mode = "ADD_LINE"

        # Connect the callback function to the shape layer
        self.line_layer.events.data.connect(self.on_line_update)

    def on_shape_update(self, event=None):
        """Updates the ROIs when the shape layer is modified."""
        self.rois = np.array(self.shape_layer.data, object)

    def on_point_update(self, event=None) -> None:
        """Update the numbering of the points."""
        new_order_numbers = list(range(1, self.points_layer.data.shape[0] + 1))
        self.point_properties["order_number"] = new_order_numbers

        # Update the points layer properties to include the new order numbers
        self.points_layer.properties = self.point_properties

        # Refresh the layer to update the visual representation
        self.points_layer.refresh()

        self.landmarks = np.array(self.points_layer.data)

    def on_line_update(self) -> None:
        """Update the numbering of the lines."""
        new_order_numbers = list(range(1, np.array(self.line_layer.data).shape[0] + 1))
        self.line_properties["order_number"] = new_order_numbers

        self.line_layer.properties = self.line_properties
        self.lines = np.array(self.line_layer.data)

    def on_undo(self) -> None:
        """Undoes the last landmark action."""
        current_layer = self.viewer.layers.selection.active

        if current_layer == self.points_layer and self.points_layer.data.shape[0] > 0:
            self.points_layer.data = np.delete(self.points_layer.data, -1, axis=0)

        elif current_layer == self.line_layer and len(self.line_layer.data) > 0:
            with self.line_layer.events.highlight.blocker():
                self.line_layer.remove_selected()

    def on_skip(self) -> None:
        """Skips the current landmark, allowing the user to move to the next without marking."""
        current_layer = self.viewer.layers.selection.active

        if current_layer == self.points_layer:
            placeholder = np.empty((1, 3))
            placeholder[:] = np.nan
            self.points_layer.data = np.concatenate(
                [self.points_layer.data, placeholder], axis=0
            )

        elif current_layer == self.line_layer:
            placeholder = np.empty((2, 3))
            placeholder[:] = np.nan
            self.line_layer.add_lines(placeholder)

    def on_angle_drawn(self, event=None):
        """Calculates and stores the angle from the drawn line."""
        if len(self.angle_layer.data) > 0:
            line = self.angle_layer.data[-1]
            start, end = line
            dy = end[0] - start[0]
            dx = end[1] - start[1]
            angle = np.arctan2(dy, dx)
            self.angle = angle

    def on_next_time_point(self):
        """Moves to the next time point in the registration process."""
        if self.current_frame_index < len(self.click_frames) - 1:
            self.current_frame_index += 1
            self.viewer.dims.set_point(0, self.click_frames[self.current_frame_index])
        self.update_time_point_buttons()

    def on_previous_time_point(self):
        """Moves to the previous time point in the registration process."""
        if self.current_frame_index > 0:
            self.current_frame_index -= 1
            self.viewer.dims.set_point(0, self.click_frames[self.current_frame_index])
        self.update_time_point_buttons()

    def update_time_point_buttons(self):
        """Updates the state of time point navigation buttons."""
        self.ui_widget.previous_time_point_button.setEnabled(
            self.current_frame_index > 0
        )
        self.ui_widget.next_time_point_button.setEnabled(
            self.current_frame_index < len(self.click_frames) - 1
        )

    def store_registration(self) -> None:
        """Stores the registration data in the animal's zarr group."""
        space_registration = self.animal.require_group(
            "SPACE_REGISTRATION"
        ).require_group(self.registration_name)

        if "landmarks" in space_registration.keys():
            del space_registration["landmarks"]
        if "lines" in space_registration.keys():
            del space_registration["lines"]
        if "angle" in space_registration.keys():
            del space_registration["angle"]
        if "rois" in space_registration.keys():
            del space_registration["rois"]
        space_registration.create_dataset(
            "rois", data=self.rois, object_codec=zarr.codecs.Pickle()
        )
        space_registration.create_dataset("landmarks", data=self.landmarks)
        space_registration.create_dataset("lines", data=self.lines)
        space_registration.attrs["angle"] = self.angle
