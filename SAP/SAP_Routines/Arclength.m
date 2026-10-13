function [arclengthValues, sideIndicesSorted, closedContour] = Arclength(imageSize, sideIndices, baseIndex, scale)
%
% [arclengthValues, sideIndicesSorted, closedContour] = Arclength(imageSize, sideIndices, baseIndex, scale)
%
% Calculates arclength values of a skeletonized list of connex pixels (conn
% = 8) for an open or closed contour from the specified base pixel index.
%
% INPUTS:
% - imageSize (1x2 matrix)
% - sideIndices = list of linear indices making up the contour
% - baseIndex = index where arclength calculation will start (arclength =0). Must be part of the contour (closed) and one of the 2
%              endpoints(open). If empty, 1st index of "ind_side" (closed)/ind_endpoints(open) is assigned.
% - scale = size of one pixel (unit �m/pixel). OPTIONAL. DEFAULT = 1 �m/pixel.
%
% OUTPUTS:
% - arclengthValues = vector containing arclength values in ascending order (starts at 0)
% - sideIndicesSorted = list of pixel indices from "ind_side" but sorted in ascending order of arclength
% - closedContour = boolean specifying if the contour is closed or open
%
% NB: max(Arclength(...)) returns the total arclength of the side
%
% KNOWN BUGS:
% - doesn't work for a closed contour with "bubbles" trapped inside
% because then there are 2 equivalent neighboring pixels comming next
% (update: not exactly equivalent: one should be a vertex) (ex: cell 48 of
% modified image "Unionseg_mod_p7_0001.png")
%
% Version 1.3
% Boris Guirao

%% Initial Tests %%

% Number of arguments:
if nargin == 3
    scale = 1;                                                             % set scale to 1 �m/pixel if not specified
end

% ind_side format:
if size(sideIndices, 2) > 1
    sideIndices = sideIndices';        % makes sure ind_side in a column vector
end

nPixels = length(sideIndices);         % number of pixels making up side (moved 1.2)

% Rebuilds image of side:
sideImage = zeros(imageSize);
sideImage(sideIndices) = 1;
sideImageEndpoints = bwmorph(sideImage, 'endpoints');                   % gets indices of side endpoints
endpointIndices = find(sideImageEndpoints);                                % empty if closed contour

% checks whether the contour is closed:
if ~isempty(sideIndices) && ~isempty(endpointIndices)
    
    closedContour = false;                                                    % Open contour case
    arclengthValues = zeros(nPixels,1);                                     % 1.2
    sideIndicesSorted = zeros(nPixels,1);                                      % 1.2
    nPixelsIteration = nPixels;                                               % 1.2
    if isempty(baseIndex)                                                   % assign the first endpoint index to ind_base if it was left empty (1.1)
        baseIndex = endpointIndices(1);
    elseif ~ismember(baseIndex, endpointIndices)
        warndlg('"Arclength" function: the base index entered does not correspond to any of the side endpoints.' ,'Warning! Open Contour')
        arclengthValues = []; sideIndicesSorted = [];
        return
    end
elseif ~isempty(sideIndices) && isempty(endpointIndices)
    
    disp('"Arclength" function: closed contour found')          % 1.2
    closedContour = true;                                       % Closed contour case
    arclengthValues = zeros(nPixels + 1,1);                     % 1.2
    sideIndicesSorted = zeros(nPixels + 1,1);                   % 1.2
    nPixelsIteration = nPixels + 1;                             % One extra value because ind_base will be repeated at the end with actual total arclength (1.2)
    if isempty(baseIndex)
        baseIndex = sideIndices(1);                             % assign the first index of ind_side to ind_base if it was left empty (1.1)
    elseif ~ismember(baseIndex, sideIndices)
        warndlg('"Arclength" WARNING: the base index entered does not correspond to any of the contour indices.' ,'Warning! Closed Contour')
        arclengthValues = []; sideIndicesSorted = [];
        return
    end
else                                                                       % empty list of indices
    warndlg('"Arclength" WARNING: empty list of pixel indices.' ,'Warning!')
    arclengthValues = []; sideIndicesSorted = [];
    return
end

%% Arclength Calculation %%

%%% Initialization:
pIndex = baseIndex;
sideIndicesSorted(1) = baseIndex;
remainingSideIndices = sideIndices;

for p = 1:nPixelsIteration-1
    
    remainingSideIndices = setdiff(remainingSideIndices, pIndex);               % removes index of pth pixel from the list of pixels to look for
    % Closed contour (1.2):
    if closedContour && p == nPixelsIteration-1
        remainingSideIndices = [remainingSideIndices ; baseIndex];              %#ok<AGROW>. Puts "baseIndex" back in the list to calculate actual total arclength.
    end
    [pI, pJ] = ind2sub(imageSize, pIndex);
    pZ = pJ + 1i * pI;
    [~, pNeighborPixels] = ixneighbors(sideImage, pIndex);                   % gets indices of pixels neighboring ind_p
    pSideNeighborPixels = intersect(pNeighborPixels, remainingSideIndices); % pixel indices neighboring current pixel. max 2 indices of pix should remain if side was skeletonized
    nNeighborPixels = length(pSideNeighborPixels); 

    if isempty(pSideNeighborPixels)                                       % checks whether no neighbor was found for pth pixel among remainging side pixels:
        disp('"Arclength" WARNING: the list of pixels making up the side is not connex (connect 8)')
        return
    end
    
    %%% calculates distance of side neighboring pixels to current pixel and selecting the nearest one:
    d = zeros(nNeighborPixels,1);                                           % will store distance of each neighboring pixels
    for k = 1:nNeighborPixels
        ind_neighbor_k = pSideNeighborPixels(k);
        [kI, kJ] = ind2sub(imageSize, ind_neighbor_k);
        kZ = kJ + 1i * kI;
        pkZ = kZ - pZ;
        d(k) = abs(pkZ);
    end
    kNearest = find(d == min(d));                                         % k of the nearest neighbor. NB: when iterating first pixel, possible to have length(k_nearest) > 1
    
    % Closed contour: breaks possible initial symmetry to initiate calculation:
    if length(kNearest) > 1 && closedContour && p == 1              % when 2 pixels at same distance from ind_base (explains p == 1)
        kNearest = kNearest(1);                                          % takes first listed nearest neighbor
        disp('"Arclength" WARNING: artificial breaking of initial symmetry in neighboring pixels to initiate calculation!')
    elseif length(kNearest) > 1                                           % 1.2
        disp('"Arclength" WARNING: unexpected case!')
        return
    end
  
    kNearestIndex = pSideNeighborPixels(kNearest);                       % get chosen neighbor pixel index
    arclengthValues(p+1) = arclengthValues(p) + d(kNearest);            % stores the incremented arclength value
    sideIndicesSorted(p+1) = kNearestIndex;                                  % stores the chosen neighbor index in the list of indices sorted in ascending
    pIndex = kNearestIndex;                                                 % updates ind_p with index of chosen neighbor for next iteration
end

%%% Closed contour: removes first values of ind_base (repeated at the end) and 0 arclength (1.2)
if closedContour
    arclengthValues = arclengthValues(2:nPixels + 1);                               
    sideIndicesSorted = sideIndicesSorted(2:nPixels + 1); 
end

%%% Rescaling arclength values with "scale" factor:
arclengthValues = arclengthValues * scale;


%% History

% 24/01/2018:
% - added boolean "closedContour" as output

% 07/07/2010: 1.3
% - REMOVED output "image_arclength" to make it faster (image of contour
% with arclength values at each corresponding pixels (background = NaN))
% Removed in the code:
%    image_arclength = NaN(image_size);
%    image_arclength(ind_side_sorted) = arclength_values;

% 01/07/2010: 1.2
% - systematic notification when closed contour is found
% - for closed contour, the first pixel (ind_base) will now store the last
% (and actual) value of arclength instead of 0. arclength_values then
% starts with value 1 and not 0 and ind_base ends up being the LAST index
% listed corresponding to total contour arclength.

% 29/06/2010: 1.1
% - default assignment of first endpoints (open contour) or pixel index (closed
% contour) when ind_base was left empty

% 16/06/2010: creation