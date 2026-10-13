function cellQs = RNs2RFeatures(cellRNs, CELLS, quantity)
%
% cellQs = RNs2RFeatures(cellRNs, CELLS, quantity)
%
% Will replace each Region Number RN in matrix "cellRNs" by its Region
% Feature ('areas','anisotropies',...) from SIA backup.
% If "cellRNs" is a nxm matrix and Q is a p-element vector, then "cellQs"
% has dimensions nxmxp.
% If "cellRNs" is a nx1 (* OR 1xn *) vector and Q is a p-element vector,
% then "cellQs" has dimensions nxp.
%
% NB: "cellRNs" may contain NaNs; string "quantity" must be listed among
% structure "CELLS" fields; The cell "quantity" must be a scalar or tensor
% in vector form (namely [Qxx Qxy Qyx Qyy]) for each cell.
%
% Example: divCellAreas = RNs2Qvalues(divCellRNs, CELLS, 'Areas');


%% Code %%

Qs = CELLS.(quantity);                              % extracting "quantity" from CELLS
Qlength = size(Qs,2);                               % number of elements of Q

[nRowsCellRNs, nColCellRNs] = size(cellRNs);        % size of "cellRNs" matrix
nCellRNs = nRowsCellRNs*nColCellRNs;                % number of elements in "cellRNs" (including NaNs)

cellQs = NaN(nRowsCellRNs, nColCellRNs, Qlength);   % initializes "cellQs"

% Filtering out NaNs (mandatory because cannot call index "NaN")
cellRNsFiltTF = ~isnan(cellRNs);
cellRNsNoFiltIndices = find(cellRNsFiltTF);         % indices in "cellRNs" actually storing RNs and not a NaN 
cellRNsFiltList = cellRNs(cellRNsNoFiltIndices);    % ordered list of found RNs as they appear

% Filling "cellQs" layer by layer
for d = 1:Qlength
    
      dthCellRNsNoFiltIndices = cellRNsNoFiltIndices + (d-1)*nCellRNs;      % getting indices to fill FOR EACH LAYER
      cellQs(dthCellRNsNoFiltIndices) = Qs(cellRNsFiltList,d);              % stores value Q for each RN at right locations
end

% If "cellRNs" was a vector, remove 3rd dimension of "cellQs":
cellQs = squeeze(cellQs);

%% History %%

% 09/01/2018: creation