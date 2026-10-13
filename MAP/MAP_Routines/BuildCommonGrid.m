function [cGRID, LOCxy] =  BuildCommonGrid(avgAnimals, allAnimals, AnimalGridList, meanMacrocaetesRaw, meanDeltaYmidRaw, gridOverlap, halfNotum, cloneTracking, DISPLAY)
%
% [cGRID, LOCxy] =  BuildCommonGrid(avgAnimals, allAnimals, AnimalGridList, meanMacrocaetesRaw, meanDeltaYmidRaw, gridOverlap, halfNotum, cloneTracking, DISPLAY)
%
% Builds a common grid that includes all the grids of the animals listed in "allAnimals".
% NB: the average macrocaetes positions is currently based on avgAnimals
% (NOT allAnimals) via "meanMacrocaetesRaw".
%
% version 1.0
% Boris Guirao

%% Building of global common grid %%

% REconverting back into PIXELS with refScale1D (% xyStart as origin)
meanMacrocaetes = meanMacrocaetesRaw/DISPLAY.refScale1D;
meanDeltaYmid = meanDeltaYmidRaw/DISPLAY.refScale1D;
% NB: this step is not necessary, but it enables to keep using the
% same parameter values ("scaleRatios" in particular) that were used
% to draw maps during the SAP processing.

% Merge all the GRID information loaded from the different annimals into
% the union of all the grids.
nAllAnimals = length(allAnimals);
nAvgAnimals = length(avgAnimals);
% Load grids to define crop and translation
nBoxes2OriginX = zeros(nAllAnimals, 1);
nBoxes2OriginY = zeros(nAllAnimals, 1);
lX = zeros(nAllAnimals, 1);
lY = zeros(nAllAnimals, 1);

for n = 1:nAllAnimals % for all the animal
    
    aGRID = AnimalGridList{n};
    % DBA case
    if isfield(aGRID,'REG')
        aGRID = MergeStructures(aGRID, aGRID.REG);
        % NB: works whether halfNotum = b, r, l (as REG = FULL in b case)
    end
    
    if ~cloneTracking % 3.1
        
        % find the coordinates (integers) in box number of the barycenter (that normally defines the ULC of the [0,0] box in the grid)
        ULC = cell2mat3D(aGRID.ULCs);
        [~, Ox_a] = ind2sub(aGRID.Size, find( ULC(:,:,1) == aGRID.xywh(1)));
        [Oy_a, ~] = ind2sub(aGRID.Size, find( ULC(:,:,2) == aGRID.xywh(2)));
        nBoxes2OriginX(n) = unique(Ox_a); % box number (along x) of origin compartment (whose ULC = barycenter) starting from left side of grid
        nBoxes2OriginY(n) = unique(Oy_a); % box number (along y) of origin compartment (whose ULC = barycenter) starting from top side of grid
        % NB: nBoxes2OriginX/Y include the origin compartment (having [0,0] as "coordinates") in the count
        
        % find total number of compartments along x and y for this animal
        lX(n) = aGRID.Size(2);
        lY(n) = aGRID.Size(1);
        
    else % clone tracking case (3.2)
    
        % adding one row and one column all around data for display covenience (3.2)
        lX(n) = aGRID.Size(2);
        lY(n) = aGRID.Size(1);
        nBoxes2OriginX(n) = 1;
        nBoxes2OriginY(n) = 1;
        % NB: this averaging assumes that clone tracking was run with
        % "matchingWTclone" = 2, ONLY case where clone parts are gathered
        % together!
    end
end

% Spot grid location in global common grid for each animal
startLocX = zeros(nAvgAnimals, 1);
startLocY = zeros(nAvgAnimals, 1);
endLocX = zeros(nAvgAnimals, 1);
endLocY = zeros(nAvgAnimals, 1);
for n = 1:nAvgAnimals
    [~,idx] = ismember(avgAnimals{n}, allAnimals);
    startLocX(n) = max(nBoxes2OriginX) - nBoxes2OriginX(idx) + 1; % +1 stems from the location being called from 1 to n (cf the piquets and barrieres pb)
    endLocX(n) = max(nBoxes2OriginX) - nBoxes2OriginX(idx) + lX(idx);
    startLocY(n) = max(nBoxes2OriginY) - nBoxes2OriginY(idx) + 1;
    endLocY(n) = max(nBoxes2OriginY) - nBoxes2OriginY(idx) + lY(idx);
end
LOCxy.startLocX = startLocX;
LOCxy.startLocY = startLocY;
LOCxy.endLocX = endLocX;
LOCxy.endLocY = endLocY;

% Find common global grid size
LtotX = max(nBoxes2OriginX) + max(lX - nBoxes2OriginX); % lx-Ox = number of boxes at the right of box Ox
LtotY = max(nBoxes2OriginY) + max(lY - nBoxes2OriginY); % ly-Oy = number of boxes below box Oy
gridSize = [LtotY LtotX];                             % manually defines "gridSize" to build it (2.7)

%%% Determining image boundaries with respect to origin (3.8)
% NB: now taking into account macrochaetes PIXEL coordinates to fit them all in image
% Xs:
macroXmin = min(meanMacrocaetes(1,:));
gridXmin = -(max(nBoxes2OriginX) - 1)*(1-gridOverlap) * DISPLAY.boxSize(1);
imageXmin = min(macroXmin, gridXmin);

macroXmax = max(meanMacrocaetes(1,:));
gridXmax = (1 + max(lX - nBoxes2OriginX)*(1-gridOverlap)) * DISPLAY.boxSize(1);
imageXmax = max(macroXmax, gridXmax);

% Ys:
macroYmin = min(meanMacrocaetes(2,:));
gridYmin = -(max(nBoxes2OriginY) - 1)*(1-gridOverlap) * DISPLAY.boxSize(2);
imageYmin = min(macroYmin, gridYmin);

macroYmax = max(meanMacrocaetes(2,:));
gridYmax = (1 + max(lY - nBoxes2OriginY)*(1-gridOverlap)) * DISPLAY.boxSize(2);
imageYmax = max(macroYmax, gridYmax);

%%% Setting Leeway (3.8)
% Adding at least 1/2 box size along X and Y on BOTH sides of images (2.7, 3.8)
leeway = 0.05;
leewayPixX = round((1+leeway)/2*DISPLAY.boxSize(1)); % image extra pixels along X
leewayPixY = round((1+leeway)/2*DISPLAY.boxSize(2)); % image extra pixels along Y

% Final image boundaries
imageXmin = round(imageXmin - leewayPixX);
imageXmax = round(imageXmax + leewayPixX);

imageYmin = round(imageYmin - leewayPixY);
imageYmax = round(imageYmax + leewayPixY);

% ACTUAL new coordinates of grid origin in image (with respect to image top left corner):
newOxReg = - imageXmin;
newOyReg = - imageYmin;

% Final image size:
sizeImageX = imageXmax - imageXmin;
sizeImageY = imageYmax - imageYmin;


%% REG grid case (2.7) %%

sizeImageXreg = sizeImageX;
sizeImageYreg = sizeImageY;

% Build global common REGULAR grid
% since using gridSize to keep previous size, need to determine grid new ULC in extended image (2.7)
gridULCx = newOxReg - DISPLAY.boxSize(1) * (max(nBoxes2OriginX) - 1) * (1 - gridOverlap);
gridULCy = newOyReg - DISPLAY.boxSize(2) * (max(nBoxes2OriginY) - 1) * (1 - gridOverlap);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
GRIDreg = MakeGrid([sizeImageYreg sizeImageXreg], DISPLAY.boxSize, [gridULCx gridULCy], gridSize , DISPLAY.gridColor, DISPLAY.gridLineWidth, gridOverlap);
% NB: at this stage, array "Coordinates" is NOT up to date as temporary
% grid origin was taken at top left corner of grid.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Updating grid xywh by actual origin [newOxReg newOyReg]:
GRIDreg.xywh = [newOxReg newOyReg GRIDreg.xywh(3) GRIDreg.xywh(4)];                 
% Updating array "Coordinates" to set compartment containing orgin to [0,0] (3.4):
[gridCoordinates, originBoxIJ] = gridULCs2gridCoordinates(GRIDreg.ULCs, round([newOxReg newOyReg]));  
% NB: rounding [newOxReg newOyReg] to the nearest pixel to avoid assigning
% wrong compartement as origin.
GRIDreg.Coordinates = gridCoordinates;
GRIDreg.originBoxIJ = originBoxIJ;

% Macrochaetes:
macrocaetesReg = meanMacrocaetes; % in pixels, set for newly made up image
macrocaetesReg(1,:) = macrocaetesReg(1,:) + newOxReg;
macrocaetesReg(2,:) = macrocaetesReg(2,:) + newOyReg;
% Midline:
meanYmidReg = meanDeltaYmid + newOyReg; % took opposite sign (1.0)
% meanYmidReg = newOyReg - meanDeltaYmid; % 2.5

% Filling REG structure (2.7)
REG.xywh = GRIDreg.xywh;
REG.Centroids = GRIDreg.Centroids;
REG.Macrocaetes = macrocaetesReg;
REG.yMid = meanYmidReg;
REG.SizeImageX = sizeImageXreg;
REG.SizeImageY = sizeImageYreg;
% Saves macro & midline positions in MICRON with macrocaetes BARYCENTER AS ORIGIN (3.6)
REG.MacrocaetesRaw = meanMacrocaetesRaw;
REG.yMidRaw =  meanDeltaYmidRaw; % took opposite sign (1.0)
% REG.yMidRaw = - meanDeltaYmidRaw;

%% Origin & Macrochaetes coordinates in MCU (Matrix Compartment Units) (3.5)%%

% 1) -1 Puts back matrix indexing (origin = 1,1) to coordinate system
% (origin = 0,0), as boxes origins are defined at upper left corner

% 2) NB: useful when directly plotting a matrix M using "image(M)" where 1
%    compartment value is plotted with one pixel. Oddly, the first matrix
%    compartment [1,1] is plotted between [0.5 0.5] and [1.5 1.5] (so that its
%    center is at [1,1]), hence the [1/2 1/2] added at the origin.

newOxMCU = (originBoxIJ(2) - 1) +  1/2; % (3.9)
newOyMCU = (originBoxIJ(1) - 1) +  1/2; % (3.9)

macrocaetesMCU = meanMacrocaetes; % in pixels, set for newly made up image
macrocaetesMCU(1,:) = macrocaetesMCU(1,:)/(DISPLAY.boxSize(1)*(1 - gridOverlap)) + newOxMCU; % added *(1 - gridOverlap)) (3.7)
macrocaetesMCU(2,:) = macrocaetesMCU(2,:)/(DISPLAY.boxSize(2)*(1 - gridOverlap)) + newOyMCU; % added *(1 - gridOverlap)) (3.7)
% macrocaetesMCU = [[1;1] macrocaetesMCU]; % DEBUG

% Midline
yMidMCU = meanDeltaYmid/(DISPLAY.boxSize(2)*(1 - gridOverlap)) + newOyMCU; % took opposite sign (1.0)
% yMidMCU = newOyMCU - meanDeltaYmid/(DISPLAY.boxSize(2)*(1 - gridOverlap)); % (3.9)

% Filling REG structure 
REG.MacrocaetesMCU = macrocaetesMCU;
REG.xywhMCU = [newOxMCU newOyMCU 1 1];
REG.yMidMCU = yMidMCU;

%% FULL grid case (2.7) %%

if ~strcmp(halfNotum,'b') % 2.8
    
    % Redefining newOy, sizeImageY, GRID and macrocaetes if making full animal out of halves (2.5)
    halfSizeImageYFull = sizeImageYreg - meanYmidReg;           % will only flip the part of image beyond midline (2.7)
    newOyFull = newOyReg + halfSizeImageYFull - meanYmidReg;    % 2.7
    newOxFull = newOxReg;                                       % keeps X coordinate (2.7)
    meanYmidFull = newOyFull + meanDeltaYmid;                   % meanYmid update: NOW RIGHT AT CENTER OF IMAGE ALONG Y (see NB below), took opposite sign (1.0)
%     meanYmidFull = newOyFull - meanDeltaYmid;                   % meanYmid update: NOW RIGHT AT CENTER OF IMAGE ALONG Y (see NB below)
    % NB: meanYmidFull  = (newOyReg + halfSizeImageYFull - meanYmidReg) - meanDeltaYmid
    %                   = halfSizeImageYFull + newOyReg - newOyReg + meanDeltaYmid - meanDeltaYmid = halfSizeImageYFull
    sizeImageXFull = sizeImageXreg;                             % keeps image width (2.7)
    sizeImageYFull = ceil(2 * halfSizeImageYFull);              % 2.7
    
    % since using gridSize to keep previous size, need to determine grid new ULC in extended image (2.7)
    gridULCx = newOxFull - DISPLAY.boxSize(1) * (max(nBoxes2OriginX) - 1) * (1 - gridOverlap);
    gridULCy = newOyFull - DISPLAY.boxSize(1) * (max(nBoxes2OriginY) - 1) * (1 - gridOverlap);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    GRIDfull = MakeGrid([sizeImageYFull sizeImageXFull], DISPLAY.boxSize, [gridULCx gridULCy], gridSize , DISPLAY.gridColor, DISPLAY.gridLineWidth, gridOverlap);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    GRIDfull.xywh = [newOxFull newOyFull GRIDfull.xywh(3) GRIDfull.xywh(4)]; % replacing gridULCx/y by actual origin (adapted to full image)
    % Updating array "Coordinates" to set compartment containing orgin to [0,0] (3.4):
    [gridCoordinates, originBoxIJ] = gridULCs2gridCoordinates(GRIDreg.ULCs, round([newOxFull newOxFull]));
    % NB: rounding [newOxFull newOxFull] to the nearest pixel to avoid assigning
    % wrong compartement as origin.
    GRIDfull.Coordinates = gridCoordinates;
    GRIDfull.originBoxIJ = originBoxIJ;
    
    % Macrochaetes:
    macrocaetesFull = zeros(2,16);
    macrocaetesFull(1,1:8) = meanMacrocaetes(1,:) + newOxFull;
    macrocaetesFull(2,1:8) = meanMacrocaetes(2,:) + newOyFull;
    % filling coordinates for 8 flipped macrocaetes:
    macrocaetesFull(1,9:16) = macrocaetesFull(1,1:8);
    macrocaetesFull(2,9:16) = 2 * meanYmidFull - macrocaetesFull(2,1:8); % (yMacro + yMacroFlipped)/2 = meanYmid => yMacroFlipped = ...
    
    % Filling FULL structure (2.7)
    FULL.xywh = GRIDfull.xywh;
    FULL.Centroids = GRIDfull.Centroids;
    FULL.Macrocaetes = macrocaetesFull;
    FULL.yMid = meanYmidFull;
    FULL.SizeImageX = sizeImageXFull;
    FULL.SizeImageY = sizeImageYFull;
    % NB: missing MacrocaetesRaw and MacrocaetesMCU in FULL structure for
    % now
    
else
    FULL = REG; % when animals are "full" (halfNotum = 'b') (2.8)
end

%% Making a common GRID structure (2.7) %%

cGRID = GRIDreg;
cGRID.REG = REG;
cGRID.FULL = FULL;
cGRID = rmfield(cGRID,{'xywh','Centroids'}); % those fields are in REG and FULL

fprintf(' Done\n')

%% History %%

% 30/09/2024: 1.0 creation (Boris)
% - with respect to initial AOA code, fixed yMid used that was strangely always used
% with a minus sign, which was not consistent with treatment of macrocaetes coordinates.