# Using pyanimalprocessing

You can convert finished MATLAB results or compute the same quantities from images and label masks. Both give the same zarr store.

## 1. Converting MATLAB results

The package installs two console scripts. `zarrify_SAP` converts a processed animal folder (raw images + `SEG_<Animal>/` + `SAP_<Animal>/` + `SAP_info_<Animal>.m`) into an animal store; `zarrify_MAP` converts an AOA or DBA average folder into an average store.

```bash
zarrify_SAP /path/to/movies/MyAnimal          # SAP folder     -> animal store
zarrify_MAP /path/to/results/AOA_myAverage    # AOA/DBA folder -> average store
```

Both accept several inputs and an `--output_path` (see `zarrify_SAP --help`). A converted store has its space registration but not the common grid. Running `generate_common_grid` on it (step 4 below) adds the grid, after which it can be used like a store computed in Python.

## 2. Computing from images

The same quantities, computed from images and label masks:

```python
from pyanimalprocessing.preprocessing import instantiate_animal, space_registrate
from pyanimalprocessing.analyze_labels import analyze_labels
from pyanimalprocessing.rescaling.registration import generate_common_grid
from pyanimalprocessing.average_over_space import average_over_space
from pyanimalprocessing.average_over_time import average_over_time

# "t(yx)": one (y, x) image file per frame; frame_ref/time_ref anchor frames to developmental time
animal = instantiate_animal("my_animal.zarr",
                            raw_image_2d="raw/", raw_image_2d_order="t(yx)",
                            labels_2d="labels/", labels_2d_order="t(yx)",
                            channel_names=["Cad"], scaling=0.161, dt=5.0,
                            frame_ref=0, time_ref="16h00")
space_registrate(animal)                # interactive napari landmark clicking
analyze_labels([animal], analysis_type="cell", properties=["area", "centroid", "coords", "contours"])
generate_common_grid([animal], boxsize=[40, 40], overlap=0.5)
average_over_space([animal], ["area"], global_spatial_type="eulerian", local_spatial_type="cell")
average_over_time([animal], ["area_mean_per_cell"], time_start="16h00", time_stop="38h00",
                  time_window="02h00")
```

Each step writes into the store: `instantiate_animal` creates `IMAGE` and `CELL`, `space_registrate` adds `SPACE_REGISTRATION`, `analyze_labels` fills the per-cell properties, `generate_common_grid` builds `GRID/<name>/GRID_PROPERTIES`, and the averaging steps write `GRID/<name>/CELL` and `TIME_AVERAGE`. Averaging across animals is one more call, `average_over_animals`, shown in the [atlas guide](atlas_pipeline.md).

## 3. The animal store

Both ways give the same layout:

```text
animal.zarr
├── IMAGE/D2/                    raw (t, c, y, x) · mask · outlines
├── CELL/D2/                     per-cell properties (analyze_labels), ragged per frame
├── GRID/<name>/
│   ├── GRID_PROPERTIES/         grid geometry: X, Y, box_corners, centroids,
│   │                            area_ratios, matrix_transform to the reference frame
│   ├── D2/                      per-box measurements (analyze_labels, eulerian)
│   └── CELL/D2/                 cell -> box averages (average_over_space)
├── TIME_AVERAGE/<grid>/<TYPE>/D2/<backup>/
│                                time-averaged quantities, weights, time/frame arrays
├── SPACE_REGISTRATION/<name>/   landmarks, lines, rois
├── TRACKING/                    masks_division_agnostic
└── GEP/                         gene-expression data (written by vgep)
```

Cohort averages live in their own stores under `<MOTION>/D2/<field>` (`EULERIAN` or `LAGRANGIAN_TRACKING`), where every quantity gains a trailing animal axis whose index 0 is the weighted mean.

## 4. Displaying properties

`read_property` reads any backup, converted or computed in Python, and `plot_property` displays it:

```python
from pyanimalprocessing.plotting import read_property, plot_property

backup = animal["TIME_AVERAGE"]["EULERIAN"]["CELL"]["D2"]["default"]
viewer = plot_property(**read_property(backup, "area_mean_per_cell"))
```

Every function above has a full entry in the API reference.
