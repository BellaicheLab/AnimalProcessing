function cellRNsInBox = FindBoxRNs(ky, kx, GRID, cellRNs, cellXYs, scale1D)
%
% cellRNsInBox = FindBoxRNs(ky, kx, GRID, cellRNs, cellXYs, scale1D)
%
% For each grid compartment, will determine which cell relative numbers (RNs) have their centroids located within the
% box(ky,kx). Cell centroid coordinates "cellXYs" must be in micrometers.
% NB: **BEWARE OF ORDER IN WHICH ky, kx ARE ENTERED!!**
%
% Version 1.5
% Boris Guirao


%% Extracting and formatting data %%

% Extracts data from GRID:
gridULCs = GRID.ULCs;
xywh = GRID.xywh;

% conversion in pixels
cellXs = cellXYs(:,1)/scale1D;
cellYs = cellXYs(:,2)/scale1D;


%% Getting this box limits %%

thisBoxULCs = gridULCs{ky,kx};

% Going over the box limits of 1/2 pixel in all directions (1.3):
% NB: by doing so, boxes then do cover all image and leave out no cells between compartments
thisXmin = thisBoxULCs(1) - 1/2;
thisXmax = thisBoxULCs(1) + xywh(3) - 1/2; % pixel @ this_box_ULCs(1) + xywh(3) = ULCs{ky,kx+1} already belongs to next compartment!!
thisYmin = thisBoxULCs(2) - 1/2;
thisYmax = thisBoxULCs(2) + xywh(4) - 1/2; % pixel @ this_box_ULCs(2) + xywh(4) = ULCs{ky+1,kx} already belongs to next compartment!!


%% Determination of cell RNs having their centroids in this box %%

cellRNsInXrange = cellRNs(cellXs >= thisXmin & cellXs <= thisXmax);
cellRNsInYrange = cellRNs(cellYs >= thisYmin & cellYs <= thisYmax);
cellRNsInBox = intersect(cellRNsInXrange, cellRNsInYrange);


end

%% History %%

% 23/07/2017: 1.5 became "BoxRNsFinder" (from "Box_RNs_Finder")
% - renamed variables & removed commented parts

% 07/03/2014: 1.4
% - commented part displaying warning when a grid compartment is found empty
% - commented part determining all cells within grid and removed second output accordingly

% 30/01/2014: 1.3
% - Going over the box limits of 1/2 pixel in all directions to leave out no cells between compartments
% - fixed mistake by calculating this_x/y_max using this_box_ULCs(1/2) instead of this_x/y_min


% 22/01/2014: 1.2
% - corrected mistake leading to one pixel overlap between boxes: replaced "this_x_max = this_x_min + xywh(3)" by "this_x_max = this_x_min + xywh(3) - 1" (same for y axis)

% 11/01/2012: creation


