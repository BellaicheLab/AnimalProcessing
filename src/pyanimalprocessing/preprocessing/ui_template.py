"""Qt widget scaffolding (title labels, button groups) shared by the napari preprocessing UIs."""

from abc import abstractmethod
from typing import List, Tuple

from qtpy.QtCore import Qt
from qtpy.QtWidgets import (
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QVBoxLayout,
    QWidget,
)


class AbstractWidgets(QWidget):
    """
    Abstract base class for creating various common UI widgets with custom properties.

    Attributes:
        None
    """

    def __init__(self, parent=None):
        """Initializes the base widget with a given parent."""
        super().__init__(parent)
        self.setup_layout()

    @abstractmethod
    def setup_layout(self):
        """Abstract method to define the layout and add widgets in subclasses."""
        pass

    def create_title_label(self, title: str) -> QLabel:
        """
        Creates a QLabel with large font size as a title.

        :param str title: The text to be used as the title.
        :return: A QLabel widget with specified title.
        :rtype: QLabel
        """
        title_label = QLabel(title, self)
        title_label.setAlignment(Qt.AlignCenter)
        font = title_label.font()
        font.setPointSize(14)  # Example font size
        title_label.setFont(font)
        return title_label


    def create_group_box_with_buttons(
        self, title: str, button_texts: List[str], orientation: str = "horizontal"
    ) -> Tuple[QGroupBox, List[QPushButton]]:
        """
        Creates a QGroupBox with a dynamic number of buttons aligned horizontally or vertically.

        :param title: The title of the group box.
        :param button_texts: A list of strings, each representing the text of a button to add.
        :param orientation: The orientation of the layout, either "horizontal" or "vertical".
        :return: The created QGroupBox instance containing the buttons.
        """
        group_box = QGroupBox(title, self)
        layout = QHBoxLayout() if orientation == "horizontal" else QVBoxLayout()

        button_list = []

        for text in button_texts:
            button = QPushButton(text, self)
            layout.addWidget(button)
            button_list.append(button)

        group_box.setLayout(layout)
        return group_box, button_list


        # Further widgets can be added to the layout as needed
