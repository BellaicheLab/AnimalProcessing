function QrangePlot = FindValueRange(CELLS,Q)
%
% rangeQPlot = FindValueRange(CELLS,Q)
%
% For any quantity "Q" listed in CELLS ('areas', 'anisotropies'...), it will find min and max values among NON-BORDER cells.
%
% version 1.1
% Boris Guirao

%% Code %%

allCellQ = CELLS.(Q);
cellCategoryTags = CELLS.CategoryTags;                              % 1.1
[~, ~, ~,nonBorderRNs] = GetCellCategories(cellCategoryTags);       % 1.1
% nonBorderRNs = CELLS.CATEGORIES.nonBorderRNs;

cellQ = allCellQ(nonBorderRNs);

QrangePlot = NaN(1,2);
QrangePlot(1) = roundn(min(cellQ),-1);
QrangePlot(2) = roundn(max(cellQ),-1);



%% History %%

% 04/05/2018: 1.1
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"

% 15/09/2016: creation


