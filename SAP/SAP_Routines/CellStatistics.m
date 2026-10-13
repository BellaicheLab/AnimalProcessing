function cellSTATISTICS = CellStatistics(CELLS, signalName)
%
% cellSTATISTICS = CellStatistics(CELLS, signalName)
%
% Returns the STRUCTURE "cellSTATISTICS" that contains statistics
% calculated over different group of cell categories (Core cells, FL cells,
% NB cells).
%
% Version 1.11
% Boris Guirao

%% Extraction from CELLS and cell_CATEGORIES %%

ExtractData(CELLS,'cell','caller')                                     % Extracts all variables stored in "CELLS"
[coreRNs, FLRNs, ~,nonBorderRNs] = GetCellCategories(cellCategoryTags);     % 1.11
% ExtractData(cellCATEGORIES,'','caller')                                % 'caller' to make extracted variables available in the FUNCTION workspace

nRawImages = size(signalName,1); % 1.7

%% Computation of statistics over cells %%


%%% Areas:
% NB: quantity not depending on neighbors (only on cell contour) => can keep FL cells
Qname = 'cellAreas';
QallValues = eval(Qname); % 1.9
% Core cells (CC):
Q_values_CC = QallValues(coreRNs,:);                                                            % 1.4
cellSTATISTICS = BasicStatistics(Q_values_CC, Qname, 'CC');                                       % ����� "cell_STATISTICS" IS CREATED HERE �����
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);                                                             % 1.4
cellSTATISTICS = BasicStatistics(Q_values_FLC, Qname, 'FLC', cellSTATISTICS);                    % ����� "cell_STATISTICS" IS BEING COMPLETED HERE AND ONWARDS �����
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);                                                     % 1.4
cellSTATISTICS = BasicStatistics(Q_values_NBC, Qname,  'NBC', cellSTATISTICS);  

%%% Anisotropies:
% NB: quantity not depending on neighbors (only on cell contour) => can keep FL cells
Qname = 'cellAnisotropies';
QallValues = eval(Qname); % 1.9
% Core cells (CC):
Q_values_CC = QallValues(coreRNs,:);                                                            
cellSTATISTICS = BasicStatistics(Q_values_CC, Qname, 'CC', cellSTATISTICS);                      
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);                                                             
cellSTATISTICS = BasicStatistics(Q_values_FLC, Qname, 'FLC', cellSTATISTICS);                   
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);                                                     
cellSTATISTICS = BasicStatistics(Q_values_NBC, Qname,  'NBC', cellSTATISTICS);  


%%% Neighbors:
% NB: quantity depending on neighbors => only computation over coreRNs is relevant on full image
Qname = 'cellnNeighbors';
QallValues = eval(Qname); % 1.9
% Core cells (CC):
Q_values_CC = QallValues(coreRNs,:);                                                            
cellSTATISTICS = BasicStatistics(Q_values_CC, Qname, 'CC', cellSTATISTICS);                      
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);                                                             
cellSTATISTICS = BasicStatistics(Q_values_FLC, Qname, 'FLC', cellSTATISTICS);                   
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);                                                     
cellSTATISTICS = BasicStatistics(Q_values_NBC, Qname,  'NBC', cellSTATISTICS);   


%%% Chord Disorders (1.3):
% NB: quantity depending on neighbors => only computation over coreRNs is relevant on full image
Qname = 'cellChordDisorders';
QallValues = eval(Qname); % 1.9
% Core cells (CC):
Q_values_CC = QallValues(coreRNs,:);                                                            
cellSTATISTICS = BasicStatistics(Q_values_CC, Qname, 'CC', cellSTATISTICS);                      
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);                                                             
cellSTATISTICS = BasicStatistics(Q_values_FLC, Qname, 'FLC', cellSTATISTICS);                   
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);                                                     
cellSTATISTICS = BasicStatistics(Q_values_NBC, Qname,  'NBC', cellSTATISTICS);  

%%% Orientations:
% NB: quantity not depending on neighbors (only on cell contour) => can keep FL cells
Qname = 'cellOrientations';
QallValues = eval(Qname); % 1.9
% Core Cells (CC):
Q_values_CC = QallValues(coreRNs,:);
cell_anisotropies_CC = cellAnisotropies(coreRNs,:);  %#ok<IDISVAR,NODEF>
cellSTATISTICS = BasicCircularStatistics(Q_values_CC, cell_anisotropies_CC, Qname, 'CC', cellSTATISTICS);        % MEAN WEIGHTED WITH ANISOTROPIES
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);
cell_anisotropies_FLC = cellAnisotropies(FLRNs,:);
cellSTATISTICS = BasicCircularStatistics(Q_values_FLC, cell_anisotropies_FLC, Qname, 'FLC', cellSTATISTICS); 
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);
cell_anisotropies_NBC = cellAnisotropies(nonBorderRNs,:);
cellSTATISTICS = BasicCircularStatistics(Q_values_NBC, cell_anisotropies_NBC, Qname, 'NBC', cellSTATISTICS); 


%%% Textures (1.3):
% NB: quantity depending on neighbors (only on cell contour) => can keep FL cells
Qname = 'cellMs';
QallValues = eval(Qname); % 1.9
% Core cells (CC):
Q_values_CC = QallValues(coreRNs,:);                                                            
cellSTATISTICS = BasicStatistics(Q_values_CC, Qname, 'CC', cellSTATISTICS);                      
% First layer cells (FLC):
Q_values_FLC = QallValues(FLRNs,:);                                                             
cellSTATISTICS = BasicStatistics(Q_values_FLC, Qname, 'FLC', cellSTATISTICS);                   
% Non Border Cells (NBC):
Q_values_NBC = QallValues(nonBorderRNs,:);                                                     
cellSTATISTICS = BasicStatistics(Q_values_NBC, Qname,  'NBC', cellSTATISTICS);  


%%% Side intensity disorders (1.6):
% NB: quantity depending on neighbors => only computation over coreRNs is relevant on full image
Qname = 'cellSideIntensityDisorders';
for r = 1:nRawImages
    % Quantities specific to this raw image r:
    rthQname = [Qname signalName{r}];                                     
    rthQallValues = eval([Qname signalName{r}]);               % gets side intenisities for raw image r
    % Core cells (CC):
    this_Q_values_CC = rthQallValues(coreRNs,:);
    cellSTATISTICS = BasicStatistics(this_Q_values_CC, rthQname, 'CC', cellSTATISTICS);
    % First layer cells (FLC):
    this_Q_values_FLC = rthQallValues(FLRNs,:);
    cellSTATISTICS = BasicStatistics(this_Q_values_FLC, rthQname, 'FLC', cellSTATISTICS);
    % Non Border Cells (NBC):
    this_Q_values_NBC = rthQallValues(nonBorderRNs,:);
    cellSTATISTICS = BasicStatistics(this_Q_values_NBC, rthQname,  'NBC', cellSTATISTICS);
end


%% History %%

% 04/05/2018: 1.11
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"

% 13/02/2018: 1.10
% - using "eval" rather than "evalin('caller',...)" because was crashing in
% SIAFUNC

% 18/01/2018: 1.9
% - removed "cell_rsp_chords"
% - calling coreRNs, FLRNs...
% - now "signalName" as argument instead of "frameRawMod"

% 05/07/2016: 1.8 (became CellStatistics)
% removed:
% Q_name = 'cell_contour_lengths';
% Q_name = 'cell_rsp_sides';
% Q_name = 'cell_roundnesses'; 

% 11/08/2011: 1.7
% - adaptation to SIA 2.1e: choice of raw images on which polarity is calculated + naming
% - replaced all num2str(r) by Filename_Raw_mod{r}
% - removed while loop

% 26/01/2011: 1.6
% - included statistics over "cell_side_intenisty_disorders" for each raw image

% 05/08/2010: 1.5
% - added cell_roundnesses

% 03/08/2010: 1.4
% - adaptation to BasicStatistics v1.3 and BasicCircularStatistics v1.2:
% now all Q values are cropped HERE to Q_values_CC, _FLC...

% 25/07/2010: 1.3
% - added computation over Contour Lengths, Chord Disorders, RSP chords,
% Texture

% 17/07/2010: creation & 1.1 & 1.2
% - systematically computes statistics over Core cells, First layer cells
% and Non Border cells (1.1).
% - extensive use of functions "BasicStatistics" and
% "BasicCircularStatistics" to carry out computation and saving within
% structure "cell_STATISTICS".


