# SAP_info File Reference

The SAP_info file contains the description of a single animal. In this context, a single animal represents a folder containing a single image or a series of images.

The `SAP_info_example` in the current working folder contains definitions of variables related to the animal, described below.

## `%% Path to raw images`

Contains information about the files to analyze.

```matlab
startFrame = 1;
finalFrame = 177;
```

Defines the frame numbers contained in the movie.

```matlab
pathFolderRaw = './sample_movie';
```

Contains the path to the raw images used for the analysis.

```matlab
filenameRaw = {'image_'};
```

Contains the prefix of each image filename. It can contain multiple values, although PIV will only be applied to the first one.

```matlab
signalName = {'Cad'};
```

Contains the signal name for the channel being analyzed. It can contain multiple values, although names must be consistent across movies that are analyzed together.

```matlab
nDigits = 4;
```

The number of digits used in the file numbering scheme (e.g., `image_0001`, `image_0002` corresponds to `nDigits = 4`).

```matlab
imageFormatRaw = 'tif';
```

The format of the images being used.

## `%% Synchronization & Scale`

These values are updated throughout the analysis and correspond to outputs of the pipeline.

```matlab
halfNotum = 'r';
```

Corresponds to the part of the notum contained in the movies. Accepted values are `r` for right, `l` for left, and `b` for both.

```matlab
timeRef = '20h00'
frameRef = 71;
```

These variables define the temporal registration of the movie in terms of developmental timing. `timeRef` corresponds to an estimated developmental time, and `frameRef` corresponds to the frame associated with that developmental time. Typically, peaks of division, migration, or rotation of the tissue are used as timing references.

**Important:** When processing multiple animals/movies in the same analysis, they should all share the same `timeRef`, with only `frameRef` varying between animals/movies.

Standard `timeRef` values depend on the event used for temporal rescaling:

- 18h35 : 3/4 of the patches rotation peak
- 20h15 : 3/4 of the cellular divisions peak
- 22h00 : 3/4 of the cellular migration peak

More detail is provided in [Timing Movies with PTE](plot_time_evolution.md).

```matlab
dt = 5;
```

Corresponds to the time interval between frames, as defined by the experimental setup. The unit is minutes.

```matlab
temperature = 29;
```

Corresponds to the temperature at which the development was filmed.

```matlab
yMid = [];
```

Corresponds to the y-position of the midline. It is initially set to empty (`[]`) and is assigned a value as the analysis progresses.

```matlab
scale1D = 0.161
```

Corresponds to the size of each pixel in microns, as determined by the imaging setup.

## `%% Box/Grid specifications (PIV, CPT, AOS, TA, SM) %%`

Defines geometrical features of the animal and the box sizes used for the analysis.

```matlab
xFactor = 1;
yFactor = 1;
```

Correspond to the X and Y scaling factors determined by `RescaleAnimals` (see [Rescaling multiple animals](rescale_animals.md)). They are left at 1 before rescaling; after rescaling, they encode how the animal compares to the archetype: an animal longer than the archetype has `xFactor > 1`, an animal wider than the archetype has `yFactor > 1`. They are used below to adjust the box size to the animal.

```matlab
boxSize = [40 40]/scale1D ./ [xFactor yFactor];
```

Corresponds to the size of the boxes (in pixels) that will be fitted onto the tissue for further analysis. The values to modify are in the `[40 40]` field, which is expressed in micrometers. Dividing by `scale1D` (micrometers per pixel) converts the size to pixels, and dividing by the factors defined above compensates for the rescaling.

```matlab
xyStart = [1100 750];
```

Corresponds to the absolute position (in pixels) of the top-left corner of the first (top-left) box.

```matlab
gridSize = [];
```

Corresponds to the number of boxes to fit onto the image. If left empty, the entire image will be filled with boxes.

## `%% Path to clone Mask %%`

This optional section links a clone mask to the movie, enabling clone tracking (see `cloneTracking` in `SAP_parameters.m`). Leave it commented out when no clone is analyzed.

```matlab
% cloneMaskFrame = 9;
% cloneName = 'COMP';
% path2cloneMask = '/path/to/masks/COMP_mask_BIGwt2_0009.png';
```

`cloneName` is the name given to the clone (e.g. `"a-act"`, `"fat"`), `cloneMaskFrame` is the frame number on which the mask was drawn, and `path2cloneMask` is the path to the mask image itself.

## `%% Scale Bar & Display %%`

Defines variables used for figure plotting.

```matlab
scaleBarLength = 50;        
scaleBarWidth = 3;                      
xyOffset = [30 70]; 
```

Corresponds to the length, width, and position of the scale bar.

```matlab
colorBarXYWH = [0.75 0.025 0.15 0.02];
```

Corresponds to the `[left bottom width height]` values of the colorbar in the plots.

```matlab
imageFading = 0.7; 
```

Corresponds to the alpha (opacity) of the background image for the display of certain maps.

```matlab
fontSizeInfo = 18;
```

Corresponds to the font size of the information (time, scale bar value) displayed on the plots. The appropriate value depends on the image size and on `imageResolution` below: lower resolutions call for larger fonts.

```matlab
imageResolution = 125;
```

Resolution in DPI of the plots generated by the pipeline.

## `%% "SAP_parameters" call %%`

With all animal parameters defined, the final section launches the analysis pipeline.

```matlab
Animal = mfilename;
```

Sets the animal name to the name of the SAP_info file itself.

```matlab
Animal = Animal(10:end);
```

Removes the `SAP_info_` prefix from the name. For example, `SAP_info_example` becomes `example`.

```matlab
SAP_parameters
```

Launches the rest of the analysis pipeline.

The guide continues with the explanation of [SAP_parameters.m](sap_parameters.md).
