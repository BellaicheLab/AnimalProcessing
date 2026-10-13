"""Image-based animal instantiation and napari registration UI (nested-schema writer)."""

__all__ = ["instantiate_animal", "space_registrate"]

from pyanimalprocessing.preprocessing.instantiate_animal import instantiate_animal


# Avoid importing heavy napari/Qt dependencies at package import time.
# Expose a lightweight callable that imports the real implementation on first use.
def space_registrate(*args, **kwargs):
    from pyanimalprocessing.preprocessing.space_registrate import (
        space_registrate as _space_registrate,
    )

    return _space_registrate(*args, **kwargs)