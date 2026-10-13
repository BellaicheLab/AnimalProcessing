function ancestorCellANs = MakeAncestors(cellANs, mode)
%
% ancestorCellANs = MakeAncestors(cellANs, mode)
%
% Generates list "ancestorCellANs" corresponding to matrix array "cellANs" and HAVING SAME SIZE (row, col). Parameter
% "mode" can either be "youngest" or "oldest" (see examples below).
%
% NB: to get rid of mothers listed multiple times, just do an additional "unique(ancestorCellANs,'rows')".
%
% Examples:
%
% if mode = 'youngest', ONLY take cells back to the PREVIOUS round of division:
% cellANs =            [123     1     0;
%                       123     2     0;
%                       345     1     1;
%                       356     0     0]
% yields:
% ancestorCellANs =    [123     0     0;
%                       123     0     0;
%                       345     1     0;
%                       356     0     0]
%
% NB: in "youngest" mode, one can equivalently use "MakeMothers"
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% if mode = 'oldest', take all cells back to their very INITIAL mother:
% cellANs =            [123     1     0;
%                       123     2     0;
%                       345     1     1;
%                       356     0     0]
% yields:
% ancestorCellANs =    [123     0     0;
%                       123     0     0;
%                       345     0     0;
%                       356     0     0]
%
% version 1.0 (replaces "Mother_Maker" v1.2 when using mode = 'youngest')
% Boris Guirao

%% Code %%

tableSize = size(cellANs);
nCells = tableSize(1);
vectorSize = tableSize(2);

ancestorCellANs = zeros(nCells,vectorSize);

if strcmp(mode, 'youngest')
    
    for i = 1:nCells
        maxInd = max(2, find(cellANs(i,:), 1, 'last'));
        ancestorCellANs(i,1:maxInd-1) = cellANs(i,1:maxInd-1);
    end
    
elseif strcmp(mode, 'oldest')
    
    ancestorCellANs(:,1) = cellANs(:,1); % simply copy/paste first column with basic AN without div tags
    
else
    disp('AncestorMaker ERROR: "mode" can either be "youngest" or "oldest"!');
    ancestorCellANs = [];
end

%% History %%

% 29/11/2016: creation

