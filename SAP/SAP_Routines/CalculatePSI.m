function cellPsiQs = CalculatePSI(CELLS, quantity, RNs2exclude)
%
% cellPsiQs = CalculatePSI(CELLS, quantity, RNs2exclude)
%
% Version 1.0
% Boris Guirao

%% Code %%

cellNeighbors = CELLS.Neighbors;    % gets neighbor RNs for all RNs
cellQs = CELLS.(quantity);          % gets "quantity" for all RNs

cellCategoryTags = CELLS.CategoryTags;
[~, ~, borderRNs] = GetCellCategories(cellCategoryTags);

allRNs2exclude = unique([RNs2exclude ; borderRNs]); % ALWAYS excluding "borderRNs"

cellNeighborFilt = cellfun(@(N) setdiff(N, allRNs2exclude), cellNeighbors, 'UniformOutput', false);   % exclude RNs listed in "allRNs2exclude" from neighbor RN list
cellNeighborQs = cellfun(@(Nf) cellQs(Nf), cellNeighborFilt, 'UniformOutput', false);             % replaces neighbor RNs by corresponding quantity value

cellNeighborMeanQs = cellfun(@mean, cellNeighborQs);                                               % takes Q averaged over neighbors

cellPsiQs = cellQs./cellNeighborMeanQs;                                                            % calculate PSI(Q)

%% History %%

% 11/10/2018: creation