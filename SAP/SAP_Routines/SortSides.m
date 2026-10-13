function sideCATEGORIES = SortSides(sideNumbers, sideCellCouples, cellCategoryTags)
%
% sideCATEGORIES = SortSides(sideNumbers, sideCellCouples, categoryTags)
%
% Categories (Partition of "allSides"):
% - coreSides               (CS, type = 0)
% - coreFLSides            (CFLS, type = 0.5)
% - FLSides                 (FLS, type = 1)
% - borderFLSides          (BFLS, type = 1.5)
% - borderSides             (BS, type = 2)
%
% Alternate partitions:
% - nonBorderSides         (NBS)    % allCoreSides U FLSides
% Combined categories:
% - allSides                (AS)
% - allCoreSides           (ACS)
% - allFLSides             (AFLS)   
% - allBorderSides         (ABS)
% - allNonBorderSides     (ANBS)   % All sides of Non-Border cells
%
%
% INPUTS:
% - sideNumbers = nSides x 1 vector of side numbers
% - sideCellCouples = nSides x 2 matrix with cells sharing each border
% - cellCategoryTags = vector containing tags for coreRNs, FLRNs, borderRNs...
%
% OUTPUTS:
% - sideCATEGORIES = structure containing lists making up each categories
%
% Version 1.5
% Boris Guirao

%% Extracting cell categories %%

% Get cell numbers making up each population:
[coreRNs, FLRNs, borderRNs] = GetCellCategories(cellCategoryTags); % Extracting cell categories from "CategoryTags" (1.5)
% coreRNs = cellCATEGORIES.coreRNs;
% FLRNs = cellCATEGORIES.FLRNs;
% borderRNs = cellCATEGORIES.borderRNs;

%% Building side categories %%

%%% All sides (1.3):
allSides = sideNumbers;     % Rename sideNumbers to allSides. NB: in C++SIA, side numbers are NOT side rows

%%% Core and Core_FL sides:
Core_and_Core_FL_side_tf = ismember(sideCellCouples, coreRNs);         	% side_cells with 1s where Core cells are found, 0s elsewhere
sum_Core_and_Core_FL_side_tf = sum(Core_and_Core_FL_side_tf, 2);      	% sum along columns                  
coreSides = sideNumbers(sum_Core_and_Core_FL_side_tf == 2);             % both cells are Core cells
coreFLSides = sideNumbers(sum_Core_and_Core_FL_side_tf == 1);           % one cell is FL

%%% FL sides:
FLSideTF = ismember(sideCellCouples, FLRNs);                            % side_cells with 1s where FL cells are found, 0s elsewhere
sumFLSideTF = sum(FLSideTF, 2);                                     	% sum along columns
FLSides = sideNumbers(sumFLSideTF == 2);                                % both cells are FL cells

%%% Border and Border_FL sides:
Border_and_Border_FL_side_tf = ismember(sideCellCouples, borderRNs);        % side_cells with 1s where Border cells are found, 0s elsewhere
sum_Border_and_Border_FL_side_tf = sum(Border_and_Border_FL_side_tf, 2);    % sum along columns
borderSides = sideNumbers(sum_Border_and_Border_FL_side_tf == 2);           % both cells are Border cells
borderFLSides = sideNumbers(sum_Border_and_Border_FL_side_tf == 1);         % one cell is FL


%% Building additional side subsets (1.1) %%

allCoreSides = sort([coreSides ; coreFLSides]);                             % ACS: ALL SIDES OF CORE CELLS
allFLSides = sort([coreFLSides ; FLSides ; borderFLSides]);               % AFLS: ALL SIDES OF FL CELLS. NB: "Border_FL_sides" NOT ALWAYS RELIABLE (some border sides not drawn)
allBorderSides = sort([borderSides ; borderFLSides]);                       % ABS: All SIDES OF Border CELLS (1.2)

nonBorderSides = sort([allCoreSides ; FLSides]);                            % NBS: ALL RELIABLE SIDES (All sides that do not involve a border cell)
% NB: Border_sides U Border_FL_sides U Non_Border_sides = All_sides
allNonBorderSides = sort([nonBorderSides ; borderFLSides]);               % ANBS: ALL BUT BORDER SIDES (1.3)

%% Filling structure "side_CATEGORIES":

% Basic categories:
sideCATEGORIES.coreSides = coreSides;
sideCATEGORIES.coreFLSides = coreFLSides;
sideCATEGORIES.FLSides = FLSides;
sideCATEGORIES.borderFLSides = borderFLSides;
sideCATEGORIES.borderSides = borderSides;

% Alternate partition (1.3):
sideCATEGORIES.nonBorderSides = nonBorderSides;

% Combined categories (1.1):
sideCATEGORIES.allSides = allSides;                                     % 1.3
sideCATEGORIES.allCoreSides = allCoreSides;
sideCATEGORIES.allFLSides = allFLSides;
sideCATEGORIES.allBorderSides = allBorderSides;
sideCATEGORIES.allNonBorderSides = allNonBorderSides;               % 1.3


%% History %%

% 04/05/2018: 1.5
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"

% 18/01/2018: 1.4
% - removed "sideTypes" as output
% - loading coreRNs, FLRNs, borderRNs now
% - changed all side category names

% 06/08/2010: 1.3
% - added "All_sides" (AS), "All_Non_Border_sides" (ANBS)

% 05/08/2010: 1.2
% - added "All_Border_sides" (ABS)

% 02-03/08/2010: 1.1
% - Now creates subsets "All_Core_sides", "Non_Border_sides",
% "All_FL_sides" combining the basic ones (CS, FL...) + sort them + saves
% them in SIDES.

%13/07/2010: creation
 

