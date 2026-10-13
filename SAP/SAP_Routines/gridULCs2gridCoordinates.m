function [gridCoordinates, originBoxIJ] = gridULCs2gridCoordinates(gridULCs, originXY)
%
% [gridCoordinates, originBoxIJ] = gridULCs2gridCoordinates(gridULCs, originXY)
%
% From grid ULCs and animal origin, determines the cell array of grid
% coordinates. The compartment containing "originXY" has grid coordinates
% [0,0] and is located at "originBoxIJ" in the grid matrix.
%
% NB: "gridULCs" and ???
%
% version 1.0
% Boris Guirao


%% Code %%

gridSize = size(gridULCs);
gridULC3D = cell2mat3D(gridULCs);

% substracts origin from ULCs:
gridDeltaXs = gridULC3D(:,:,1) - originXY(1);
gridDeltaYs = gridULC3D(:,:,2) - originXY(2);

% Finds negative values along X and Y:
gridDeltaXsTF = gridDeltaXs <= 0;
gridDeltaYsTF = gridDeltaYs <= 0;

% Finds index of BOTH, positive X & Y:
gridBothTF = all(cat(3,gridDeltaXsTF,gridDeltaYsTF),3);
originIndex = find(gridBothTF, 1, 'last'); % the origin compartment index is the LAST ONE to have BOTH negative DeltaXs&Ys
[oI,oJ] = ind2sub(gridSize,originIndex);
originBoxIJ = [oI oJ]; % indices of box contaning the origin

% Creates gridCoordinates
[gridXs, gridYs] = meshgrid(1:gridSize(2),1:gridSize(1));
% sets origin compartment to 0:
gridXs = gridXs - oJ;
gridYs = gridYs - oI;
gridCoordinatesMat = [gridXs(:) gridYs(:)];
% Makes it a gridSize cell array:
gridCoordinates = reshape(num2cell(gridCoordinatesMat,2),gridSize(1),gridSize(2));

%% History %%

% 17/05/2020: creation

