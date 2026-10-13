function GRID = MakeGrid(imageSize, boxSize, xyStart, gridSize, gridColor, gridLineWidth, gridOverlap)
%
% GRID = MakeGrid(imageSize, boxSize, xyStart, gridSize, gridColor, gridLineWidth, gridOverlap)
%
% This generates a grid (no display as of 1.4, use "Grid_Plotter" to do that) made of boxes of width
% "boxSize(1)" and height "boxSize(2)" IN PIXELS, and overlap between compartments ("gridOverlap"). The
% grid is defined starting with upper left corner at coordinates "xyStart" of grid upper left
% compartment (1,1), and have ny = "gridSize(1)" x nx = "gridSize(2)" compartments, if it fits in the
% image. If "gridSize" is empty, the grid fills up the image. "GRID" (structure) contains:
%
% GRID.xywh = xywh;
% GRID.Size = gridSize;
% GRID.Overlap = gridOverlap;        % 1.7
% GRID.Centroids = gridCentroids;
% GRID.ULCs = gridULCs;
% GRID.Color = gridColor;
% GRID.LineWidth = gridLineWidth;
% GRID.Coordinates = gridCoordinates; % 1.11
%
% Except for "xywh", "gridSize", "gridOverlap"' "gridColor" and "gridLineWidth", all cell arrays are organized
% similarly (ny rows  * nx col) to the drawn boxes and contains xy coordinates (pixels) of each box
% Upper Left Corner (ULC)(grid_ULCs) and centroid (box_centroids). Display of grid must be carried out
% with "PlotGrid".
%
% NB1: if "boxSize" has only one value, the grid is made of square compartments (w=h)
% NB2: if xyStart = [], default value is xy_start = [image_size(2)/2 image_size(1)/2]
% NB3: Output "box" is only created for compatibility with programs determining Fourier transform of
% images (see below).
% NB4: if grid_overlap = [], it will be set to 0 and saved as such
%
% Version 1.15
% Boris Guirao
% Anais Bailles


%% Parameters defining grid compartments %%

% largest xy values in image:
xMax = imageSize(2);
yMax = imageSize(1);

% Full image processing ?
fullImage = false; % default

% Extracting box dimensions from "box_size":
boxSize = roundn(boxSize,-1); % 1.8
if length(boxSize)== 2
    wBox = boxSize(1);
    hBox = boxSize(2);
elseif length(boxSize)== 1                       % square grid if only one value provided
    wBox = boxSize(1);
    hBox = boxSize(1);   
elseif isempty(boxSize) && isempty(xyStart)     % Full image processing (1.9)
    wBox = xMax;
    hBox = yMax;
    xyStart = [0 0];
    boxSize = [wBox hBox]; % 1.12
    fullImage = true;
else
    disp('Error: please provide width ("w") and height ("h") of box in format [w h]. ')
    return
end

% Extracting x_start and y_start:
xyStart = roundn(xyStart, -1); % 1.8
if ~isempty(xyStart)
    xStart = xyStart(1); % pixels
    yStart = xyStart(2);
else
    xStart = imageSize(2)/2;                   % takes middle of image as default if nothing provided (pixels)
    yStart = imageSize(1)/2;
    xyStart = [xStart yStart];              % updating "xyStart" (1.15)
end

xywh = [xStart yStart wBox hBox];

% Extracting grid_overlap (1.6,1.7)
if isempty(gridOverlap)
    gridOverlap = 0;
    disp('Warning: parameter "gridOverlap" was empty and was set to zero!')
elseif length(gridOverlap) > 1
    disp ('Error: parameter "gridOverlap" must be scalar!!') 
    return
elseif gridOverlap >= 1
    disp('Error: parameter "gridOverlap" must be in [0 1[!!')
    return
end


%% Builds Grid %%

if isempty(gridSize)
    
    %%% Build largest grid filling up the image:
    xGridBasis = 0:wBox*(1-gridOverlap):xMax; % 1.6 : grid compartiments overlap
    xGridPlus = xGridBasis + xStart;
    xGridMinus = -xGridBasis + xStart;
    xGrid = [xGridMinus xGridPlus];
    xGrid = xGrid(xGrid >= 0 & xGrid <= xMax-wBox); %1.6
    xGrid = unique(xGrid);
    nX = length(xGrid); %1.6
    
    yGridBasis = 0:hBox*(1-gridOverlap):yMax; % 1.6 : grid compartiments overlap
    yGridPlus = yGridBasis + yStart;
    yGridMinus = -yGridBasis + yStart;
    yGrid = [yGridMinus yGridPlus];
    yGrid = yGrid(yGrid >= 0 & yGrid <= yMax-hBox); %1.6
    yGrid = unique(yGrid);
    nY = length(yGrid); %1.6
    
elseif length(gridSize) == 2
    
    %%% Builds grid entered by user:
    nYo = gridSize(1);
    nXo = gridSize(2);

    xGridBasis = 0:wBox*(1-gridOverlap):(nXo-1)*wBox*(1-gridOverlap); % compartiments overlap (1.6), applies -1 to nXo (1.13)
    xGrid = xGridBasis + xStart;
    xGrid = xGrid(xGrid >= 0 & xGrid <= xMax-wBox); % 1.6
    nX = length(xGrid); % 1.6
    
    yGridBasis = 0:hBox*(1-gridOverlap):(nYo-1)*hBox*(1-gridOverlap); % compartiments overlap (1.6), applies -1 to nYo (1.13)
    yGrid = yGridBasis + yStart;
    yGrid = yGrid(yGrid >= 0 & yGrid <= yMax-hBox); % 1.6
    nY = length(yGrid); % 1.6
    
else
    warndlg('Parameter "gridSize" must be a 1x2 vector.','"GridMaker" Error!!!');
    disp('Parameter "gridSize" must be a 1x2 vector ("GridMaker" Error!!).')
    GRID = [];
    return
end


%%% Checking validity of grid:
if nX <= 0 || nY <= 0
    warndlg('No grid fitting in the image could be generated with the selected values. Please change parameters "boxSize" and/or "xyStart".','"GridMaker" Error!!!');
    disp('No grid fitting in the image could be generated with the selected values ("GridMaker" error).')
    GRID = [];
    return
elseif ~isempty(gridSize) && (nX < nXo || nY < nYo) % use of < NOT ~= (1.13)
    h = warndlg(['The grid selected by user ' num2str(nYo) 'x' num2str(nXo)...
        ' does not fit in the image, and was cropped to the largest possible (' num2str(nY) 'x' num2str(nX)...
        ') grid with ULC at "xyStart". Parameter "gridSize" has been changed accordingly.'],'Grid does not fit!!!');
    uiwait(h);
end

%%% Assign final OUTPUT value of "grid_size":
gridSize = [nY nX];


%% Determination of box ULCs and centroids (and "box" filling) %%

gridULCs = cell(nY,nX);                                                                                                % stores xy coordinates of each box ULC (Upper Left Corner)
gridCentroids = cell(nY,nX);                                                                                           % stores box centers xy coordinates    
nBoxes = nX*nY;

for b = 1:nBoxes   
        [ky,kx] = ind2sub(gridSize,b);         % turns linear index b into (i,j) grid coordinate (1.11)
        
        % Storing this box ULC:
        bULCxy = [xGrid(kx) yGrid(ky)];                                                                          % ULC: Upper Left Corner
        gridULCs{ky,kx} = bULCxy;
        
        % Determining box centroids:
        bXmin = bULCxy(1);
        bYmin = bULCxy(2);
        bXmax = bXmin + wBox;
        bYmax = bYmin + hBox;
        bX = 1/2*(bXmin + bXmax);
        bY = 1/2*(bYmin + bYmax);
        gridCentroids{ky,kx} = [bX bY];                                                                 % storage of values in PIXELS
end


%% Grid Coordinates (1.11) %%

% Builds cell array "gridCoordinates" that contains coordinates of box compartments in units of boxSize and centered on xyStart
% NB: xyStart therefore corresponds to Upper Left Corner of (0,0) box

gridULCsMat = cell2mat(gridULCs(:));                                                            % nBoxes x 2 matrix of ULC coordinates
xyStartMat = repmat(xyStart,nBoxes,1);                                                          % repeats xyStart coordinates
gridCoordinatesMat = gridULCsMat - xyStartMat;                                                  % ULC coordinates now centered on xyStart
gridCoordinatesMat = [gridCoordinatesMat(:,1)./boxSize(1) gridCoordinatesMat(:,2)./boxSize(2)]; % divides by width and height of box compartments
gridCoordinatesMat = roundn(gridCoordinatesMat,-2);                                             % round to 1e-2 in case of box overlap
gridCoordinates = reshape(num2cell(gridCoordinatesMat,2),nY,nX);                                % back to initial gridSize


%% Storage in structure GRID %%

GRID.xywh = xywh;
GRID.Size = gridSize;
GRID.Overlap = gridOverlap;        % if "grid_overlap" was empty, it has been set and saved as 0 (1.7)
GRID.Centroids = gridCentroids;
GRID.ULCs = gridULCs;
GRID.fullImage = fullImage; % 1.9
% display related:
GRID.Color = gridColor;
GRID.LineWidth = gridLineWidth;
GRID.Coordinates = gridCoordinates;



%% History %%

% 16/10/2018: 1.15
% - fixed bug when "xyStart" was empty.

% 14/06/2017: 1.14
% - put capitals to every quantity "Q" that was called "gridQ" when stored
% in GRID. This to avoid having variable "size" that is also a function.

% 30/11/2017: 1.13
% - fixed bug where the grid asked by user was not respecting "gridSize"
% - fixed bug where program was forcing a larger grid than the one asked by user!

% 14/01/2016: 1.12
% - fixed bug when running in "full image" mode

% 22/12/2015: 1.11: REMOVED "compatibility with Fourier transform" and "box" output (cell array)
% - added field "coordinates" in GRID: cell array that contains coordinates of box compartments in
% units of boxSize and centered on xyStart (for Herve Isamber data formatting and possibly for space
% registration).
% - linear iteration over grid compartments

% 02/06/2015: 1.10 became "GridMaker"
% - changed paramter names

% 24/02/2015: 1.9
% - support of full image processing: builds a 1-box grid covering the whole image when both "xy_start" and "box_size" are BOTH empty
% - storage of logical variable "full_image" in GRID to indicate processing of full image

% 13/10/2014: 1.8
% - now rounds up values of "box_size" and "xy_start" to 0.1 precision since decimal values are now possible due to animal rescaling.

% 07/03/2014: 1.7
% - added storage of "overlap" in GRID structure

% 17/02/2014: 1.6 Anais
% - added grid overlap /!\ number of inputs has changed

% 20/01/2012: 1.5
% - added new input "grid_size" to control number of grid compartments.
% - check for grid validity (empty, or difference with user grid)

% 10/01/2012: 1.4
% - removed the display part and created "Grid_Plotter"
% - accordingly put back "image_size" as input instead of image
% - stores "grid_color, grid_linewidth" in GRID.

% 10/01/2012: 1.3
% - now output is structure "GRID" containing "xywh", "size", "grid_ULCs" and "box_centroids" (both nx*ny cell arrays)
% - new inputs: image (instead of image_size), grid_color, grid_linewidth
% - added back display of box overlayed on image

% 08/02/2011: 1.2
% - removed display of grid and moved it to "Average_Over_Grid"
% - replaced "image" by "image_size" as input (minimal input)
% - replaced "wh_box" by "box_size" as input
% - added "wh_box" as output

% 07/02/2011: creation 1.1 (changed name from "Grid_Tool" to "Grid_Maker")


