% TensorAnalysis (TA)

%% Comments %%
%
% This program aims at building structures CELLS_TA and LINKS that will contain the calculation of all tensors on a
% single cell basis, between the current and the previous frame ("old" tag in program). Each link has 2 half
% contributions: one for each cell to which it belongs.
%
% NB0: full image processing is ALWAYS done taking into account Core-FL links. Those links can be removed from
% calculation during grid processing by setting keepCoreFLHLs = false. If they are kept during grid processing, grid
% subfolder will contain "allHLs" in its name, and nothing when not kept.
%
% NB1: TENSOR MAIN CONTRIBUTIONS ARE DEFINED IN "CalculateTensors" AND STORED IN "TENSORS" (do field(TENSORS)).
%
% NB2:
% "TensorAnalysis" calls   "MakeHLCplotstyle" that generates "HLCplotstyle" that lists ALL contributions (J+,...) and colors/linestyles
%                          "CalculateTensors"  that generates "TENSORS" and "ERROR"
%                          "DisplayHLCs"          
%
% NB3:
% "HLCplotstyle" must match:   * the part of this program that assigns a contribution to each couple "ijs" and "iokos"
%                              * the part of "CalculateTensors" that merges ALL contributions into MAIN contributions
%
% NOTATIONS:
% ----------------------------------------------------------------------------------------------------------------------
% HL = Half Link
% HLC = Half Link Category ('B', 'Dd', 'A',...)
% RN = Relative Number
% ANVS = Absolute Number Vector Style
% ios = ALL RNs of PREVIOUS frame containing ALL ANVS contained in region i in CURRENT frame (built with "iioMatcher")
% js = set of ACTUAL i neighbors in current frame
% jos = set of ios neighbors INFERRED from js in previous frame (contains mothers)
% kos = set of ACTUAL ios neighbors in previous frame
% ks = set of i neighbors INFERRED from kolds in previous frame (contains daughters)
% gs = gained neighbors in CURRENT frame = {js} \ {ks}
% los = lost neigbhors in OLD frame =  {kos} \ {jos}
% cs = conserved neighbors in CURRENT frame = intersect({js},{ks})
%      NB: contains daughter RN neighboring i if mother RN was neighboring ios
% cos = conserved neighbors in OLD frame = intersect({jos},{kos})  (contains mothers if )
%       NB: contains mother RN neighboring ios if 1+ daughter is neighboring i.
% jCs = list of CURRENT cell RNs "js" found to be coalesced in CURRENT (js) OR PREVIOUS frame (jos)
% koCs = list of OLD cell RNS "kos" found to be coalesced in CURRENT (ks) OR PREVIOUS frame (kos)
% Hgs = Half GAINED neighbors. Conserved neighbors (among "cs") whose wheights go 1/2 -> 1
% Hgos = Half GAINED neighbors. Conserved neighbors (among "cos") whose wheights go 1/2 -> 1
% Hls = Half LOST neighbors. Conserved neighbors (among "cs") whose wheights go 1 -> 1/2
% Hlos = Half LOST neighbors. Conserved neighbors (among "cos") whose wheights go 1 -> 1/2
% Ngs = NEW gained neighbors. Neighbors GAINED because they are NEW ("gs" listed in "New_cells")
% Alos = APOPTOTIC lost neighbors. Neighbors LOST because they are APOPTOTIC ("los" listed in "Apoptotic_cells_old")
% Extra_cells = non core regions of CURRENT frame to consider because 1+ region of "ios" is Core in OLD frame
% Aos = ALL RNs of APOPTOTIC cells that just delaminated in CURRENT frame
% GoneOut_RNs = cells gone out of frame between old and current (non-apoptotic cells that have disappeared)
% Kos = ALL neighbors of CORE Aos, then GoneOut_RNs  cells
% Ks = corresponding RN of Kos
% KoCs = cells found coalescenced in CURRENT (Ks) OR PREVIOUS frame (Kos)
%
% GRID RELATED:
% NB: CUMULATED QUANTITIES WILL BE RECALCULATED IN EACH GRID COMPARTMENT STARTING AT FRAME "startFrame" UP TO
% "finalFrame". FULL IMAGE BACKUPS ARE ONLY USED TO KNOW EACH HL CONTRIBUTION BETWEEN 2 FRAMES.
% ULCs: Upper Left Corners
%
% NB: gridType = 'L' or 'E' DIFFERENT FROM "GRID_TA" which is the structure storing tensors
% ----------------------------------------------------------------------------------------------------------------------
  version = '5.8';
% Boris Guirao


%% Defining "HLCplostyle", and initializing "old" quantities %%

keepCoreFLHLs = false;       % In GRID mode, will KEEP all Core-FL Half-Links (often leading to large F contribution @  boundaries) out from tensor calculation (4.4) 
% NB: before grid processing, Core-FL Half-Links are included in the analysis
% NB: as of 4.4+, ONLY links between GRID core RNs are kept, excluding the ones with other IMAGE core RNs (and
% accordingly excluding the macrochaetes)

versionName = version;
if displayHLC
    versionName = [ version ' - HLC PLOT MODE'];               % 4.1
end

% Assigning program name matching box option "TA_Box":
if isempty(gridType)                                                 % This program name. Used for saving files
    programName = 'TA';                                              % For titles
elseif strcmp(gridType,'E')
    programName = 'TA Eulerian Grid';
elseif strcmp(gridType,'L')
    programName = 'TA Lagrangian Grid';
end

% Display program info in workspace:
disp(' '); disp(' ');
disp([programName ' ' versionName  ': processing "' Animal '": initialization (' num2str(0) '/' num2str(nInterFrames) ')']);
disp('---------------------------------------------------------------------------------');
tic

% Display warning when nLayers = 0 (3.1)
if ~isempty(gridType) && nLayers == 0
    button = questdlg('Parameters "nLayers" is set to 0!','TA WARNING','Continue','Cancel','Continue');
    if strcmp(button,'Cancel')
        disp('Stopped execution.')
        return
    end
end

% Sets default values of "actual_Start/finalFrame" (1.1.5):
actualStartFrame = startFrame;
actualFinalFrame = finalFrame;
% NB: in replot mode, quantities are still cumulated from "actual_Start_frame" and not "startFrame".

% Creates empty arrays:
CorrespondenceOLD = [];                                       % initializing "Correspondence_old" for 1st iteration
all_HLCold = cell(1,1);                                       % USELESS: HERE TO PREVENT MATLAB WRONG WARNING
all_Miokos = [];
all_Wiokos = [];

% Defines list of ALL POSSIBLE HL categories (2.0.7) 
HLCplotstyle = MakeHLCplotstyle(HLstyles);        % always includes Jb+/- only relevant for grid             

% Defines list of MAIN contributions (2.0.2)
TENSORS = CalculateTensors([], [], HLCplotstyle, dtH, renormM);  	% 2.0.5, 2.0.9, 2.2.0, 2.3.1, 3.0
MCatList = fields(TENSORS);                                         % list of main tensors: {'EG', 'ES'..., 'EJb'}.
nMcat = length(MCatList);


%% Loading CTD all-time backups (4.3)    

% Loading "allDelaminatingCells.mat" and "allDividingCells.mat"
load([pathFolderCTD filesep 'allDelaminatingCells.mat'],'allLastFramesDel','allDelaminatingLastRNs');
load([pathFolderCTD filesep 'allDividingCells.mat'],'allLastFramesDiv','allSisterFirstRNs','allDividingLastRNs');
[allMacroRNs, allMacroANs] = LoadMacroBackup(pathFolderCTD);


%% Loading grid from CPT backups (4.0) %%

%%% Defining folders:
saveFolder = pathFolderTA; % main folder
if ~isempty(gridType)
    
    saveFolder = [saveFolder filesep gridSpecs]; % defines grid subfolder
    
    % Loading grid (moved into if 4.1)
    GRID_DEF = load(pathGridDefFile);
    nx = GRID_DEF.Size(2);
    ny = GRID_DEF.Size(1);
    nBoxes = nx*ny;
    
    gridTENSORS = cell(ny,nx);
end

backupFolder = [saveFolder filesep 'Backups']; % backups
linkFolder = [saveFolder filesep 'CellLinks']; % cell link images (4.1)
% figureFolder = [saveFolder filesep 'Figures']; % images


%% Saving parameter txt file & initializing progress bar %%

if ~displayHLC 
    
    thisFilename = [filenameTA '_' num2str(finalFrame, digitsFormat) '.mat'];
    lastTAbackup = [backupFolder filesep thisFilename];
    if exist(lastTAbackup,'file')
        fprintf(['\n' programName ' WARNING: LAST backup already exists. Skipping TA execution...\n']);
        return
    end
    % Only starts progressbar if actually running TA:
    if ~isempty(gridType)
        progressbar(['TA iteration over ' Animal ' frames...'], 'TA iteration over grid compartments...') % 2.3.5
    else
        progressbar(['TA iteration over ' Animal ' frames...'], ['TA iteration over ' Animal ' cells...'])
    end
else
    progressbar(['TA iteration over ' Animal ' frames...'])
end

% Saving txt file indicating date and version used in "saveFolder" (2.0.16, moved 2.2.1)
today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style. Look up date for details
txtFilename = [today '_TA_' version '.txt'];

% Writing main parameters in txt file (3.1, extended 4.0)
parameterCell = {   'Main Parameters:',[];
                    [],[];
                    'PIVgrid = ', PIVgrid; % 4.0, removed "Used" (5.2)
                    'nLayers = ', nLayers;
                    'keepCoreFLHLs = ', keepCoreFLHLs;
                    'renormM = ', renormM;
                    [],[];
                    'Display Parameters:',[];
                    [],[];
                    'killMeanTraceTA = ', killMeanTraceTA;
                    'errorPsMin = ', errorPsMin;
                    'errorDnPsMin = ', errorDnPsMin;
                    'displayHLC =', displayHLC;
                    'display_naHL = ', display_naHL};
                
mkdir(saveFolder); % 4.0               
dlmcell([saveFolder filesep txtFilename], parameterCell,' ');


%% Filling "SAVE" structure %%

if displayHLC % 4.3
    
    %%% From AIA:
    SAVE.Animal = Animal;
    SAVE.startFrame = startFrame;
    SAVE.finalFrame = finalFrame;
    SAVE.scale1D = scale1D;
    SAVE.frameRef = frameRef;
    SAVE.timeRef = timeRef;
    SAVE.dt = dt;
    SAVE.HLstyles = HLstyles;
    SAVE.yMid = yMid;
    SAVE.nInterFrames = nInterFrames;
    SAVE.displayHLC = displayHLC;
    SAVE.gridType = gridType; % 4.3
    SAVE.display = plotTensorsTA;
    SAVE.gridDisplay = gridDisplay;
    SAVE.xyOffset = xyOffset;
    SAVE.minimalInfoDisplay = minimalInfoDisplay;
    SAVE.fontSizeInfo = fontSizeInfo;
    SAVE.colorInfo = colorInfo;
    SAVE.printResolution = printResolution;
    SAVE.scaleBarWidth = scaleBarWidth;
    SAVE.scaleBarLength = scaleBarLength;
    SAVE.imageSize = imageSize; % 4.3
    SAVE.colorMacrochaetes = colorMacrochaetes; % 4.3
    SAVE.colorFLCells = colorFLCells;           % 5.6
    SAVE.colorBorderCells = colorBorderCells;   % 5.6
    
    % Specific to TA:
    SAVE.scaleBarLengthTA = scaleBarLengthTA;
    SAVE.EVstyles = EVstyles;
    SAVE.linkWidth = linkWidth;
    SAVE.lineWidth = lineWidth;
    SAVE.signOpacities = signOpacities;
    SAVE.plotType = plotType;
    SAVE.imageFading = imageFading;
    SAVE.scaleRatio = scaleRatioTA;
    SAVE.killMeanTrace = killMeanTraceTA;
    
    %%% From here:
    SAVE.programName = programName;         % mod 4.0
    SAVE.saveFolder = saveFolder;           % mod 4.0
    SAVE.backupFolder = backupFolder;       % mod 4.0
    SAVE.figureFolder = linkFolder;         % mod 4.0
    SAVE.filename = filenameTA;
    SAVE.HLCplotstyle = HLCplotstyle;
    SAVE.display_naHL = display_naHL;
end

%% ITERATION OVER FRAMES %%

%%% Creating backup folder (4.0)
if ~exist(backupFolder,'dir')
    mkdir(backupFolder);
end

%%% Creating figure folder (4.0, 4.1)
if displayHLC && ~exist(linkFolder,'dir') 
    mkdir(linkFolder);
end

for n = startFrame:finalFrame
    
    %%% Display program info in workspace:
    if n > startFrame
        disp(' '); disp(' ');
        disp([programName ' ' versionName  ': processing "' Animal '": interframe ' num2str(n-1) '-' num2str(n) ' (' num2str(n-startFrame) '/' num2str(nInterFrames) ')']);
        disp('---------------------------------------------------------------------------------');
    end
    
    
    %%%% Loading macroRNs & CPT backup for this frame (4.0, 4.1, 4.3)
    %-------------------------------------------------------------------------------------------------------
    macroRNs = [];                  % default (4.3)
    if ~isempty(allMacroANs)
        macroRNs = allMacroRNs(:,n); % loads this frame RNs for macrochaetes (4.3)
    end
    
    if ~isempty(gridType)
        
        fprintf(['Loading CPT backup ' filenameCPT '_' num2str(n, digitsFormat) '.mat...'])
        fileCPT = [pathCPTbackupFiles '_' num2str(n, digitsFormat) '.mat'];
        buCPT = load(fileCPT);
        
        gridCoreRNs = buCPT.CoreRNs; % may contain some FL cells
        gridMaskTF = buCPT.MaskTF;
        gridContourIndices = buCPT.ContourIndices; % A
        gridnCoreRNs = buCPT.nCoreRNs;
        gridAreaRatios = buCPT.AreaRatios;
        gridCoreANs = buCPT.CoreANs;
        
        if strcmp(gridType,'L')
            gridLcentroids = buCPT.Lcentroids;
        end
        
        % gathering all coreRNs together (4.4, 5.8)
        gridCoreRNsEmptyTF = cellfun(@isempty, gridCoreRNs);
        gridCoreRNsCrop = gridCoreRNs(~gridCoreRNsEmptyTF);
        allGridCoreRNs = cell2mat(gridCoreRNsCrop(:)); % 3.32
        % NB: this crop before using "cell2mat" is because one gets a
        % weird bug when concatenating EMPTY compartmeent of different
        % sizes!! (1x0 vs 0x0!!)
        
%         allGridCoreRNs = unique(cell2mat(gridCoreRNs(:))); % gathering all coreRNs together (4.4)

        % NB: "macroRNs" have already been excluded from "gridCoreRNs" in CPT
        
        fprintf('Done.\n')
    end
    %-------------------------------------------------------------------------------------------------------
  
    %%% Defining "nthBackupFile" (5.1)
    nthBackupFilename = [filenameTA '_' num2str(n,digitsFormat) '.mat'];
    nthBackupFile = [backupFolder filesep nthBackupFilename];
    nextBackupFile = [backupFolder filesep filenameTA '_' num2str(n+1,digitsFormat) '.mat'];
    
    
    if ~displayHLC && ~exist(nthBackupFile,'file') % checking existence of nth backup (5.1)
        %% NON-REPLOT MODE: COMMON parts (full image AND grid processing) %%    
        
        fprintf('Loading segmented image, SIA, CTD, tracking txt backups...');
        
        %%% Loading image, SIA for CURRENT frame (mod 4.1, 5.0):
        %---------------------------------------------------------------------------------------------------------------
        % segmented image:
%         segImage = imread([pathFolder filesep filename num2str(n, digitsFormat) '.' imageFormat]);      % loads CURRENT segmented image
        
        % SIA backups:
        backupSIA = load([pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat),'.mat']); % mod 4.0
        % Extraction of required quantities from CELLS:
        CELLS = backupSIA.CELLS;
        cellRNs = CELLS.Numbers;
        cellAreas = CELLS.Areas;  
        nCells = length(cellRNs);
        cellNeighbors = CELLS.Neighbors;
        cellXYs = CELLS.XYs;
        cellContourIndices = CELLS.ContourIndices;
        cellCategoryTags = CELLS.CategoryTags;                              % 5.5
        [coreRNs, FLRNs, borderRNs] = GetCellCategories(cellCategoryTags);  % 5.5
        nonCoreRNs = sort([FLRNs ; borderRNs]);
        extFLRNs = FLRNs;                           % default value, actually extended in grid mode (5.0)
        
        % Extraction of required quantities from SIDES:
        SIDES = backupSIA.SIDES;
        sideChordLengths = SIDES.ChordLengths;
        sideCells = SIDES.Cells;
        if isfield(SIDES,'Parts')     % (5.4) stephane: Manage if SIA generate by matlab or c++
            sideParts = SIDES.Parts;  % Matlab SIA provide junctions parts while C++ SIA doesnt.
        else
            sideParts = ones(length(sideChordLengths),1);
        end
        nSides = length(SIDES.Numbers); % 5.2
        %---------------------------------------------------------------------------------------------------------------
        
        
        %%%% Loading this frame quantities from CTD backups (4.1, 4.3)
        %---------------------------------------------------------------------------------------------------------------       
        % Loading RNs that will DELAMINATE between n & n+1 from CTD backups (4.1)
        delaminatingRNsTF = allLastFramesDel == n;
        delaminatingRNs = allDelaminatingLastRNs(delaminatingRNsTF);
        
        % Loading couples of sister RNs that JUST appeared: finds rows (in allDividingANs,...) of cells that had n-1 as their last existence frame
        thisFrameDividedRowsTF = ismember(allLastFramesDiv, n-1); 
        % NB: a mother cells that still existed in frame n-1 AND stopped existing in frame n gives two daughters in frame n
        
        daughterRNsMat = allSisterFirstRNs(thisFrameDividedRowsTF,:);   % RELIABLE couples of sister RNs (sister 1 first)
        daughterRNs = sort(daughterRNsMat(:));                          % 1-column list of all daughters in ascending order 
        
        % Loading RNs that will DIVIDE between n & n+1 from CTD backups (4.1)
        thisFrameDividingRowsTF = ismember(allLastFramesDiv, n); 
        dividingRNs = allDividingLastRNs(thisFrameDividingRowsTF);
        %---------------------------------------------------------------------------------------------------------------
        
        
        %%% Loading txt files from C++ tracking:
        %---------------------------------------------------------------------------------------------------------------
        % Expanding nb Correspondence columns according to "max_n_divisions_nStart-nEnd.txt":
        CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
        Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); % using "FormatCorrespondence", (4.0)
        clear CorrespondenceRaw;
        % NB: all "Correspondence" arrays should therefore have the same number of columns
        
        coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
        coalescedRNs = coalescedRNs(coalescedRNs > 0);                                                  % removes -1 stored when empty txt file
        
        newRNs = dlmread([trackingFolder filesep 'new_cells_RN_' num2str(n) '.txt']);
        newRNs = newRNs(newRNs > 0);
        %---------------------------------------------------------------------------------------------------------------

        fprintf('Done.\n');
        
        
        
        %% NON-REPLOT MODE: SPECIFIC Parts (full image vs. grid processing)%%
                
        if isempty(gridType)
            
            %% CASE 1: FULL IMAGE PROCESSING (no grid, gridType = '') %%
            
            %%% Initialize quantities to be stored in LINKS for CURRENT frame (defining larger arrays):
            %-------------------------------------------------------------------------------------------------------------------
            nExtraCellsMax = nCells - length(coreRNs); % maximal number of extra cells to consider
            % CELLS_TA:
            extraCells = NaN(nExtraCellsMax,1);
            cell_ijLoc = cell(nCells,1);
            cell_iokoLoc = cell(nCells,1);
            
            % LINKS:
            nHL = 2*nSides;              % number of Half-Links is EXACTLY twice the number of sides (or links) (5.2)
            all_HLC = cell(nHL,1);       % WILL NOT BE PASSED ON TO NEXT ITERATION
            % OLD:
%             nHL = ceil(length(nonBorderRNs)*12.2);   % overestimate number of HL : N_cells x 2 x 6.1
%             all_ijMatch = NaN(nHL,2);
%             all_Wijs = NaN(nHL,1);
%             all_Lijs = NaN(nHL,2);
%             all_LijPlots = NaN(nHL,4);            
            %-------------------------------------------------------------------------------------------------------------------
            
            
            %%% Determination of cell couples sharing a single-part side of 0 length (4-vertex) in CURRENT frame:
            %-------------------------------------------------------------------------------------------------------------------
            zeroLengthSides = find(sideChordLengths == 0);                      % finding sides with zero chord length
            singlePartSides = find(sideParts == 1);                             % finding sides made up by one single part
            selectedZeroSides = intersect(zeroLengthSides,singlePartSides);     % only keeping 0 length sides with one single part
            V4CellCouples = sideCells(selectedZeroSides,:);                     % retrieving cell couples for these sides
            %-------------------------------------------------------------------------------------------------------------------
                
            %%% Direct determination of "all_ijMatch", "all_Wijs", "all_Lijs", "all_LijPlots" (5.2)
            %-------------------------------------------------------------------------------------------------------------------
            % "all_ijMatch"
            all_ijMatch = sortrows([sideCells ; fliplr(sideCells)],[1 2]); % sorting according to 1st column, then 2nd to break ties
            
            % "all_Lijs"
            all_iRNs = all_ijMatch(:,1);
            all_jRNs = all_ijMatch(:,2);
            all_iXYs = cellXYs(all_iRNs,:);
            all_jXYs = cellXYs(all_jRNs,:);
            all_Lijs = all_jXYs - all_iXYs;                                                         % [Xj1-Xi Yj1-Yi; Xj2-Xi Yj2-Yi;... ]
            
            % "all_LijPlots"
            all_LijMiddles = (all_jXYs + all_iXYs)/2;                                               % [XM1 YM1; XM2 YM2;... ]
            all_LijPlots = [all_iXYs(:,1) all_LijMiddles(:,1) all_iXYs(:,2) all_LijMiddles(:,2)];   % [Xi XM1 Yi YM1 ; Xi XM2 Yi YM2 ;... ]
            
            % "all_Wijs"
            all_Wijs = ones(nHL,1);                                             % default
            V4CellCouplesFull = [V4CellCouples; fliplr(V4CellCouples)];         % adding ji versions of ij couples
            Wijs2changeTF = ismember(all_ijMatch, V4CellCouplesFull,'rows');    % finding ij couples involved in a 4-vertex
            all_Wijs(Wijs2changeTF) = 1/2;                                      % replace weights 1 by 1/2 at those locations
            %-------------------------------------------------------------------------------------------------------------------
                 
            
            %%% Iteration over ALL regions i of CURRENT frame (LIMITING STEP)
            %-------------------------------------------------------------------------------------------------------------------
%             startRow = 1;
            nExtraCells = 0;
            tic
            fprintf('Iterating over all regions of CURRENT frame...'); %2.3.5
            for i = 1:nCells
                
                %%%% Determining ith cell "ijLoc", "ijMatch", "Wijs", and set "js" for CURRENT frame (5.2):
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                ijLoc = find(ismember(all_iRNs,i));
                js = all_jRNs(ijLoc);
                njs = length(js);
                ijMatch = all_ijMatch(ijLoc,:);
                Wijs = all_Wijs(ijLoc);
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

                
                %%%% Determining "ijMatch", "Lijs", "LijPlots", "Wijs", and set "js" for CURRENT frame (REMOVE FROM LOOP??):
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%                 % Gathering required info on i, determining "js":
%                 js = (cellNeighbors{i})';                                   % Build column vector of i neighbors: "js"
%                 iXY = cellXYs(i,:);
%                 njs = length(js);
%                 jXYs = cellXYs(js,:);
%                 iVect = repmat(i,njs,1);
%                 iXYmat = repmat(iXY,njs,1);                                 % Build matrix of i centroids: [Xi Yi ; Xi Yi ;... ]
%                 endRow = startRow + njs - 1;                                % updating endRow
%                 ijLoc = (startRow:endRow)';                                 % indices of ij lines in "all_ijMatch"
%                 
%                 % Building "ijMatch", "Lijs", "LijPlots" (formatted to be cropped according to HLC and plotted with "line"):
%                 ijMatch = [iVect js];
%                 Lijs = jXYs - iXYmat;                                                  % [Xj1-Xi Yj1-Yi; Xj2-Xi Yj2-Yi;... ]
%                 LijMiddles = (jXYs + iXYmat)/2;                                        % [XM1 YM1; XM2 YM2;... ]
%                 LijPlots = [iXYmat(:,1) LijMiddles(:,1) iXYmat(:,2) LijMiddles(:,2)];  % [Xi XM1 Yi YM1 ; Xi XM2 Yi YM2 ;... ]
%                 
%                 % Building weights "Wijs":
%                 Wijs = ones(njs,1);                                     % sets default values to 1
%                 V4iTF = any(ismember(V4CellCouples,i),2);               % get lines in "V4CellCouples" where i can be found
%                 V4js = setdiff(unique(V4CellCouples(V4iTF,:)),i);       % get list of j neighbors involved in a 4-vertex with i (V4js)                                                                                %
%                 if ~isempty(V4js)
%                     V4TF = ismember(js,V4js);                           % get locations of neighbors V4js in js
%                     Wijs(V4TF) = 1/2;                                   % replace weights 1 by 1/2 at those locations
%                 end
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                
                
                if n > startFrame
                                     
                    %%%% Determining sets "ios","kos","jos","ks","gs","los","cs","cos" and "iokoMatch", "Wiokos", "Liokos"
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    % "ios":
                    ios = iioMatcher(i, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs);  % NB: "ios" will be empty if "i" is new (1.0i)
                    
                    % "iokoMatch", "Wiokos", "Liokos":
                    iosLocTF = ismember(all_iokoMatch(:,1),ios);           % gets lines in "all_iokoMatch" containing 1 element of "ios" IN FIRST COLUMN
                    iokoLoc = find(iosLocTF);                               % indices of io-ko lines in "all_iokoMatch" (equivalent to "ios_loc_TF")
                    niokoLoc = sum(iosLocTF);                               % gets number of 1s
                    iokoMatch = all_iokoMatch(iokoLoc,:);                  % builds matrix: [io1 ko1 ; io2 ko2 ; io1 ko1' ;...] (not ordered)
                    Wiokos = all_Wiokos(iokoLoc);
                    Liokos = all_Liokos(iokoLoc,:);
                    
                    % "kos":
                    kos = unique(all_iokoMatch(iosLocTF,2));               % gets all kos neighbors of all regions ios associated to i
                    
                    % "jos" and "jjosMatch":
                    [jos, jjoMatch] = iioMatcher(js, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs);    % STRAIGHTFORWARD WAY: NOT SLOWER THAN USING "cell_ios" for
                    % already processed js (namely, js<i)!! (1.0i)
                    % "ks" and "koksMatch":
                    [ks, kokMatch] = ioiMatcher(kos, Correspondence, CorrespondenceOLD, dividingRNsOLD);
                    
                    % "jCs":
                    jCs = FindCoalescences(jjoMatch, coalescedRNs, coalescedRNsOLD);
                    jCs_TF = ismember(ijMatch(:,2),jCs);                                % vector of length "njs" with 1s where js/jos were found coalesced
                    njCs = sum(jCs_TF);
                    
                    % "koCs"
                    kokMatchFlipped = fliplr(kokMatch);                                         % flips matrix left/right to put old RNs to the left
                    [~,koCs] = FindCoalescences(kokMatchFlipped, coalescedRNs, coalescedRNsOLD);
                    koCsTF = ismember(iokoMatch(:,2),koCs);                                      % vector of length "n_ios_loc" with 1s where "koCs" are found in "iokoMatch" col 2
                    nkoCs = sum(koCsTF);
                    
                    % "gs", "los", "cs", "cos":
                    cs = intersect(js,ks);
                    csTF = ismember(ijMatch(:,2),cs);
                    ncs = sum(csTF);
                    cos = intersect(kos,jos);
                    cosTF = ismember(iokoMatch(:,2),cos);
                    ncos = sum(cosTF);
                    gs = setdiff(js,ks);
                    gsTF = ismember(ijMatch(:,2),gs);
                    ngs = sum(gsTF);
                    los = setdiff(kos,jos);
                    losTF = ismember(iokoMatch(:,2),los);
                    nlos = sum(losTF);
                    
                    % Filling up "CELLS_TA" quantities:
                    cell_ijLoc{i} = ijLoc;
                    cell_iokoLoc{i} = iokoLoc;
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    
                    %%%% Determining additional "cs/cos" related subsets for tensor calculation
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    % "divided_cs":
                    divided_jsTF = ismember(js, daughterRNs);
                    divided_csTF = all([csTF divided_jsTF],2);
                    n_divided_cs = sum(divided_csTF);
                    
                    % "dividing_cos":
                    dividing_kos_TF = ismember(iokoMatch(:,2), dividingRNsOLD);
                    dividing_cos_TF = all([cosTF dividing_kos_TF],2);
                    n_dividing_cos = sum(dividing_cos_TF);
                    
                    % "Hgs", "Hgos", "Hls", "Hlos":
                    icMatch = ijMatch(csTF,:);                             % [i c1; i c2 ; ...]. NB: js, hence cs, are listed once
                    Wics = Wijs(csTF);                                     % corresponding weights
                    iocoMatch = iokoMatch(cosTF,:);                        % cos listed once IF io is unique (i not coalesced for ex)
                    Wiocos = Wiokos(cosTF);
                    
                    ccoMatchTF1 = ismember(jjoMatch(:,1),cs);              % get 1s where cs are in 1st jjoMatch column
                    ccoMatchTF2 = ismember(jjoMatch(:,2),cos);             % get 1s where cos are in 2nd jjoMatch column
                    ccoMatchTF = all([ccoMatchTF1 ccoMatchTF2],2);         % only keeps 1s where 1s found on both lines
                    ccoMatch = jjoMatch(ccoMatchTF,:);                     % builds ccoMatch
                    
                    [~,csLoc] = ismember(ccoMatch(:,1),icMatch(:,2));      % gets indices of each c in icMatch (same size as ccoMatch)
                    [~,cosLoc] = ismember(ccoMatch(:,2),iocoMatch(:,2));   % gets indices of each co in iocoMatch (same size as ccoMatch)
                    
                    delta_WicWioco = Wics(csLoc) - Wiocos(cosLoc);         % vector Wic-Wioco
                    % Half-GAINED links (links going 1/2 -> 1):
                    delta_plus_TF = delta_WicWioco > 0;
                    Hgs =  ccoMatch(delta_plus_TF,1);                      % gets list of RNs (among cs) in CURRENT frame
                    Hgos = ccoMatch(delta_plus_TF,2);                      % gets list of RNs (among cos) in OLD frame
                    HgsTF = ismember(ijMatch(:,2),Hgs);                    % gets "Hgs" locations in "ijMatch"
                    nHgs = sum(HgsTF);
                    HgosTF = ismember(iokoMatch(:,2),Hgos);                % gets "Hgos" locations in "iokoMatch"
                    nHgos = sum(HgosTF);
                    
                    % Half-LOST links (links going 1 -> 1/2):
                    delta_minus_TF = delta_WicWioco < 0;
                    Hls =  ccoMatch(delta_minus_TF,1);                     % gets list of RNs (among cs) in CURRENT frame
                    Hlos = ccoMatch(delta_minus_TF,2);                     % gets list of RNs (among cos) in OLD frame
                    HlsTF = ismember(ijMatch(:,2),Hls);                    % gets "Hls" locations in "ijMatch"
                    nHls = sum(HlsTF);
                    HlosTF = ismember(iokoMatch(:,2),Hlos);                % gets "Hlos" locations in "iokoMatch"
                    nHlos = sum(HlosTF);
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    
                    %%%% Determining additional "gs/los", "ios" related subsets for tensor calculation
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    NjsTF = ismember(ijMatch(:,2), newRNs);
                    NgsTF = all([gsTF NjsTF],2);
                    nNgs = sum(NgsTF);
                    
                    AkosTF = ismember(iokoMatch(:,2), delaminatingRNsOLD);
                    AlosTF = all([losTF AkosTF],2);
                    nAlos = sum(AlosTF);
                    
                    core_iosTF = ismember(iokoMatch(:,1), coreRNsOLD);
                    nCore_ios = sum(core_iosTF);
                    nonCore_ios_TF = ~core_iosTF;
%                     n_NonCore_ios = sum(nonCore_ios_TF); % Com in 5.0
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    
                    %%%% Determining "iSister" if "i" just divided:
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    if ismember(i,daughterRNs) && ~ismember(i,coalescedRNs)
                        iTF = any(ismember(daughterRNsMat,i),2);             % finds line where "i" is in "daughterRNsMat"
                        iSister = setdiff(daughterRNsMat(iTF,:),i);         % removes i from line to get sister
                        iSisterTF = ismember(ijMatch(:,2),iSister);       % vector of njs elements: 1 where "i_sister" is, 0s elsewhere
                    end
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    
                    %%%% Determining "HLC/HLC"_old and all TENSOR contributions:
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    if ismember(i,coalescedRNs) || any(ismember(ios,coalescedRNsOLD))   % Regions "i" OR "ios" COALESCED (either CURRENT or OLD)
                        % Filling "all_HLCold":
                        iHLCold = num2cell(repmat('n/a',niokoLoc,1),2);               % DEFAULT: Filling up all io-ko lines with 'n/a'
                        iHLCold(core_iosTF) = num2cell(repmat('F',nCore_ios,1));      % OVERWRITES all Core_io-kos lines with 'F'
                        if ismember(i,coreRNs)                                          % "i" is a Core cell
                            % CALCULATE M(i)
                            iHLC = num2cell(repmat('F',njs,1));                        % Filling up all ij lines with 'F'
                        else                                                            % "i" NOT a core cell
                            iHLC = num2cell(repmat('n/a',njs,1),2);                    % Filling up all ij lines with 'n/a'
                            if nCore_ios >= 1
                                nExtraCells = nExtraCells + 1;
                                extraCells(nExtraCells) = i;                            % Add Non-Core region i to "extraCells"
                            end
                        end
                    else                                                       % NEITHER regions "i" NOR "ios" NOT coalesced (neither CURRENT nor OLD)
                        if ismember(i,newRNs)                                  % "i" is a NEW CELL
                            if ismember(i,coreRNs)                             % "i" is a Core cell
                                % CALCULATE M(i)
                                iHLC = num2cell(repmat('N+',njs,1),2);          % DEFAULT: Filling up all lines with 'N+' (2.1.0) 
                                iHLC(jCs_TF) = num2cell(repmat('F',njCs,1));    % OVERWRITES j cells that ARE or WERE coalesced with 'F'
                                iHLCold = [];                                  % no io-ko for new cells (1.0h)
                            else                                                 % "i" is NOT a Core cell
                                iHLC = num2cell(repmat('n/a',njs,1),2);         % Filling up all ij lines with 'n/a'
                                iHLCold = [];                                  % no io-ko for new cells (1.0h)
                            end
                        else                                                               % "i" is NOT a New cell
                            if ismember(i,coreRNs)                                         % "i" is a Core cell
                                % CALCULATE M(i)
                                if any(ismember(ios,coreRNsOLD))                           % 1+ "ios" was a Core cell in previous frame
                                    if ismember(i,daughterRNs)                             % cell i just divided: CASE 2
                                        % Filling "all_HLC":
                                        iHLC = num2cell(repmat('Dn',njs,1),2);            % DEFAULT: Filling all lines with 'Dd'
                                        iHLC(iSisterTF) = num2cell('Ds',2);             % OVERWRITES i-i_sister HL with 'Ds'
                                        iHLC(jCs_TF) = num2cell(repmat('F',njCs,1));      % OVERWRITES HL for j cells that ARE or WERE coalesced with 'F'
                                        % Filling "all_HLCold":
                                        iHLCold = num2cell(repmat('Dm',niokoLoc,1),2);    % DEFAULT: Filling up all lines with 'Dm'
                                        iHLCold(koCsTF) = num2cell(repmat('F',nkoCs,1));  % OVERWRITES HL for ko cells that WERE or WILL BE coalesced with 'F'
                                    else                                                                 % cell i DID NOT just divide: CASE 1
                                        % Filling "all_HLC":
                                        iHLC = cell(njs,1);
                                        % HL with conserved neighbors "cs":
                                        iHLC(csTF) = num2cell(repmat('G',ncs,1),2);                   % DEFAULT: Filling up all "cs" lines with 'G'
                                        iHLC(HgsTF) = num2cell(repmat('G/R+',nHgs,1),2);              % OVERWRITES HL of Half-GAINED neighbors
                                        iHLC(HlsTF) = num2cell(repmat('G/R-',nHls,1),2);              % OVERWRITES HL of Half-LOST neighbors
                                        iHLC(divided_csTF) = num2cell(repmat('TD+',n_divided_cs,1),2); % OVERWRITES HL of "cs" neighbors that just divided
                                        % HL with gained neighbors "gs":
                                        iHLC(gsTF) = num2cell(repmat('R+',ngs,1),2);                  % DEFAULT: Filling up all "gs" lines with 'R+'
                                        iHLC(NgsTF) = num2cell(repmat('TN+',nNgs,1),2);                % OVERWRITES HL for j neighbors thar are NEW, TN+ (2.1.0)
                                        % Overwrites links involved in Coalescence and storage:
                                        iHLC(jCs_TF) = num2cell(repmat('F',njCs,1));                   % OVERWRITES HL for j cells that ARE or WERE coalesced with 'F'
                                        
                                        % Filling "all_HLCold":
                                        iHLCold = cell(niokoLoc,1);
                                        % HL with conserved neighbors "cos":
                                        iHLCold(cosTF) = num2cell(repmat('G',ncos,1),2);                     % DEFAULT: Filling up all "cos" lines with 'G'
                                        iHLCold(HgosTF) = num2cell(repmat('G/R+',nHgos,1),2);                % OVERWRITES HL of Half-GAINED neighbors
                                        iHLCold(HlosTF) = num2cell(repmat('G/R-',nHlos,1),2);                % OVERWRITES HL of Half-LOST neighbors
                                        iHLCold(dividing_cos_TF) = num2cell(repmat('TD-',n_dividing_cos,1),2); % OVERWRITES HL of "cos" neighbors dividing
                                        % HL with lost neighbors "los":
                                        iHLCold(losTF) = num2cell(repmat('R-',nlos,1),2);                    % DEFAULT: Filling up all "los" lines with 'R-'
                                        iHLCold(AlosTF) = num2cell(repmat('TA-',nAlos,1),2);                  % OVERWRITES HL for ko neighbors thar are APOPTOTIC, TA- (2.1.0)
                                        % Overwrites links involved in Coalescence and storage:
                                        iHLCold(koCsTF) = num2cell(repmat('F',nkoCs,1));                     % OVERWRITES HL for ko cells that WERE or WILL BE coalesced with 'F'
                                    end
                                else                                                         % NONE of "ios" was a Core cell in previous frame
                                    if ismember(i,daughterRNs)                            % cell i just divided: CASE 4
                                        % Filling "all_HLC":
                                        iHLC = num2cell(repmat('Dn',njs,1),2);             % DEFAULT: Filling all lines with 'Dd'
                                        iHLC(iSisterTF) = num2cell('Ds',2);               % OVERWRITES i-i_sister HL with 'Ds'
                                        iHLC(jCs_TF) = num2cell(repmat('F',njCs,1));       % OVERWRITES HL for j cells that ARE or WERE coalesced with 'F'
                                        % Filling "all_HLCold":
                                        iHLCold = num2cell(repmat('n/a',niokoLoc,1),2);  % Filling up all lines with 'n/a'
                                    else                                                     % cell i DID NOT just divide: CASE 3
                                        % Filling "all_HLC":
                                        iHLC = num2cell(repmat('J+',njs,1),2);              % DEFAULT: Filling all lines with 'J+'
                                        iHLC(jCs_TF) = num2cell(repmat('F',njCs,1));        % OVERWRITES HL for j cells that ARE or WERE coalesced with 'F'
                                        % Filling "all_HLCold":
                                        iHLCold = num2cell(repmat('n/a',niokoLoc,1),2);   % Filling up all lines with 'n/a'
                                    end
                                end
                            elseif any(ismember(ios,coreRNsOLD))                     % "i" NOT Core BUT 1+ "ios" was
                                nExtraCells = nExtraCells + 1;
                                extraCells(nExtraCells) = i;                          % Add Non-Core region i to "Extra_cells"
                                if ismember(i,daughterRNs)                            % cell i just divided: CASE 6
                                    % Filling "all_HLC":
                                    iHLC = num2cell(repmat('n/a',njs,1),2);            % Filling up all lines with 'n/a'
                                    % Filling "all_HLCold":
                                    iHLCold = num2cell(repmat('Dm',niokoLoc,1),2);   % DEFAULT: Filling up all lines with 'Dm'
                                    iHLCold(koCsTF) = num2cell(repmat('F',nkoCs,1)); % OVERWRITES HL for ko cells that WERE or WILL BE coalesced with 'F'
                                else                                                     % cell i DID NOT just divide: CASE 5
                                    % Filling "all_HLC":
                                    iHLC = num2cell(repmat('n/a',njs,1),2);            % Filling up all lines with 'n/a'
                                    % Filling "all_HLCold":
                                    iHLCold = num2cell(repmat('J-',niokoLoc,1),2);   % DEFAULT: Filling all lines with 'J-'
                                    iHLCold(koCsTF) = num2cell(repmat('F',nkoCs,1)); % OVERWRITES HL for ko cells that WERE or WILL BE coalesced with 'F'
                                end
                            else                                                         % Neither "i" nor any "ios" are Core
                                iHLC = num2cell(repmat('n/a',njs,1),2);                % Filling up all ij lines with 'n/a'
                                iHLCold = num2cell(repmat('n/a',niokoLoc,1),2);      % Filling up all io-ko lines with 'n/a'
                            end
                        end
                    end
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                end
                
                
                %%%% Filling up LINKS quantities for CURRENT frame:
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%                 all_ijMatch(ijLoc,:) = ijMatch;
%                 all_Wijs(ijLoc,:) = Wijs;
%                 all_Lijs(ijLoc,:) = Lijs;
%                 all_LijPlots(ijLoc,:) = LijPlots;
                if n > startFrame
                    all_HLC(ijLoc) = iHLC;             % Filling up all ij lines for cell i
                    all_HLCold(iokoLoc) = iHLCold;   % Filling up all io-ko lines for cell i
                end
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                
                %%%% Updating "start_row" and progressbar over cell iteration:
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                progressbar([],i/nCells)
%                 startRow = endRow + 1;
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            end
            elapsedTime = toc;
            fprintf(['Done. (' num2str(elapsedTime) ' s)\n']); % 2.3.5
            %-------------------------------------------------------------------------------------------------------------------
            
            
            
            %%% Treatment of ALL "APOPTOTIC"/"GONE OUT OF FRAME" cells that just disappeared in CURRENT frame (NO LOOPS):
            %-------------------------------------------------------------------------------------------------------------------
            if n > startFrame
                
                % APOPTOTIC CELLS:
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                if ~isempty(delaminatingRNsOLD)
                    disp('Processing "Apoptotic" cells...');
                    % Finds those that were among "Core_cells_old" and those that were not:
                    Core_Aos = intersect(delaminatingRNsOLD, coreRNsOLD);
                    Core_Aos_TF = ismember(all_iokoMatch(:,1), Core_Aos);                   % Finds ALL Core apoptotic cells RNs in FIRST col of "all_iokoMatch"
                    n_Core_Aos = sum(Core_Aos_TF);
                    NonCore_Aos = setdiff(delaminatingRNsOLD, coreRNsOLD);
                    NonCore_Aos_TF = ismember(all_iokoMatch(:,1), NonCore_Aos);             % Finds ALL NON Core apoptotic cells RNs in FIRST col of "all_iokoMatch"
                    n_NonCore_Aos = sum(NonCore_Aos_TF);
                    
                    % Fills up "all_HLCold" with DEFAULT values:
                    all_HLCold(Core_Aos_TF) = num2cell(repmat('A-',n_Core_Aos,1),2);         % DEFAULT: fills up ALL lines with 'A' for Core cells, A- (2.1.0)
                    all_HLCold(NonCore_Aos_TF) = num2cell(repmat('n/a',n_NonCore_Aos,1),2); % DEFAULT: fills up ALL lines with 'n/a' for NON Core cells
                    
                    if ~isempty(Core_Aos)
                        % Finds ALL "Core_Aos" coalesced neighbors (CURRENT OR OLD frame), overwrites these links with "F":
                        Kos = unique(all_iokoMatch(Core_Aos_TF,2));                                                            % gets list of all CORE Aos neighbors
                        [Ks, KoKMatch] = ioiMatcher(Kos, Correspondence, CorrespondenceOLD, dividingRNsOLD);             % Building "KoKMatch"
                        KoKMatch_flipped = fliplr(KoKMatch);                                                                  % flips matrix left/right to put old RNs to the left
                        [~,KoCs] = FindCoalescences(KoKMatch_flipped, coalescedRNs, coalescedRNsOLD);                 % Builds list of neighbors "KoCs" coalesced in CURRENT/OLD frame
                        KoCs_TF = ismember(all_iokoMatch(:,2),KoCs);                                                           % 1s for lines in "all_iokoMatch" where "KoCs" are found
                        Core_Aos_KoCs_TF = all([Core_Aos_TF KoCs_TF],2);                                                        % 1s for lines in "all_iokoMatch" with BOTH "Core_Aos" and "KoCs"
                        n_Core_Aos_KoCs = sum(Core_Aos_KoCs_TF);
                        all_HLCold(Core_Aos_KoCs_TF) = num2cell(repmat('F',n_Core_Aos_KoCs,1),2);                              % OVERWRITES: fills up ALL corresponding lines with 'F'
                    end
                end
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                
                % GONE OUT OF FRAME CELLS:
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                % Determining "GoneOut_RNs" (1.0i):
                ALL_ios = cellRNsOLD;
                [~, ALL_ioiMatch] = ioiMatcher(ALL_ios, Correspondence, CorrespondenceOLD, dividingRNsOLD);
                candidate_Disappeared_cells_TF = ismember(ALL_ioiMatch(:,2),0);                                  % finds all RNs (repeated) with corresponding 0 in col 2
                candidate_Disappeared_cells_RNs = unique(ALL_ioiMatch(candidate_Disappeared_cells_TF,1));
                ALL_ioiMatch_NoZeros = ALL_ioiMatch(~candidate_Disappeared_cells_TF,:);                         % crops "ALL_ioiMatch" to lines with no 0 in col 2
                NonDisappeared_cells = unique(ALL_ioiMatch_NoZeros(:,1));                                        % lists all RNs not matched with 0 in col 2 (still found in current)
                Disappeared_cells_RNs = setdiff(candidate_Disappeared_cells_RNs, NonDisappeared_cells);           % removes them from "candidate_Disappeared_cells_RNs"
                GoneOut_RNs = setdiff(Disappeared_cells_RNs, delaminatingRNsOLD);                                % removes apoptotic cell RNs from list of disappeared cells
                
                if ~isempty(GoneOut_RNs)
                    disp('Processing "Gone out of frame" cells...');
                    % Finds those that were among "Core_cells_old" and those that were not:
                    Core_GoneOut_RNs = intersect(GoneOut_RNs, coreRNsOLD);
                    Core_GoneOut_RNs_TF = ismember(all_iokoMatch(:,1), Core_GoneOut_RNs);       % Finds ALL Core Gone out RNs in FIRST col of "all_iokoMatch"
                    n_Core_GoneOut_RNs = sum(Core_GoneOut_RNs_TF);
                    NonCore_GoneOut_RNs = setdiff(GoneOut_RNs, coreRNsOLD);
                    NonCore_GoneOut_RNs_TF = ismember(all_iokoMatch(:,1), NonCore_GoneOut_RNs); % Finds ALL NON Core Gone out RNs in FIRST col of "all_iokoMatch"
                    n_NonCore_GoneOut_RNs = sum(NonCore_GoneOut_RNs_TF);
                    
                    % Fills up "all_HLCold" with DEFAULT values:
                    all_HLCold(Core_GoneOut_RNs_TF) = num2cell(repmat('J-',n_Core_GoneOut_RNs,1),2);        % DEFAULT: fills up ALL lines with 'J-' for Core cells
                    all_HLCold(NonCore_GoneOut_RNs_TF) = num2cell(repmat('n/a',n_NonCore_GoneOut_RNs,1),2); % DEFAULT: fills up ALL lines with 'n/a' for NON Core cells
                    
                    if ~isempty(Core_GoneOut_RNs)
                        % Finds ALL "Core_GoneOut_RNs" coalesced neighbors (CURRENT OR OLD frame) and overwrites with "F":
                        Kos = unique(all_iokoMatch(Core_GoneOut_RNs_TF,2));                                        % gets list of all CORE GoneOut_RNs neighbors
                        [Ks, KoKMatch] = ioiMatcher(Kos, Correspondence, CorrespondenceOLD, dividingRNsOLD); % Building "KoKMatch"
                        KoKMatch_flipped = fliplr(KoKMatch);                                                      % flips matrix left/right to put old RNs to the left
                        [~,KoCs] = FindCoalescences(KoKMatch_flipped, coalescedRNs, coalescedRNsOLD);     % Builds list of neighbors "KoCs" coalesced in CURRENT/OLD frame
                        KoCs_TF = ismember(all_iokoMatch(:,2),KoCs);                                               % 1s for lines in "all_iokoMatch" where "KoCs" are found
                        Core_GoneOut_RNs_KoCs_TF = all([Core_GoneOut_RNs_TF KoCs_TF],2);                            % 1s for lines in "all_iokoMatch" with BOTH "Core_GoneOut_RNs" and "KoCs"
                        n_Core_GoneOut_RNs_KoCs = sum(Core_GoneOut_RNs_KoCs_TF);
                        all_HLCold(Core_GoneOut_RNs_KoCs_TF) = num2cell(repmat('F',n_Core_GoneOut_RNs_KoCs,1),2);  % OVERWRITES: fills up ALL corresponding lines with 'F'
                    end
                end
                %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            end
            %-------------------------------------------------------------------------------------------------------------------
            
            
            
            %%% Overriding HLC R+ to A+ for regions that became neighbor after apoptosis of a common neighbor (2.1.2)
            %------------------------------------------------------------------------------------------------------------------- 
            if n > startFrame
                if ~isempty(delaminatingRNsOLD)

                    all_HLC_allowed_TF = strcmp(all_HLC,'R+');      % finds locations of candidates ij
                    
                    % Finding CURRENT RNs that had the same apoptotic neighbor in OLD frame:
                    nAcells = length(delaminatingRNsOLD);
                    all_HLC_sameApopNeigbhor_TF = false(length(all_HLC),1);
                    for a = 1:nAcells
                        aRNo = delaminatingRNsOLD(a);              % ath apoptotic cell in OLD frame
                        aNeighRNsOld = cellNeighborsOLD{aRNo};    % its neighbor RNs in OLD frame
                        aNeighRNs = ioiMatcher(aNeighRNsOld, Correspondence, CorrespondenceOLD, dividingRNsOLD); % corresponding RNs in CURRENT frame
                        aTF = ismember(all_ijMatch, aNeighRNs);    % their locations in all_ijMatch
                        aTF = all(aTF,2);                           % get lines where cells ij BOTH HAD THE SAME apoptotic neighbor in OLD frame
                        all_HLC_sameApopNeigbhor_TF(aTF) = true;    % switches lines to 1 in boolean
                    end
                    all_HLC_switching_TF = all([all_HLC_allowed_TF all_HLC_sameApopNeigbhor_TF],2); % location that will switch in all_HLC
                    all_HLC(all_HLC_switching_TF) = {'A+'}; 
                end
            end
            %-------------------------------------------------------------------------------------------------------------------
            
            %%% Overriding HLC R- to N- for regions that used to be neighbor before "nucleation" of a new common neighbor (2.1.3)
            %------------------------------------------------------------------------------------------------------------------- 
            if n > startFrame
                if ~isempty(newRNs)

                    all_HLCold_allowed_TF = strcmp(all_HLCold,'R-');  % finds locations of candidates ioko
                    
                    % Finding OLD RNs that will have the same new neighbor in CURRENT frame:
                    nNcells = length(newRNs);
                    all_HLCold_sameNewNeigbhor_TF = false(length(all_HLCold),1);
                    for p = 1:nNcells
                        nRN = newRNs(p);                             % nth apoptotic cell in CURRENT frame
                        nNeighRNs = cellNeighbors{nRN};                % its neighbor RNs in CURRENT frame
                        nNeighRNsOld = iioMatcher(nNeighRNs, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs); % corresponding RNs in OLD frame
                        nTF = ismember(all_iokoMatch, nNeighRNsOld);   % their locations in all_iokoMatch
                        nTF = all(nTF,2);                               % get lines where cells ioko WILL BOTH HAVE THE SAME new neighbor in CURRENT frame
                        all_HLCold_sameNewNeigbhor_TF(nTF) = true;     % switches lines to 1 in boolean
                    end
                    all_HLCold_switching_TF = all([all_HLCold_allowed_TF all_HLCold_sameNewNeigbhor_TF],2); % location that will switch in all_HLC
                    all_HLCold(all_HLCold_switching_TF) = {'N-'}; 
                end
            end
            %-------------------------------------------------------------------------------------------------------------------
            
            
            %%% Cropping extraCells and LINKS quantities to relevant size (up to "endRow"):
            %-------------------------------------------------------------------------------------------------------------------
            extraCells = RemoveNaNs(extraCells); % use of "RemoveNaNs" (5.2)
%             extraCells = extraCells(~isnan(extraCells));

            % checking nHL = endRow always (5.2)
%             if endRow ~= nHL
%                 warndlg(['ERROR: mismatch between "nHL" (' num2str(nHL) ') and "endRow" (' num2str(endRow) ')!!'], 'ERROR!!')
%                 return
%             end
            % NO NEED TO CROP ANYMORE (5.2):
%             all_ijMatch = all_ijMatch(1:endRow,:);
%             all_Wijs = all_Wijs(1:endRow);
%             all_Lijs = all_Lijs(1:endRow,:);
%             all_LijPlots = all_LijPlots(1:endRow,:);
%             all_HLC = all_HLC(1:endRow);
            %-------------------------------------------------------------------------------------------------------------------
            
            % REMOVED OVERRIDING OF CORE-FL LINKS (MOVED TO GRID PROCESSING PART IN 2.0.10)  
     
            %%% Saving CELLS_TA, APOPTOTIC_CELLS_TA and LINKS in current frame backup
            %-----------------------------------------------------------------------------------------------------------
            fprintf(['Saving backup file "' nthBackupFilename '"...']); % mod 5.1
            
            %%%% Filling up "CELLS_TA":
            CELLS_TA.extraCells = extraCells; % changed names (5.2)
            CELLS_TA.cell_ijLoc = cell_ijLoc;
            CELLS_TA.cell_iokoLoc = cell_iokoLoc;
            
            %%%% Filling up "LINKS":
            % Current quantities;
            LINKS.all_ijMatch = all_ijMatch;
            LINKS.all_Wijs = all_Wijs;
            LINKS.all_Lijs = all_Lijs;
            LINKS.all_LijPlots = all_LijPlots;
            LINKS.all_HLC = all_HLC;
            if n > startFrame
                LINKS.all_iokoMatch = all_iokoMatch;
                LINKS.all_Wiokos = all_Wiokos;
                LINKS.all_Liokos = all_Liokos;
                LINKS.all_LiokoPlots = all_LiokoPlots;
                LINKS.all_HLCold = all_HLCold;         % THIS ONE IS NOT REDUNDANT!!
            end
            
            %%%% Saves Backup file:
            save(nthBackupFile, 'CELLS_TA', 'LINKS'); % Stopped saving tensors on whole image (2.0.3), stopped saving FRAME (4.0), using "nthBackupFile" (5.1)
            fprintf('Done.\n')
            % NB: indeed, all the HL categorization is independant of the renormalization and takes a while to run, so
            % backup generated over the whole image should be common to all renorm.
            %-----------------------------------------------------------------------------------------------------------
            
        elseif strcmp(gridType, 'E') || strcmp(gridType, 'L')
            
            %% CASE 2: GRID/BOX PROCESSING (gridType = 'E'/'L') %%
            
            %%% Initializing: loading full image TA backup (overhaul 4.0, 5.3):
            %-----------------------------------------------------------------------------------------------------------
            thisEnd = ['_' num2str(n, digitsFormat) '.mat'];
            fullPathTAbackup = [rootFulImageTAbackup thisEnd]; % only current version supported (5.3)
            
            if exist(fullPathTAbackup,'file')
                fprintf('Loading TA backup file...') 
                TAbackup2load = fullPathTAbackup;
            else % 4.4
                fprintf('ERROR: NO TA backup of full image processing could be found!!\n')
                fprintf('Stopped execution.')
                return
            end
            TA_Backup = load(TAbackup2load);
            LINKS = TA_Backup.LINKS;
            ExtractData(LINKS);
            fprintf('Done.\n')
            %-----------------------------------------------------------------------------------------------------------
            
            %%% Defining "extFLRNs" that will extend FLRNs to when processing grid (4.4)
            %-----------------------------------------------------------------------------------------------------------
            extNonCoreRNs = setdiff(cellRNs, allGridCoreRNs);
            extFLRNs = setdiff(extNonCoreRNs, borderRNs);
            %-----------------------------------------------------------------------------------------------------------
            
            
            %%% Updating "all_HLC" and "all_HLCold" with new notations if they were created with TA 2.1.1- (2.1.2)
            %-----------------------------------------------------------------------------------------------------------
            if n == startFrame
                clear updateHLCsTF;                            % clears variable it it case it was still in the workspace
            elseif ~exist('updateHLC','var')
                fprintf('Definition of "udpateHLC" and update of all_HLC and all_HLCold if necessary.\n')
                [all_HLC, updateHLCsTF] = UpdateHLCs(all_HLC);   % defines "updateHLCsTF" and updates all_HLC, all_HLCold if necessary
                all_HLCold = UpdateHLCs(all_HLCold);
            elseif updateHLCsTF
                fprintf('Updating "all_HLC" and "all_HLCold"...')
                all_HLC = UpdateHLCs(all_HLC);               % updates all_HLC
                all_HLCold = UpdateHLCs(all_HLCold);
                fprintf('Done.\n')
            end
            % NB: the aim here is to support old backups
            %-----------------------------------------------------------------------------------------------------------
            
            
            %%% Overriding HLC R+ to A+ for regions that became neighbor after apoptosis of a common neighbor (2.1.2)
            %------------------------------------------------------------------------------------------------------------------- 
            if n > startFrame
                if ~isempty(delaminatingRNsOLD)

                    all_HLC_allowed_TF = strcmp(all_HLC,'R+');      % finds locations of candidates ij
                    
                    % Finding CURRENT RNs that had the same apoptotic neighbor in OLD frame:
                    nAcells = length(delaminatingRNsOLD);
                    all_HLC_sameApopNeigbhor_TF = false(length(all_HLC),1);
                    for a = 1:nAcells
                        aRNo = delaminatingRNsOLD(a);              % ath apoptotic cell in OLD frame
                        aNeighRNsOld = cellNeighborsOLD{aRNo};    % its neighbor RNs in OLD frame
                        aNeighRNs = ioiMatcher(aNeighRNsOld, Correspondence, CorrespondenceOLD, dividingRNsOLD); % corresponding RNs in CURRENT frame
                        aTF = ismember(all_ijMatch, aNeighRNs);    % their locations in all_ijMatch
                        aTF = all(aTF,2);                           % get lines where cells ij BOTH HAD THE SAME apoptotic neighbor in OLD frame
                        all_HLC_sameApopNeigbhor_TF(aTF) = true;    % switches lines to 1 in boolean
                    end
                    all_HLC_switching_TF = all([all_HLC_allowed_TF all_HLC_sameApopNeigbhor_TF],2); % location that will switch in all_HLC
                    all_HLC(all_HLC_switching_TF) = {'A+'}; 
                end
            end
            %-------------------------------------------------------------------------------------------------------------------
            
            %%% Overriding HLC R- to N- for regions that used to be neighbor before "nucleation" of a new common neighbor (2.1.3)
            %------------------------------------------------------------------------------------------------------------------- 
            if n > startFrame
                if ~isempty(newRNs)

                    all_HLCold_allowed_TF = strcmp(all_HLCold,'R-');  % finds locations of candidates ioko
                    
                    % Finding OLD RNs that will have the same new neighbor in CURRENT frame:
                    nNcells = length(newRNs);
                    all_HLCold_sameNewNeigbhor_TF = false(length(all_HLCold),1);
                    for p = 1:nNcells
                        nRN = newRNs(p);                             % nth apoptotic cell in CURRENT frame
                        nNeighRNs = cellNeighbors{nRN};                % its neighbor RNs in CURRENT frame
                        nNeighRNsOld = iioMatcher(nNeighRNs, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs); % corresponding RNs in OLD frame
                        nTF = ismember(all_iokoMatch, nNeighRNsOld);   % their locations in all_iokoMatch
                        nTF = all(nTF,2);                               % get lines where cells ioko WILL BOTH HAVE THE SAME new neighbor in CURRENT frame
                        all_HLCold_sameNewNeigbhor_TF(nTF) = true;     % switches lines to 1 in boolean
                    end
                    all_HLCold_switching_TF = all([all_HLCold_allowed_TF all_HLCold_sameNewNeigbhor_TF],2); % location that will switch in all_HLC
                    all_HLCold(all_HLCold_switching_TF) = {'N-'}; 
                end
            end
            %-------------------------------------------------------------------------------------------------------------------
            
            
            %%% OVERRIDING HLs INVOLVING FL CELLS IN "all_HLCold" and "all_HLC" with "n/a" if "keepCoreFLHLs = 0" %%
            %-------------------------------------------------------------------------------------------------------------------
            if ~keepCoreFLHLs && n > startFrame
                
                % displays warning in workspace:
                fprintf('Overwritting all Core-FL HLCs with "n/a","J-","J+" (keepCoreFLHLs = 0)...'); % 2.0.6,2.0.15  
                
                % in OLD:
                Core_FL_HLs_old_TF = ismember(all_iokoMatch(:,2), extFLRNsOLD);
                n_Core_FL_HLs_old = sum(Core_FL_HLs_old_TF);
                all_HLCold(Core_FL_HLs_old_TF) = num2cell(repmat('n/a',n_Core_FL_HLs_old,1),2);
                
                % Overriding contributions of HL of cells WHOSE NEIGHBORS go from Core to FL with "J-" (2.0.8)
                %-------------------------------------------------------------------------------------------------------
                [~, ioiMatch] = ioiMatcher(cellRNsOLD, Correspondence, CorrespondenceOLD, dividingRNsOLD);
                % returns "ioisMatch" = [io i1; io i2 ; io' i1' ; ...], with i = 0 when i is APOPTOTIC

                oldCore_TF = ismember(ioiMatch(:,1), coreRNsOLD);          % spots old core cells in ioiMatch col 1
                CoreioiMatch = ioiMatch(oldCore_TF,:);                        % crops "ioiMatch" to old core cells
                
                FL_TF = ismember(CoreioiMatch(:,2), extFLRNs);                 % spots current FL cells in ioiMatch col 2
                CoreioFLiMatch = CoreioiMatch(FL_TF,:);                       % match between old Core RNs becoming FL RNs
                oldCore2FL = unique(CoreioFLiMatch(:,1));                      % list of oldCore RNs becoming FL
                
                oldCore2FL_TF = ismember(all_iokoMatch(:,2), oldCore2FL);      % spots HL involved in all_iokoMatch => in all_HLCold as well
                % NB: not looking in first column since Core becoming FL have already all their HL tagged with J- (when
                % not F) since they are flux. However, when searching in col 2, one can spot cells of col 1 that remains
                % core (their HL is not J-) that can have links with some cells of col 2 becoming FL in next frame, that
                % can be tagged with anything now (R,D,TA,TD...). BUT these links will disappear and should be tagged J-
                % (when not F or 'n/a).
                
                % Overriding allowed contribution with 'J-'
                all_HLCold_OK = ~any([strcmp(all_HLCold,'F') strcmp(all_HLCold,'n/a')], 2) ; % 1 where not F nor 'n/a', replaced "ismember" by "strcmp" (2.0.12)
                all_HLCold_madeJ = all([all_HLCold_OK oldCore2FL_TF],2);
                all_HLCold(all_HLCold_madeJ) = {'J-'};
                % WARNING:
                % This override results in cells having SOME of their HLs tagged with J- EVEN THOUGH THEY ARE CORE
                % REMAINING CORE. All the other cells actually going out (Core to NON-Core) hormally have ALL their HLs
                % tagged with J-, not just SOME.
                %-------------------------------------------------------------------------------------------------------
                
                % in CURRENT:
                Core_FL_HLs_TF = ismember(all_ijMatch(:,2), extFLRNs);
                n_Core_FL_HLs = sum(Core_FL_HLs_TF);
                all_HLC(Core_FL_HLs_TF) = num2cell(repmat('n/a',n_Core_FL_HLs,1),2);
                
                % Overriding contributions of HL of cells WHOSE NEIGHBORS went from FL to Core with "J+" (2.0.10)
                %-------------------------------------------------------------------------------------------------------
                [~, iioMatch] = iioMatcher(cellRNs, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs);
                % Also returns "iiosMatch" = [i io1 ; i io2 ; i' io1' ; ...], with io = 0 when i is NEW

                Core_TF = ismember(iioMatch(:,1), coreRNs);                 % spots current core cells in iioMatch col 1
                CoreiioMatch = iioMatch(Core_TF,:);                           % crops "iioMatch" to current core cells
                
                oldFL_TF = ismember(CoreiioMatch(:,2), extFLRNsOLD);          % spots old FL cells in iioMatch col 2
                CoreiFLioMatch = CoreiioMatch(oldFL_TF,:);                    % match between current Core RNs that were old FL RNs
                oldFL2Core = unique(CoreiFLioMatch(:,1));                      % list of Core RNs thast were oldFL
                
                oldFL2Core_TF = ismember(all_ijMatch(:,2), oldFL2Core);      % spots HL involved in all_ijMatch => in all_HLC as well
                % NB: NOT looking in first column since FL becoming Core have already all their HL tagged with J+ (when
                % not F) since they are flux. However, when searching in col 2, one can spot cells of col 1 that remains
                % core (their HL is not J+) that can have links with some cells of col 2 becoming Core in next frame, that
                % can be tagged with anything now (R,D,TA,TD...). BUT these links will appear and should be tagged J+
                % (when not F or 'n/a).
                
                % Overriding allowed contribution with 'J+'
                all_HLC_OK = ~any([strcmp(all_HLC,'F') strcmp(all_HLC,'n/a')], 2) ; % 1 where not F nor 'n/a,'replaced "ismember" by "strcmp" (2.0.12)
                all_HLC_madeJ = all([all_HLC_OK oldFL2Core_TF],2);
                all_HLC(all_HLC_madeJ) = {'J+'};
                % WARNING:
                % This override results in cells having SOME of their HLs tagged with J- EVEN THOUGH THEY ARE CORE
                % REMAINING CORE. All the other cells actually going out (Core to NON-Core) hormally have ALL their HLs
                % tagged with J-, not just SOME.
                %-------------------------------------------------------------------------------------------------------
                fprintf('Done.\n'); % 2.0.15
                
            elseif n > startFrame % defines iioMatch when keepCoreFLHLs = true (2.3.3)
                
                [~, iioMatch] = iioMatcher(cellRNs, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs);
                % Also returns "iiosMatch" = [i io1 ; i io2 ; i' io1' ; ...], with io = 0 when i is NEW
            end
            %-----------------------------------------------------------------------------------------------------------
          
            
            %%% Creating empty arrays:
            %-----------------------------------------------------------------------------------------------------------
            gridLINKS = cell(ny,nx);
            
            % Initializing G,S... tensor structures and AreaRatios (2.0.1, 3.0):
            for c = 1:nMcat
                mcat = MCatList{c};                                 % getting this contribution letter, say 'Q'= G,S...
                mcatDim = length(TENSORS.(mcat));                   % 3.0
                eval([mcat ' = NaN(ny,nx,' num2str(mcatDim) ');']); % overrides mcat by its GRID equivalent with right depth "mcatDim" (3.0)
            end
            gridAreaRatiosRaw = zeros(ny,nx);           % 2.0.1, zeros instead of NaN (2.0.4)
            onlyCoreCells_TF = true(ny,nx);         % filled with trues as default (2.0.1)
            RConds = zeros(ny,nx);                  % matrix of RCond numbers to estimate accuracy of inv(MoC) in each compartment (2.0.5)
            errorPs = NaN(ny,nx);                   % will store difference between EG and sum over EP in each compartment(2.0.5)
            errorDnPs = NaN(ny,nx);                 % will store difference between dnTot = nT-nTo and sum over dnP in each compartment (2.0.5)
            %---------------------------------------------------------------------------------------------------------------
            
            
            %%% Copying and renaming UNCHANGED full image quantities (1.1.5):
            %-----------------------------------------------------------------------------------------------------------
            % Actually UNCHANGED:
%             gridLijs = all_Lijs; % COM 5.1
            gridLijPlots = all_LijPlots;
            gridWijs = all_Wijs;
            % Initialization of "grid_HLC/HLCold", get UPDATED later (2.1.6):
            gridHLC = all_HLC;
            gridHLCold = all_HLCold;
            % NB: aim is to have self-sufficient backups in grid mode and not have to load full image backups for replot
            %-----------------------------------------------------------------------------------------------------------

            
            %%% ITERATION OVER GRID COMPARTMENTS:
            %---------------------------------------------------------------------------------------------------------------
            if n == startFrame            
                
                %%%% Loading data from "gridFrame" SIA backups (3.4)
                %-------------------------------------------------------------------------------------------------------
                if gridFrame > startFrame && strcmp(gridType, 'L')
                    
                    disp('Loading SIA backup file for "gridFrame"...');
                    gridFrameBU = load([pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(gridFrame, digitsFormat),'.mat'],'CELLS');
                    
                    gridFrameRNs = gridFrameBU.CELLS.Numbers;
                    [gridFrameCoreRNs, gridFrameFLRNs, gridFrameBorderRNs] = GetCellCategories(gridFrameBU.CELLS.CategoryTags); % 5.7
                     % commented 5.7
%                     gridFrameCellCentroids = gridFrameBU.CELLS.centroids;
%                     gridFrameCoreRNs = gridFrameBU.CELLS.CATEGORIES.Core_cells;
%                     gridFrameFLRNs = gridFrameBU.CELLS.CATEGORIES.FL_cells;
%                     gridFrameBorderRNs = gridFrameBU.CELLS.CATEGORIES.Border_cells;
                    gridFrameNonCoreRNs = sort([gridFrameFLRNs ; gridFrameBorderRNs]);
                    
                    %%% Loading txt files from C++ tracking (common to TA and CppT_display)
                    gridFrameCorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(gridFrame) '.txt']);
                    gridFrameCorrespondence = FormatCorrespondence(gridFrameCorrespondenceRaw, nColTotal); % 4.0
                    clear gridFrameCorrespondenceRaw;
                    % NB: all "Correspondence" arrays should therefore have the same number of columns
                    
                else
                    gridFrameRNs = cellRNs;
%                     gridFrameCellCentroids = cellXYs; % commented 5.7
                    gridFrameCoreRNs = coreRNs;
                    gridFrameBorderRNs = borderRNs;
                    gridFrameNonCoreRNs = nonCoreRNs;
                    gridFrameCorrespondence = Correspondence;
                end
                %-------------------------------------------------------------------------------------------------------
                

                %-------------------------------------------------------------------------------------------------------
                % CASE: n > startFrame
                %-------------------------------------------------------------------------------------------------------
                
            else
                
                % Initialization of boolean vectors tagging HL belonging to the grid (2.1.6)
                grid_HLC_TF = ~logical(all_ijMatch(:,1));          % build a column of false that will be turned into true when HL ij belongs to a box
                grid_HLCold_TF = ~logical(all_iokoMatch(:,1));

                % Iteration over grid compartments
                fprintf('Iteration over grid compartments...');
                for b = 1:nBoxes   
                    
                    [ky,kx] = ind2sub(GRID_DEF.Size,b);         % turns linear index b into (i,j) grid coordinate
                    
                    boxCoreRNs = gridCoreRNs{ky,kx}; % 4.0
                    boxCoreRNsOLD = gridCoreRNsOLD{ky,kx};                                                        % retrieves cell RNs in this box in PREVIOUS frame
                    
                    %%% Defining "box_is", "box_ios", "box_ros", "box_rs" (***TO BE EXPLAINED AT VERY BEGINNING***):
                    box_is = boxCoreRNs;                                                                              % renaming to match CASE 1 notations
                    box_ios = iioMatcher(box_is, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs); % expected "box_ios" inferred from "box_is"
                    box_ros = boxCoreRNsOLD;                                                                         % renaming to match CASE 1 rationale of notations
                    box_rs = ioiMatcher(box_ros, Correspondence, CorrespondenceOLD, dividingRNsOLD);              % expected "box_rs" inferred from "box_ros"
                    
                    %%% Defining all "box_Qijs" and "box_Qrokos" quantities by cropping "all_Qijs" and "all_Qiokos":
                    % Current (Qijs):
                    box_ijMatch_TF = ismember(all_ijMatch(:,1), box_is);                                              % finding locations of RNs listed in "box_is" found in 1st column
                    box_ijMatch = all_ijMatch(box_ijMatch_TF,:);                                                     % Cropping all_ijMatch/Wijs/Lijs/... to HL in box
                    box_Wijs = all_Wijs(box_ijMatch_TF);
                    box_Lijs = all_Lijs(box_ijMatch_TF,:);
                    box_LijPlots = all_LijPlots(box_ijMatch_TF,:);
                    box_HLC = all_HLC(box_ijMatch_TF);
                    % Old (Qrokos) (NB: could be loaded from "grid_LINKS_old", except for "all_HLCold"):
                    box_rokoMatch_TF = ismember(all_iokoMatch(:,1), box_ros);                                         % finding locations of RNs listed in "box_ros" found in 1st column
                    box_rokoMatch = all_iokoMatch(box_rokoMatch_TF,:);                                               % Cropping all_rokoMatch/Wrokos/Lrokos/... to HL in box
                    box_Wrokos = all_Wiokos(box_rokoMatch_TF);
                    box_Lrokos = all_Liokos(box_rokoMatch_TF,:);
                    box_LrokoPlots = all_LiokoPlots(box_rokoMatch_TF,:);
                    box_HLCold = all_HLCold(box_rokoMatch_TF);                                                       % HAS TO BE CALCULATED FROM "all_HLCold", NOT LOADED from LINK_old
                    
                    %%% Determining cells remaining or going in/out of this box:
                    box_is_remained = intersect(box_is, box_rs);
                    box_ros_remaining = intersect(box_ros, box_ios);
                    box_is_gone_in = setdiff(box_is, box_is_remained);
                    box_ros_going_out = setdiff(box_ros, box_ros_remaining);
                    
                    
                    %%% Updating "box_HLC", "box_HLCold" by overwritting appropriate HLC from full image by Jb+/- (mod 2.0.13,2.1.3):
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % Locations of contributions ALLOWED to become Jb+/-:
                    % NB: It's basically all HL of uncoalesced cells that are not undergoing division, apoptosis,
                    % nucleation, image flux and that must be taken into account, NOT JUST CONSERVED LINKS.
                    box_HLC_changeable_TF = ~any([strcmp(box_HLC,'Ds') strcmp(box_HLC,'Dn') strcmp(box_HLC,'A+') strcmp(box_HLC,'N+') strcmp(box_HLC,'J+')  strcmp(box_HLC,'F')  strcmp(box_HLC,'n/a')],2);
                    box_HLCold_changeable_TF = ~any([strcmp(box_HLCold,'Dm') strcmp(box_HLCold,'A-') strcmp(box_HLCold,'N-') strcmp(box_HLCold,'J-')  strcmp(box_HLCold,'F')  strcmp(box_HLCold,'n/a')],2);
                    %
                    % OLD (from 1.1.3, commented 2.0.13):
                    % box_HLC_changeable_TF = any([strcmp(box_HLC, 'B') strcmp(box_HLC, 'B/R+')],2);
                    % box_HLCold_changeable_TF = any([strcmp(box_HLCold, 'B') strcmp(box_HLCold, 'B/R-')],2);
                    %
                    % NB: This used to only allow conserved links to become Jb, which was wrong and not consistent
                    % with the way the image flux J is calculated (it only cares if NonCore became Core and the
                    % inverse (when the cell is not undergoing D,A and is not F, which all have priority over J)
                    % then ALL cell HLs are tagged J, not just the one conserved) and the rule of prioritizing events
                    % occuring for the cell over those occurring for the neighbors (TD,TA...).
                    %
                    % Observed example: cell @ box boundary with 3 links: R-,TA,TD-, that moves into neighboring box in next
                    % frame where it has 2 links: TD+,TN. Therefore, NO LINKS WERE TAGGED Jb- or Jb+ at any point. Hence, when running
                    % HLC2RC, the cell is detected as conserved also it was NOT in the box in the previous frame!!! An error on cell
                    % number balance is therefore detected, which causes also an error in the new (renormalized) tensor balance
                    
                    % Note that when R is ocurring with Jb, the neighboring cell will still have its own HL tagged R.
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    box_ijMatch_gone_IN_TF = ismember(box_ijMatch(:,1), box_is_gone_in);                              % HL candidate for Jb+
                    box_rokoMatch_going_OUT_TF = ismember(box_rokoMatch(:,1), box_ros_going_out);                     % HL candidate for Jb-
                    % Finding locations that are both Jb+/- AND changeable:
                    box_ij_Jplus_TF = all([box_HLC_changeable_TF box_ijMatch_gone_IN_TF],2);
                    n_Jplus_TF = sum(box_ij_Jplus_TF);
                    box_roko_Jminus_TF = all([box_HLCold_changeable_TF box_rokoMatch_going_OUT_TF],2);
                    n_Jminus_TF = sum(box_roko_Jminus_TF);
                    % Updating "box_HLC"/"grid_HLC" and "box_HLCold"/"grid_HLCold" with Jb+/- contributions:
                    box_HLC(box_ij_Jplus_TF) = num2cell(repmat('Jb+',n_Jplus_TF,1),2);
                    box_HLCold(box_roko_Jminus_TF) = num2cell(repmat('Jb-',n_Jminus_TF,1),2);
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    %%% Updating "grid_HLC" and "grid_HLCold" with Jb+/- contributions (1.1.2):
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    % Current:
                    box_ijMatch_Jplus = box_ijMatch(box_ij_Jplus_TF,:);                          % gets couples ij which contribution has been turned into Jb+
                    grid_ij_Jplus_TF = ismember(all_ijMatch, box_ijMatch_Jplus, 'rows');         % relocates them in all_ijMatch
                    gridHLC(grid_ij_Jplus_TF) = num2cell(repmat('Jb+',n_Jplus_TF,1),2);            % overwrites contributions in "grid_HLC" at the right locations
                    % Old
                    box_rokoMatch_Jminus = box_rokoMatch(box_roko_Jminus_TF,:);                  % gets couples roko which contribution has been turned into Jb-
                    grid_roko_Jminus_TF = ismember(all_iokoMatch, box_rokoMatch_Jminus, 'rows'); % relocates them in all_iokoMatch
                    gridHLCold(grid_roko_Jminus_TF) = num2cell(repmat('Jb-',n_Jminus_TF,1),2);   % overwrites contributions in "grid_HLCold" at the right locations
                    
                    % Update of boolean vectors keeping track of HL found in any box (2.1.6)
                    grid_HLC_TF(box_ijMatch_TF) = true;        % turns lines of HL ij into true
                    grid_HLCold_TF(box_rokoMatch_TF) = true;  % turns lins of HL ioko into true
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    %%% Storage in LINKS (moved 2.0.2):
                    %-----------------------------------------------------------------------------------------------
                    % Current quantities:
                    gridLINKS{ky,kx}.box_ijMatch = box_ijMatch;
                    gridLINKS{ky,kx}.box_Wijs = box_Wijs;
                    gridLINKS{ky,kx}.box_Lijs = box_Lijs;
                    gridLINKS{ky,kx}.box_LijPlots = box_LijPlots;
                    gridLINKS{ky,kx}.box_HLC = box_HLC;
                    
                    % Old quantities
                    gridLINKS{ky,kx}.box_rokoMatch = box_rokoMatch;
                    gridLINKS{ky,kx}.box_Wrokos = box_Wrokos;
                    gridLINKS{ky,kx}.box_Lrokos = box_Lrokos;
                    gridLINKS{ky,kx}.box_LrokoPlots = box_LrokoPlots;
                    gridLINKS{ky,kx}.box_HLCold = box_HLCold;
                    %-----------------------------------------------------------------------------------------------
                    
                    %%% Loading, calculating and updating tensor contributions FOR THIS BOX using "Tensor_Calculator":
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    boxTENSORS = gridTENSORS{ky,kx};
                    % getting CURRENT AND OLD numbers of non border cells (BASED ON RNs) actually in this box (1.4):
                    boxTENSORS.ncells = length(box_is);
                    boxTENSORS.ncells_old = length(box_ros);
                    HLCat = HLCplotstyle(:,1);                 % gets 1st column (2.0.3)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                   disp(['kx = ' num2str(kx) '; ky = ' num2str(ky)]); % DEBUG
                    [boxTENSORS, boxERROR] = CalculateTensors(gridLINKS{ky,kx}, iioMatch, HLCat, dtH, renormM);         %  added iioMatch 2.3.0, removed "renormType" (3.0)
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    RConds(ky,kx) = boxERROR.RCond;            % 2.0.5
                    errorPs(ky,kx) = boxERROR.errorP;          % 2.0.5
                    errorDnPs(ky,kx) = boxERROR.errorDnP;      % 2.0.5
                    
                    % For each tensor Q = G,S..., filling compartment (ky,kx) for fields XYs, Es, Angles
                    for c = 1:nMcat
                        mcat = MCatList{c};
                        eval(['Q = ' mcat ';']);                    % loading tensor mcat
                        Q(ky,kx,:) =  boxTENSORS.(mcat);           %#ok<SAGROW> % filling compartment ky,kx (2.1.7, 2.3.0)
                        eval([mcat '= Q;']);                        % update of contribution
                    end
                    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    
                    %%% Updating progressbar over compartment iteration (2.3.5)
                    progressbar([],b/nBoxes)

                end
                fprintf('Done.\n');
                
                %%% Overwritting "all_HLC/HLCold" entries in "grid_HLC/HLCold" with 'n/a' when HL are not involved (2.1.6)
                %---------------------------------------------------------------------------------------------------------------
                gridHLC(~grid_HLC_TF) = {'n/a'};           % overwrites with 'n/a' where HLs ij were not involved in any box
                gridHLCold(~grid_HLCold_TF) = {'n/a'};   % overwrites with 'n/a' where HLs ioko were not involved in any box
                %---------------------------------------------------------------------------------------------------------------
                
            end
            %---------------------------------------------------------------------------------------------------------------
            
            
            %%% Storage in structure GRID and saving backup file:
            %---------------------------------------------------------------------------------------------------------------
            fprintf(['Saving backup file "' nthBackupFilename '"...']); % mod 5.1, 5.3
            
            % Filling GRID with tensors:
            for c = 1:nMcat
                mcat = MCatList{c};
                eval(['Q = ' mcat ';']);                   % loading tensors 'G','S'... 
                GRID.(mcat) = Q;                            % storage in GRID
            end
 
            % GRID filling:
            GRID.LINKS = gridLINKS;
            GRID.HLC = gridHLC;
            GRID.HLCold = gridHLCold;
            GRID.LijPlots = gridLijPlots;
            GRID.Wijs = gridWijs;

            if n > startFrame
                GRID.LiokoPlots = gridLiokoPlots;
                GRID.Wiokos = gridWiokos;
            end
            
            % Finalizing AreaRatios (both L&E grids)
            if ~GRID_DEF.fullImage
                
                % Renormalization of RConds
                RCondsRaw = RConds;
                RConds = Normalizer(RConds,gridMaskTF, normalizeMethod);
            else
                gridAreaRatios = 1;
                RConds = 1;     
                RCondsRaw = RConds; 
            end
            
            % Storing AreaRatios (2.0.1):
            GRID.AreaRatios = gridAreaRatios;

            % Storing accuracy and error related quantities:
            GRID.RConds = RConds;
            GRID.errorDnPs = errorDnPs;
            GRID.errorPs = errorPs;
            GRID.RCondsRaw = RCondsRaw; % TO BE COMMENTED IN THE FUTURE

            % Saves Backup file:
            GRID_TA = orderfields(GRID);                   % Saving GRID under name "GRID_TA" in the backups (2.0.1), AND field sorted 3.0           
            save(nthBackupFile, '-struct', 'GRID_TA')      % removed '-v7.3' switch (2.1.3), removed FRAME (4.0), using "nthBackupFile" (5.1)
            fprintf('Done.\n')
            %---------------------------------------------------------------------------------------------------------------

        end 
        
    elseif displayHLC || ~exist(nextBackupFile,'file') % if NOT displayHLC, only loading current backup if next one does NOT exist (5.1)    
               
        %% HLC PLOT MODE : Loading backups and extracting structures %%
        
        %%% Loading nth SIA backup (5.1, moved up here 5.6)
        %---------------------------------------------------------------------------------------------------------------
        backupSIA = load([pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat),'.mat']);
        CELLS = backupSIA.CELLS;
        cellRNs = CELLS.Numbers;
        cellNeighbors = CELLS.Neighbors;
        cellCategoryTags = CELLS.CategoryTags;                                 % 5.5
        [coreRNs, extFLRNs, borderRNs] = GetCellCategories(cellCategoryTags);  % 5.5
        
        if ~isempty(gridType)
            extNonCoreRNs = setdiff(cellRNs, allGridCoreRNs);
            extFLRNs = setdiff(extNonCoreRNs, borderRNs);
        end
        %---------------------------------------------------------------------------------------------------------------
        
         if displayHLC % 5.1
             
             % Loading segmented images for HLC display:
             segImageFilename = [filename num2str(n, digitsFormat) '.' imageFormat];
             fprintf(['Loading image "' segImageFilename '"...'])
             segImage = imread([pathFolder filesep segImageFilename]);                  % loads CURRENT segmented image
             segImageLabels = GetImageLabels(segImage);                                 % REcreates the image labelled uint8 or uint16 according to the number of regions (5.6)
             fprintf('Done.\n')
             
         else % Case of nth backup found, BUT NOT THE NEXT ONE => loading additional backups to define OLD quantitites for next iteration

             %%% Loading txt files from C++ tracking (5.1)
             %---------------------------------------------------------------------------------------------------------------
             % Expanding nb Correspondence columns according to "max_n_divisions_nStart-nEnd.txt":
             CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
             Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); % using "FormatCorrespondence", (4.0)
             clear CorrespondenceRaw;
             % NB: all "Correspondence" arrays should therefore have the same number of columns
             
             coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
             coalescedRNs = coalescedRNs(coalescedRNs > 0);                                                  % removes -1 stored when empty txt file
             %---------------------------------------------------------------------------------------------------------------
             
             %%%% Loading this frame quantities from CTD backups (5.1)
             %---------------------------------------------------------------------------------------------------------------
             % Loading RNs that will DELAMINATE between n & n+1 from CTD backups (4.1)
             delaminatingRNsTF = allLastFramesDel == n;
             delaminatingRNs = allDelaminatingLastRNs(delaminatingRNsTF);
             
             % Loading RNs that will DIVIDE between n & n+1 from CTD backups (4.1)
             thisFrameDividingRowsTF = ismember(allLastFramesDiv, n);
             dividingRNs = allDividingLastRNs(thisFrameDividingRowsTF);
             %---------------------------------------------------------------------------------------------------------------
         end

         if isempty(gridType)
             
             % Loading (current, old, older) TA backup of full image processing (4.1)
             thisEnd = ['_' num2str(n, digitsFormat) '.mat'];
             fullPathTAbackup =      [rootFulImageTAbackup       thisEnd];
             
             if exist(fullPathTAbackup,'file')
                 fprintf('Loading this TA backup file...')
                 TAbackup2load = fullPathTAbackup;
                 
             else % 4.2
                 fprintf('ERROR: NO TA backup of full image processing could be found!!\n')
                 fprintf('Stopped execution.')
                 return
             end
             thisTAbackup = load(TAbackup2load);
             
             % Moved here (5.1)
             LINKS = thisTAbackup.LINKS;
             ExtractData(LINKS);
             
             nHL = size(all_ijMatch,1); % loading "nHL" (5.2)
             
             fprintf('Done.\n')
             
         else
             % Loading grid backup (4.1)
             thisFilename = [backupFolder filesep filenameTA '_' num2str(n,digitsFormat) '.mat'];
             thisTAbackup = load(thisFilename);
             % NB: different processing of grid backups (NOT looking for
             % older versions) because they're easy and fast to create.
             
             % Moved here (5.1)
             GRID = thisTAbackup;                    % stored as "GRID_TA" now (4.1)
             GRID.color = gridColor;                % overwrite before extraction (2.1.5)
             ExtractData(GRID,'grid');               % mod 5.0
         end
         
    else % 5.1
        disp(['Backups "' nthBackupFilename '" and the next one were found => skipped iteration!']) 
    end
    
    
    %% DISPLAY of HL categories on BOTH OLD AND CURRENT images %%
    
    %%% Image plot
    if displayHLC && n > startFrame % included "displayHLC" (5.1)
        
        if isempty(gridType)
            PLOT_HLC = LINKS; % mod 5.6
        else
            PLOT_HLC = GRID; % mod 5.6
        end

        % OLD image
        %-------------------------------------------------------------------------------------------------------------------------------
        thisFilename = [filenameTA '_' , num2str(n-1) 'i.' HLimageFormat];  % 2.1.3, moved up 5.0
        thisFilenameFull = [linkFolder filesep thisFilename];               % 5.0
        
        if ~exist(thisFilenameFull,'file')                                      % checking existence of image before proceeding (5.0)
            
            SAVE.use = 'old';
            SAVE.macroRNs = macroRNsOLD;    % 4.3
            SAVE.borderRNs = borderRNsOLD;  % 5.6
            SAVE.FLRNs = extFLRNsOLD;       % 5.6
            SAVE.segImageLabels = segImageLabelsOLD; % 5.6
            if strcmp(gridType,'L')
                SAVE.contourIndices = gridContourIndicesOLD;    % Stores Lagrangian centroids and contour indices of OLD frame (2.1.5), 4.1
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            DisplayHLCs(segImageOLD, PLOT_HLC, SAVE, n-1);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fprintf(['Saving image of Half-Link (HL) network "' thisFilename '"...']);
            if strcmp(HLimageFormat, 'pdf')
                thisFilenamePDF = [filenameTA '_' , num2str(startFrame) '-'  num2str(finalFrame) '.pdf'];
                if n == startFrame + 1
                    export_fig([linkFolder filesep thisFilenamePDF], '-pdf');                                              % overwrites existing file
                else
                    export_fig([linkFolder filesep thisFilenamePDF], '-pdf','-append');                                    % appends following pages
                end
            else
                print(['-d' HLimageFormat], printResolution, thisFilenameFull);
            end
            close
            fprintf('Done.\n')
        else
            disp(['Image "' thisFilename '" was found and was skipped.'])
        end
        %-------------------------------------------------------------------------------------------------------------------------------
        
        % CURRENT image
        %-------------------------------------------------------------------------------------------------------------------------------
        thisFilename = [filenameTA '_' , num2str(n) 'f.' HLimageFormat];    % 2.1.3, moved up 5.0
        thisFilenameFull = [linkFolder filesep thisFilename];               % 5.0
        
        if ~exist(thisFilenameFull,'file')                                      % checking existence of image before proceeding (5.0)
            
            SAVE.use = 'current';
            SAVE.macroRNs = macroRNs;              	% 4.3
            SAVE.borderRNs = borderRNs;             % 5.6
            SAVE.FLRNs = extFLRNs;                  % 5.6
            SAVE.segImageLabels = segImageLabels;   % 5.6
            if strcmp(gridType,'L')
                SAVE.contourIndices = gridContourIndices;    % Stores Lagrangian centroids and contour indices of CURRENT frame (2.1.5), 4.1
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            DisplayHLCs(segImage, PLOT_HLC, SAVE, n);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            fprintf(['Saving image of Half-Link (HL) network "' thisFilename '"...']);
            if strcmp(HLimageFormat,'pdf')
                thisFilenamePDF = [filenameTA '_' , num2str(startFrame) '-'  num2str(finalFrame) '.pdf'];
                export_fig([linkFolder filesep thisFilenamePDF], '-pdf','-append');
            else
                print(['-d' HLimageFormat],printResolution,thisFilenameFull);
            end
            close
            fprintf('Done.\n')
        else
            disp(['Image "' thisFilename '" was found and was skipped.'])
        end
        %-------------------------------------------------------------------------------------------------------------------------------
    end
    
    
    
    %% Updating OLD quantities with CURRENT ones for next iteration: CURRENT -> OLD (mod 5.1) %%
    
    if ~displayHLC && ~exist(nextBackupFile,'file') % only defining OLD quantities next backup does NOT exist (5.1)
        
        fprintf('Updating OLD quantities with CURRENT ones...')
        
        % Common to Full image and Grid processing:
        CorrespondenceOLD = Correspondence;
        coalescedRNsOLD = coalescedRNs;
        dividingRNsOLD = dividingRNs;           % UNcommented in 4.1
        delaminatingRNsOLD = delaminatingRNs;   % name update (4.1)
        cellRNsOLD = cellRNs;
        coreRNsOLD = coreRNs;
        extFLRNsOLD = extFLRNs;                 % "FLRNs" became "extFLRNs" (4.4)
        cellNeighborsOLD = cellNeighbors;
        
        if isempty(gridType)
            
            all_iokoMatch = all_ijMatch;
            all_Wiokos = all_Wijs;
            all_Liokos = all_Lijs;
            all_LiokoPlots = all_LijPlots;
            all_HLCold = cell(nHL,1);        % INITIALIZE AN EMPTY CELL ARRAY AT RIGHT SIZE "nHL" (that replaced "endRow" in 5.2)
            
        else % grid case
            
            % Grid specific quantities
            gridCoreRNsOLD = gridCoreRNs;
            gridWiokos = gridWijs;
            %                 gridLiokos = gridLijs; % COM 5.1
            gridLiokoPlots = gridLijPlots;
            % NB: no need to pass on "grid_HLC" and "grid_HLCold"
            % since these quantities are interframe specific and WILL BE REDEFINED in next iteration
        end
        fprintf('Done.\n');
        
    elseif displayHLC % 5.6
        
        % Updating OLD quantities related to display (moved here 5.6)
        segImageOLD = segImage;
        macroRNsOLD = macroRNs;                     % always need macroRNs, display or not (4.3)
        % new in 5.6
        segImageLabelsOLD = segImageLabels;
        borderRNsOLD = borderRNs;
        extFLRNsOLD = extFLRNs;
        if strcmp(gridType, 'L')
            gridContourIndicesOLD = gridContourIndices; % 4.1, moved here 5.6
        end
    end
    
    %% Updating progressbar over frame iteration:
    %-------------------------------------------------------------------------------------------------------------------
    iterationIndex = n-startFrame+1;                % 4.1
    if ~isempty(gridType) || displayHLC  
        progressbar(iterationIndex/nFrames)
    else
        progressbar(iterationIndex/nFrames,[])
    end
    disp('---------------------------------------------------------------------------------');
    %-------------------------------------------------------------------------------------------------------------------
    
end



%% History %%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FUTURE IMPROVEMENTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% - initial iteration over cells on full image is very slow => PARALLELIZE OR IMPROVE CODE
% - IMPLEMENT NEW RENORMALIZATION BY "M" RATHER THAN "Mc"
% - BALANCE ON ROTATION
% - UPDATE REPLOT MODE => REsave "(grid_)cell_ANs" WHEN IMPLEMENTING RESUME MODE
% - The first TA backup may introduce bias because (so far v3.2) it saves tensors being null (whereas they have not been calculated yet)
% and some AreaRatios that may be used for the calculation of the accurate one stored in next backup. Bottom line is first TA grid backup is
% NOT reliable and was NOT meant to be used in any calculation!!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 04/04/2019: 5.8
% - doing a crop before using "cell2mat" is because one gets a
% weird bug when concatenating EMPTY compartment of different
% sizes!! (1x0 vs 0x0!!)

% 16/10/2018: 5.7
% - fixed bug due to calling of old substructure "CATEGORIES" in "CELLS"
% (now replaced by "Categories").

% 26/07/2018: 5.6
% - "PLOT" became "PLOT_TA" in order not to overwrite PLOT defined in SAP
% - fixed issues related to the display of HLCs (wrong image, wrong grid
% contour...)
% - now displays borderRNs and extFLRNs in their specific colors when
% displaying HLCs

% 04/05/2018: 5.5
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"
% - fixed bug when resuming TA execution with existing backups: some paths
% to older versions of backups were only partially defined and were causing
% crash.

% 10/04/2018: 5.4 (stephane)
% - add if statement when loading SIA backup to manage differences between Matlab or C++ SIA generation

% 14/03/2018: 5.3
% - removed loading of backups with older names

% 15/02/2018: 5.2
% - direct determination of "all_ijMatch", "all_Wijs", "all_Lijs",
% "all_LijPlots" outside of first iteration loop.
% - direct definition of ACTUAL "nHL" as 2*nSides, thereby making "endRow" obsolete
% - continued changing variable names

% 14/02/2018: 5.1
% - now skipping calculations when nth AND (n+1)th TA backups are found
% - loading SIA backup, correspondence_XX.txt and TA backups when nth TA
% backup is found BUT next one is missing => drastically decreased
% execution when many TA backups already exist. (Tested by manual
% comparison of intitial and rebuilt backups in Matlab workspace)
% - now running in GRID mode as well (also skipping existing backups and HLC images)
% - now running in CLONE mode as well (skipping existing backups and HLC images)

% 13/02/2018: 5.0 (1st run OK, 2nd run on grid NOT tested)
% - adjustments to match new function names, new programs and Matlab 2017
% - dtH = dt/60 is now defined in AIA_parameters
% - skip HLC images already existing: will save a HUGE amount of time if
% many images have already been generated. ONLY works for HLC png images
% - changed some variable names

% 21/12/2017: 4.4
% - in grid mode, now excluding from tensor calculation links with RNs that do not belong any grid compartment, even
% when they are core RNs for the image. Therefore created an extended list of FLRNs "extFLRNs".
% - moved parameter "keepCoreFLHLs" out of AIA paramters, into TA because it was always set to false.

% 21/12/2017: 4.3
% - added loading and display of macrochaetaes
% - stopped loading all-time CTD backups at each frame (was a mistake)

% 20/12/2017: 4.2
% - cleaned up code by removing many huge commented parts that became obsolete with 4.0 upgrade and the determination of
% cell RNs in each compartments earlier in CPT rather than here in TA.
% - also removed many commented parts dealing with AreaRatios.
% - fixed bug that was plotting same cell links on many images when TA backups were not available anymore.

% 18/12/2017: 4.1
% - STOPPED loading "just_divided_cells_RN_XX.txt" files (to define "daughterRNs" and "daughterRNsMat") that do not pair
% daughter RNs properly.
% - STOPPED loading "dividing_cells_RN_XX.txt" files (to define "dividingRNs") that contains RNs corresponding to cells
% NOT dividing (most likely due to divisions cancelled by a tracking patch and not updated in the txt file).
% - Accordingly now defines "daughterRNsMat", "daughterRNs" and "dividingRNs" matrices from RELIABLE CTD backups.
% - stopped loading "delaminating_cells_XX.txt" files to define "delaminatingRNs", but rather use CTD backups.
% - "displayHLC" (that already existed) replaced "replot_TA" that disappeared
% - moved loading of CPT backups right at beginning of interation over frames
% - fixed display of Half Links that now works for full image (also with older backups), grid and clone.
% - cell link images now saved in "CellLinks" folder (instead of "Figures" before)

% 16/10/2017: 4.0
% - changes to make TA compatible with AIA_parameters 7.5+ and CPT backups
% - removed structure FRAME that was not used anymore
% - renamed lots of variables
% - removed email notifications when TA is done running
% - for simplicity, now takes AreaRatios of CPT (even if the former one involving the one of previous frame was slightly better)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% USE OF CPT BACKUPS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 13/10/2017:
% - CppTD became CTD

% 05/12/2016: 3.4
% - supports use of parameter "gridTime" (only relevant for L grids) to draw the grid on an ARBITRARY image/time
% - stopped including FL cells in the patches (why were they??) to only keep Core cells so LG and TA patches match
% - stopped using parameter "renormType" (not defined in AIA_parameters v6.7+ anymore)
% - compatibility with older version of TA that can be used to recaculate new grids with this version
% - removed unused variable "renormName" (related to "renormType")

% 06/07/2016: 3.3
% - removed "tag" and lines of code associated with Original resolution (matching SIA updated to 2.15)

% 28/04/2016: 3.2
% - "dt" used to calculate "DtH" (=dt/60) is now ALREADY CORRECTED ACCORDING TO TEMPERATURE THEREBY ALSO IMPACTING TENSOR RATES
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage

% 26/04/2016: 3.1
% - warning when grid processing AND nLayers = 0 to make sure it was set to 0 on purpose
% - now writes main parameter values in the text file that is saved at the beginning of each execution.

% 19/01/2016: 3.0


% 07/12/2015: 2.3.5 => combined with tracking 4.0, solved ALL TA balance errors and TRBL1 bug due to mismatch in Correspondence column nb!!
% - reverted change made in 2.3.4 because file is now RE-renamed "just_divided_cells_RN.txt" in tracking 4.0, as it used to be in tracking 3.6
% - removed addition of extra columns to deal with inaccuracy of "max_n_divisions_nStart-nEnd.txt" file (which was fixed in tracking 4.0)
% - in grid mode, added progressbar when iterating over grid compartments
% - in grid mode, replaced double loop over (kx,ky) by a single one over linear index b

% 04/12/2015: 2.3.4
% - change to support newly named file "justDividedCells_RN.txt" in tracking 4.0

% 30/07/2015: 2.3.3
% - fixed bug where "iioMatch" was not defined when keepCoreFLHLs = true.

% 02/07/2015: 2.3.2
% - support of "Phi" quantities (only PhiU so far) that need to be treated specialy because they are 2D matrices of scalars
% - added animal name in iteration bar

% 26/06/2015: 2.3.1
% - fixed 1st call to "CalculateTensors" that had the "iioMatch" argument missing

% 24/06/2015: 2.3.0 *** INTRODUCTION OF U *** 

% 26-28/05/2015: 2.2.1 **USE OF "Normalizer" v1.4 WITH THRESHOLD @ 0.01 IN "AreaRatios"**
% - changed parameter names to match AIA_parameters 6.0
% - fixed initialization of progressbar when execution was skipped due to existence of last backup.
% - removed requirement to be in NON-replot mode so as NOT display the grid being used: now only "gridValidation" parameter matters
% - parameter "normalizeAR" became "normalizeMethod" and was transfered to AIA_parameters

% 21/05/2015: 2.2.0 *** REMOVED "BETA" TAG ***
% - accordingly now calls "CalculateTensors" instead of "CalculateTensorsBETA"
% - calls to "FindOuterLayers" instead of "FindLayerIndices"

% 29/04/2015: 2.1.13
% - storage of "minimalInfoDisplay" in SAVE to only display time APF and scalebar (and not the quantity being plotted nor the frame number)

% 20/04/2015: 2.1.12 *** Function "Normalizer" UPDATED ***
% - fixed bug preventing Replot mode to plot links because (obviously) last backup was found => was skipping execution
% - Function "Normalizer" used to renormalize AreaRatios and RConds was updated (to 1.3) replacing NaNs with 0s since we don't want NaNs when
% defining weights => may change some results ??
% - introduced time threshold before sending email notification (2h)
% - removed CTaddon from pdf names

% 16/04/2015: 2.1.11
% - moved out parameter "nLayers" to "AIA_parameters" because it has to change according to the grid used (Cannot remove 3 layers when the
% grid only has 3x3 compartments!)
% - removed some comments around locations where AreaRatios are normalized.

% 14/04/2015: 2.1.10
% - Skips execution when LAST backup already exists (full image OR grid mode)

% 08/04/2015: 2.1.9
% - strengthened "AreaRatios" decay at boundaries: now takes mininum value between current and old frame
% - stopped saving "allFilteredTF" by mistake
% - renamed "AreaRatios_current" to "AreaRatiosRaw"
% - set ncol_extra = 1 because of unmatching number of col in Correspondence(_old) bug encouterd again in BIG1 and BIG5Nm.

% 07/04/2015: 2.1.8
% - removed extra filtering by "GlobalFilter" since did not solved the huge tensor values in a box at grid boundaries.
% - the problem came from using onlyCore_TF boolean that is IRRELEVANT with lagrangian grids, since after some time, a
% box can be made up by a single core cell!! This occurs when cells are leaving the box, becoming border, to only leave
% one or two cells of this box, then inward flux of cell may keep this cell as core. Therefore, it is really bad to
% assign value 1 to AreaRatios and RConds at these locations.
% - fixed this issue by using "maskTF" instead that only has 1s in the bulk of the animal (removed nLayers = 3 layers of
% boxes) => won't keep values RConds of 10^(-17) by doing so!!
% - use of new function "FindLayerIndices" to determine "maskTF"

% 06/04/2015: 2.1.7
% - added additional filtering of extreme data points with "GlobalFilter" with criterion of 1000*std(|Q|), the std being
% evaluated over the "bulk" values where only core cells make up the boxes. Corresponding AreaRatios are then put to 0.
% - now all quantities EG,ER,ES... are 3D matrices directly containing the XYs instead of being structures containing
% the 3D matrices XYs,Es,Angles.

% 06/04/2015: 2.1.6
% - fixed bug in grid mode that was always considering Eulerian grid bounds (even in LGrid!) leading to wrong drawing of
% HL in cells lying outside LGrid boxes, and absence of HL of some cells lying inside Lboxes. Was due to bad definiion
% of "grid_HLC(_old)" (initialized as "all_HLC(_old)") where the subset of HL overridden with 'n/a' was wrong.
% - stopped using variable "outside_grid_cell_RNs(_old)" accordingly

% 03/04/2015: 2.1.5
% - support of HL display on Lagrangian grid, updated "DisplayHLCs" accordingly to v3.1.

% 02/04/2015: 2.1.4: *** stopped saving "grid_cell_ANs" (saved as "cell_ANs") in backups which will be required for resume mode ***
% - REset ncol_extra = 0 to avoid creating a lot of unncessary offspring cells which slows down execution. The encountered bug in BIG1 may
% have come from unmatch between segmented image and listed regions (segmented images had been modified after SIA had been run)
% - stopped saving array "cell_ANs" in GRID_TA (LGrid only) that used to take a huge amount of space and was not used when reloaded.
% - removed '-v7.3' when saving GRID_TA accordingly

% 31/03/2015: 2.1.3
% - override of R- by N- (full image and grid processing, checked on wt2NEW)
% - fixed bug where Jb was overriding A+/- (and N+/-)
% - improved naming of frames displaying HLC: now saved as couples "(n-1)i"-"nf", "ni"-"(n+1)f",... => now number of filenames and frames match
% - improved email notification
% - added '-v7.3' to be able to save GRID_TA in backups for BIGwt2 that now weight about 500 MB on the hard drive and more than 2GB in the
% workspace, almost entirely due to cell_ANs and LINKS arrays.

% 30/03/2015: 2.1.2
% - override of R+ by A+ OK (both full image AND grid processing)
% - support of older backups: IN GRID MODE, now first updates all_HLC(_old) with UpdateHLCs when older versions are
% detected, then overrides R+ with A+.

% 27/03/2015: 2.1.1 
% - fixed issues in override of R+ by A+. (full image processing)

% 26/03/2015: 2.1.0
% - override of R+ to A+: works but misses some A+ when a cell has several apoptotic cells
% - introduction of G, A+/-, N+/-, TA- and TN+
% - removed some commented parts 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTRODUCTION OF A+/-, N+/-, TA- and TN+ (TA 2.1+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 21/03/2015: 2.0.16
% - saving txt file indicating date and version used in "Save_folder"
% - adding leeway of ncol_extra = 3 columns in Correspondence BECAUSE "max_n_divisions_" txt file is not reliable
% - added display of execution steps in workspace (tagged 2.0.15)
% - removed code history prior to 04/09/2014: 1.3.6

% 21/03/2015: 2.0.15 (NOT working)
% - attempt of parallelization of iteration over grid compartments

% 20/03/2015: 2.0.14
% - calculation of AreaRatios for Lagrangian grid based on ratio of numbers of core cells in Lbox.
% - using Normalizer with method = mean (tested max and min on full TRBL8)

% 17/03/2015: 2.0.13 IMPLEMENTED CHANGE IN ASSIGNMENT OF Jb (WHEN USING GRIDS)
% - implemented change in assignement of Jb: now overriding ALL HL to Jb+/- for a cell changing boxes, and NOT just the conserved HL, ie
% overriding, TD+/-, TA, TN, R+/-, B, B/R+/- and NOT just B, B/R+/- as before
% - support of HL plot for old full image backups

% 12/03/2015: 2.0.12
% - fixed "ismember" bug by replacing "ismember" by "strcmp" when looking for contribution letters ('F','n/a'...) in
% cell arrays all_HLC...
% - fixed wrong naming of Grid subfolder after PIVgrid instead of CppT_PIVgrid.
% - definition of "CppT_PIVgrid" moved into AIA_parameters

% 10/03/2015: 2.0.11
% - FULL IMAGE PROCESSING IS NOW ALWAYS CARRIED OUT WITH ALL HLs; PARAMETER "keepCoreFLHLs" IS NOW ONLY APPLIED IN GRID
% PROCESSING. WHEN keepCoreFLHLs = 0 NOTHING SPECIFIED IN BACKUP FOLDER NAME, WHEREAS keepCoreFLHLs =1 ADDS A "allHLs"
% tag in folder names.
% - checked results were the same as the one obtained in 2.0.9,10

% 06/03/2015: 2.0.10 BUG WITH "keepCoreFLHLs=0" FIXED!
% - FINISHED FIXING MISTAKE WHEN USING keepCoreFLHLs = 1 FOR J+ AS WELL (see commments in code) (Tested with "J+Test"
% Potts simulation)

% 06/03/2015: 2.0.9
% - changed parameter "Remove_CoreFLHLs" into "keepCoreFLHLs"
% - "renorm" became "renormType"

% 05/03/2015: 2.0.8
% - FIXED MISTAKE WHEN USING Remove_CoreFLHLs = 1 FOR J- ONLY SO FAR (see commments in code)
% - supports HLdisplay with grid
% - saving "display_naHL" in SAVE
% - fixed bug with progress bar

% 04/03/2015: 2.0.7: FOUND MISTAKE WHEN Remove_CoreFLHLs = 1!!
% - adjustments to saving into separate folders results of analysis wether Remove_CoreFLHLs = 1 or 0
% - many changes to support plots of HL categories with new function "DisplayHLCs"

% 02/03/2015: 2.0.6
% - use function Normalizer to renormalize AreaRatios and RConds
% - checks there is something to plot before creating Figure folder (2.0.6)

% 27/02/2015: 2.0.5
% - renormalizes "AreaRatios_old" (for initial frame treatment) to keep values in [0 1], which fixes bug where some
% values of AreaRatios at later times were > 1
% - replaced "TA_plotstyle" by "Mcat_list".
% - adjustments to make it run with latest "CalculateTensors" (2.0.5)
% - fixed AreaRatio bug due to wrong filling of OnlyCoreCells_TF
% - Gets total execution time and sends email notification once TA is done running.

% 25/02/2015: 2.0.4
% - initialization of AreaRatios with zeros instead of NaN: non NaN should be in AreaRatios!
% - support of old full image backups to avoid recomputation
% - stopped calculating and storing (in LINKS) all_Mijs, all_Miokos, box_Mijs, box_Mrokosbecause can be done direclty
% from all_Lijs,all_Liokos, box_Lijs, box_Lrokos with "Mij_Maker" in CalculateTensors. The idea is to do the same with
% upcoming Cij_Maker which will enable to use old backups of full image to do new renormalizations.

% 24/02/2015: 2.0.3
% - supports new names of parameters in AIA_parameters changed for compatibility with AOT processing
% - stopped calculating tensors for whole image => backups are common to ALL renormalizations, just containing the
% sorting of Half-Links (HL) in LINKS.
% - removed "Backup" from all backup file names (will solve AOT issue with TA backups).

% 21/02/2015: 2.0.2
% - look for 2.0.2 to see changes
% - removed new commented part on determination of number of cells created by each process

% 18/02/2015: 2.0.1: started implementation of new renormalized framework
% - look for 2.0.1 to see changes

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NEW FRAMEWORK RENORMALIZATION (TA 2.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 18/02/2015: 1.4.2
% - line_width_TA -> link_width_TA ; ellipse_line_width -> line_width_TA
% - included "scalebar_width" in SAVE

% 21/09/2014: 1.4.1
% - extracts and save B tensor ONLY WHEN REPLOT AND centered mean are selected. Motivation is to build Bstack for correlation
% with strain rate

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 19/09/2014: 1.4 TEST OF INTENSIVE TENSORS
% NB: **ONLY** MODIFIED PROGRAM IS "Tensor_Calculator" UPDATED TO VERSION 1.6
%     => simply switch back Tensor_Calculator 1.5 for EXTENSIVE tensors
% - in "Tensor_Calculator" 1., tensores are now Q = 1/ncells*sum(gained) - 1/ncells_old*sum(lost)
% - now excludes "Border_cells" from "box_cell_RNs" in EGrid as well
% - renamed "n_cells" to "N_cells" = total number of cells (including Border cells)
% - stores "ncells" and "ncells_old" in TENSORS (number of Non Border cells) or
% box_TENSORS (number of Non Border cells in the box) when Grid processing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 10/11/2011: creation

