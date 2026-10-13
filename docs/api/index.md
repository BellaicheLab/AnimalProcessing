# API Reference

The API follows the order of the analysis, from raw movies or MATLAB outputs to averages displayed in napari.

- {doc}`io`: `zarrify_SAP` and `zarrify_MAP` convert SAP and MAP folders (images, segmentation masks, tensor backups, tracking and metadata) to zarr.
- {doc}`preprocessing`: create an animal store from images, masks and labels, then click landmarks in napari to register it.
- {doc}`analyze_labels`: measure scikit-image region properties and custom ones (outlines, background intensity, Fourier modes, junctional polarity) on cells, regions or grid boxes.
- {doc}`rescaling`: fit transforms from landmarks, build the archetype and the common grid, and convert between frames and developmental time with temperature correction.
- {doc}`averaging`: average cell measurements in grid boxes (AOS), over time windows (AOT) and across animals (AOA).
- {doc}`spatial_statistics`: global and local Moran's I to find significant spatial clusters of tissue deformation.
- {doc}`gep`: rescale gene expression maps from [vgep](https://github.com/BellaicheLab/vgep) to image resolution and advect them with cell tracking.
- {doc}`plotting`: read quantities with `read_property`, display scalars, vectors and tensors in napari with `plot_property`, and export PNG, SVG or video.
- {doc}`transformation`: weighted tensor statistics and relabeling of tracked cells.
- {doc}`utils`: shared helpers.
- {doc}`scripts`: the command-line entry points.

```{toctree}
:maxdepth: 1
:hidden:

io
preprocessing
analyze_labels
rescaling
averaging
spatial_statistics
gep
plotting
transformation
utils
scripts
```
