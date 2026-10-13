# AnimalProcessing

MATLAB and Python code to quantify the dynamics of 2-D epithelia from live imaging or from fixed images. It was developed for the *Drosophila* pupal notum and used in Leroy, van Leen et al., *Morphodynamic domains enable integration of live morphometrics and spatial transcriptomics*, Cell Reports (2026). Code and data: [10.5281/zenodo.19633285](https://doi.org/10.5281/zenodo.19633285).

The MATLAB pipeline processes 2-D projected movies. SAP (Single Animal Processing) runs PIV, decomposes tissue deformation into the contributions of cell division, rearrangement, apoptosis and cell shape changes, and averages each movie over time. MAP (Multiple Animal Processing) rescales animals onto a common grid and averages them.

The Python package, `pyanimalprocessing`, converts SAP and MAP results to zarr, computes the same quantities from images and label masks, and displays them in napari. Each specimen, or cohort average, is one zarr store that holds the images and everything computed from them.

## Getting started

Install the Python package:

```bash
pip install git+https://github.com/BellaicheLab/AnimalProcessing.git
```

The MATLAB requirements are listed in [Installation](installation.md).

To process movies with MATLAB, follow the [guides](guides/index.md) in order. The parameter files are described in [SAP_info](guides/sap_info.md), [SAP parameters](guides/sap_parameters.md) and [MAP parameters](guides/map_parameters.md).

To use the Python package, start with [Using pyanimalprocessing](guides/python_route.md) and the two [walkthrough notebooks](walkthroughs.md). The [atlas guide](guides/atlas_pipeline.md) shows how the gene expression atlas of the paper was built. All functions are documented in the [API reference](api/index.md).

## Citing

If you use the MATLAB pipeline, please cite:

- Guirao B., Rigaud S. U., Bosveld F. et al. (2015). Unified quantitative characterization of epithelial tissue development. *eLife* 4:e08519. [doi:10.7554/eLife.08519](https://doi.org/10.7554/eLife.08519)
- Bosveld F., Bonnet I., Guirao B. et al. (2012). Mechanical control of morphogenesis by Fat/Dachsous/Four-jointed planar cell polarity pathway. *Science* 336:724-727. [doi:10.1126/science.1221071](https://doi.org/10.1126/science.1221071)
- Bosveld F., Markova O., Guirao B. et al. (2016). Epithelial tricellular junctions act as interphase cell shape sensors to orient mitosis. *Nature* 530:495-498. [doi:10.1038/nature16970](https://doi.org/10.1038/nature16970)

If you use the Python package, please cite:

- Leroy A., van Leen E. et al. (2026). Morphodynamic domains enable integration of live morphometrics and spatial transcriptomics. *Cell Reports*. Code and data: [10.5281/zenodo.19633285](https://doi.org/10.5281/zenodo.19633285)

## Related repositories

[morphodomains](https://github.com/BellaicheLab/morphodomains) reproduces the figures of the paper. [vgep](https://github.com/BellaicheLab/vgep) reconstructs the spatial transcriptome, and [vgep_gui](https://github.com/BellaicheLab/vgep_gui) is the web app to browse it ([live app](https://ybellaichelab.shinyapps.io/NotumvGEP/)).

```{toctree}
:maxdepth: 2
:caption: Getting Started
:hidden:

installation
```

```{toctree}
:maxdepth: 1
:caption: Walkthroughs
:hidden:

walkthroughs
```

```{toctree}
:maxdepth: 2
:caption: Guides
:hidden:

guides/index
```

```{toctree}
:maxdepth: 2
:caption: API Reference
:hidden:

api/index
```
