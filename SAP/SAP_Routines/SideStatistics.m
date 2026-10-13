function sideSTATISTICS = SideStatistics(SIDES, signalName, cellCategoryTags)
%
% sideSTATISTICS = SideStatistics(SIDES, signalName, cellCategoryTags)
%
% Returns the STRUCTURE "sideSTATISTICS" that contains statistics
% calculated over different group of side categories (Core sides, Core-FL
% sides...).
%
% Reminder:
% CS: coreSides
% CFLS: coreFLSides
% ACS: All_Core_sides (ALL SIDES OF CORE CELLS)
% FLS: FLSides
% BFLS: Border_FL_Sides
% AFLS: allFLSides
% BS = borderSides
% ABS = allBorderSides
% NBS: nonBorderSides (ALL RELIABLE SIDES: All sides that do not involve a border cell)
% ANBS: allNonBorderSides
%
% Version 1.11
% Boris Guirao


%% Extraction from SIDES and sideCATEGORIES %%

ExtractData(SIDES,'side','caller')                                          % Extracts all variables stored in "SIDES"
sideCATEGORIES = SortSides(sideNumbers, sideCells, cellCategoryTags); % 1.11
ExtractData(sideCATEGORIES,'','caller')                                     % Extracts all side categories. 
% NB: 'caller' to make extracted variables available in the FUNCTION workspace

nRawImages = size(signalName,1); % 1.7


%% Finding rows in "allSides" corresponding to side numbers (1.11) %%

% NB: required because in C++SIA, side numbers no longer correspond to side rows!!

[~,coreSideRows] = ismember(coreSides,sideNumbers);
[~,coreFLSideRows] = ismember(coreFLSides,sideNumbers);
[~,FLSideRows] = ismember(FLSides,sideNumbers);
[~,borderFLSideRows] = ismember(borderFLSides,sideNumbers);
[~,borderSideRows] = ismember(borderSides,sideNumbers);

[~,nonBorderSideRows] = ismember(nonBorderSides,sideNumbers);

[~,allCoreSideRows] = ismember(allCoreSides,sideNumbers);
[~,allFLSideRows] = ismember(allFLSides,sideNumbers);
[~,allBorderSideRows] = ismember(allBorderSides,sideNumbers);
[~,allNonBorderSideRows] = ismember(allNonBorderSides,sideNumbers);


%% Computation of statistics over sides (mod 1.8) %%

%%% Chord Lengths:
% NB: quantity not depending on neighbors (only on side contour) => can keep FL sides
Qname = 'sideChordLengths';
QallValues = sideChordLengths;
% Core sides (CS):
Q_values_CS = QallValues(coreSideRows,:);                                                             
sideSTATISTICS = BasicStatistics(Q_values_CS, Qname, 'CS');                              % ����� "side_STATISTICS" IS CREATED HERE ����� (mod 1.8)             
% Core-FLSides (CFLS):
Q_values_CFLS = QallValues(coreFLSideRows,:);                                                        
sideSTATISTICS = BasicStatistics(Q_values_CFLS, Qname, 'CFLS', sideSTATISTICS);          % ����� "side_STATISTICS" IS BEING COMPLETED HERE ONWARDS �����         
% All Core sides (ACS):
Q_values_ACS = QallValues(allCoreSideRows,:);                                                        
sideSTATISTICS = BasicStatistics(Q_values_ACS, Qname, 'ACS', sideSTATISTICS);
% FLSides (FLS):
Q_values_FLS = QallValues(FLSideRows,:);                                                               % 1.6
sideSTATISTICS = BasicStatistics(Q_values_FLS, Qname, 'FLS', sideSTATISTICS);
% borderFLSides (BFLS):
Q_values_BFLS = QallValues(borderFLSideRows,:);                                                       % 1.6
sideSTATISTICS = BasicStatistics(Q_values_BFLS, Qname, 'BFLS', sideSTATISTICS);
% All FLSides (AFLS):
Q_values_AFLS = QallValues(allFLSideRows,:);                                                          % 1.6
sideSTATISTICS = BasicStatistics(Q_values_AFLS, Qname, 'AFLS', sideSTATISTICS);
% borderSides (BS):
Q_values_BS = QallValues(borderSideRows,:);                                                            % 1.6
sideSTATISTICS = BasicStatistics(Q_values_BS, Qname, 'BS', sideSTATISTICS);
% allBorderSides (ABS):
Q_values_ABS = QallValues(allBorderSideRows,:);                                                       % 1.6
sideSTATISTICS = BasicStatistics(Q_values_ABS, Qname, 'ABS', sideSTATISTICS);
% Non Border sides (NBS):
Q_values_NBS = QallValues(nonBorderSideRows,:);                                                       % 1.3
sideSTATISTICS = BasicStatistics(Q_values_NBS, Qname, 'NBS', sideSTATISTICS); 
% allNonBorderSides (ANBS):
Q_values_ANBS = QallValues(allNonBorderSideRows,:);                                                  % 1.6
sideSTATISTICS = BasicStatistics(Q_values_ANBS, Qname, 'ANBS', sideSTATISTICS);


%%% Intensity:
% NB: quantity not depending on neighbors (only on side contour) => can keep FL sides
Qname = 'sideIntensities';
for r = 1:nRawImages
    rthQname = [Qname signalName{r}];           % (1.5)
    QallValues = eval(rthQname);    % gives "QallValues" value of variable "rthQname" (1.5, 1.10)
    % Core sides (CS):
    Q_values_CS = QallValues(coreSideRows,:);
    sideSTATISTICS = BasicStatistics(Q_values_CS, rthQname, 'CS', sideSTATISTICS);
    % Core-FLSides (CFLS):
    Q_values_CFLS = QallValues(coreFLSideRows,:);
    sideSTATISTICS = BasicStatistics(Q_values_CFLS, rthQname, 'CFLS', sideSTATISTICS);
    % All Core sides (ACS):
    Q_values_ACS = QallValues(allCoreSideRows,:);
    sideSTATISTICS = BasicStatistics(Q_values_ACS, rthQname, 'ACS', sideSTATISTICS);
    % FLSides (FLS):
    Q_values_FLS = QallValues(FLSideRows,:);                                                               % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_FLS, rthQname, 'FLS', sideSTATISTICS);
    % borderFLSides (BFLS):
    Q_values_BFLS = QallValues(borderFLSideRows,:);                                                       % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_BFLS, rthQname, 'BFLS', sideSTATISTICS);
    % All FLSides (AFLS):
    Q_values_AFLS = QallValues(allFLSideRows,:);                                                          % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_AFLS, rthQname, 'AFLS', sideSTATISTICS);
    % borderSides (BS):
    Q_values_BS = QallValues(borderSideRows,:);                                                            % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_BS, rthQname, 'BS', sideSTATISTICS);
    % allBorderSides (ABS):
    Q_values_ABS = QallValues(allBorderSideRows,:);                                                       % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_ABS, rthQname, 'ABS', sideSTATISTICS);
    % Non Border sides (NBS):
    Q_values_NBS = QallValues(nonBorderSideRows,:);                                                       % 1.3
    sideSTATISTICS = BasicStatistics(Q_values_NBS, rthQname, 'NBS', sideSTATISTICS);
    % allNonBorderSides (ANBS):
    Q_values_ANBS = QallValues(allNonBorderSideRows,:);                                                  % 1.6
    sideSTATISTICS = BasicStatistics(Q_values_ANBS, rthQname, 'ANBS', sideSTATISTICS);
end



%% History %%

% 04/05/2018: 1.11
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"
% - added input "cellCategoryTags" accordingly
% - use of "SortSides" to determine "sideCATEGORIES"
% - now need to retrieve rows of coreRNs, FLRNs...

% 13/02/2018: 1.10
% - using "eval" rather than "evalin('caller',...)" because was crashing in
% SIAFUNC

% 18/01/2018: 1.9
% - removed "side_chord_angles"
% - calling coreSides, FLSides...
% - now "signalName" as argument instead of "frameRawMod"

% 05/07/2016: 1.8 (became SideStatistics)
% - removed Q_name = 'side_lengths'; case

% 11/08/2011: 1.7
% - adaptation to SIA 2.1e: choice of raw images on which polarity is calculated + naming
% - replaced all num2str(r) by Filename_Raw_mod{r}
% - removed while loop

% 05/12/2010: 1.6
% Added calculation over all side categories left apart so far:
% FLS: FLSides
% BFLS: Border_FL_Sides
% AFLS: allFLSides
% BS = borderSides
% ABS = allBorderSides
% ANBS: allNonBorderSides

% 29/11/2010: 1.5
% - changes to make it compatible with >1 raw images

% 30/09/2010: 1.4
% - circular statistics over chord angles are NOW WEIGHTED WITH INTENSITY VALUES

% 03/08/2010: 1.3
% - adaptation to BasicStatistics v1.3 and BasicCircularStatistics v1.2:
% now all Q values are cropped HERE to Q_values_CS, _CFLS...

% 02/08/2010: 1.2
% - changed ACFLS to NBS
% - do not build ACS, NBS, AFLS anymore: loaded from "side_CATEGORIES"
% - removed calculation over AFLS: can contain unreliable sides + not
% required by Pluc

% 17-19/07/2010: creation from "Cell_Statistics"


