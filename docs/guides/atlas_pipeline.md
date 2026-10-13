# Building a gene-expression atlas and a spatial transcriptome

This guide goes from fixed, stained animals, with several specimens per gene, to a per-gene expression atlas on a common grid, and then to the reconstruction of the spatial transcriptome. It registers each animal on anatomical landmarks, builds a reference archetype, rescales all animals onto its grid, measures the expression in each box, averages each gene, and assembles a table that `vgep` turns into a spatial transcriptome.

```text
per-animal zarr stores (one gene each, [Cad, Gene] channels)
        |
        v
space registration ........ 8 macrochaetae + midline (+ neck)
        |
        v
archetype ................. generate_archetype (landmarks in microns, fixed grid frame)
        |
        v
common grid ............... generate_common_grid (xyscale_translation, 40 um boxes)
        |
        v
per-box expression ........ analyze_labels (eulerian) -> average_over_time
        |
        v
per-gene average .......... average_over_animals (one AOA store per gene)
        |
        v
normalize + assemble ...... one row per grid box, one column per gene
        |
        v
spatial transcriptome ..... vgep: generate_vgep / optimize_transcriptome
```

The Python steps below run on the data of the Zenodo archive ([10.5281/zenodo.19633285](https://doi.org/10.5281/zenodo.19633285)). The MATLAB scripts that built the atlas of the paper are summarized in [section 11](#11-reference-the-matlab-production-route).

## 1. What you can run

Sections 3 to 9 use `data/zarr_atlases/` and section 10 uses `data/morphology/` and `data/single_cell/` from the Zenodo archive. Section 11 (MATLAB) needs the per-animal SAP folders, which are not distributed.

The [morphodomains](https://github.com/BellaicheLab/morphodomains) repository runs sections 4 to 7 with `scripts/figures/figure_gene_atlas/preprocessing.py`:

```bash
cd morphodomains
python scripts/figures/generate.py --figure figure_gene_atlas
```

Set `pipeline.genes` and `pipeline.max_animals_per_gene` in `figure_config.yaml` to restrict the run. The sections below show the same calls, to use on your own data.

## 2. Concepts

Each atlas specimen is a zarr store with a single-frame, two-channel image (`IMAGE/D2/raw`, channels `["Cad", "Gene"]` for E-cadherin and the gene), a tissue mask, and the root attributes `gene`, `modality` (`fish` or `protein`), `scaling` (µm/px) and `half_notum`. The stores are created with `instantiate_animal`. Unlike movies they have no timing, so the pipeline sets `time_ref` and `frame_ref` before time-averaging.

Animals are registered on up to 8 macrochaetae (sensory bristles at stereotyped positions) and the midline, clicked once per animal. In the shipped stores, `SPACE_REGISTRATION/atlas_sr` holds a `(9, 3)` array of landmarks: the 8 macrochaetae and the neck. `atlas_sr_matlab` keeps the original MATLAB clicks, where the neck is a line of 2 points (`Neck_XYs.txt`).

The archetype is a reference animal that only has landmarks (in microns) and a fixed grid frame. Every animal is rescaled onto it, so all genes share the same grid and their maps can be put side by side in one table.

## 3. Register each animal

Every store needs a space registration before anything else. The shipped `data/zarr_atlases` stores already carry `atlas_sr`, so this step is already done for the data of the archive. For new animals, run the interactive napari registration:

```python
from pyanimalprocessing.preprocessing import space_registrate

space_registrate(animal, registration_name="atlas_sr")
```

Click the macrochaetae in the standard order, then the midline; close the viewer to save landmarks into `SPACE_REGISTRATION/atlas_sr`. The clicking protocol and anatomy are the same as the MATLAB `SR` module. See [Space registration](space_registration.md).

## 4. Build the reference archetype

The atlas of the paper uses the 8 macrochaetae of the 2019 protein-scale archetype, in microns, with a fixed frame that gives a 40 × 67 grid of 40 µm boxes with 0.5 overlap.

```python
from pyanimalprocessing.rescaling.registration import generate_archetype

ARCHETYPE_YX = [
    [-37.8125145, -109.1786175],
    [10.9751895, -87.3504135],
    [9.0800595, 62.7462045],
    [17.7572655, 133.7828265],
    [103.2276555, 35.0425305],
    [173.6478135, 55.1225925],
    [199.5614415, 153.7899345],
    [200.6938215, 80.0648145],
]
GRID_FRAME = (-190.0, 610.0, -470.0, 870.0)   # y_min, y_max, x_min, x_max in microns

archetype = generate_archetype(
    output_path="gene_archetype.zarr", landmarks=ARCHETYPE_YX,
    grid_frame=GRID_FRAME, n_macros=8, registration_name="atlas_sr",
    name="gene_archetype",
)
```

To derive an archetype from your own cohort instead, pass `animals=` (a list of registered stores) in place of `landmarks=`: the archetype landmarks become the across-animal mean, with the origin at the barycenter of the first `n_anchor_macros` macrochaetae.

## 5. Rescale everything onto one common grid

Load the animals by gene, then rescale them all onto the archetype in one call. `transform_type="xyscale_translation"` is the transform of the MATLAB pipeline (independent x and y scaling and a translation, no rotation). Because the archetype has a stored grid frame, every animal gets the same 40 × 67 grid.

```python
import glob
from collections import defaultdict
import numpy as np
import zarr

from pyanimalprocessing.rescaling.registration import generate_common_grid

animals_by_gene = defaultdict(list)
for path in sorted(glob.glob("data/zarr_atlases/*/*.zarr")):
    animal = zarr.open(path, mode="a")
    landmarks = animal["SPACE_REGISTRATION/atlas_sr/landmarks"][:]
    if (~np.isnan(landmarks).any(axis=1)).sum() < 2:
        continue
    animals_by_gene[animal.attrs["gene"]].append(animal)
all_animals = [a for group in animals_by_gene.values() for a in group]

generate_common_grid(
    all_animals, boxsize=[40, 40], overlap=0.5, registration_name="atlas_sr",
    reference_animal=archetype, transform_type="xyscale_translation",
    grid_type="eulerian", verbose=True,
)
```

:::{note}
The pipeline augments each store in place: `generate_common_grid` writes a `GRID` group, the next steps add `TIME_AVERAGE` and stamp `time_ref`/`frame_ref`. `IMAGE` and `SPACE_REGISTRATION` are never touched. Work on copies if you want to keep the stores unchanged, and restrict `animals_by_gene` to a couple of genes for a first run, as the full build of the 538 stores takes a while.
:::

MATLAB-processed animals join the pipeline here: a store converted with `zarrify_SAP` has its registration but not the grid, and `generate_common_grid` adds it.

## 6. Measure per-box expression

Per-box gene expression is the mean intensity of the gene channel over each grid compartment, computed by the same regionprops machinery as per-cell measurements. The single fixed frame is then time-averaged as a one-frame timelapse at 17 hAPF, producing the `TIME_AVERAGE` backup read by the next steps.

```python
from pyanimalprocessing.analyze_labels import analyze_labels
from pyanimalprocessing.average_over_time import average_over_time

analyze_labels(
    all_animals, analysis_type="eulerian", intensity_image="raw",
    properties=["intensity_mean"], dimension="D2", verbose=True,
)

for animal in all_animals:
    animal.attrs["time_ref"] = "17h00"
    animal.attrs["frame_ref"] = 0
average_over_time(
    all_animals, properties=["intensity_mean"], grid_type="eulerian",
    averaged_type=None, time_start="17h00", time_stop="17h05",
    time_window="00h01", time_step=5, verbose=True,
)
```

## 7. Average each gene across animals

One `average_over_animals` call per gene produces one AOA store per gene, all on the shared grid. In the output, every quantity gains a trailing animal axis whose index 0 is the weighted average and indices 1..N are the individual animals; `AreaRatios` (the per-box tissue coverage, same layout) is what the normalization step uses.

```python
from pyanimalprocessing.average_over_animals import average_over_animals

backups = {}
for gene, group in animals_by_gene.items():
    out = f"aoa/{gene}.zarr"
    average_over_animals(group, output_path=out, animal_reference=group[0], rescale="Full")
    backups[gene] = zarr.open(out, mode="r")["EULERIAN/D2/default"]
```

## 8. Normalize

Each animal's map is rescaled to [0, 1] by percentile min–max (0.5 / 99.5) computed on its fully-covered boxes (`AreaRatios == 1`), negatives clipped, poorly-covered boxes (`AreaRatios < 0.7`) dropped, then averaged across animals. The reference implementation is `normalizePrctl5D` in `GEP_atlas/step_6_analysis_variability_Images_40um_corrected.m`.

```python
mean_maps, n_valid = {}, {}
for gene, b in backups.items():
    maps = np.asarray(b["intensity_mean"][0, 1, :, :, 0, 1:], float)   # gene channel, (67, 40, N)
    ar = np.asarray(b["AreaRatios"][0, 0, :, :, 0, 1:], float)
    normalized = np.full(maps.shape, np.nan)
    for i in range(maps.shape[-1]):
        m, a = maps[..., i], ar[..., i]
        lo, hi = np.nanpercentile(m[a == 1], [0.5, 99.5])
        n = np.clip((m - lo) / (hi - lo), 0, None)
        n[a < 0.7] = np.nan
        normalized[..., i] = n
    mean_maps[gene] = np.nanmean(normalized, axis=-1)
    n_valid[gene] = np.sum(~np.isnan(normalized), axis=-1)
```

## 9. Assemble the atlas table

The atlas is a CSV table, one row per grid box and one column per gene, in the format of `data/morphology/atlas_validation.txt`.

```python
import pandas as pd

n_cy, n_cx = next(iter(mean_maps.values())).shape   # (67, 40)
table = pd.DataFrame({g: m.ravel() for g, m in mean_maps.items()})
table["n_nota_gene"] = np.min(np.stack(list(n_valid.values())), axis=0).ravel()
table["coordX"] = np.tile(np.arange(1, n_cx + 1), n_cy)
table["coordY"] = np.repeat(np.arange(1, n_cy + 1), n_cx)
table.to_csv("atlas.txt", index=False)
```

As a sanity check, a capped run of this exact thread (3 animals each of *svp* and *tsh* from the archive) reproduces the corresponding published columns with Pearson r ≈ 0.7 and 0.94; the difference comes from the smaller cohort.

## 10. Reconstruct the spatial transcriptome (vgep)

:::{note}
Install `vgep` in the same environment (morphodomains README).
:::


```python
import numpy as np
import pandas as pd
from vgep.spatial_transcriptome import generate_vgep
from vgep.optimization._vgep import optimize_transcriptome
from scripts.figures.figure_spatial_transcriptome.preprocessing import TRAINING_GENES, VALIDATION_GENES, NAME_CORRECTIONS

raw_counts = pd.read_csv("data/single_cell/epi_RNA_counts.csv", index_col=0).T   # cells x genes
macrochaete = pd.read_csv("data/morphology/macrochaete.csv", header=None)        # 2 x 8: row 0 = coordY, row 1 = coordX, grid units

atlas_full = pd.read_csv("data/morphology/atlas_validation.txt").rename(columns=NAME_CORRECTIONS)
geometry = atlas_full.iloc[:, -2:].rename({"coordX": "x", "coordY": "y"}, axis=1)
gene_data = atlas_full[TRAINING_GENES + VALIDATION_GENES + ["n_nota_gene"]]
mask = (gene_data.fillna(0).sum(axis=1) > 0) & (gene_data["n_nota_gene"] > 0)
gene_data, geometry = gene_data.loc[mask], geometry.loc[mask]
atlas, validation = gene_data[TRAINING_GENES], gene_data[VALIDATION_GENES]

mdata = generate_vgep(sc_data=raw_counts, atlas=atlas, geometry=geometry,
                      cutoff=0.98, validation=validation)

best = optimize_transcriptome(
    single_cells=raw_counts, atlas=atlas, geometry=geometry, validation=validation,
    list_cutoffs=np.arange(0.97, 0.999, 0.0005),
    output_path="data/gep_results/spatial_transcriptome_output",
    macrochaetae=macrochaete, plot_recap=True,
)
```

`generate_vgep` reconstructs at one correlation cutoff; `optimize_transcriptome` sweeps cutoffs, scores each against the validation genes, and writes `results.csv`, `best_transcriptome.h5mu`, and a PDF report. The notebook [`02_spatial_transcriptome_reconstruction.ipynb`](https://github.com/BellaicheLab/morphodomains/blob/main/notebooks/02_spatial_transcriptome_reconstruction.ipynb) in morphodomains walks through this step with figures, and the reconstructed transcriptome can be browsed interactively at <https://ybellaichelab.shinyapps.io/NotumvGEP/>.

## 11. Reference: the MATLAB production route

The published atlas was built with the MATLAB drivers in `GEP_atlas/`, on top of the SAP/MAP engine. The steps mirror this tutorial: `step_1` space registration (interactive clicking of up to 8 macrochaetae, with right-click marking an invisible one as NaN and at least 4 required, then midline and neck), `step_2` rescale onto the archetype (`RA` with `rescaleMode='Rescale'`), `step_3` writes the resulting `xFactor/yFactor/yMid/xyStart` back into each `SAP_info_*.m`, `step_4` runs SAP with `GEP=1`, `step_5` loops genes with `AOA=1`, `step_6` normalizes, `step_7` assembles the atlas `.txt`.

Practical points that make it work:

- Run from inside `GEP_atlas/` so its `SAP_parameters.m` (`SR=0`, `GEP=1`, `averageOverAll={'GEP'}`, `timeWidthAll=[0]`, `clickTime`/`gridTime='17h00'`) wins MATLAB's current-folder precedence over any movie `SAP_parameters.m` on the path. Some scripts also enforce this with `thisDir = fileparts(mfilename('fullpath')); cd(thisDir); addpath(thisDir)`.
- `timeWidthAll=[0]` makes MAP read each gene's backup from `noAverage_17h00/`, the only window single-frame animals have.
- The scripts stay compatible with MATLAB R2018b: no `matches()`, no `writematrix`.
- The route needs the per-animal SAP folders, which are not distributed.

## See also

- [Space registration](space_registration.md): the landmark-clicking protocol
- [Rescaling animals](rescale_animals.md): archetypes and `RA` in detail
- [Averaging over animals](average_over_animals.md): the AOA parameters
