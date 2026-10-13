function cellCategoryTags = MakeCellCategoryTags(cellCATEGORIES)
%
% cellCategoryTags = MakeCellCategoryTags(cellCATEGORIES)
%
% Rebuilds "cellCategoryTags" vector from coreRNs, FLRNs, borderRNs stored
% in "cellCATEGORIES".
%
% Version 1.0
% Boris Guirao


%% Code %%

ExtractData(cellCATEGORIES);

nCoreRNs = length(coreRNs);
nFLRNs = length(FLRNs);
nBorderRNs = length(borderRNs);

nRNs = nCoreRNs + nFLRNs + nBorderRNs; % total number of cells

% filling "cellCategoryTags" with appropriate values:
cellCategoryTags = NaN(nRNs,1); % initialization
cellCategoryTags(coreRNs) = 0;
cellCategoryTags(FLRNs) = 1;
cellCategoryTags(borderRNs) = 2;


%% History %%

% 03/05/2018: creation