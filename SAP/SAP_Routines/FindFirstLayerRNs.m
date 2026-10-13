function FLRNs = findFirstLayerRNs(borderRNs, neighborRNs)
%
% FLRNs = findFirstLayerRNs(borderRNs, neighborRNs)
%
% Will find First Layer RNs "FLRNs" from the lists of "borderRNs" and "neighborRNs".
%
% Version 1.0
% Boris Guirao

%% Code %%

BCneighbors = neighborRNs(borderRNs,:);
BCneighbors = unique(BCneighbors);                          % list containing ALL Border cells AND their neighbors
BCneighbors = BCneighbors(BCneighbors > 0);                % removes 0
if size(BCneighbors,2) > 1                                   % making sure it is a column vector (1.3.2)
    BCneighbors = BCneighbors';
end
FLRNs = setdiff(BCneighbors, borderRNs);
% coreCells = setdiff(cellRNs, BCneighbors);


%% History %%

% 17/11/2017: creation