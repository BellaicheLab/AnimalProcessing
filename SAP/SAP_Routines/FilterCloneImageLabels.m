function [cloneImageLabelsFiltered, wtImageLabelsFiltered] = FilterCloneImageLabels(cloneImageLabels, yMid, borderRNs, cellContourIndices, imageLabels, matchingWTclone,nCellsMin)
%
% [cloneImageLabelsFiltered, wtImageLabelsFiltered] = FilterCloneImageLabels(cloneImageLabels, yMid, borderRNs, cellContourIndices, imageLabels, matchingWTclone,nCellsMin)
%
% IF matchingWTclone = true AND yMid NOT empty (introduced in 1.2)
% Aim is to study mutant clones and their corresponding symmetric WT part across the midline. IN INITIAL IMAGE
% "cloneImageLabels", the program will therefore filter out the pixels without existing matching WT part due to:
%   1) out-of-bounds flipped pixels
%   2) flipped pixels falling into another mutant clone part
%   3) regular AND flipped pixels that fall into "borderRNs" regions that won't be analyzed.
% The resulting "cloneImageLabelsFiltered" and its flipped version "cloneImageLabelsFlipped" should have symmetric
% matching regions with respect to midline.
%
% IF matchingWTclone = false OR yMid EMPTY, then just filters out border cells from clone binary image
%
% Version 1.3
% Boris Guirao


%% Filtering out borderRNs pixels (1.1) %%

% NB: borderRNs will NOT be counted in clone regions anyway => they souldn't be used to define the symmetric clone WT
% counterpart => excluding them right away

imageSize = size(cloneImageLabels);                 % moved up (1.2)

% Initializations
cloneImageLabelsFiltered = cloneImageLabels;
wtImageLabelsFiltered = zeros(imageSize);         % moved up (1.2)

borderRNsTF = ismember(imageLabels, borderRNs);                         % determining borderRNs in full image
borderRNsIndices = find(borderRNsTF);                                           % 1.3
borderRNsContourIndices = cell2mat(cellContourIndices(borderRNs));              % 1.3
borderRNsAllIndices = unique([borderRNsIndices ; borderRNsContourIndices]);       % 1.3
cloneImageLabelsFiltered(borderRNsAllIndices) = 0;                              % setting borderRNs pixels to 0
% cloneImageLabelsFiltered(borderRNsTF) = 0;                              % setting borderRNs pixels to 0


%% Removing regions with few cells (< nCellsMin) (1.3)%%

ny = double(max(cloneImageLabelsFiltered(:))); % gets current number of regions

for r = 1:ny
    
    rthRegionTF = ismember(cloneImageLabelsFiltered, r);    % gets region r
    rthRegionRNs = unique(imageLabels(rthRegionTF));        % gets RNs in this region
    rthRegionRNs = rthRegionRNs(rthRegionRNs > 0);          % removes 0 from list
    rthRegionnCells = length(rthRegionRNs);
    
    % Erase region if it contains less cells than "nCellsMin"
    if rthRegionnCells < nCellsMin
        cloneImageLabelsFiltered(rthRegionTF) = 0;
        disp(['WARNING "FilterCloneImageLabels": erasing ' num2str(r) 'th clone region that contains less than ' num2str(nCellsMin)  ' cells']);
    end
end

% % Updating clone labels
% cloneImageFiltered = logical(cloneImageLabelsFiltered);
% cloneImageFilteredCC = bwconncomp(cloneImageFiltered,4);
% cloneImageLabelsFiltered = labelmatrix(cloneImageFilteredCC); % REcreates the image labelled uint8 or uint16 according to the number of regions


%% Flipping & Filtering clone pixels (1.1) OR NOT (1.2)%%

if matchingWTclone == 1 && ~isempty(yMid) % Flipping & Filtering clone pixels
% if matchingWTclone && ~isempty(yMid) % Flipping & Filtering clone pixels
    
    % Flipping cloneImageLabels with respect to midline
    
    cloneTF = cloneImageLabelsFiltered > 0; % mod 1.1
    cloneIndices = find(cloneTF);
    
    [cloneIs, cloneJs] = ind2sub(imageSize, cloneIndices);
    
    cloneJsFlipped = cloneJs;
    cloneIsFlipped  = yMid + (yMid-cloneIs); % flipping row indices % midline
    % NB: "Flipped" indices are sorted EXACLTY as those in regular clone
    
    
    % Removing: 1) flipped pixels that are out of bound
    %           2) flipped pixels that belong to ANY clone pixels
    %           3) flipped pixels that correspond to image borderRNs (1.1)
    
    % Determining out-of-bounds pixels:
    cloneIsFlippedOutOfBoundsTF = cloneIsFlipped < 1 | cloneIsFlipped > imageSize(1); % finding out of bounds flipped Is
    % cloneIsFlippedInBoundsTF = ~cloneIsFlippedOutOfBoundsTF;
    % Replacing them by NaNs
    cloneIsFlippedNaNFiltered = cloneIsFlipped;
    cloneIsFlippedNaNFiltered(cloneIsFlippedOutOfBoundsTF) = NaN;
    cloneJsFlippedNaNFiltered = cloneJsFlipped;
    cloneJsFlippedNaNFiltered(cloneIsFlippedOutOfBoundsTF) = NaN;
    % Now Rebuilding partially filtered indices
    cloneIndicesFlippedNaNFiltered = sub2ind(imageSize, cloneIsFlippedNaNFiltered, cloneJsFlippedNaNFiltered);
    
    % Determining indices in common between clone and their flipped version:
    cloneIndicesOverlapTF = ismember(cloneIndices, cloneIndicesFlippedNaNFiltered); % 1.1
    % cloneIndicesOverlapTF = ismember(cloneIndices, cloneIndicesFlippedHalfFiltered);
    
    % Determining flipped clone indices corresponding to borderRNs pixels (1.1)
    borderRNsIndices = find(borderRNsTF);
    cloneIsFlippedOnBorderRNsTF = ismember(cloneIndicesFlippedNaNFiltered, borderRNsIndices);
    
    % Determining ALL pixels to exclude
    cloneIsFlipped2FilteredTF = ~any([cloneIsFlippedOutOfBoundsTF cloneIndicesOverlapTF cloneIsFlippedOnBorderRNsTF],2); % added "cloneIsFlippedOnBorderRNsTF" (1.1)
    % NB: % WORKS BECAUSE BOTH "Flipped" and regular ARE SORTED IN THE EXACT SAME WAY!
    
    cloneIsFlippedFiltered = cloneIsFlipped(cloneIsFlipped2FilteredTF); % excluding out of bounds AND overlapping indices
    cloneJsFlippedFiltered = cloneJsFlipped(cloneIsFlipped2FilteredTF); % cropping similarly the Js vector
    cloneIndicesFlippedFiltered = sub2ind(imageSize, cloneIsFlippedFiltered, cloneJsFlippedFiltered); % back to linear indices
    
    % filtering back the regular pixels
    cloneJsFiltered = cloneJsFlippedFiltered;
    cloneIsFiltered = yMid + (yMid - cloneIsFlippedFiltered);
    
    cloneIndicesFiltered = sub2ind(imageSize, cloneIsFiltered, cloneJsFiltered); % **SORTED EXACTLY AS "cloneIndicesFlippedFiltered"**
    cloneIndices2Exlude = setdiff(cloneIndices, cloneIndicesFiltered);
    
    % Killing pixels to exclude in original "cloneImageLabels":
    cloneImageLabelsFiltered(cloneIndices2Exlude) = 0;
    
    % Building "cloneImageLabelsFlipped" (and already filtered):
    cloneNumbersFiltered = cloneImageLabelsFiltered(cloneIndicesFiltered); % vector with clone number matching each pixel index
    
    % Updating "cloneImageLabelsFlipped"
    wtImageLabelsFiltered(cloneIndicesFlippedFiltered) = cloneNumbersFiltered; % putting SAME clone numbers in flipped regions
    
elseif matchingWTclone == 2 % taking complementary part of clone
    
    wtImageLabelsFiltered(cloneImageLabels == 0) = 1;         % takes negative of clone
    wtImageLabelsFiltered(borderRNsAllIndices) = 0;          % setting borderRNs pixels to 0
end

%% History %%

% 05/04/2019: 1.4
% - changes to support the 3 possible values of "matchingWTclone" (used to
% be boolean).
% - with "matchingWTclone" = 2, now selects the wt tissue surrounding the clone. 

% 02/11/2017: 1.3
% - added "cellContourIndices" and "nCellsMin" as arguments.
% - now properly removing all border RN pixels thanks to the loading of
% "cellContourIndices".
% - removing regions with fewer cells than "nCellsMin".

% 06/09/2017: 1.2
% - now also supports simple tracking of clones without WT counterparts when "matchingWTclone" = false OR yMid is EMPTY
% - accordingly introduced "matchingWTclone" as new argument

% 22/07/2017: 1.1
% - also removed clone pixels corresponding to borderRNs AS WELL AS matching WT clone pixels corresponding to borderRNs,
% namely all borderRNs pixels AND their mirror % midline from actual clone or its mirror

% 21/07/2017: creation