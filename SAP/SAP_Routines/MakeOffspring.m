function cellANsOffspring = MakeOffspring(cellANs)
%
% cellANsOffspring = OffspringMaker(cellANs)
%
% INPUT: list of cells "cellANVS" in Absolute Number Vector Style
% OUTPUT: "cellANVSoffspring" column listing all cells possible offspring in ANVS
%        
% EX:
% cellANs      =        [132     2     1     0     0;
%                        402     1     1     2     0]
%
% cellANsoffspring  =   [132     2     1     1     0;
%                        132     2     1     2     0;
%                        132     2     1     1     1;
%                        132     2     1     1     2;
%                        132     2     1     2     1;
%                        132     2     1     2     2;
%                        402     1     1     2     1;
%                        402     1     1     2     2]
%
% Version 1.4
% Boris Guirao

%% Code %%

cellListSize = size(cellANs);
nCells = cellListSize(1);   % number of cells listed in cell i
nCol = cellListSize(2);     % length of their numbering

cellANsOffspring = double.empty(0,nCol); % initialized as empty array with RIGHT amount of columns (1.4)

% checks there is at least one cell in the list before proceeding (mod 1.4)
if nCells == 0
    return
end

% cellANsOffspring = [];

for i = 1:nCells
    
    %%% this cell cell i:
    iAN = cellANs(i,:);
    
    %%% building cell i POSSIBLE OFFSPRING:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    nZeros = length(find(iAN == 0)); % Ex: n_zeros = 2;
    iANoffspring = [];
    previousRoundDaughters = iAN;
    
    while nZeros > 0
        thisRoundDaughters = [];
        for n = 1:size(previousRoundDaughters,1)
            thisCellDaughterOne = previousRoundDaughters(n,:);
            thisCellDaughterTwo = previousRoundDaughters(n,:);
            thisCellDaughterOne(nCol-nZeros+1) = 1;
            thisCellDaughterTwo(nCol-nZeros+1) = 2;
            thisRoundDaughters = [thisRoundDaughters ; thisCellDaughterOne ; thisCellDaughterTwo]; %#ok<*AGROW>
        end
        
        iANoffspring = [iANoffspring ; thisRoundDaughters];
        previousRoundDaughters = thisRoundDaughters;
        nZeros = length(find(thisCellDaughterTwo == 0)); % checks on last cell how many 0s remain
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%% Adding cell i ancestor and offspring to the list:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    cellANsOffspring = [cellANsOffspring ; iANoffspring];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end



%% History

% 09/01/2018: 1.4
% - initializes "cellANsOffspring" as empty array with RIGHT amount of
% columns (otherwise empty output "[]" will cause bugs in "ismember")

% 30/06/2015: 1.3 became "OffspringMaker" then "MakeOffspring"
% - removed warning "Offspring_Maker warning: empty list of cells!"

% 24/04/2012: 1.2
% - replaced warndlg by simple display in workspace

% 09/02/2011: creation from "Lineage_Generator"


