function [neighborColor] = AssignNeighborColor(mycmap_bo, nNeighbors)
%
% [neighborColor] = AssignNeighborColor(mycmap_bo, nNeighbors)
%
% Use colormap "mycmap_bo" stored in Matlab file
% "Colormaps_neighbors_bo.mat" (that must have been loaded previously)to
% attribute a color corresponding to "value".
%
% version 1.0
% Boris Guirao

%% Code

if nNeighbors <= 3
    neighborColor = mycmap_bo(33,:); % yellow
elseif nNeighbors == 4
    neighborColor = mycmap_bo(85,:); % green
elseif nNeighbors == 5
    neighborColor = mycmap_bo(99,:); % salmon
elseif nNeighbors == 6
    neighborColor = mycmap_bo(114,:); % white
elseif nNeighbors == 7
    neighborColor = mycmap_bo(130,:); % blue
elseif nNeighbors == 8
    neighborColor = mycmap_bo(146,:); % red
elseif nNeighbors == 9
    neighborColor = mycmap_bo(161,:); % purple
elseif nNeighbors == 10 || nNeighbors == 11
    % remains lines 175 > 256 in mycmap_bo
    neighborColor = mycmap_bo(180,:); % turquoise
elseif nNeighbors == 12 || nNeighbors == 13
    neighborColor = mycmap_bo(210,:); % darker turquoise
elseif nNeighbors > 13
    neighborColor = mycmap_bo(240,:); % darker darker turquoise
elseif isnan(nNeighbors)
    disp('Warning: a cell with "n_neighbors = NaN" was found')
    neighborColor = [0 0 0]; % black
else
    disp('Warning: unexpected number of neighbors')
    return
end


%% History

% 12/02/2010: start