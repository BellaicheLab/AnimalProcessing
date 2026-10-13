# SAP_parameters.m Reference

While the SAP_info file defines the properties of an individual animal, `SAP_parameters.m` is the script that determines which analyses to perform on the movie.

The template for this script is `SAP_parameters_reference.m` at the root of the repository; copy it next to your data as `SAP_parameters.m` and edit that copy.

## %% PROGRAMS TO RUN %%

This section lists the available analyses. Setting a value to `0` disables the analysis; setting it to `1` enables it.

### `% PRE-segmentation`

These analyses can be launched immediately and do not require prior segmentation of the movie.

- ```matlab
  TR = 0;
  ```

  Corresponds to `TimeRegistration`. This step times the animal by detecting a peak in division and assigning the frame at which 3/4 of the peak is attained to a developmental time of 20h15.

- ```matlab
  SR = 0;
  ```

  Corresponds to `SpaceRegistration`. This analysis determines the `yMid` variable defined in the SAP_info file as well as the macrochaete positions of the movie. Setting this value to 1 opens a GUI that prompts the user to click on the macrochaetae, the midline, and the neck of the image set by `clickTime`.

- ```matlab
  PIV = 0; 
  ```

  Corresponds to `ParticleImageVelocimetry`. This analysis produces the first raw results of the pipeline, primarily an estimation of patch velocities and tissue deformation.

- ```matlab
  GEP = 0;
  ```

  Computes the average signal intensity inside each box defined in the `SAP_info` file.

- ```matlab
  VM = 0;
  ```

  Computes and plots the `VelocityMaps`, which represent three quantities:

  - UPIV: Cellular velocity during the movie
  - EpsilonPIV: Tissue compression during the movie
  - OmegaPIV: Circular momentum during the movie

### `% POST-segmentation`

These analyses require a segmentation of the movie, added as described in [Adding masks](adding_masks.md).

- ```matlab
  FFPB = 0;
  ```

  Corresponds to `FilterFourPixelBlocks`. Detects and corrects 4-pixel blocks in the segmented images, which are ambiguous for the skeleton-based analyses. Corrected images overwrite the originals (a backup of each modified frame is kept). No specific parameters.

- ```matlab
  SIA = 0;
  ```

  Corresponds to `SegmentedImageAnalysis`. Measures per-cell geometry and signal from the segmented images: areas, anisotropies, neighbor numbers, chord lengths, side intensities. Key parameters: `matlabSIA` (MATLAB vs C++ implementation), `noDisplay` and `noStatistics` (skip image and histogram/xls outputs), `skelDilatation`/`skelDilatationBG` (skeleton dilation used to measure side signal and background).

- ```matlab
  CT = 0;
  ```

  Corresponds to `CellTracking`. Tracks every cell across frames and writes the correspondence files used by all downstream tracking analyses. No specific parameters. Note that `HC` (`HolesCorrection`), which repairs holes in the tracking, always runs and also has no parameters.

- ```matlab
  CTD = 0;
  ```

  Corresponds to `CellTrackingDisplay`. Renders the tracking as images: division rounds in shades of green, delaminations, newly formed junctions. Key parameters: `makeCTDimages`, `makeDivImages`/`nDivMax`, `makeDelImages`/`nDelMax`, the `color...` variables of cell categories, and `minCycleDuration` (minimal time between two divisions, in the common parameters).

- ```matlab
  CPT = 0;
  ```

  Corresponds to `CellPatchTracking`. Tracks patches of cells — grid compartments or clones — through time. Key parameters: `excludeLostCells` (filtering of cells lost during the movie, in the common parameters), the clone-related `matchingWTclone` and `nCellsMin`, and display switches such as `makeCPTimages`.

- ```matlab
  CTA = 0;
  ```

  Corresponds to `CellTrackingAnalysis`. Computes statistics from the tracking: division angles, cell-cycle durations, delaminations, sister-area asymmetries. Can also run before CPT in full-image mode. Key parameters: the `display...Data` switches and the averaging time ranges (`averagingTimeRangeDIV`, `averagingTimeRangeDEL`).

- ```matlab
  AOS = 0;
  ```

  Corresponds to `AverageOverSpace`. Averages cell-level quantities inside each grid compartment. Key parameters: `plotTensorsAOS` (quantities to plot), `imagePlotAOS` (`'raw'` or `'seg'` background image), and the per-quantity `scaleRatioAOS`/`scaleBarLengthAOS`.

- ```matlab
  TA = 0;
  ```

  Corresponds to `TensorAnalysis`. Decomposes the tissue deformation rate into its cellular contributions — divisions, rearrangements, shape changes, delaminations — as tensors (`EG`, `ED`, `ER`, `ES`, `EA`, ...). Key parameters: `plotTensorsTA` (tensors to plot), `renormM` (renormalization by number of links or cells), and the `plotType`-dependent scaling blocks.

### `% Force inference`

These analyses estimate junction tensions, cell pressures, and tissue stress from the segmented cell geometry.

- ```matlab
  GV = 0;
  ```

  Corresponds to `GetVertex`. Extracts the vertex positions required by the force inference. No specific parameters.

- ```matlab
  STPE = 0;
  ```

  Corresponds to `STPEstimate`. Bayesian force inference estimating junction tensions (T) and cell pressures (P). Key parameters: `ABICminMethod` (`'fminbnd'`, `'manual'` or `'forced'`), `muAccuracy`, `qrMethod`, and the P/T map display options (`makePimage`, `makeTimage`, `rangeP`, `rangeT`).

- ```matlab
  MSM = 0;
  ```

  Corresponds to `MatlabShujiMatcher`. Matches cell and vertex numbering between the MATLAB segmentation and the force-inference output. Key parameters: `nVerticesMin` (minimal number of vertices used to rescue unmatched cells) and `displayMSM`.

- ```matlab
  SM = 0;
  ```

  Corresponds to `StressMap`. Builds tissue stress maps from the inferred tensions and pressures. Key parameters: `plotTensorsSM` (`'S'` total stress, `'SP'` pressure part, `'ST'` tension part, `'P'`), `makePlotsSM`, `killMeanTraceSM`, and the associated scale factors.

### `% Time averaging`

- ```matlab
  AOT = 0;
  ```

  Corresponds to `AverageOverTime`. Averages the results of the programs listed in `averageOverAll` (`'VM'`, `'TA'`, `'AOS'`, `'SM'`) inside sliding time windows. Key parameters: `timeWidthAll` (window widths in hours, `Inf` for a whole-movie average), `timeOverlapAll` (fraction of overlap between windows), `makePlotsAllAOT`, and `timeStart`/`timeStop`. See [Running AOT](average_over_time.md).

- ```matlab
  POT = 0;
  ```

  Corresponds to `PlotOverTime`. Plots the time evolution of quantities averaged over selected grid/clone compartments. Key parameters: `boxIJs` (compartments to average over), `plotTypePOT` (`'inst'` or `'cum'`), `plotRenormPOT`, and the `Qs2Plot` lists of quantities.

As a general rule, the further down an analysis appears in the list, the more likely it is to depend on upstream analyses having been completed first.
