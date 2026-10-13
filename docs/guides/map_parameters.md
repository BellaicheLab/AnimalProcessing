# MAP_parameters.m Reference

While `SAP_parameters.m` handles analyses related to individual animals, `MAP_parameters.m` is the script that manages comparisons between groups of animals.

It provides the following capabilities:

- Rescaling animals onto a common frame of reference
- Comparing values calculated for individual animals, such as PIV quantities

The template for this script is `MAP_parameters_reference.m` at the root of the repository; copy it next to your data as `MAP_parameters.m` and edit that copy.

## %% ANIMALS TO INCLUDE %%

Defines which animals to include in the analysis. Example values:

```matlab
%% ANIMALS TO INCLUDE %%

% Definition of animal lists often use for analysis:
%--------------------------------------------------------------------------
% Animal lists:
avgAnimals_v = {'210507_vi_pupa1';'210507_vi_pupa3'; '210823_vi_pupa1'; '220218_vi_pupa3'; '220902_vi_pupa1'}
avgAnimals_Tollo = {'210603_Tolloi_pupa1'; '210603_Tolloi_pupa3'; '210604_Tolloi_pupa6'; '210818_Tolloi_pupa2'; '210823_Tolloi_pupa2'}

%--------------------------------------------------------------------------
% Animals to take into account in the average (selection of one of the above list)
%--------------------------------------------------------------------------
mapAnimal = 'avgAnimal';                                               % name of average animal OR actual animal name (BIG1, TRBL4...) when processing single animal
avgAnimals = [avgAnimals_v; avgAnimals_Tollo];
PathName = '/path/to/movies/movies_v_Tollo';                             % Global output path: all outputs will be saved there in a structure file.

```

## %% Operation Name (Oname) Selection / PROGRAMS TO RUN %%

Selects which operations to perform on the group of animals.

```matlab
%% Operation Name (Oname) Selection / PROGRAMS TO RUN %%

% PRE-segmentation
RA = 0;                % "RescaleAnimals"

% POST-segmentation
AOA = 0;               % "AverageOverAnimals"
DBA = 0;               % "DifferenceBetweenArchetypes"
POA = 0;               % "ProjectionOverAnimals"
PTE = 0;               % "PlotTimeEvolution"

% NOT updated
% COQ = 0;               % "CalculOverQuantities"
% CCF = 1;              % Cross-Correlation Function
% TC  = 0;               % Tensor Corelator (in progress)
```

### 1. `RA`

Rescales animals onto a common coordinate system. It operates in two modes controlled by the following parameters:

```matlab
%% RA - RescaleAnimals (3.0)%%

% Enter "Archetype" to CREATE archetype OR "Rescale" to use existing archetype for RESCALING
rescaleMode = 'Rescale';

% Time at which landmarks were clicked IN ALL MOVIES
clickTimeAll = '17h00';

% Minimum number of macrochaetes AVAILABLE (ON EACH SIDE OF ANIMAL if halfNotum = 'b') in all animals to process (USED TO CALCULATE BARYCENTERS)
nMacroMin = 4;

%%% Archetype related
% Parent folder that will contain archetypes made at different clicking times
parentArchetypeFolder = '/path/to/movies/Archetypes/';

% Prefix that will appear before "archetype_..." in folder name
archetypeName = 'Gene_';

%%% Rescaled animal related:
% Parent folder that will contain rescaled animals made at different clicking times
parentRescaledAnimalsFolder = '/path/to/movies/movies_v_Tollo/rescaled_animal/';

% Prefix that will appear before "rescaled_..." in folder name
rescaleName = 'v_tollo_';

makeSVG = false;
```

### 2. `AOA`

`AverageOverAnimals` merges the AOT backups of all animals listed in `avgAnimals` onto a common grid (built from `allAnimals`) and computes the average of every quantity across animals e.g mean `PIV` values. One output folder is produced per time window configured in AOT. The quantities listed in `Qname` are plotted unless `skipAOAplots = true` (note that `makePlotsAllAOT` in `SAP_parameters.m` must also authorize plotting). `AOAvalidityThreshold` together with `QnameFilter` discards grid boxes in which any listed quantity exceeds the threshold. See [Comparing animals with AOA](average_over_animals.md).

### 3. `DBA`

`DifferenceBetweenArchetypes` computes the difference between two averaged animals produced by the same program (usually two AOA outputs, e.g. mutant minus wild type) to obtain the difference in `PIV` values, for instance. The two animals are set in `deltaAnimals = {'A1'; 'A2'}` and the output animal is named `A1-A2`. Both inputs must have the same spatial and temporal size and the same overlap; single animals must first go through AOA so that a common grid exists.

### 4. `POA`

`ProjectionOverAnimals` projects the tensor quantities of an AOA or DBA output onto a unitary tensor, yielding signed scalar maps (e.g. deformation along the local direction of tissue elongation). `OnameProjection` selects the origin (`'AOA'` or `'DBA'`); the unitary tensor is defined by `uAnimal`, `uOname`, `uQname` (e.g. `'EG'`), `uTimeWidth`, and `uTimeOverlap`. Unlike AOA and DBA, only the quantities listed in `Qname` are calculated and plotted; `tagProjPlot` selects which `'i'`/`'d'`/`'do'` tagged projections to plot, and `skipPOAplots` disables plotting.

### 5. `PTE`

`PlotTimeEvolution` merges the MAP backups and plots one or more quantities over time within a selected region of the common grid. `QplotOrigin` selects the origin (`'AOA'` or `'DBA'`), `QplotType` instantaneous or cumulative curves, and `QplotRenorm` optional renormalization of each curve to its absolute maximum. Quantities are listed in `QnamePTE` (VM quantities need their `'PIV'`/`'CT'` suffix, e.g. `'UPIV'`), the components or projections to plot in `Qtags` (`'xx'`, `'yy'`, ... or `'u0'`, `'uPar'`, ...; the unitary tensor is taken from the POA section). The region is set through `Qboxes` (leave empty to start a GUI). See [Timing movies with PTE](plot_time_evolution.md).
