function cellPNs = AssignPatch(cellRNs, allCoreRNs, allCoalescedRNs, allNeighborRNs, allCellPNs)
%
% cellPNs = AssignPatch(cellRNs, allCoreRNs, allCoalescedRNs, allNeighborRNs, allCellPNs)
%
% Assigning cells listed in "cellRNs" to grid compartments (Patch Number) based on number of neighbors
% belonging to these patches IN CURRENT FRAME. "cellBNs" and "cellRNs" have same size.
%
% version 1.2
% Boris Guirao


%% Code %%

nCells = length(cellRNs);
coreRNs = intersect(allCoreRNs, cellRNs);            % only considering core cells => no border cells as neighbors
nCoreCells = length(coreRNs);
[~,coreLoc] = ismember(coreRNs,cellRNs);            % locations of coreRNs in cellRNs

cellPNs = NaN(nCells,1);
cellRNsUnassigned = cellRNs; % cellRNs that have not been assigned to a patch yet (1.1)

for c = 1:nCoreCells
    
    cNeighborRNs = allNeighborRNs{coreRNs(c)};                                  % gets current neighbors of cth new cell
    cNeighborRNs = setdiff(cNeighborRNs, [cellRNsUnassigned; allCoalescedRNs]);
    % NB: excludes neighbors listed in cellRNsUnassigned: box assignment based on neighbors ALREADY belonging to a specific patch
    % NB: excluding neighbor RNs being coalesced limits errors AND weird box assignement
    
    cNeighborPNs = allCellPNs(cNeighborRNs);
    cPosPNs = unique(cNeighborPNs);                     % all possible Box Numbers for c
    cPosPNs = RemoveNaNs(cPosPNs);                      % 1.2
    
    if ~isempty(cPosPNs)                                % 1.2
        
        cPosPNsCount = histc(cNeighborPNs,cPosPNs);         % returns the number of occurences of each BN listed in "c_posBNs"
        [~,cPNind] = max(cPosPNsCount);                     % if equality in the count, returns the first index
        cPN = cPosPNs(cPNind);                              % found to which box this new cell will be assigned
        
        % filling cellPNs
        cellPNs(coreLoc(c)) = cPN;
        
        % removing cell from unassigned list (1.1)
        cellRNsUnassigned = setdiff(cellRNsUnassigned,coreRNs(c));
    end
end


%% History %% 

% 08/02/2018: 1.2
% - adjustments to use "histc" without NaNs (Matlab 2017b)

% 05/12/2016: 1.1
% - update of "cellRNsUnassigned" during the process

% 29/11/2016: creation