# AnimalProcessing

MATLAB and Python code to quantify the dynamics of 2-D epithelia, used in Leroy, van Leen *et al.*, Cell Reports (2026). The MATLAB pipeline, SAP (Single Animal Processing) and MAP (Multiple Animal Processing), implements the tissue mechanics formalism of [Guirao *et al.*, eLife 2015](https://doi.org/10.7554/eLife.08519). The Python package, `pyanimalprocessing`, converts SAP and MAP results to zarr, computes the same quantities from images and label masks, and displays them in napari.

To reproduce the figures of the paper, start from [morphodomains](https://github.com/BellaicheLab/morphodomains).

Boris Guirao, Adrien Leroy, Stéphane Rigaud, Mehdi Ech-Chouini. Bellaiche Lab, Institut Curie (CNRS UMR3215, Inserm U934).

Documentation: [https://animalprocessing.readthedocs.io](https://animalprocessing.readthedocs.io)

## Installation

```bash
pip install git+https://github.com/BellaicheLab/AnimalProcessing.git
```

For the full environment including `vgep`, follow the [morphodomains README](https://github.com/BellaicheLab/morphodomains).

## Getting started

### MATLAB

Follow the guides in `docs/guides/` in this order:

* [Preparing your movies](docs/guides/preparing_movies.md) and [adding masks](docs/guides/adding_masks.md)
* Single Animal Processing:
    * [Space registration](docs/guides/space_registration.md)
    * [PIV](docs/guides/piv.md)
    * [Velocity maps](docs/guides/velocity_maps.md)
    * [Averaging over time](docs/guides/average_over_time.md)
* Multiple Animal Processing:
    * [Rescaling onto an archetype](docs/guides/rescale_animals.md)
    * [Averaging over animals](docs/guides/average_over_animals.md)
    * [Plotting time evolution](docs/guides/plot_time_evolution.md)

The three parameter files are described in [SAP_info](docs/guides/sap_info.md), [SAP parameters](docs/guides/sap_parameters.md) and [MAP parameters](docs/guides/map_parameters.md).

### Python

[Using pyanimalprocessing](docs/guides/python_route.md) shows how to convert SAP and MAP results with `zarrify_SAP` and `zarrify_MAP`, how to compute the quantities from images, and how a store is organized. Two notebooks run the package on demo data: [01_python_route_basics](notebooks/01_python_route_basics.ipynb) goes from a segmented movie crop to cell area on a grid, and [02_build_an_expression_atlas](notebooks/02_build_an_expression_atlas.ipynb) builds a 10-gene atlas.

## Repository map

```text
AnimalProcessing/
├── SAP/                        # single-animal engine: SAP.m + SAP_Suite + SEG_Suite
├── MAP/                        # multi-animal engine: MAP.m + MAP_Suite (RA, AOA, DBA, POA, PTE)
├── GEP_atlas/                  # atlas production scripts (steps 1-7)
├── EpiSegLauncher.m            # segmentation launcher
├── SAP_info_example.m          # template: per-animal metadata
├── SAP_parameters_reference.m  # template: SAP parameters
├── MAP_parameters_reference.m  # template: MAP parameters
├── src/
│   ├── cpp_executables/        # compiled helpers used by the MATLAB pipeline
│   └── pyanimalprocessing/     # converters, measurement, averaging, rescaling, plotting, statistics
├── docs/                       # MATLAB guides + Python API reference
└── tests/                      # pytest suite
```

## Tests

```bash
pip install -e ".[testing]"
pytest
```

## Gene atlas

The 17 hAPF gene expression atlas of the paper is built with this code and turned into a spatial transcriptome by [vgep](https://github.com/BellaicheLab/vgep). The [atlas guide](docs/guides/atlas_pipeline.md) walks through it, and the MATLAB scripts are in [`GEP_atlas/`](GEP_atlas/).

## Citing

- MATLAB pipeline: Guirao B. et al. (2015). *Unified quantitative characterization of epithelial tissue development.* eLife 4:e08519. [doi:10.7554/eLife.08519](https://doi.org/10.7554/eLife.08519)
- Python package: Leroy A., van Leen E. et al. (2026). *Morphodynamic domains enable integration of live morphometrics and spatial transcriptomics.* Cell Reports. Code and data: [10.5281/zenodo.19633285](https://doi.org/10.5281/zenodo.19633285)

## Related repositories

[morphodomains](https://github.com/BellaicheLab/morphodomains) reproduces the figures of the paper. [vgep](https://github.com/BellaicheLab/vgep) reconstructs the spatial transcriptome, and [vgep_gui](https://github.com/BellaicheLab/vgep_gui) is the web app to browse it ([live app](https://ybellaichelab.shinyapps.io/NotumvGEP/)).

## License

MIT
