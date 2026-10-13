function [coreRNs, firstLayerRNs, borderRNs, nonBorderRNs] = GetCellCategories(cellCategoryTags)
%
% [coreRNs, FirstLayerRNs, borderRNs, nonBorderRNs] = GetCellCategories(cellCategoryTags)
%
% From "CategoryTags" which contains 0 for core RNs, 1 for first layer RNs,
% and 2 for border RNs, retrieves the lists of corresponding cell RNs for
% each category.
%
% Version 1.0
% Boris Guirao

%% Code %%

% Finding category locations;
coreTF = cellCategoryTags == 0;
firstLayerTF = cellCategoryTags == 1;
borderTF = cellCategoryTags == 2;

% Retrieving cell RNs:
coreRNs = find(coreTF);
firstLayerRNs = find(firstLayerTF);
borderRNs = find(borderTF);

% Combined categories
nonBorderRNs = unique([coreRNs;firstLayerRNs]);

%% History %%

% 03/05/2018: creation