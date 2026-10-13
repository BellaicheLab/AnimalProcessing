# test_initialize_animal.py


def test_single_channel_single_timepoint(animal_single_channel_single_timepoint):
    animal = animal_single_channel_single_timepoint
    assert animal["IMAGE/D2/raw"].shape == (1, 1, 105, 97)
    assert animal["IMAGE/D2/label"].shape == (1, 105, 97)
    assert {
        "channels": ["ECad"],
        "dt": 5,
        "name": "single_channel_single_timepoint",
        "scaling": 0.161,
        "temperature": 25,
    }.items() <= dict(animal.attrs).items()


def test_multiple_channels_single_timepoint(animal_multiple_channels_single_timepoint):
    animal = animal_multiple_channels_single_timepoint
    assert animal["IMAGE/D2/raw"].shape == (1, 2, 105, 97)
    assert animal["IMAGE/D2/label"].shape == (1, 105, 97)
    assert {
        "channels": ["ECad", "Myosin"],
        "dt": 5,
        "name": "multiple_channels_single_timepoint",
        "scaling": 0.161,
        "temperature": 25,
    }.items() <= dict(animal.attrs).items()


def test_single_channel_multiple_timepoints(animal_single_channel_multiple_timepoints):
    animal = animal_single_channel_multiple_timepoints
    assert animal["IMAGE/D2/raw"].shape == (3, 1, 105, 97)
    assert animal["IMAGE/D2/label"].shape == (3, 105, 97)
    assert {
        "channels": ["ECad"],
        "dt": 5,
        "name": "single_channel_multiple_timepoints",
        "scaling": 0.161,
        "temperature": 25,
    }.items() <= dict(animal.attrs).items()


def test_multiple_channels_multiple_timepoints(
    animal_multiple_channels_multiple_timepoints,
):
    animal = animal_multiple_channels_multiple_timepoints
    assert animal["IMAGE/D2/raw"].shape == (3, 2, 105, 97)
    assert animal["IMAGE/D2/label"].shape == (3, 105, 97)
    assert {
        "channels": ["ECad", "Myosin"],
        "dt": 5,
        "name": "multiple_channels_multiple_timepoints",
        "scaling": 0.161,
        "temperature": 25,
    }.items() <= dict(animal.attrs).items()
