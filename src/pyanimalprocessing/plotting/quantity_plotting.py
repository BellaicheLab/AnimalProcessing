"""Display properties for tensor quantities.

Each class defines the default ``color``, ``scale``, and ``vector_style``
for visualizing a named quantity.

Attributes
----------
QUANTITY_TO_CLASS : dict
    Maps quantity names to their display-property classes.
"""


class EpsilonPIV:
    """Deformation rate (PIV). Slateblue, scale 3000."""
    color = "slateblue"
    scale = 3000
    vector_style = None


class OmegaPIV:
    """Rotation rate (PIV). Purple, scale 3000."""
    color = "purple"
    scale = 3000
    vector_style = None


class UPIV:
    """Velocity field (PIV). Dark orange, scale 30, arrow style."""
    color = "darkorange"
    scale = 30
    vector_style = "arrow"


class EF:
    """Fusion rate. Fuchsia, scale 3000."""
    color = "fuchsia"
    scale = 3000
    vector_style = None


class EG:
    """Growth rate. Dark blue, scale 3000."""
    color = "darkblue"
    scale = 3000
    vector_style = None


class ES:
    """Shrinkage rate. Deep sky blue, scale 3000."""
    color = "deepskyblue"
    scale = 3000
    vector_style = None


class ER:
    """Rearrangement rate. Deep pink, scale 3000."""
    color = "deeppink"
    scale = 3000
    vector_style = None


class EA:
    """Apoptosis rate. Black, scale 3000."""
    color = "black"
    scale = 3000
    vector_style = None


class ED:
    """Division rate. Green, scale 3000."""
    color = "green"
    scale = 3000
    vector_style = None


QUANTITY_TO_CLASS = {
    "EpsilonPIV": EpsilonPIV,
    "OmegaPIV": OmegaPIV,
    "UPIV": UPIV,
    "EF": EF,
    "EG": EG,
    "ES": ES,
    "ER": ER,
    "EA": EA,
    "ED": ED,
}
