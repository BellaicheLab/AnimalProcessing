function cloneRNs = FindCloneRNs(ky, cloneImageLabels, cellXYs, scale1D)
%
% cloneRNs = FindCloneRNs(ky, cloneImageLabels, cellXYs, scale1D)
%
% Will find region RNs corresponding to clone number "ky" in "cloneImageLabels".
%
% Version 1.2
% Boris Guirao

%% Code %%

cellXs = round(cellXYs(:,1)/scale1D); % back in pixels and rounded
cellYs = round(cellXYs(:,2)/scale1D);

imageSize = size(cloneImageLabels);

cellLs = sub2ind(imageSize, cellYs, cellXs);    % gets linear indices of centroids

cellCloneNumbers = cloneImageLabels(cellLs);    % finds the clone number at every region centroid (or 0 when not clone region)

% cellsInCloneTF = cellCloneNumbers > 0;          % finding regions corresponding to clone (mod 1.1)
cellsInCloneTF = ismember(cellCloneNumbers, ky); % finding regions corresponding to clone "ky"

cloneRNs = find(cellsInCloneTF);                % indices in "cellsInCloneTF" corresponds to RNs


%% History %%

% 02/11/2018: 1.2
% - reverted 1.1 change and added back argument "ky"

% 26/06/2018: 1.1
% - removed input argument "ky" as now all clone parts are gathered into a
% single compartment grid => only looking at cells belonging to any clone
% part.

% 20/07/2017: creation