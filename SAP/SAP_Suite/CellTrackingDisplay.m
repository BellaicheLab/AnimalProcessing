% CellTrackingDisplay
%
% Illustrates results of the C++ tracking with images displaying division rounds with shades of greens (colorDivision),
% coalesced cells (colorFustion), macrochaetae (when available in colorMacrochaetes), and divisions that occured sooner
% than "minCycleDuration" (colorDivisionIssue). 

%This WITHOUT SIA backups, so it can run right after the cell tracking.
% --> THIS IS WRONG ! WHEN THERE IS AN SIA BACKUP, IT WILL USE IT !
% 
% Generate backups macroCells.mat, allDelaminatingCells.mat, allDividingCells.mat, allDividingCellsSIA.mat, 
% allOtherCells.mat, and allNewJunctions.mat.
%
% NB: "allDelaminatingCells.mat" and "allDividingCells.mat"  backups require full iteration over all frames to be
% completed (but NO SIA backups). ONLY "allNewJunctions.mat", and "allDividingCellsSIA.mat" requires ALL SIA backups
% to make junction RN couples available, and to determine matrices "allSisterCentroidXYs" and "allSisterJunctinonXYs".
%
% NB: for new junctions, the backup contains the list of ANs couples (making up junctions) THAT DID NOT EXIST *AT THE
% BEGINNING OF THE MOVIE* "allNewCoupleANs" AND the frames at which those couples were born IN THEIR EARLIEST VERSION,
% namely keeping couple/junction identity when a cell divides. The filtering of links according to time of appearance
% "newJunctionStartTime" and through which process (T1 or Division) is done right before the plot using function
% "FindCoupleANs".
% NB: Existing before, "allNewJunctionCoupleANs" is very redundant with "allNewCoupleANs" but it is associated with 
% "allNewJunctionLengths" giving history of lengths of junctions for each new AN couples listed in
% "allNewJunctionCoupleANs".
%
% NB: nDiv*2 matrix "allSisterFirstRNs" (in "allDividingCells.mat") now constains RELIABLE couples of sister RNs (sister 1
% listed first) for each divided ANs as they appear. Those RNs naturally corresponds to regions in frames
% allLastFramesDiv + 1, as sisters appear in frame following mother cell disappearance.
% *** Enables to stop using UNRELIABLE "just_divided_cells_RN_XX.txt" file. ***
%
% NB: same for nDiv*1 matrix "allDividingLastRNs" (in "allDividingCells.mat") now contains RELIABLE list of dividing
% RNs, namely last RNs of dividing mother cells.
% *** Enables to stop using UNRELIABLE "dividing_cells_RN_XX.txt" file. ***
%
% Boris Guirao
version = '2.31';

%#ok<*AGROW>


%% Checking existence of last frames of requested plots AND backup completion before running (overhaul 2.1) %%

disp(' '); disp(' ');
disp(['CTD' ' ' version  ': processing "' Animal '": initialization']);
disp('---------------------------------------------------------------------------------');

% Defines directories:
saveFolder = pathFolderCTD;
saveFolderTracking = [saveFolder filesep 'Tracking_tB4Del=' num2str(timeB4Del) 'h' junctionTag]; % 1.32, 2.12, 2.14
saveFolderProliferation = [saveFolder filesep 'Proliferation_nDivMax=' num2str(nDivMax)];        % 1.32
saveFolderDelamination = [saveFolder filesep 'Delamination_nDelMax=' num2str(nDelMax)];          % 1.32

% Determining whether program must iterate to plot images
%----------------------------------------------------------------------------------------------------------------------
% Checking existence of last image for each type of plots
lastCTDimage = [saveFolderTracking filesep filenameCTD '_' num2str(finalFrame, digitsFormat) '.' imageFormatOutput];
if exist(lastCTDimage,'file') && makeCTDimages      % last CTD image EXISTS and CTD generation was requested
    fprintf('WARNING: all "CTD" images already exist! Skipping plot.\n')
    makeCTDimages = false;  % overriding
    
elseif makeCTDimages
    fprintf('CTD images will be generated.\n')
end

lastDivImage = [saveFolderProliferation filesep 'Proliferation_' Animal '_' num2str(finalFrame, digitsFormat) '.' imageFormatOutput];
if exist(lastDivImage,'file') && makeDivImages
    fprintf('WARNING: all "Proliferation" images already exist! Skipping plot.\n')
    makeDivImages = false;  % overriding
    
elseif makeDivImages
    fprintf('Proliferation images will be generated.\n')
end

lastDelImage = [saveFolderDelamination filesep 'Delamination_' Animal '_' num2str(finalFrame, digitsFormat) '.' imageFormatOutput];
if exist(lastDelImage,'file') && makeDelImages
    fprintf('WARNING: all "Delamination" images already exist! Skipping plot.\n')
    makeDelImages = false; % overriding
    
elseif makeDelImages
    fprintf('Delamination images will be generated.\n')
end

images2plotTF = [makeCTDimages ; makeDivImages ; makeDelImages];    % user request in AIA_parameters
%NB: for a plot to occur, images must both have been requested AND have the last one NOT existing

images2plotTF = any(images2plotTF); % 1 if just one image type to plot => iteration required
%----------------------------------------------------------------------------------------------------------------------


% Defining paths to backups and map images
%----------------------------------------------------------------------------------------------------------------------
% paths to TEMP version of delamination, division and macro backups:
allDelaminatingCellsTEMPfile = [saveFolder filesep 'allDelaminatingCellsTEMP.mat'];   % 2.1
allDividingCellsTEMPfile = [saveFolder filesep 'allDividingCellsTEMP.mat'];           % 2.1
macroCellsTEMPfile = [saveFolder filesep 'macroCellsTEMP.mat'];                       % 2.2

% paths to COMPLETE versions of delamination, division and macro backups:
allDelaminatingCellsFile = [saveFolder filesep 'allDelaminatingCells.mat'];   % moved out of the if (1.17)
allDividingCellsFile = [saveFolder filesep 'allDividingCells.mat'];           % 1.27
macroCellsFile = [saveFolder filesep 'macroCells.mat'];                       % 1.25
allDividingCellsSIAfile = [saveFolder filesep 'allDividingCellsSIA.mat'];     % 2.8
allOtherCellsFile = [saveFolder filesep 'allOtherCells.mat'];               % 2.9

% path new junctions backup:
allNewJunctionsFile = [saveFolder filesep 'allNewJunctions.mat'];           % moved up 2.1
% allLostANsFile = [saveFolder filesep 'allLostCells.mat'];                 % 1.32, commented 2.1`

% path to global map images:
delaminationMapFile = [saveFolder filesep 'Delamination_map_' Animal  '.' imageFormatOutput];
divisionMapCoMsFile = [saveFolder filesep 'DivisionCoMs_map_' Animal  '.' imageFormatOutput];
divisionMapJsFile = [saveFolder filesep 'DivisionJs_map_' Animal  '.' imageFormatOutput];       % 2.1

% path to CTD,  last image (2.22)
lastCTDimage = [saveFolderTracking filesep filenameCTD '_' num2str(finalFrame, digitsFormat) '.' imageFormatOutput];

% file existence logical vector:
backupsAndMapsExistTF = [exist(allDividingCellsFile,'file') ; exist(allDividingCellsSIAfile,'file') ; ...
                        exist(allDelaminatingCellsFile,'file') ; exist(delaminationMapFile,'file'); ...
                        exist(allOtherCellsFile,'file');...             % 2.9
                        exist(allNewJunctionsFile,'file');...           % 2.16
                        makeCTDimages & ~exist(lastCTDimage,'file');... % if CTD images are requested AND last image does NOT exist (2.22)
                        exist(divisionMapCoMsFile,'file') ; exist(divisionMapJsFile,'file') ]; % DIVISION MAPS MUST REMAINS AT THE LAST TWO LOCATIONS!!
% NB: NOT adding "macroANsFile" here in case the txt does NOT exist
%----------------------------------------------------------------------------------------------------------------------


% ALWAYS checking availability of SIA backups
%----------------------------------------------------------------------------------------------------------------------
oneSIAbackupMissingTF = false; % default
fprintf('Checking availability of ALL SIA backups...')
for n = startFrame:finalFrame
    nthSIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat) '.mat'];
    if ~exist(nthSIAbackupFile,'file')
        oneSIAbackupMissingTF = true;
        fprintf(['SIA backup # ' num2str(n,digitsFormat) ' is missing!\n'])
        break
    end
end
allSIAbackupAvailableTF = ~oneSIAbackupMissingTF;

if allSIAbackupAvailableTF
    fprintf('Done.\n')
    
elseif ~isempty(junctionTag)
    % erase "junctionTag" & update "saveFolderTracking" if some SIA backup are NOT available (2.20)
    disp('WARNING: "junctionTag" has been reset to empty because all SIA backups are NOT available!')
    junctionTag = [];
    saveFolderTracking = [saveFolder filesep 'Tracking_tB4Del=' num2str(timeB4Del) 'h' junctionTag];
end
%----------------------------------------------------------------------------------------------------------------------


% Checking if delamination and division backups are complete (2.1,2.2)
%----------------------------------------------------------------------------------------------------------------------
macroBackupCompleteTF = false;
if exist(macroCellsFile,'file')
    macroBackupCompleteTF = true;
else
    fprintf('Macrocaetaes complete backup file was NOT found.\n')
end
% NB: macrochaetae backup CANNOT be complete without iteration over ALL frames

delBackupCompleteTF = false;
if exist(allDelaminatingCellsFile,'file')
    delBackupCompleteTF = true;
    load(allDelaminatingCellsFile); % moved here 2.15
    fprintf('Delamination complete backup file was FOUND and loaded.\n')
else
    fprintf('Delamination complete backup file was NOT found.\n')
end
% NB: delamination backup CANNOT be complete without iteration over ALL frames

divBackupCompleteTF = false;
if exist(allDividingCellsFile,'file')
    divBackupCompleteTF = true;
    load(allDividingCellsFile); % moved here 2.15
    fprintf('Division complete backup file was FOUND and loaded.\n')
else
    fprintf('Division complete backup file was NOT found.\n')
end
% NB: division backup CANNOT be complete without iteration over ALL frames

divSIAbackupTF = false;
if exist(allDividingCellsSIAfile,'file')
    divSIAbackupTF = true;
    load(allDividingCellsSIAfile); % moved here 2.15
    fprintf('Division SIA backup file was FOUND and loaded.\n')
else
    fprintf('Division SIA backup file was NOT found.\n')
end
% NB: division SIA backup requires backup from SIA


% Make SIA division backup ?
makeDivSIAbackupTF = false;
if ~divSIAbackupTF && allSIAbackupAvailableTF
    
    makeDivSIAbackupTF = true;
    fprintf('Division SIA backup was NOT found AND ALL SIA backups were found.\n')
    
elseif ~divSIAbackupTF && ~allSIAbackupAvailableTF
    
    fprintf('Division SIA backup was NOT found AND CANNOT be generated as some SIA backups are missing.\n')
    backupsAndMapsExistTF = backupsAndMapsExistTF(1:end-2); % removes tests on division maps that require SIA backups since still cannot be make (2.8)
end

% 2.14, 2.16
newJuctionBackupTF = false;
if exist(allNewJunctionsFile,'file')
    
    newJuctionBackupTF = true;
    load(allNewJunctionsFile); % 2.15
    fprintf('New junction backup file was FOUND and loaded.\n')  
else
    fprintf('New junction backup file was NOT found.\n')
end

makeNewJunctionsBackupTF = false; % default
if ~newJuctionBackupTF && nInterFrames > 0 % added "nInterFrames > 0" (2.28)
    
    if allSIAbackupAvailableTF
        
        makeNewJunctionsBackupTF = true;
        fprintf('New junction backup was NOT found AND ALL SIA backups were found.\n')
    else
        fprintf('New junction backup was NOT found AND CANNOT be generated as some SIA backups are missing.\n')
    end
end

%----------------------------------------------------------------------------------------------------------------------

% will do 1ST frame iteration:
% if 1+ CTD all-time backup does not exist, EVEN in its TEMP version:
firstFrameIterationTF = (~exist(allDelaminatingCellsFile,'file') && ~exist(allDelaminatingCellsTEMPfile,'file')) || ...
                        (~exist(allDividingCellsFile,'file') && ~exist(allDividingCellsTEMPfile,'file')) || ...
                         ~exist(allOtherCellsFile,'file');      % 2.17, some "&&" became "||" (2.20)

% will do 2ND frame iteration:
% (i) there are images to plot; (2) delamination backup is NOT complete; (3) division backup is NOT complete AND all SIA backups are available:
secondFrameIterationTF = any([images2plotTF ; ~delBackupCompleteTF ; ~divBackupCompleteTF ; makeDivSIAbackupTF ; makeNewJunctionsBackupTF]); % 2.8, 2.14

% stopping execution if NO iteration to make, AND all backup and maps already exist
if ~secondFrameIterationTF && all(backupsAndMapsExistTF,1)
    fprintf('WARNING: ALL requested images and maps already exist and backups are complete!\n')
    fprintf('Execution skipped. Please erase some files for CTD to rerun.\n')
    disp('---------------------------------------------------------------------------------');
    return
    
elseif secondFrameIterationTF
    fprintf('CTD will iterate over all frames to generate images OR to complete backups.\n')
end

mkdir(saveFolder); % creates folder after checking it's running (1.10)

%% Determination of "nCells0" (2.21) %%

nCells0 = GetnCells0(trackingFolder, startFrame);

%% Saving parameter txt file (moved 2.17) %%

if firstFrameIterationTF || secondFrameIterationTF % 2.17
    
    today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style
    txtFilename = [today '_CTD_' version '.txt'];
    
    % Writing main parameters in txt file
    parameterCell = {
        'Main Parameters:',[];
        [],[];
        'startFrame = ', startFrame;                                    % 2.1
        'finalFrame = ', finalFrame;                                    % 2.1
        'PIVgrid = ' PIVgrid;                                           % PIV used for the tracking (1.32)
        'maxDivisionRound = ', maxDivisionRound;                        % number loaded from "max_n_divisions_X-X.txt' file (2.7)
        'nCells0 = ', nCells0;                                        
        'displayNewT1Junctions = ', displayNewT1Junctions;              % 2.16
        'displayNewDivJunctions = ', displayNewDivJunctions;            % 2.16
        'newJunctionStartTime = ', num2str(newJuncDisplayTimes);        % 2.14, 2.17
        'timeB4Del = ', timeB4Del;                                      % 2.12
        'minCycleDuration = ', minCycleDuration;                        % 2.7
        'displayCellNumbers = ', displayCellNumbers;
        'displayPatchedCellNumbers = ', displayPatchedCellNumbers;
        'displayJustDividedCellLinks = ', displayJustDividedCellLinks};
    
    dlmcell([saveFolder filesep txtFilename], parameterCell,' ');
end

%% Determination of MACROCHAETES ANs %%

% Copied/Pasted from ClickLandmarks => could be included in AIA_parameters and used in both
%-------------------------------------------------------------------------------
nMacroMax = 8;  % Default number of macrochaeteae to click for half notum (1.4)
if halfNotum == 'l'
    sideStr = 'LEFT';
elseif halfNotum == 'r'
    sideStr = 'RIGHT';
else
    sideStr = 'BOTH';
    nMacroMax = 16;         % increased from 14 to 16 to be consistent with half notum treatments (1.4)
end
clickFrame = time2frame(clickTime, timeRef, frameRef, dt);
clickFrame = round(clickFrame);         % rounding up to ensure it is always an integer
%-------------------------------------------------------------------------------

macroClickFile = [pathFolderSR filesep 'Macro_XYs_' Animal '.txt']; % 2.22
foundMacroClickFileTF = exist(macroClickFile,'file');               % 2.1

if foundMacroClickFileTF % macrochaetaes were clicked and file was found
    
    if ~exist(macroCellsFile,'file') && ~exist(macroCellsTEMPfile,'file') % 1.31, TEMP case (2.2)
        
        fprintf('\nDetermining ANs of macrochaetes...\n')
        
        clickedMacroXYs = dlmread(macroClickFile); % retrieves clicked macro XY coordinates IN PIXELS from txt file
        
        % Loading "clickFrame" image
        %-----------------------------------------------------------------
        uSegImage = imread([pathFolder filesep filename num2str(clickFrame, digitsFormat) '.' imageFormat]);
        imageLabels = GetImageLabels(uSegImage); % REcreates image labelled uint8 or uint16 according to the number of regions (1.29), use of GetImageLabels (2.0)
        nCellsClickedFrame = max(imageLabels(:)); % 1.29
        %-----------------------------------------------------------------

        % Loading "Correspondence" && "coalescedCells" for clickFrame
        %-----------------------------------------------------------------
        CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(clickFrame) '.txt']);
        Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); % 1.32
        clear CorrespondenceRaw;
        % Loading "coalescedCells" (1.29)
        coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(clickFrame) '.txt']);
        %-----------------------------------------------------------------
        
        % Finding macrochaetes ANs IN FIRST FRAME (1.25, 1.29)
        %-----------------------------------------------------------------
        clickedMacroIndices = sub2ind(imageSize, clickedMacroXYs(:,2), clickedMacroXYs(:,1));
        
        clickedMacroTF = ~isnan(clickedMacroIndices); % finds those clicked among the 16 possible
        nMacro = sum(clickedMacroTF);
        
        clickedMacroIndices = clickedMacroIndices(clickedMacroTF); % cropping
        
        macroTypes = find(clickedMacroTF); % list of macro numbers from 1 to 16
        macroANs = NaN(nMacro,nColTotal-1);
        
        nMacro2find = nMacro;
        for c = 0:nCellsClickedFrame % starts at 0 to check skeleton (30)
            
            cTF = ismember(imageLabels,c); % 1.29
            cIndices = find(cTF);
            [~,macroLoc] = ismember(cIndices, clickedMacroIndices);
            macroLoc = macroLoc(macroLoc > 0);
            nMacroLoc = length(macroLoc);
            
            if nMacroLoc > 0 && c == 0              % Case of macro clicked on skeleton !! (1.30)
                disp('The following clicked macrochaetes belong to the skeleton!')
                disp(num2str(macroTypes(macroLoc)));
                nMacro2find = nMacro2find - nMacroLoc;
                
            elseif nMacroLoc > 0 && ~ismember(c, coalescedRNs) % checking not among coalesced cells (1.29)
                macroANs(macroLoc,:) = RNs2ANs(c, Correspondence); % this macro AN
                nMacro2find = nMacro2find - 1;
                fprintf(['Found AN of macrochaete # ' num2str(macroTypes(macroLoc)) '! Still looking for '...
                    num2str(nMacro2find) ' clicked macrochaetes...\n'])
                
            elseif nMacroLoc > 0
                disp('The following clicked macrochaetes belong to a coalesced region!')
                macroTypes(macroLoc)
                nMacro2find = nMacro2find - nMacroLoc;
            end
            
            if nMacro2find == 0
                break
            end
        end
        %-----------------------------------------------------------------
        
        save(macroCellsTEMPfile,'macroANs','macroTypes','clickedMacroIndices','clickFrame','clickTime'); % Temp file (2.2)
        
        macroRNs = NaN(nMacro,finalFrame);
        
    elseif exist(macroCellsTEMPfile,'file') % 2.2
        
        fprintf('File "macroCellsTEMP.mat" was found and is loading...')
        load(macroCellsTEMPfile);
        nMacro = size(macroANs,1);
        macroRNs = NaN(nMacro,finalFrame);
        
    elseif exist(macroCellsFile,'file') % 1.31
        
        fprintf('File "macroCells.mat" was found and is loading...')
        load(macroCellsFile)   
    end
    fprintf('Done.\n')
    
else
    fprintf('No txt files of clicked macrochaete were found => not processing macrochaetes.\n')
    macroANs = []; % 2.2
end

%% 1ST ITERATION OVER FRAMES (2.13) %%

% NB: checking that at least one backup file is missing before iterating

% 2.27
if exist(pathFolderTMP,'dir')
    if ~exist(pathFolderTCTD,'dir')
        mkdir(pathFolderTCTD)
    end
end

if firstFrameIterationTF
    
    fprintf('\nDetermination of complete lists of DELAMINATING, DIVIDING and OTHER ANs...');
    
    if PLOT.displayImages == "on"
        progressbar('CTD: determination of lists of DELAMINATING, DIVIDING and OTHER  ANs...');
    end
    
    for n = startFrame:finalFrame
        
        %% Loading of common cell tracking txt files %%
        
        CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
        Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); % 2.1
        clear CorrespondenceRaw;
        nRow = size(Correspondence,1);                   % current number of rows
        nCol = size(Correspondence,2);                   % current number of columns
        
        % loading borderRNs, neighborRNs, coalescedRN sand inferring FLRNs:
        borderRNs = dlmread([trackingFolder filesep 'border_cells_RN_' num2str(n) '.txt']);
        neighborRNs = dlmread([trackingFolder filesep 'neighbours_RN_' num2str(n) '.txt']);
        FLRNs = FindFirstLayerRNs(borderRNs, neighborRNs);
        excludeRNs = [borderRNs ; FLRNs];                           % namely NON CORE
        
        coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
        coalescedRNs = coalescedRNs(coalescedRNs > 0);                                                    % removes -1 stored when empty txt file
        
        cellRNs = Correspondence(:,1);      % moved up here (2.20)
        cellANs = Correspondence(:,2:end);
        
        %% Determination of complete list of DELAMINATING cells PART 1/2 %%
        
        if ~exist(allDelaminatingCellsFile,'file') && ~exist(allDelaminatingCellsTEMPfile,'file') % mod 2.1
            
            if n == startFrame
                nDelANsMax = 3*nRow;                                    % taking more leeway to prevent crashes (1.31)
                allDelaminatingANs = zeros(nDelANsMax, nColTotal-1);    % initializing matrix row number at total number of initial regions
                allDelaminatingLastRNs = NaN(nDelANsMax, 1);            % 2.11, "NaN" instead of "zeros" (2.20)
                coreDelaminatingLastRNsTF = false(nDelANsMax, 1);       % will store info if last delaminating RNs was border or FL (2.12)
                allLastFramesDel = NaN(nDelANsMax,1);                   % "NaN" instead of "zeros" (2.20)
                allLastTimesDel = NaN(nDelANsMax,1);                  % 1.17, "NaN" instead of "zeros" (2.20)
            end
            
            try                                                                                                       % try to read txt file
                delaminatingLastRNs = dlmread([trackingFolder filesep 'delaminating_cells_' num2str(n) '.txt']);      % List of cell RNs that WILL undergo apoptosis between n and n+1 (1.0h)
                delaminatingLastRNs = delaminatingLastRNs(delaminatingLastRNs > 0);                                   % 1.3.3
            catch err                                                                                                 % dlmread error when txt file is EMPTY or MISSING
                delaminatingLastRNs = [];
            end
            
            %%% Filtering out delaminating RNs that are border or FL because they are inaccurate (2.12)
            coreLastRNsTF = ~ismember(delaminatingLastRNs, excludeRNs); % 1s on rows where RNs are CORE
            
            if ~isempty(delaminatingLastRNs)
                
                [~, delaminatingANsLoc] = ismember(delaminatingLastRNs, Correspondence(:,1));
                delaminatingANs = Correspondence(delaminatingANsLoc,2:end);
                nA = length(delaminatingLastRNs);
                startRow = find(isnan(allLastFramesDel), 1); % UPDATED FOR **DEL CELLS** AT EACH ITERATION, mod 2.20
                endRow = startRow + nA - 1;
                allDelaminatingANs(startRow:endRow,1:nCol-1) = delaminatingANs;
                allDelaminatingLastRNs(startRow:endRow) = delaminatingLastRNs;              % 2.11
                coreDelaminatingLastRNsTF(startRow:endRow) = coreLastRNsTF;                 % 2.12
                allLastFramesDel(startRow:endRow) = n;                                      % LAST frame OF EXISTENCE NOT frame of disappearance
                allLastTimesDel(startRow:endRow) = frame2time(n,timeRef,frameRef,dt,'dec'); % saves as decimal hAPF (1.17)
            end
        end
        
        %% Determination of complete list of DIVIDING cells PART 1/2 (overhaul 2.10) %%
        
        % NB: since neither "just_divided_cells_RN_XX.txt" nor "dividing_cells_RN_XX.txt" are reliable, now totally redetermines
        % them STRAIGHT FROM "Correspondence" at each time point.
        
        if ~exist(allDividingCellsFile,'file') && ~exist(allDividingCellsTEMPfile,'file') % 2.1
            
            errorLogFile = [trackingFolder filesep '#ERROR.log.from.CTDisplay.txt'];
            errorLogFileBis = [saveFolder filesep '#ERROR.log.from.CTDisplay.txt'];
            
            % Erasing pre-existing files
            if exist(errorLogFile,'file')
                delete(errorLogFile);
            end
            if exist(errorLogFileBis,'file')
                delete(errorLogFileBis);
            end
            
            if n == startFrame
                
                % Initializations of tables for cells that divide:
                nDividingANsMax = 8*nRow;                               % taking leeway assuming ALL cells divides 3 times (2^3)
                allDividingANs = zeros(nDividingANsMax, nColTotal-1);   % will store ANs of all cells that divide
                allDividingLastRNs = NaN(nDividingANsMax, 1);           % will store RNs of all cells that divide IN THEIR LAST FRAME OF EXISTENCE, "NaN" instead of "zeros" (2.20)
                allSisterFirstRNs = NaN(nDividingANsMax,2);             % will store couples of sister RNs IN THEIR FIRST FRAME OF EXISTENCE
                allLastFramesDiv = NaN(nDividingANsMax,1);              % last frame of existence, "NaN" instead of "zeros" (2.20)
                
                % Discarded quantities
                nDiscardedANsMax = nRow;
                allDiscardedANs = zeros(nDiscardedANsMax, nColTotal-1);     % ANs of cells that divide BUT ONLY GIVE ONE DAUGHTER
                allDiscardedLastRNs = NaN(nDiscardedANsMax, 1);             % corresponding RNs IN THEIR LAST FRAME OF EXISTENCE,"NaN" instead of "zeros" (2.20)
                allDiscardedSisterANs = NaN(nDiscardedANsMax,nColTotal-1);  % sister ANs (not trivial because ONLY one sister found)
                allDiscardedSisterFirstRNs = NaN(nDiscardedANsMax,1);       % SINGLE sister RNs IN THEIR FIRST FRAME OF EXISTENCE
                allLastFramesDis = NaN(nDiscardedANsMax,1);                 % "NaN" instead of "zeros" (2.20)
                
                % Initialization of OLD quantities for first frame (mod 2.20)
                cellRNsOLD = cellRNs;
                cellANsOLD = cellANs;
                
            else
  
                [possibleSister1ANs, possibleSister2ANs] = MakeDaughters(cellANsOLD); % make all possible daughters
                
                [foundSister1ANsTF, foundSister1ANsLoc] = ismember(possibleSister1ANs, cellANs, 'rows');
                [foundSister2ANsTF, foundSister2ANsLoc] = ismember(possibleSister2ANs, cellANs,'rows');
                
                % checking that BOTH daughers were found
                foundSisterANsCheckTF = [foundSister1ANsTF foundSister2ANsTF];
                foundSisterCoupleANsTF = sum(foundSisterANsCheckTF,2) == 2 ;
                missingSisterANsTF = sum(foundSisterANsCheckTF,2) == 1 ;
                % NB: 0 is ok (the corresponding mother has NOT divided), 2 is ok (both daugher ANs are found), 1 is NOT.
                
                % ONLY keeping ANs of mother ANs for which sister couples were found
                keptMotherANsOLD = cellANsOLD(foundSisterCoupleANsTF,:);    % ANs existing in frame n-1 (not in n)
                keptMotherRNsOLD = cellRNsOLD(foundSisterCoupleANsTF);      % RNs in frame n-1
                
                % Determining daughter RNs in frame n
                keptSister1ANsLoc = foundSister1ANsLoc(foundSisterCoupleANsTF);
                keptSister2ANsLoc = foundSister2ANsLoc(foundSisterCoupleANsTF);
                
                keptSister1RNs = cellRNs(keptSister1ANsLoc);
                keptSister2RNs = cellRNs(keptSister2ANsLoc);
                keptSisterRNsMat = [keptSister1RNs keptSister2RNs];
                
                % Storage:
                nD = size(keptMotherANsOLD,1);
                startRow = find(isnan(allLastFramesDiv), 1); % UPDATED FOR **DIV CELLS** AT EACH ITERATION (mod 2.20)
                endRow = startRow + nD - 1;
                allDividingANs(startRow:endRow,:) = keptMotherANsOLD;
                allDividingLastRNs(startRow:endRow) = keptMotherRNsOLD;            % RELIABLE LIST OF MOTHER RNs
                allSisterFirstRNs(startRow:endRow,:) = keptSisterRNsMat;              % RELIABLE LIST OF SISTER RNs (2.10)
                allLastFramesDiv(startRow:endRow) = n-1;
                
                % Cases where ONLY one sister was found (sould NOT occur!)
                noDiscardedCell = true;
                if any(missingSisterANsTF)
                    
                    noDiscardedCell = false;
                    nDis = sum(missingSisterANsTF);
                    disp(['WARNING: found ' num2str(nDis) ' cases of ONLY ONE SISTER FOUND at division!!'])
                    warndlg(['Found ' num2str(nDis) ' cases of ONLY ONE SISTER FOUND at division!!','WARNING!']); % 2.12
                    
                    discardedMotherANsOLD = cellANsOLD(missingSisterANsTF,:);
                    discardedMotherRNsOLD = cellRNsOLD(missingSisterANsTF);
                    
                    discardedSisterANs = NaN(nDis,nColTotal-1);
                    discardedSisterRNs = NaN(nDis,1);
                    
                    onlySister1FoundANsTF = all([foundSister1ANsTF missingSisterANsTF],2);
                    onlySister2FoundANsTF = all([foundSister2ANsTF missingSisterANsTF],2);
                    
                    discardedSister1ANs = possibleSister1ANs(onlySister1FoundANsTF,:);
                    discardedSister2ANs = possibleSister2ANs(onlySister2FoundANsTF,:);
                    
                    discardedSister1ANsLoc = foundSister1ANsLoc(onlySister1FoundANsTF);
                    discardedSister2ANsLoc = foundSister2ANsLoc(onlySister2FoundANsTF);
                    
                    discardedSister1RNs = cellRNs(discardedSister1ANsLoc);
                    discardedSister2RNs = cellRNs(discardedSister2ANsLoc);
                    
                    [~, sis1RowsLoc ] = ismember(MakeMothers(discardedSister1ANs), discardedMotherANsOLD, 'rows');
                    [~, sis2RowsLoc ] = ismember(MakeMothers(discardedSister2ANs), discardedMotherANsOLD, 'rows');
                    
                    discardedSisterANs(sis1RowsLoc,:) = discardedSister1ANs;
                    discardedSisterANs(sis2RowsLoc,:) = discardedSister2ANs;
                    
                    discardedSisterRNs(sis1RowsLoc) = discardedSister1RNs;
                    discardedSisterRNs(sis2RowsLoc) = discardedSister2RNs;
                    
                    % Storage:
                    startRow = find(isnan(allLastFramesDis), 1); % mod 2.20
                    endRow = startRow + nDis - 1;
                    allDiscardedANs(startRow:endRow,:) = discardedMotherANsOLD;
                    allDiscardedLastRNs(startRow:endRow) = discardedMotherRNsOLD;
                    allDiscardedSisterANs(startRow:endRow,:) = discardedSisterANs;
                    allDiscardedSisterFirstRNs(startRow:endRow) = discardedSisterRNs;
                    allLastFramesDis(startRow:endRow) = n-1;
                    
                    % writing in error log files
                    text2displayOne = {'';'WARNING! The following mother ANs'};
                    num2displayOne = discardedMotherANsOLD;
                    text2displayTwo = {'are giving only one sister AN !'};
                    num2displayTwo = discardedSisterANs;
                    %                  text2display = {'';['WARNING! The following mother RNs are missing in "dividing_cells_RN_' num2str(n-1) '.txt" file!']};
                    %                  num2display = motherOldRNs(missingMotherRNsTF);
                    
                    cell2save = [text2displayOne ; num2str(num2displayOne) ; text2displayTwo; num2str(num2displayTwo) ];
                    dlmcell(errorLogFile, cell2save, '-a');
                    dlmcell(errorLogFileBis, cell2save, '-a');
                    
                end
                
                % Update of OLD quantities
                cellRNsOLD = cellRNs;
                cellANsOLD = cellANs;
            end
            
            % REMOVED HERE FORMER WAY OF BUILDING REF "motherANs", CHECKING "Dividing_cells_RNs_XX.txt" file and WRITING ERROR LOG FILE (2.10)
        end
        
        %% Determination of complete list of OTHER cells PART 1/2 (2.9, 2.19) %%
        
        % NB: in contrast to macro, del or div backups, the complete backup for other ANs is generated right here.
        
        if ~exist(allOtherCellsFile,'file')
            
            % Initialization of parameters and tables
            if n == startFrame                
%                 startRow = 1; % commented 2.20
                nOtherANsMax = 20*nRow;                                  % taking more leeway to prevent crashes. further increased size (2.26)
                allOtherANs = zeros(nOtherANsMax, nColTotal-1);         % initializing matrix row number at total number of initial regions * 8
                allOtherRNs = NaN(nOtherANsMax, finalFrame);            % will store RNs of Other ANs over time (1 column per frame)
                allFirstFramesOther = NaN(nOtherANsMax,1);
                allLastFramesOther = NaN(nOtherANsMax,1);
                allOtherRNsFilterTF = false(nOtherANsMax, finalFrame);  % will store location to exclude in "allDelaminatingRNs" (2.19)
            end

            % finding and storing new ANs and corresponding RNs
            [oldANsTF, oldANsLoc] = ismember(cellANs, allOtherANs,'rows');
            newANsTF = ~oldANsTF;
            nNewANs = sum(newANsTF,1);
            % selecting new ANs and corresponding RNs
            newANs = cellANs(newANsTF,:);
            newRNs = cellRNs(newANsTF,:);
            % storage of newANs, newRNs
            startRow = find(isnan(allFirstFramesOther), 1); % UPDATED FOR **OTHER CELLS** AT EACH ITERATION (2.20)
            endRow = startRow + nNewANs - 1;
            allOtherANs(startRow:endRow,:) = newANs;
            allOtherRNs(startRow:endRow,n) = newRNs;
            allFirstFramesOther(startRow:endRow) = n; % puts frame number as first frame of existence
            
            % Storing RNs of "old" ANs in nth column of "allOtherRNs":
            oldRNs = cellRNs(oldANsTF);
            oldANsLoc = oldANsLoc(oldANsTF); % mod 2.20
            allOtherRNs(oldANsLoc,n) = oldRNs;                      % putting them at the right locations
            
            % Checking that some old ANs found here have not already been declared as lost:
            declaredLostANsLoc = find(~isnan(allLastFramesOther));
            oldANsLostAndFoundLoc = intersect(oldANsLoc,declaredLostANsLoc);
            allLastFramesOther(oldANsLostAndFoundLoc) = NaN;                    % setting back their last frames to "NaN" (since still existing)
            declaredLostANsLoc = find(~isnan(allLastFramesOther));              % updating list of lost ANs locations
            
            % Storing last frame of existence for lost ANs:
            allOtherANsCrop = allOtherANs(1:endRow,:);                  % cropping before looking for unfound ANs
            lostANsTF = ~ismember(allOtherANsCrop, cellANs, 'rows');     % 1s where an ANs formerly listed cannot be found anymore (includes death and divisions)
            lostANsLoc = find(lostANsTF);                               % need to use indices because the crop version does not have the right size
            newlyLostANsLoc = setdiff(lostANsLoc, declaredLostANsLoc);  % removing indices already declared as lost (otherwise last frame number processed will overwrite the actual ones)
            allLastFramesOther(newlyLostANsLoc) = n-1;                  % those ANs only still existed until previous frame
            
%              startRow = endRow + 1;                                      % updating "startRow" for next iteration (commented 2.20)
            
            % Updating "allOtherRNsFilterTF"(2.19)
            excludeRNs = [borderRNs; FLRNs; coalescedRNs];
            excludeRNsTF = ismember(allOtherRNs(:,n), excludeRNs);
            allOtherRNsFilterTF(excludeRNsTF,n) = true;
        end
        if PLOT.displayImages == "on"
            progressbar((n-startFrame+1)/nFrames) 
        end
        
    end
else
    fprintf('All temporary or full backups have been found: skipping 1st iteration!\n')
end

%% Determination of complete list of DELAMINATING cells Part 2/2 (2.13) %%

 if ~exist(allDelaminatingCellsFile,'file') && ~exist(allDelaminatingCellsTEMPfile,'file') % mod 2.1
     
    delCutRow = find(isnan(allLastFramesDel), 1) - 1;                       % mod 2.20
    allDelaminatingANs = allDelaminatingANs(1:delCutRow,:);
    allDelaminatingLastRNs = allDelaminatingLastRNs(1:delCutRow);           % 2.11
    coreDelaminatingLastRNsTF = coreDelaminatingLastRNsTF(1:delCutRow);     % 2.12
    allLastFramesDel = allLastFramesDel(1:delCutRow);
    allLastTimesDel = allLastTimesDel(1:delCutRow);                         % 1.17
    
    % Determining cumulated number of delaminations for each basic AN (1.28)
    delaminatingRootANsRepeated = allDelaminatingANs(coreDelaminatingLastRNsTF,1); % ONLY KEEPING CORE DELAMINATING LAST RNs (2.12)
    delaminatingRootANs = unique(delaminatingRootANsRepeated);
    nDelRootANs = hist(delaminatingRootANsRepeated, delaminatingRootANs)'; % directly counts occurences of each basic ANs
    
    save(allDelaminatingCellsTEMPfile,'allDelaminatingANs','allLastFramesDel','allLastTimesDel','delaminatingRootANs','nDelRootANs',...% mod 1.28, using Temp file (2.1)
                                    'allDelaminatingLastRNs', 'coreDelaminatingLastRNsTF'); % 2.11, 2.12

    allDelaminatingLastXYs = NaN(delCutRow,2);                % will only be filled during main iteration
    allDelaminatingRNs = NaN(delCutRow, finalFrame);            % will store RNs of delaminating ANs over time (1 column per frame) (2.2)
    allDelaminatingRNsFilterTF = false(delCutRow, finalFrame);  % will store location to exclude in "allDelaminatingRNs" (2.2), BACK IN 2.12
    allFirstFramesDel = NaN(delCutRow,1);                       % first frame of appearance (2.6)
    
elseif exist(allDelaminatingCellsTEMPfile,'file')               % 2.1
        
    fprintf('File "allDelaminatingCellsTEMP.mat" was found and is loading...')
    load(allDelaminatingCellsTEMPfile);
    delCutRow = length(allLastFramesDel);                       % defines "cutRow" when loading backup (1.18)
    
    allDelaminatingLastXYs = NaN(delCutRow,2);                % will only be filled during main iteration (2.1), mod 2.20
    allDelaminatingRNs = NaN(delCutRow, finalFrame);            % will store RNs of delaminating ANs over time (1 column per frame) (2.2)
    allDelaminatingRNsFilterTF = false(delCutRow, finalFrame);  % will store location to exclude in "allDelaminatingRNs" (2.2), BACK IN 2.12
    allFirstFramesDel = NaN(delCutRow,1);                       % first frame of appearance (2.6), mod 2.20
    
elseif exist(allDelaminatingCellsFile,'file') % 2.1
        
    fprintf('File "allDelaminatingCells.mat" was found and is loading...')
    load(allDelaminatingCellsFile);
    % NB: allDelaminatingLastXYs, allDelaminatingRNs already exist and should not be be overwritten
 end
 delCutRow = length(allLastFramesDel);                       % defines "cutRow" when loading backup (2.14)
 fprintf('Done.\n')


% Determining nDelMax and nDelRootANsPlot (1.28)
if makeDelImages
    nDelRootANsPlot = nDelRootANs; % initialization
    if isempty(nDelMax)
        nDelMax = max(nDelRootANs);
    else
        nDelRootANsPlot(nDelRootANs > nDelMax) = nDelMax; % saturates to value entered by user
    end
    grayLevelsDel =(0:nDelMax)'/nDelMax; % determines number of shades of grey (mod 2.5)
%     grayLevelsDel = flipud((0:nDelMax)'/nDelMax); % determines number of shades of grey
end

%% Determination of complete list of DIVIDING cells Part 2/2 (2.13) %%

 if ~exist(allDividingCellsFile,'file') && ~exist(allDividingCellsTEMPfile,'file') % 2.1  
    % cropping matrices to minimal size
    divCutRow = find(isnan(allLastFramesDiv), 1) - 1; % mod 2.20
    allDividingANs = allDividingANs(1:divCutRow,:);
    allDividingLastRNs = allDividingLastRNs(1:divCutRow);
    allSisterFirstRNs = allSisterFirstRNs(1:divCutRow,:);      % 2.10
    allLastFramesDiv = allLastFramesDiv(1:divCutRow);
    
    if exist('noDiscardedCell','var') && ~noDiscardedCell % added "exist('noDiscardedCell','var')" (2.28)
        
        disCutRow = find(isnan(allLastFramesDis), 1) - 1; % mod 2.20
        allDiscardedANs = allDiscardedANs(1:disCutRow,:);
        allDiscardedLastRNs = allDiscardedLastRNs(1:disCutRow);
        allDiscardedSisterANs = allDiscardedSisterANs(1:disCutRow,:);
        allDiscardedSisterFirstRNs = allSisterFirstRNs(1:disCutRow,:);
        allLastFramesDis = allLastFramesDis(1:disCutRow);
    else
        clear allDiscardedANs allDiscardedRNs allDiscardedSisterANs allDiscardedSisterRNs allLastFramesDis
    end
    
    % Determining total offspring for each basic AN
    dividingRootANsRepeated = allDividingANs(:,1);
    dividingRootANs = unique(dividingRootANsRepeated);
    nDivRootANs = hist(dividingRootANsRepeated, dividingRootANs)'; % directly counts occurences of each basic ANs

    % Saving backup "allDividingCellsTEMP.mat"
    allLastTimesDiv = frame2time(allLastFramesDiv,timeRef,frameRef,dt,'dec'); % saves as decimal hAPF
    save(allDividingCellsTEMPfile,'allDividingANs','allLastFramesDiv','allLastTimesDiv','dividingRootANs','nDivRootANs',...
        'allSisterFirstRNs','allDividingLastRNs'); % 2.10
    
    % Appends backup with "discarded" quantities
    if exist('allDiscardedANs','var')
        
        allLastTimesDis = frame2time(allLastFramesDis,timeRef,frameRef,dt,'dec'); % saves as decimal hAPF
        save(allDividingCellsTEMPfile,'allDiscardedANs', 'allDiscardedLastRNs', 'allDiscardedSisterANs', 'allDiscardedSisterFirstRNs',...
                                      'allLastFramesDis', 'allLastTimesDis','-append');
    end              
      
    allDividingLastXYs = NaN(divCutRow,2);                  % will only be filled during main iteration (2.20)
    allDividingRNs = NaN(divCutRow,finalFrame);             % will store RNs of dividing ANs over time (1 column per frame) (2.2)
    allDividingRNsFilterTF = false(divCutRow, finalFrame);  % will store location to exclude in "allDividingRNs" (2.2), BACK IN 2.12
    allFirstFramesDiv = NaN(divCutRow,1);                   % first frame of appearance (2.6)
    
elseif exist(allDividingCellsTEMPfile,'file') % 2.1
    
    fprintf('File "allDividingCellsTEMP.mat" was found and is loading...')
    load(allDividingCellsTEMPfile);
    divCutRow = length(allLastFramesDiv);                   % defines "divCutRow" when loading backup (1.18)
       
    allDividingLastXYs = NaN(divCutRow,2);                  % will only be filled during main iteration (2.20)
    allDividingRNs = NaN(divCutRow,finalFrame);             % will store RNs of dividing ANs over time (1 column per frame) (2.2)
    allDividingRNsFilterTF = false(divCutRow, finalFrame);  % will store location to exclude in "allDividingRNs" (2.2), BACK IN 2.12
    allFirstFramesDiv = NaN(divCutRow,1);                   % first frame of appearance (2.6), mod 2.20
    
elseif exist(allDividingCellsFile,'file') % 2.1
    
    fprintf('File "allDividingCells.mat" was found and is loading...')
    load(allDividingCellsFile);
    divCutRow = size(allDividingANs,1); % 2.8
end
fprintf('Done.\n')

% Special case of division SIA backup (2.8)
%--------------------------------------------------------------
if ~exist(allDividingCellsSIAfile,'file')
    
    % division XYs (filled during main iteration) (2.1), daughters in 3rd dimension (2.3)
    allSisterCentroidXYs = NaN(divCutRow,2,2);
    allSisterJunctionXYs = NaN(divCutRow,2,2);
else
    fprintf('File "allDividingCellsSIA.mat" was found and is loading...')
    load(allDividingCellsSIAfile);
end
%--------------------------------------------------------------
fprintf('Done.\n')

% Determining nDivMax and nDivRootANsPlot (1.28)
if makeDivImages
    
    nDivRootANsPlot = nDivRootANs;
    if isempty(nDivMax)
        nDivMax = max(nDivRootANs);
    else
        nDivRootANsPlot(nDivRootANs > nDivMax) = nDivMax; % saturates to value entered by user
    end
    grayLevelsDiv = (0:nDivMax)'/nDivMax; % determines number of shades of grey (mod 2.5)
%     grayLevelsDiv = flipud((0:nDivMax)'/nDivMax); % determines number of shades of grey
end

%% Determination of complete list of OTHER cells Part 2/2 (2.13) %%

if ~exist(allOtherCellsFile,'file')

    % Removing rows corresponding to "allDelaminatingANs" and "allDividingANs" (and "macroANs"):
    allDelDivMacroANsTF = ismember(allOtherANs, [allDelaminatingANs ; allDividingANs; macroANs], 'rows');
    actualOtherANsTF = ~allDelDivMacroANsTF;                                                    % actual other ANs (not div, not del, not macro)
    allOtherANs = allOtherANs(actualOtherANsTF,:);                                              % cropping to non-delaminating and non-dividing ANs
    allOtherRNs = allOtherRNs(actualOtherANsTF,:);
    allFirstFramesOther = allFirstFramesOther(actualOtherANsTF);
    allLastFramesOther = allLastFramesOther(actualOtherANsTF);
    allOtherRNsFilterTF = allOtherRNsFilterTF(actualOtherANsTF,:); % 2.19
    
    % Determining "otherCutRow" and cropping tables to minimal size
    otherCutRow = find(allOtherANs(:,1) == 0, 1) - 1;
    allOtherANs = allOtherANs(1:otherCutRow,:);
    allOtherRNs = allOtherRNs(1:otherCutRow,:);
    allFirstFramesOther = allFirstFramesOther(1:otherCutRow);
    allLastFramesOther = allLastFramesOther(1:otherCutRow);
    allOtherRNsFilterTF = allOtherRNsFilterTF(1:otherCutRow,:); % 2.19
    
    % Turning frames numbers into times:
    allFirstTimesOther = frame2time(allFirstFramesOther,timeRef,frameRef,dt,'dec');
    allLastTimesOther = frame2time(allLastFramesOther,timeRef,frameRef,dt,'dec');
    
    % Converts logical table into vector of locations (2.19):
    allOtherRNsFilterLoc = find(allOtherRNsFilterTF);
    % NB: to exclude border, FL and coalesced RNs, just do : allOtherRNs(allOtherRNsFilterLoc) = NaN;
    
    save(allOtherCellsFile, 'allOtherANs','allOtherRNs','allLastFramesOther','allFirstFramesOther','allFirstTimesOther', 'allLastTimesOther',...
                            'allOtherRNsFilterLoc'); % 2.19

elseif exist(allOtherCellsFile,'file') % 2.1
        
    fprintf('File "allOtherCells.mat" was found and is loading...')
    load(allOtherCellsFile);
end
fprintf('Done.\n')
disp('---------------------------------------------------------------------------------');

%% 2ND ITERATION OVER FRAMES %%

if secondFrameIterationTF % 2.1
    
    maxRootAN = 0;                                              % initialization of max root AN number
    newJunctionsBackupNotLoadedYet = true;                          % 2.24
    if PLOT.displayImages == "on"
        progressbar(['CTD iteration over ' Animal ' frames...']);   % 1.10
    end
    
    for n = startFrame:finalFrame
        %% Display info & Loading segmented image %%
        
        iterationIndex = n - startFrame + 1; % 2.6
        
        disp(' '); disp(' ');
        disp(['CTD' ' ' version  ': processing "' Animal '" frame # ' num2str(n) ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);
        disp('---------------------------------------------------------------------------------');
        
        % loading image
        uSegImage = imread([pathFolder filesep filename num2str(n, digitsFormat) '.' imageFormat]); 
                         
        %% Making "imageLabels", loading SIA backup IF available OR REextracting centroids (mod 2.1)%%
        
        disp('Determining cell centroids and pixel index list directly from segmented image...');
        [imageLabels, imageCC] = GetImageLabels(uSegImage); % REcreates image labelled uint8 or uint16 according to the number of regions (1.29), use of GetImageLabels (2.0)
               
        % loading SIA backup IF IT EXISTS
        nthSIAbackupFoundTF = false;
        nthSIAbackupPath = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat) '.mat']; % mod 1.32, 2.1
        
        if allSIAbackupAvailableTF
            
            fprintf(['Loading SIA backup ' filenameSIA '_' num2str(n,digitsFormat) '...'])
            nthSIAbackupFoundTF = true;
            SIAbackup = load(nthSIAbackupPath);
            cellXYs = SIAbackup.CELLS.XYs; % mod 2.18
            cellXYs = cellXYs/scale1D;     % converting back to pixels
            % ONLY available when SIA backups are FOUND
            %----------------------------------------------------------
            sideRNcouples = SIAbackup.SIDES.Cells;
            sideVertexIndices = SIAbackup.SIDES.VertexIndices; % mod 2.18
            [RN1Ys, RN1Xs] = ind2sub(imageSize,sideVertexIndices(:,1));
            [RN2Ys, RN2Xs] = ind2sub(imageSize,sideVertexIndices(:,2));
            %----------------------------------------------------------
        else
            fprintf(['SIA backup ' filenameSIA num2str(n,digitsFormat) ' NOT found! Extracting some region properties straight from image...'])
            statAllRegions = regionprops(imageCC, 'Centroid');          % removed "PixelIdxList" (1.29)
            statAllRegionsCellArray = (struct2cell(statAllRegions))';
            cellXYs = cell2mat(statAllRegionsCellArray(:,1));
            clear statAllRegionsCellArray statAllRegions                % 1.24
        end
        clear imageCC
        fprintf('Done.\n')
            
        %% Loading txt files from C++ tracking %%
        
        % loading tables (common with TA):
        CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
        coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
        coalescedRNs = coalescedRNs(coalescedRNs > 0);                                                    % removes -1 stored when empty txt file
        % Expanding nb Correspondence columns according to "max_n_divisions_nStart-nEnd.txt" (1.14):
        Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); % 1.32
        clear CorrespondenceRaw;
        
        cellRNs = unique(Correspondence(:,1)); % all regions (moved up 2.17)
        
        newRNsMat = dlmread([trackingFolder filesep 'new_cells_RN_' num2str(n) '.txt']);
        newRNs = newRNsMat(newRNsMat > 0);
  
        % loading tables (specific to CTD):
        borderRNs = dlmread([trackingFolder filesep 'border_cells_RN_' num2str(n) '.txt']);
        neighborRNs = dlmread([trackingFolder filesep 'neighbours_RN_' num2str(n) '.txt']);
        FLRNs = FindFirstLayerRNs(borderRNs, neighborRNs); % 2.12
 
        % determining max rootANs (1.32)
        if ~isempty(newRNs)
            maxRootAN = max(maxRootAN, max(newRNs)); % update
        end
                
        %% Loading this frame "sisterRNsMat" and "daughterRNs" (2.10) %%
        
        thisFrameDividedRowsTF = ismember(allLastFramesDiv, n-1); % finds rows of allDividingANs, allLastDividingRNs... of cells that had n-1 as their last existence frame
        thisFrameDividedRows = find(thisFrameDividedRowsTF);      % gets row numbers
        % NB: a mother cells that stopped existing in frame n gives two daughters in frame n
        
        sisterRNsMat = allSisterFirstRNs(thisFrameDividedRowsTF,:); % couples of sister RNs (sister 1 first)
        
        daughterRNs = sort(sisterRNsMat(:)); % 1-column list of all daughters in ascending order
                     
        %% Loading "Solved_XX_n.txt" files for Apoptotic, Blue, RedGreen and RedGreenExtended patched regions (1.12) %%
        
        try
            solvedA_RNs = dlmread([trackingFolder filesep 'Solved_A_' num2str(n) '.txt']);
            disp('Apoptotic-patch regions found!')
        catch err
            solvedA_RNs = [];
        end
        try
            solvedB_RNs = dlmread([trackingFolder filesep 'Solved_B_' num2str(n) '.txt']);
            disp('Blue-patch regions found!')
        catch err
            solvedB_RNs = [];
        end
        try
            solvedRG_RNs = dlmread([trackingFolder filesep 'Solved_RG_' num2str(n) '.txt']);
            disp('RedGreen-patch regions found!')
        catch err
            solvedRG_RNs = [];
        end
        try
            solvedRGE_RNs = dlmread([trackingFolder filesep 'Solved_RGe_' num2str(n) '.txt']);
            disp('RedGreenExtended-patch regions found!')
        catch err
            solvedRGE_RNs = [];
        end
                           
        %% Finding DELAMINATING RNs (2.2) & building list of apoptotic cell CoMs (mod 21.12)  %%
        
        if ~delBackupCompleteTF
            
            if n==startFrame
                unfoundDelANsLoc = (1:delCutRow)';              % initialization (2.6)
            end
            
            %%% Finds existing delaminating ANs and their corresponding RNs:
            [foundDelRNs, foundDelANs] = ANs2RNs(allDelaminatingANs, Correspondence);      % a lot of delaminating ANs do NOT exist in the beginning
            [~, foundDelANsLoc] = ismember(foundDelANs, allDelaminatingANs,'rows');        % finding rows in "allDelaminatingANs" where "croppedDelANs" are
            
            allDelaminatingRNs(foundDelANsLoc,n) = foundDelRNs;                            % storing RNs at the right location in table
            
            %%% Filling "allFirstFramesDel" (2.6)
            newlyFoundDelANsLoc = intersect(unfoundDelANsLoc, foundDelANsLoc);
            allFirstFramesDel(newlyFoundDelANsLoc) = n;                         % entering frame number
            unfoundDelANsLoc = setdiff(unfoundDelANsLoc, newlyFoundDelANsLoc);  % removing form list of unfound delaminating cells
            
            %%% Removing RNs being either borderRNs, FLRNs and coalescedRNs:
            excludeRNs = unique([coalescedRNs; borderRNs; FLRNs]);                         % gathering all RNs to exclude
            foundDelRNs2excludeTF = ismember(foundDelRNs, excludeRNs);                     % finding RNs involved
            foundDelANsLoc2exclude = foundDelANsLoc(foundDelRNs2excludeTF);                % getting their rows in "allDelaminatingANs"
            
            allDelaminatingRNsFilterTF(foundDelANsLoc2exclude,n) = true;                   % setting those locations to true, BACK IN 2.12
%             allDelaminatingRNs(foundDelANsLoc2exclude,n) = NaN;                            % removing those RNs right away (2.4)
            % NB: to apply filter, just do: allDelaminatingRNs(allDelaminatingRNsFilterTF) = NaN;
            
            %%% Building list of CORE apoptotic RN CoMs (mod 2.12)
            nthDelRowsTF = allLastFramesDel == n;
            nthDelRowsFiltTF = all([nthDelRowsTF coreDelaminatingLastRNsTF], 2); % must be both CORE and occuring now
            nthDelFiltRNs = allDelaminatingLastRNs(nthDelRowsFiltTF);
            nthDelFiltXYs = cellXYs(nthDelFiltRNs,:);
            allDelaminatingLastXYs(nthDelRowsFiltTF,:) = nthDelFiltXYs;
        end
                 
        %% Finding DIVIDING RNs (2.2, 2.6, 2.8) %%
        
        if ~divBackupCompleteTF % 2.8
            
            if n == startFrame
                notFoundYetDivANsLoc = (1:divCutRow)';              % initialization (2.6)
            end
            
            %%% Finds existing dividing ANs and their corresponding RNs:
            [foundDivRNs, foundDivANs] = ANs2RNs(allDividingANs, Correspondence);           % a lot of dividing ANs do NOT exist in the beginning
            [~, foundDivANsLoc] = ismember(foundDivANs, allDividingANs,'rows');             % locating found ANs in the initial list
            
            allDividingRNs(foundDivANsLoc,n) = foundDivRNs;                                 % storing RNs at the right location in table
            
            %%% Filling "allFirstFramesDiv" (2.6)
            newlyFoundDivANsLoc = intersect(notFoundYetDivANsLoc, foundDivANsLoc);
            allFirstFramesDiv(newlyFoundDivANsLoc) = n;                                 % entering frame number
            notFoundYetDivANsLoc = setdiff(notFoundYetDivANsLoc, newlyFoundDivANsLoc);  % update: removing form list of unfound dividing cells
            
            %%% Filling "allDividingLastXYs" (2.20)
            thisFrameLastFramesTF = allLastFramesDiv == n;
            thisFrameLastRNs = allDividingLastRNs(thisFrameLastFramesTF);   % gets RNs of cells whose last frame is "n"
            thisFrameLastXYs = cellXYs(thisFrameLastRNs,:);                 % gets corresponding XYs
            allDividingLastXYs(thisFrameLastFramesTF,:) = thisFrameLastXYs;
            
            %%% Saving info of RNs being eitherborderRNs, FLRNs an coalescedRNs:
            excludeRNs = unique([coalescedRNs; borderRNs; FLRNs]);                          % gathering all RNs to exclude
            foundDivRNs2excludeTF = ismember(foundDivRNs, excludeRNs);                      % finding RNs involved
            foundDivANsLoc2exclude = foundDivANsLoc(foundDivRNs2excludeTF);                 % getting their rows in "allDelaminatingANs"
            
            allDividingRNsFilterTF(foundDivANsLoc2exclude,n) = true;                        % setting those locations to true, BACK IN 2.12
%             allDividingRNs(foundDivANsLoc2exclude,n) = NaN;                                 % removing those RNs right away (2.4)
            
            % NB: to apply filter, just do: allDividingRNs(allDividingRNsFilterTF) = NaN;
        end
               
        %% Finding MACROCHAETAE RNs (1.25, 1.26, 1.27, 2.2) %%

        if foundMacroClickFileTF
            if ~macroBackupCompleteTF
                
                excludeRNs = unique([coalescedRNs; borderRNs]);                             % gathering all RNs to exclude
                thisFrameMacroRNs = macroANs2macroRNs(macroANs, Correspondence, excludeRNs);
                macroFoundRNs = RemoveNaNs(thisFrameMacroRNs);
                macroRNs(:,n) = thisFrameMacroRNs;                                          % filling macroRNs nth column
                
            else
                macroFoundRNs = RemoveNaNs(macroRNs(:,n));
            end
        else
            macroFoundRNs = [];
        end
                              
        %% Building "allSisterCentroid/JunctionXYs" (2.1,2.6, 2.8, 2.10) %%
        
        if ~isempty(daughterRNs) && makeDivSIAbackupTF % 2.10
              
                % getting sister centroids
                sister1CentroidXYs = cellXYs(sisterRNsMat(:,1),:);
                sister2CentroidXYs = cellXYs(sisterRNsMat(:,2),:);
                
                % ALREADY sorted like in "allDividingANs" and store it into "allDaughterCentroid/JunctionXYs"
                allSisterCentroidXYs(thisFrameDividedRows,:,1) = sister1CentroidXYs; % use of 3D matrices (2.3), use of "thisFrameDividedRows" (2.10)
                allSisterCentroidXYs(thisFrameDividedRows,:,2) = sister2CentroidXYs;
                
                % getting sister shared junction vertex coordinates;
                sisterRNsMatSorted = sort(sisterRNsMat,2);                              % puts lower RN in first col to find RN couple in "sideRNs"
                [~,sisterRNsMatLoc] = ismember(sisterRNsMatSorted, sideRNcouples,'rows');
                foundLocTF = logical(sisterRNsMatLoc);            % sister couple for which no junction was found (normally impossible) (2.10)
                sisterRNsMatLoc = sisterRNsMatLoc(foundLocTF);    % cropping to found junctions (2.10)
                sister1JunctionXYs = [RN1Xs(sisterRNsMatLoc) RN1Ys(sisterRNsMatLoc)];
                sister2JunctionXYs = [RN2Xs(sisterRNsMatLoc) RN2Ys(sisterRNsMatLoc)];               
                
                thisFrameDividedRowsFound = thisFrameDividedRows(foundLocTF);               % cropping to found junctions (2.10)
                allSisterJunctionXYs(thisFrameDividedRowsFound,:,1) = sister1JunctionXYs;   % use of "thisFrameDividedRowsFound" (2.10)
                allSisterJunctionXYs(thisFrameDividedRowsFound,:,2) = sister2JunctionXYs;
        end
        
        %% DETERMINATION OF NEW JUNCTIONS (new neighbor couples) *** SIA BACKUP REQUIRED ***
        
        % NB: hereafter, "new" refers to neighbor couples (or junctions) that did NOT exist before
        % "newJunctionStartTime" and that have been created by T1s. Thus, a junction can be created
        % right after "newJunctionStartFrame" and remain "new" throughout the whole movie.
        
        if makeNewJunctionsBackupTF % 2.15
                      
            % Build 2 column matrix of cell ANs (without division tags) of cells couples being neighbors in initial frame
            fprintf('Determining newly formed junctions: extracting relevant data from SIA backup...'); % 1.24
            cellNeighbors = SIAbackup.CELLS.Neighbors;          % mod 2.18
            sideChordLengths = SIAbackup.SIDES.ChordLengths;    % mod 2.18
                        
            % Making "neighborCoupleRNs" (NOT CLEAR WHY NOT USING "sideCellCoupleRNs"!!!??)
            nCells = length(cellNeighbors);
            coupleRNs = NaN(4*nCells,2); % 3*nCells on average
            indStart = 1;
            for c = 1:nCells
                
                cNeighbors = cellNeighbors{c}';
                cNeighborsFilt = cNeighbors(cNeighbors > c); % only keeping neighbors of RN > cell RN to list couples only once
                cN = length(cNeighborsFilt);
                cRep = repmat(c,cN,1);
                
                indEnd = indStart + cN-1;
                coupleRNs(indStart:indEnd,:) = [cRep cNeighborsFilt];
                indStart = indEnd + 1;
            end
            coupleRNs = coupleRNs(1:indEnd,:); % cropping to minimal size
            % NB: did NOT remove border cells
            fprintf('Done.\n')
            
            if n == startFrame % 2.15
                
                %%% Initializing matrices
                nCellsInit = nCells;
                nJunctionsMax = 50*nCells;                                     % prefactor went from 18 to 30, to 50 (2.20)
                allNewJunctionCoupleANs = NaN(nJunctionsMax,(nColTotal-1)*2);    % 2 ANs to store in each row
                allNewJunctionLengths = NaN(nJunctionsMax,finalFrame);
                
                sideOfT1CouplesPixels = [];
                sideOfDivCouplesPixels = [];
 
                motherCellANsToLookFor = [];
                daughterCellANs1ToLookFor = [];
                daughterCellANs2ToLookFor = [];
                
                allNewCoupleANs = NaN(nJunctionsMax,(nColTotal-1)*2); % 2.14
                allNewFrames = NaN(nJunctionsMax,1); % 2.14

                % Building "initNeighborCoupleANs" that will determine which AN couple is NEW or NOT:
                initCoupleANs1 = uncoalescedRNs2ANs(coupleRNs(:,1), Correspondence); % 1.20
                initCoupleANs2 = uncoalescedRNs2ANs(coupleRNs(:,2), Correspondence); % 1.20
                initCoupleANs = [initCoupleANs1 initCoupleANs2];
                % NB: for coalesced RNs, only last matching AN will appear and may NOT be the relevant
                % one => try to update list of "initNeighborCoupleANs" for those RNs in following frames
                
                % Sorting neighbor ANs (required now that n can be ~= startFrame) (2.14)
                [initCoupleANs, initCoupleANs1, initCoupleANs2] = SortNeighborCouples(initCoupleANs);
                
                % initialization of OLD quantities (2.24)
                CorrespondenceOld = Correspondence;
                cellNeighborsOld = cellNeighbors;
            else
                
                %%% filtering out rows involving a Coalesced RNs
                % --------------------------------------------------------------------
                CCtf = ismember(coupleRNs, coalescedRNs);
                CCrowsTF = any(CCtf,2);
                coupleRNs = coupleRNs(~CCrowsTF,:);
                % --------------------------------------------------------------------
                
                %%%  Turning RNs into ANs to compare OLD vs NEW neighbor relationships
                % --------------------------------------------------------------------
                coupleANs1 = uncoalescedRNs2ANs(coupleRNs(:,1), Correspondence);
                coupleANs2 = uncoalescedRNs2ANs(coupleRNs(:,2), Correspondence);
                % --------------------------------------------------------------------
                
                %%% PERMANENTLY adding edges with non-core AND new cells to "initNeighborCoupleANs" so
                %%% they do NOT show up suddenly when cells become core or enter field (2.14)
                % --------------------------------------------------------------------
                nonCoreAndNewRNs = [borderRNs ; FLRNs; newRNs];
                nonCoreAndNewANs = RNs2ANs(nonCoreAndNewRNs, Correspondence);
                nonCoreAndNewRows1TF = ismember(coupleANs1, nonCoreAndNewANs,'rows');
                nonCoreAndNewRows2TF = ismember(coupleANs2, nonCoreAndNewANs,'rows');
                nonCoreAndNewRowsTF = any([nonCoreAndNewRows1TF nonCoreAndNewRows2TF],2);
                
                couple2AddANs1 = coupleANs1(nonCoreAndNewRowsTF,:);
                couple2AddANs2 = coupleANs2(nonCoreAndNewRowsTF,:);
                
                initCoupleANs1 = [initCoupleANs1 ; couple2AddANs1];
                initCoupleANs2 = [initCoupleANs2 ; couple2AddANs2];
                
                % Sorting neighbor ANs (2.14)
                initCoupleANs = [initCoupleANs1 initCoupleANs2];
                [initCoupleANs, initCoupleANs1, initCoupleANs2] = SortNeighborCouples(initCoupleANs);
                % --------------------------------------------------------------------
                

                %%% Updating couples involving JUST DIVIDED cells (overhaul 1.21)
                % -----------------------------------------------------------------------------------------------------
                daughterANs = RNs2ANs(daughterRNs, Correspondence);
                
                % REMOVING neighbor couples involving divided MOTHER from initNeighborCoupleANsSorted
                motherANsRaw = MakeMothers(daughterANs);                            % renamed it with Raw (2.1)
                motherANs = unique(motherANsRaw,'rows');                            % removes duplicates (1.24)
                motherRows1TF = ismember(initCoupleANs1, motherANs,'rows');
                motherRows2TF = ismember(initCoupleANs2, motherANs,'rows');
                motherRowsTF = any([motherRows1TF motherRows2TF],2);
                
                % Cropping (remains sorted at this point)
                initCoupleANs1 = initCoupleANs1(~motherRowsTF,:);
                initCoupleANs2 = initCoupleANs2(~motherRowsTF,:);
                
                % ADDING neighbor couples involving newly appeared DAUGHTERS from initNeighborCoupleANsSorted
                daughterRows1TF = ismember(coupleANs1, daughterANs,'rows');
                daughterRows2TF = ismember(coupleANs2, daughterANs,'rows');
                daughterRowsTF = any([daughterRows1TF daughterRows2TF],2);
                
                couple2AddANs1 = coupleANs1(daughterRowsTF,:);
                couple2AddANs2 = coupleANs2(daughterRowsTF,:);
                
                % filtering OUT those that were NOT neighbors of mother cell (to avoid removing newly
                % created junctions with mother cell) (1.21):
                
                % Replacing new daughter ANs with their mother ANs
                motheredCouple2AddANs1 = couple2AddANs1;                                % initialization of matrix
                [daugtherRows1TF, loc1 ] = ismember(motheredCouple2AddANs1, daughterANs,'rows');
                foundLoc1 = loc1(loc1 > 0);
                foundMotherANs1 = motherANsRaw(foundLoc1,:);                                            % use of "motherANsRaw" (2.1)
                motheredCouple2AddANs1(daugtherRows1TF,:) = foundMotherANs1;
                
                motheredCouple2AddANs2 = couple2AddANs2;
                [daugtherRows2TF, loc2] = ismember(motheredCouple2AddANs2, daughterANs,'rows');
                foundLoc2 = loc2(loc2 > 0);
                foundMotherANs2 = motherANsRaw(foundLoc2,:);                                            % use of "motherANsRaw" (2.1)
                motheredCouple2AddANs2(daugtherRows2TF,:) = foundMotherANs2;
                
                % sorting ANs
                motheredCouple2AddANs = [motheredCouple2AddANs1 motheredCouple2AddANs2];
                motheredCouple2AddANs = SortNeighborCouples(motheredCouple2AddANs);             % Sorting neighbor Couples
                
                preExistingNeighborCouplesTF = ismember(motheredCouple2AddANs, initCoupleANs,'rows');        
                 
                % Limiting new neighbor couples to add to ONLY neighbor relationship existing with mothers
                couple2AddANs1 = couple2AddANs1(preExistingNeighborCouplesTF,:);
                couple2AddANs2 = couple2AddANs2(preExistingNeighborCouplesTF,:);
                
                % Updating "initCoupleANs1/2"
                initCoupleANs1 = [initCoupleANs1 ; couple2AddANs1];
                initCoupleANs2 = [initCoupleANs2 ; couple2AddANs2];
                % -----------------------------------------------------------------------------------------------------
                
                
                %%% sorting UPDATED "initCoupleANs" and "coupleANs":
                % -----------------------------------------------------------------------------------------------------
                initCoupleANs = [initCoupleANs1 initCoupleANs2];
                coupleANs = [coupleANs1 coupleANs2];
                
                % Sorting initial and current neighbor Couple ANs:
                [initCoupleANs, initCoupleANs1, initCoupleANs2] = SortNeighborCouples(initCoupleANs);
                [coupleANs, coupleANs1, coupleANs2] = SortNeighborCouples(coupleANs);   
                % -----------------------------------------------------------------------------------------------------
                
                
                %%% Determining NEW neighbor couples (overhaul 1.22)
                % -----------------------------------------------------------------------------------------------------
                newCoupleTF = ~ismember(coupleANs, initCoupleANs,'rows');
                % NB: contains both new junctions by T1s OR division    
                
                % cropping "neighborCoupleANs" to new couples (1.22)
                newCoupleANs1 = coupleANs1(newCoupleTF,:);
                newCoupleANs2 = coupleANs2(newCoupleTF,:);
                % Getting corresponding RNs
                newCoupleRNs1 = ANs2RNs(newCoupleANs1, Correspondence);
                newCoupleRNs2 = ANs2RNs(newCoupleANs2, Correspondence);
                % Sorting RNs (CRITICAL SO THEY CAN BE FOUND IN SIDES.cells) (1.22)
                newCoupleRNs = [newCoupleRNs1 newCoupleRNs2];
                newCoupleRNs = SortNeighborCouples(newCoupleRNs);    % Sorting neighbor Couples
                % NB: keeping merged new couples for compatibility with "History of new junction lengths" part
                % -----------------------------------------------------------------------------------------------------
                
                
                
                %%% Saving new T1 AN couples in "allNewT1CoupleANs" (2.14)
                % --------------------------------------------------------------------
                % NB: idea is to list ALL AN couples that corresponds to new junctions (% start of
                % movie) with their frame of appearance. BUT, as cells divide, AN couples need to
                % change accordingly AND they should NOT be associated with a different n.
                
                [newCoupleANs, newCoupleANs1, newCoupleANs2] = SortNeighborCouples([newCoupleANs1 newCoupleANs2]);
%                 [newT1CoupleANs, newT1CoupleANs1, newT1CoupleANs2] = SortNeighborCouples([newT1CoupleANs1 newT1CoupleANs2]);
                actualNewCoupleANsTF = ~ismember(newCoupleANs, allNewCoupleANs, 'rows'); % look for ANs couples NOT already listed
                actualNewCoupleANs = newCoupleANs(actualNewCoupleANsTF,:);
                nNewCouples2Add = size(actualNewCoupleANs,1);               % number of new junctions by T1 to add (the other "old" new ones already listed)
                              
                % Fiding out ACTUAL frame of appearance for new found couples involving daughters
                actualNewCoupleANs1 = newCoupleANs1(actualNewCoupleANsTF,:);
                actualNewCoupleANs2 = newCoupleANs2(actualNewCoupleANsTF,:);
                % getting mother ANs
                motherActualNewCoupleANs1 = MakeMothers(actualNewCoupleANs1);
                motherActualNewCoupleANs2 = MakeMothers(actualNewCoupleANs2);
                % look for couple involving mothers of those new links
                % AA = new couples we just found
                MA = SortNeighborCouples([motherActualNewCoupleANs1 actualNewCoupleANs2]);
                AM = SortNeighborCouples([actualNewCoupleANs1 motherActualNewCoupleANs2]);
                MM = SortNeighborCouples([motherActualNewCoupleANs1 motherActualNewCoupleANs2]);
                % looking for those AN couples in "allNewCoupleANs"
                [MAtf, MAloc] = ismember(MA, allNewCoupleANs, 'rows');
                [AMtf, AMloc] = ismember(AM, allNewCoupleANs, 'rows');
                [MMtf, MMloc] = ismember(MM, allNewCoupleANs, 'rows');
                
                % Looking for smallest frame number where the earliest "version" of the AN couple appeared
                rowsTFmat = [MAtf AMtf MMtf];       % MA, AM & MM couples can sometimes be found simultaneously (at different locations)
                rowsLocMat = [MAloc AMloc MMloc];
                rowsFramesMat = NaN(nNewCouples2Add,3);
                
                rowsTFind = find(rowsTFmat);
                rowsLocVec = rowsLocMat(rowsTFind);
                rowsFramesVec = allNewFrames(rowsLocVec);         % gets frame numbers of appearance for each
                rowsFramesMat(rowsTFind) = rowsFramesVec;         % put them in the matrix
                rowsFramesMin = min(rowsFramesMat,[],2);          % keeps smallest frame number on each row
                rowsTF = any(rowsTFmat,2);                        % where such a couple was found; CANNOT have 2 ones on same row             
                
                actualNewFrames = n*ones(nNewCouples2Add,1);      % initialization to current frame number "n"
                actualNewFrames(rowsTF) = rowsFramesMin(rowsTF);  % replacing current frame number by the one corresponding to early version of the AN couple
                
                % Filling "allNewT1Frames" and "allNewT1CoupleANs"
                indexStart = find(all(isnan(allNewCoupleANs),2), 1);              % gets first empty row (with only NaNs)
                indexEnd = indexStart + nNewCouples2Add - 1;
                allNewFrames(indexStart:indexEnd) = actualNewFrames;            % filling matrix              
                allNewCoupleANs(indexStart:indexEnd,:) = actualNewCoupleANs;    % NB: ANs are stored already SORTED
                
                % Cropping to minimal size at the end
                if  n == finalFrame
                    allNewCoupleANs = allNewCoupleANs(1:indexEnd,:); 
                    allNewFrames = allNewFrames(1:indexEnd);
                end
                % --------------------------------------------------------------------
                
                
                %% Building history of "new" junction (chord) lengths (1.23,1.24) %% 
                
                % NB: this part has NOT been updated in version 2.14 and therefore does NOT take
                % advantage of the better separation between new junctions created by T1 or by
                % division.
                
                % NB: need to remove AN couples involving a cell that just divided and replace it with the appropriate
                % daughter. For now, leaving OUT new junctions cut into two due to the division of a neighbor mother
                % into two neighbor daughters. 
                
%                 sideRNcouples = SIAbackup.SIDES.cells;                             % gets couples making up each side (2.16)
                sideOfNewCouplesTF = ismember(sideRNcouples, newCoupleRNs,'rows'); % moved here 2.16
                
                newNeighborJunctionLengths = sideChordLengths(sideOfNewCouplesTF);
                
                newNeighborCoupleANs = [newCoupleANs1 newCoupleANs2]; % ALREADY sorted AND matching "newNeighborSideLengths"
                
                % NB: "newNeighborCoupleANs" contains ALL the "new" junctions to consider in CURRENT frame. 5 subcategories:
                % 1) some that already existed as such
                % 2) some already existed but involved ONE mother that just divided
                % 3) some already existed but involved TWO mothers that just divided
                % 4) some already existed but got CUT in two by the division of one cell => EXCLUDED FOR NOW
                % 5) some of those couples have JUST appeared (the rest) => must be added to "allNewJunctionCoupleANs"
                
                
                %%%% update of "allNewJunctionCoupleANs" with daughter cells AND junctions that just appeared
                % --------------------------------------------------------------------
                
                % MUST FIND ROWS IN allNewJunctionCoupleANs THAT MUST BE UPDATED NOW OR IN THE FUTURE
                
                % - transform the outdated rows with mothers by replacing them with BOTH daughters
                % This frame old mothers and new daughters:
                nMothers = size(motherANs,1);
                [daughterCellANs1, daughterCellANs2] = MakeDaughters(motherANs); % 2.6
                             
                % Defining mothers and daughters to look for in "allNewJunctionCoupleANs":
                % --------------------------------------------------------------------
                % IN ORDER TO UPDATE **ALL** NEW JUNCTIONS THAT EVER EXISTED IN THE MOVIE (including those NOT currently
                % existing because the new junction that existed with a mother cell (that has now divided) has currently disappeared):
                %                 motherCellANsToLookFor = [motherCellANsToLookFor; motherCellANs];
                %                 daughterCellANs1ToLookFor = [daughterCellANs1ToLookFor ; daughterCellANs1];
                %                 daughterCellANs2ToLookFor = [daughterCellANs2ToLookFor ; daughterCellANs2];
                
                % IN ORDER TO ONLY UPDATE CURRENTLY **EXISTING** NEW JUNCTIONS:
                motherCellANsToLookFor = motherANs;
                daughterCellANs1ToLookFor = daughterCellANs1;
                daughterCellANs2ToLookFor = daughterCellANs2;
                % --------------------------------------------------------------------
                
                % Replacing motherANs by both daughter ANs => duplicating mother rows
                allNewJunctionCoupleANs1 = allNewJunctionCoupleANs(:,1:nColTotal-1);
                allNewJunctionCoupleANs2 = allNewJunctionCoupleANs(:,nColTotal:(nColTotal-1)*2);
                
                [outdatedRows1TF, motherANs1Loc] = ismember(allNewJunctionCoupleANs1, motherCellANsToLookFor,'rows');
                motherANs1Loc = motherANs1Loc(outdatedRows1TF);
                possibleNewJunctionCoupleANs1D1s = allNewJunctionCoupleANs1;
                possibleNewJunctionCoupleANs1D1s(outdatedRows1TF,:) = daughterCellANs1ToLookFor(motherANs1Loc,:); % replace mother ANs with daughter 1 ANs
                possibleNewJunctionCoupleANs1D2s = allNewJunctionCoupleANs1;
                possibleNewJunctionCoupleANs1D2s(outdatedRows1TF,:) = daughterCellANs2ToLookFor(motherANs1Loc,:); % replace mother ANs with daughter 2 ANs
                
                [outdatedRows2TF, motherANs2Loc] = ismember(allNewJunctionCoupleANs2, motherCellANsToLookFor,'rows');
                motherANs2Loc = motherANs2Loc(outdatedRows2TF);
                possibleNewJunctionCoupleANs2D1s = allNewJunctionCoupleANs2;
                possibleNewJunctionCoupleANs2D1s(outdatedRows2TF,:) = daughterCellANs1ToLookFor(motherANs2Loc,:); % replace mother ANs with daughter 1 ANs
                possibleNewJunctionCoupleANs2D2s = allNewJunctionCoupleANs2;
                possibleNewJunctionCoupleANs2D2s(outdatedRows2TF,:) = daughterCellANs2ToLookFor(motherANs2Loc,:); % replace mother ANs with daughter 2 ANs
                
                
                % NB: if the daughter never make contact again with the neighbor, the outdated rows will remain
                % untouched but that's ok
                
                
                possibleNewJunctionCoupleANsD1s = [possibleNewJunctionCoupleANs1D1s possibleNewJunctionCoupleANs2D1s];
                possibleNewJunctionCoupleANsD2s = [possibleNewJunctionCoupleANs1D2s possibleNewJunctionCoupleANs2D2s];
                
                clear possibleNewJunctionCoupleANs1D1s possibleNewJunctionCoupleANs1D2s...
                    possibleNewJunctionCoupleANs2D1s possibleNewJunctionCoupleANs2D2s% 1.24
                
                possibleNewJunctionCoupleANsD1s = SortNeighborCouples(possibleNewJunctionCoupleANsD1s); % Sorting neighbor Couples
                possibleNewJunctionCoupleANsD2s = SortNeighborCouples(possibleNewJunctionCoupleANsD2s); % Sorting neighbor Couples
                
                % NB: at this point, did NOT consider all cases where BOTH cells in the row were dividing, namely cases
                % [ANs1D1s ANs2D2s] and [ANs1D2s ANs2sD1s]
                
                
                % - each time look for those hypothetical ANs couples involving daughters in "newNeighborCoupleANs"
                [foundD1TF, foundD1Loc] = ismember(possibleNewJunctionCoupleANsD1s, newNeighborCoupleANs,'rows');
                [foundD2TF, foundD2Loc] = ismember(possibleNewJunctionCoupleANsD2s, newNeighborCoupleANs,'rows');
                
                % - IF BOTH hypothetical couples are found, means that the mother's division cut the junction into two
                % => EXCLUDE them from "newNeighborCoupleANs" so as not to re-add them as new junctions in "allNewJunctionCoupleANs"
                foundBothTF = all([foundD1TF foundD2TF],2);
                removeD1loc = foundD1Loc(foundBothTF);
                removeD2loc = foundD2Loc(foundBothTF);
                removeLoc = unique([removeD1loc ; removeD2loc]);
                newNeighborCoupleANsFiltered = setdiff(newNeighborCoupleANs, newNeighborCoupleANs(removeLoc,:),'rows');
                
                % - IF only one is found => replace the old couple with tne new one AND start fill junction length
                replaceD1TF = all([foundD1TF ~foundBothTF],2);
                replaceD2TF = all([foundD2TF ~foundBothTF],2);
                replaceTF = any([replaceD1TF replaceD2TF],2);
                
                % UPDATING "allNewJunctionCoupleANs"
                allNewJunctionCoupleANs(replaceD1TF,:) = possibleNewJunctionCoupleANsD1s(replaceD1TF,:); % new couples involving daughter 1
                allNewJunctionCoupleANs(replaceD2TF,:) = possibleNewJunctionCoupleANsD2s(replaceD2TF,:); % new couples involving daughter 2
                
                clear possibleNewJunctionCoupleANsD1s possibleNewJunctionCoupleANsD2s % 1.24
                
                % CASE where both cell divide in the time interval where the junction doesn't exist: DOUBLE OUtdated
                % => outdatedRows1/2TF need to be updated to score 0, 1 or 2 when both need to be updat               
                
                % Now adding AN couples that appeared for the first time in current frame
                foundNewNeighborCoupleANsTF = ismember(newNeighborCoupleANsFiltered, allNewJunctionCoupleANs,'rows');
                newNeighorsCouplesANs2Add = newNeighborCoupleANsFiltered(~foundNewNeighborCoupleANsTF,:); % gets those that WEREN't already found
                nNewCouples2Add = size(newNeighorsCouplesANs2Add,1);
                
                indexStart = find(all(isnan(allNewJunctionCoupleANs),2), 1); % gets first empty row (with only NaNs)
                indexEnd = indexStart + nNewCouples2Add - 1;
                allNewJunctionCoupleANs(indexStart:indexEnd,:) = newNeighorsCouplesANs2Add; % still already sorted
                
                
                % Finding new junctions in NOW UP TO DATE "allNewJunctionCoupleANs" AND filling junction lengths
                [foundNewNeighborCoupleANsTF, foundNewNeighborCoupleANsLoc] = ismember(newNeighborCoupleANs, allNewJunctionCoupleANs,'rows');
                % removing unfound couples:
                newNeighborJunctionLengthsFound = newNeighborJunctionLengths(foundNewNeighborCoupleANsTF);
                foundNewNeighborCoupleANsLocFound = foundNewNeighborCoupleANsLoc(foundNewNeighborCoupleANsTF);
                % filling new length values for those junctions
                allNewJunctionLengths(foundNewNeighborCoupleANsLocFound,n) = newNeighborJunctionLengthsFound;      % putting values
                
                if n == finalFrame
                    % Cropping to ACTUAL number of new junctions:
                    allNewJunctionCoupleANs = allNewJunctionCoupleANs(1:indexEnd,:);
                    allNewJunctionLengths = allNewJunctionLengths(1:indexEnd,:);
                end
                
                
                %% Determining the origin of new junctions: DIV, DEL, T1 (2.24) %%
                
                 % need to crop "allNewCoupleANs" to remove NaNs if not last frame:
                 if n < finalFrame
                     indexCrop = find(all(isnan(allNewCoupleANs),2), 1) - 1;
                     allNewCoupleANsCrop = allNewCoupleANs(1:indexCrop,:);
                     allNewFramesCrop = allNewFrames(1:indexCrop);
                 else
                     allNewCoupleANsCrop = allNewCoupleANs;
                     allNewFramesCrop = allNewFrames;
                 end
                 
                cnjARG.allNewCoupleANs = allNewCoupleANsCrop;
                cnjARG.allNewFrames = allNewFramesCrop;
                
                cnjARG.allLastFramesDel = allLastFramesDel;
                cnjARG.allDelaminatingLastRNs = allDelaminatingLastRNs;
                cnjARG.n = n;
                cnjARG.allDividingANs = allDividingANs;
                cnjARG.allLastFramesDiv = allLastFramesDiv;

                cnjARG.cellNeighborsOld = cellNeighborsOld;
                cnjARG.CorrespondenceOld = CorrespondenceOld;
          
                % DIV
                [~, allNewDivCouplesTF] = FindCoupleANs(cnjARG,'offspring');      % new junctions by division
                cnjARG.newDivCouplesTF = allNewDivCouplesTF; % update
                % DEL
                [~, allNewDelCouplesTF] = FindCoupleANs(cnjARG,'delamination');  % new junctions by delamination (1.1)
                cnjARG.newDelCouplesTF = allNewDelCouplesTF; % update
                % T1s
                allNewT1CouplesTF = all([~allNewDivCouplesTF ~allNewDelCouplesTF],2);    % new junctions by T1s (mod 1.1)
                cnjARG.newT1CouplesTF = allNewT1CouplesTF; % update
                %-----------------------------------------------------------------------------------------
                
                % Update of OLD quantities
                cellNeighborsOld = cellNeighbors;
                CorrespondenceOld = Correspondence;
                
            end
        end
             
        %% Making CTD images %%    
        
        CTDimageFilename = [saveFolderTracking filesep  filenameCTD '_' num2str(n, digitsFormat) '.' imageFormatOutput]; % mod 2.23
        
        if makeCTDimages || n == startFrame || n == finalFrame % exceptions for start/finalFrame (2.30)
            
            %%% Making delaminating ANs ancestor 3D matrix "ancestorAllDelaminatingANs" (2.12, moved here 2.25) %%
            if n == startFrame
                
                fprintf('Building "ancestorAllDelaminatingANs" 3D matrix to generate CTD images...')
                ancestorAllDelaminatingANs = NaN(nColTotal-1, delCutRow, maxDivisionRound+1);
                ancestorAllDelaminatingANs(:,:,1) = allDelaminatingANs'; % initialized with actual delaminating ANs
                for d = 2:maxDivisionRound+1
                    ancestorAllDelaminatingANs(:,:,d) = MakeMothers(ancestorAllDelaminatingANs(:,:,d-1)')'; % taking mothers at each rounds
                end
                fprintf('Done.\n')
            end
            % NB: building "ancestorAllDelaminatingANs" TRANSPOSE matrix because later using reshape that takes elements COLUMN-WISE
            
            if ~exist(CTDimageFilename,'file') % mod 2.23
                
                %%% Determination of apoptotic cell RNs that will delaminate in "timeB4Del" frames or less (overhaul 2.12, 2.25)
                %---------------------------------------------------------------------------------------------------------
                fprintf('Displaying apoptotic regions according to "timeB4Del"...') % AND "coreDelaminatingLastRNsTF"
                
                [ancestorCoreDelaminatingRNs, ancestorNonCoreDelaminatingRNs] = ...
                    DisplayAncestorDelRNs(ancestorAllDelaminatingANs,coreDelaminatingLastRNsTF,allLastFramesDel,timeB4Del,Correspondence,nColTotal,n,dt); % 2.25
                
                % OLD
%                 nFramesB4Del = round(timeB4Del*60/dt); % conversion in number of frames
%                 allFramesB4Del = allLastFramesDel - n;
%                 allSelectedFramesB4DelTF = allFramesB4Del >= 0 & allFramesB4Del < nFramesB4Del;
%                 % NB: strict < ensures A/D cells are only displayed in their last frame when timeB4Del is 5 min
%                 
%                 % Splitting delaminating RNs to display according to their final RNs status (CORE vs NON-CORE)
%                 coreDelaminatingANsTF = all([allSelectedFramesB4DelTF coreDelaminatingLastRNsTF],2);
%                 nonCoreDelaminatingANsTF = all([allSelectedFramesB4DelTF ~coreDelaminatingLastRNsTF],2);
%                 
%                 % Now gathering all ancestors ANs of delaminating cells that should be displayed:
%                 % RELIABLE delaminations ending with CORE RNs
%                 ancestorCoreDelaminatingANs = ancestorAllDelaminatingANs(:,coreDelaminatingANsTF,:);
%                 ancestorCoreDelaminatingANs = reshape(ancestorCoreDelaminatingANs,nColTotal-1,[]);  % stacking all ANs along dimension 2
%                 ancestorCoreDelaminatingANs = ancestorCoreDelaminatingANs';                         % reshape to normal ANs list
%                 ancestorCoreDelaminatingANs = unique(ancestorCoreDelaminatingANs,'rows');
%                 ancestorCoreDelaminatingRNs = ANs2RNs(ancestorCoreDelaminatingANs, Correspondence); % will only find existing ones
%                 
%                 % UNRELIABLE delaminations ending with NON-CORE RNs
%                 ancestorNonCoreDelaminatingANs = ancestorAllDelaminatingANs(:,nonCoreDelaminatingANsTF,:);
%                 ancestorNonCoreDelaminatingANs = reshape(ancestorNonCoreDelaminatingANs,nColTotal-1,[]);  % stacking all ANs along dimension 2
%                 ancestorNonCoreDelaminatingANs = ancestorNonCoreDelaminatingANs';                         % reshape to normal ANs list
%                 ancestorNonCoreDelaminatingANs = unique(ancestorNonCoreDelaminatingANs,'rows');
%                 ancestorNonCoreDelaminatingRNs = ANs2RNs(ancestorNonCoreDelaminatingANs, Correspondence); % will only find existing ones
                
                fprintf('Done.\n')
                %------------------------------------------------------------------------------------------------
                
                % creating sub directory only if we got there (1.32)
                if n == startFrame
                    mkdir(saveFolderTracking);
                end
                
                %%% Creation of CTD mask for correction (CTimage_forcorrection) at the same time than classical CTD output (2.29)
                %%% Creates empty image:
                CTimage = zeros(imageSize(1),imageSize(2),3);
                CTimage_forcorrection = zeros(imageSize(1),imageSize(2),3);
                
                %%% Counting divisions:
                divisionTags = Correspondence(:,3:end);                                                % [RN AN 1 1 0 0] => starts at 3rd column
                divisionTagsTF = divisionTags > 0;
                nDivisionVector = sum(divisionTagsTF,2);                                               % vector matching Correspondence with n_divisions undergone
                nDivisionMax = max(nDivisionVector);
                
                % Coloring ALL cells according to their number of division:
                nColorDivision = size(colorDivision,1); % 2.7
                nDivColorIndex = min(nColorDivision, 1);                                       % gets corresponding color (nDiv+1 because indices) (mod 2.7)
                nDivTF = nDivisionVector == 0;
                nDivRNs = unique(Correspondence(nDivTF,1));                                         % RNs of regions with n_div
                nDivRNsPixelsTF = ismember(imageLabels, nDivRNs);                                   % directly using imageLabels to find regions (1.28)
                CTimage = Paint(CTimage, nDivRNsPixelsTF, colorDivision(nDivColorIndex,:)); 
                CTimage_forcorrection = Paint(CTimage_forcorrection, nDivRNsPixelsTF, black);
                for nDiv = 1:nDivisionMax
                    nDivColorIndex = min(nColorDivision, nDiv+1);                                       % gets corresponding color (nDiv+1 because indices) (mod 2.7)
                    nDivTF = nDivisionVector == nDiv;
                    nDivRNs = unique(Correspondence(nDivTF,1));                                         % RNs of regions with n_div
                    nDivRNsPixelsTF = ismember(imageLabels, nDivRNs);                                   % directly using imageLabels to find regions (1.28)
                    CTimage = Paint(CTimage, nDivRNsPixelsTF, colorDivision(nDivColorIndex,:));
                    CTimage_forcorrection = Paint(CTimage_forcorrection, nDivRNsPixelsTF,  black);         % Coloring regions:
                end
                
                %%% Overriding colors for cells having divided faster than "minCycleDuration" (2.7)
                allDeltaFramesDiv = allLastFramesDiv - allFirstFramesDiv;                       % NB: we do NOT have the "Times" version yet
                allDeltaTimesDiv = (allDeltaFramesDiv * dt)/60 ;                                % time conversion. NB: no "timeRef" needed as it is a time difference
                dividedTooSoonTF = allDeltaTimesDiv < minCycleDuration;
                % determining division round for d
                allnDivRounds = GetnDivRounds(allDividingANs) + 1; % for each dividing AN, division round that it WILL acquire right AFTER division (2.9)
                firstDivRoundsTF = allnDivRounds == 1;
                dividedTooSoonTF(firstDivRoundsTF) = false;                                     % NOT counting first divisions
                
                dividedTooSoonANs = allDividingANs(dividedTooSoonTF,:);
                daughtersBornTooSoonANs = MakeOffspring(dividedTooSoonANs);                     % will display ALL offspring in special color
                daughtersBornTooSoonRNs = ANs2RNs(daughtersBornTooSoonANs, Correspondence);     % NB: many of "allDividedTooSoonANs"
                % coloring those region pixels
                allDividedTooSoonRNsPixelsTF = ismember(imageLabels, daughtersBornTooSoonRNs);     % directly using imageLabels to find regions
                CTimage = Paint(CTimage, allDividedTooSoonRNsPixelsTF, colorDivisionIssue);
                CTimage_forcorrection = Paint(CTimage_forcorrection, allDividedTooSoonRNsPixelsTF, dark_orange);
                
                
                %%% Blending existing colors with "colorNewCells" for new cells:
                alltimeNewRNsTF = Correspondence(:,2) > nCells0;                     % finds ANs above nCells0
                alltimeNewRNs = unique(Correspondence(alltimeNewRNsTF,1));               % gets corresponding RNs in this frame
                alltimeNCnewRNs = setdiff(alltimeNewRNs, coalescedRNs);                  % removes coalesced cells
                alltimeNCnewRNsPixelsTF = ismember(imageLabels, alltimeNCnewRNs);        % directly using imageLabels to find regions (1.28)
                % Blending existing colors with "colorNewCells" for new cells:
                CTimage = Blend(CTimage, alltimeNCnewRNsPixelsTF, colorNewCells, 0.5);   % 1.9, 1.28
                CTimage_forcorrection = Blend(CTimage_forcorrection, alltimeNCnewRNsPixelsTF, colorNewCells, 0.5);
                
                %%% Overriding colors for NON-CORE apoptotic cells with "colorApoptosisIssue" (2.12):
                nonCoreDelaminatingRNspixelsTF = ismember(imageLabels, ancestorNonCoreDelaminatingRNs);
                CTimage = Paint(CTimage, nonCoreDelaminatingRNspixelsTF, colorApoptosisIssue);
                CTimage_forcorrection = Paint(CTimage_forcorrection, nonCoreDelaminatingRNspixelsTF, colorApoptosisIssue);
                
                %%% Overriding colors for CORE apoptotic cells with "colorApoptosis" (mod 2.12):
                ancestorCoreDelaminatingRNspixelsTF = ismember(imageLabels, ancestorCoreDelaminatingRNs);   % directly using imageLabels to find regions (1.28)
                CTimage = Paint(CTimage, ancestorCoreDelaminatingRNspixelsTF, colorApoptosis);              % 1.4
                CTimage_forcorrection = Paint(CTimage_forcorrection, ancestorCoreDelaminatingRNspixelsTF, yellow);
                
                %%% Overriding colors for macrochaetes with "colorMacrochaetes" (1.25)
                macrochaetesPixelsTF = ismember(imageLabels, macroFoundRNs);                        % directly using imageLabels to find regions (1.28)
                CTimage = Paint(CTimage, macrochaetesPixelsTF, colorMacrochaetes);
                CTimage_forcorrection = Paint(CTimage_forcorrection, macrochaetesPixelsTF, custom_yellow);
                
                %%% Overriding colors for Coalesced cells with "colorFusion":
                coalescedRNsPixelsTF = ismember(imageLabels, coalescedRNs);                          % directly using imageLabels to find regions (1.28)
                CTimage = Paint(CTimage, coalescedRNsPixelsTF, colorFusion);                         % 1.9
                CTimage_forcorrection = Paint(CTimage_forcorrection, coalescedRNsPixelsTF, red);
                
                %%% Coloring BC and FLC
                % Blending existing colors with "colorBorderCells" and "colorFLCells" for FLC display:
                FLCpixelsTF = ismember(imageLabels, FLRNs);                                              % directly using imageLabels to find regions (1.28)
                CTimage = Blend(CTimage, FLCpixelsTF, colorFLCells, 0.8);
                CTimage_forcorrection = Blend(CTimage_forcorrection, FLCpixelsTF, colorFLCells, 0.8);
                
                % Overriding ALL BC colors (not just #1) with "colorBorderCells" by using Paint instead of Blend (1.5)
                BCpixelsTF = ismember(imageLabels, borderRNs);                                           % directly using imageLabels to find regions (1.28)
                CTimage = Paint(CTimage, BCpixelsTF, colorBorderCells);          % 1.5
                CTimage_forcorrection = Paint(CTimage_forcorrection, BCpixelsTF, colorBorderCells);     
                
                %%% Overriding colors for LONE sisters (2.10)
                if exist('allDiscardedANs','var')
                    discardedSisterRNs = ANs2RNs(allDiscardedSisterANs,Correspondence);             % NB: ANs not existing yet or anymore won't be found
                    discaredSisterRNspixelsTF = ismember(imageLabels, discardedSisterRNs);
                    CTimage = Paint(CTimage, discaredSisterRNspixelsTF, colorDivisionDiscarded);
                    CTimage_forcorrection = Paint(CTimage_forcorrection, discaredSisterRNspixelsTF, colorDivisionDiscarded);
                end
                
                %%% Coloring junction pixels with "colorJunctions" (2.5)
                junctionPixelsTF = ismember(imageLabels, 0);
                CTimage = Paint(CTimage, junctionPixelsTF, colorJunctions);
                
                %%% Coloring NEW junctions (2.15,2.16, 2.17,2.24)
                %----------------------------------------------------------------------------------------------------------
                if (displayNewT1Junctions || displayNewDivJunctions) && allSIAbackupAvailableTF && n >= newJuncDisplayFrames(1) && n > startFrame
                    
                    fprintf('Displaying new links according to their origin (T1 vs Div) and "newJuncDisplayTimes"...')
                    
                    %                 % If still in the making of new junction backup, need to crop "allNewCoupleANs" to remove NaNs
                    %                 if makeNewJunctionsBackupTF
                    %                     indexCrop = find(all(isnan(allNewCoupleANs),2), 1) - 1;
                    %                     allNewCoupleANsCrop = allNewCoupleANs(1:indexCrop,:);
                    %                 else
                    %                     allNewCoupleANsCrop = allNewCoupleANs; % has already been cropped
                    %                 end
                    
                    % Loading "allNewJunctionsFile" if not loaded before (2.24)
                    if ~makeNewJunctionsBackupTF &&  newJunctionsBackupNotLoadedYet
                        
                        load(allNewJunctionsFile,'allNewCoupleANs','allNewFrames','allNewDivCouplesTF','allNewDelCouplesTF','allNewT1CouplesTF');
                        junctionBackupNotLoadedYet = false;
                        
                        cnjARG.allNewCoupleANs = allNewCoupleANs;
                        cnjARG.allNewFrames = allNewFrames;
                        cnjARG.newDivCouplesTF = allNewDivCouplesTF;
                        cnjARG.newDelCouplesTF = allNewDelCouplesTF;
                        cnjARG.newT1CouplesTF = allNewT1CouplesTF;
                        
                    elseif makeNewJunctionsBackupTF
                        
                        cnjARG.allNewCoupleANs = allNewCoupleANsCrop;
                        cnjARG.allNewFrames = allNewFramesCrop;
                    end
                    
                    sideDilatedIndices = SIAbackup.SIDES.DilatedIndices; % mod 2.18
                    
                    % Filling argument structure "cnjARG" for function "ColorNewJunctions" (2.17)
                    cnjARG.Correspondence = Correspondence;
                    cnjARG.sideCoupleRNs = sideRNcouples;
                    cnjARG.sideDilatedIndices = sideDilatedIndices;
                    cnjARG.newJuncDisplayFrames = newJuncDisplayFrames;
                    cnjARG.displayNewT1Junctions = displayNewT1Junctions;
                    cnjARG.displayNewDivJunctions = displayNewDivJunctions;
                    cnjARG.colorNewT1Junctions = colorNewT1Junctions;
                    cnjARG.colorNewDivJunctions = colorNewDivJunctions;
                    cnjARG.displayNewDelJunctions = displayNewDelJunctions; % 2.24
                    cnjARG.colorNewDelJunctions = colorNewDelJunctions;% 2.24
                    
                    % Coloring
                    CTimage = ColorNewJunctions(CTimage, cnjARG); % coloring junctions with "ColorNewJunctions" (2.17)
                    CTimage_forcorrection = ColorNewJunctions(CTimage_forcorrection, cnjARG);
                    
                    fprintf('Done.\n')
                end
                %----------------------------------------------------------------------------------------------------------
                
                if makeonlyCorrectionBackup == false % Possibility to run CTD to make only correction masks (2.29)
                
                    % Display & Save (mod 1.12) %%
                    
                    disp("CT SIZE")
                    disp(size(CTimage))
                    figure('PaperPositionMode', 'auto', 'visible', PLOT.displayImages)
                    imshow(CTimage,'Border', 'tight')

                    % Displaying link between new daughters (1.12)
                    if displayJustDividedCellLinks && ~isempty(daughterRNs)
                        line(L_D1D2_Xs, L_D1D2_Ys, 'Color',green,'LineStyle','-','LineWidth',JDClineWidth);
                    end

                    % Display ANs resolved by tracking patches (1.12)
                    if displayPatchedCellNumbers

                        % Initialization (to have them defined)
                        BredRNs = []; RGredRNs = []; RGEredRNs = [];
                        BgreenRNs = []; RGgreenRNs = []; RGEgreenRNs = [];
                        BblueRNs = []; RGblueRNs = []; RGEblueRNs = [];
                        blackRNs = [];

                        % Regions solved by Blue patch
                        %--------------------------------------------------------------------------------------------------------------------
                        if ~isempty(solvedB_RNs(:))
                            BredRNs = solvedB_RNs(:,1);
                            % simple red-blue case
                            if size(solvedB_RNs,2) < 3
                                BblueRNs = solvedB_RNs(:,2);
                                BgreenRNs = [];
                                % red-green-blue case:
                            else
                                BblueRNs = solvedB_RNs(:,3);            % contains NaNs in rows of red-blue case
                                BgreenRNs_TF = ~isnan(BblueRNs);        % gets locations where there is a "green" cell
                                BgreenRNs = solvedB_RNs(BgreenRNs_TF,2);
                            end
                        end
                        %--------------------------------------------------------------------------------------------------------------------

                        % RedGreen patch
                        %--------------------------------------------------------------------------------------------------------------------
                        if ~isempty(solvedRG_RNs(:))
                            RGredRNs = solvedRG_RNs(:,1);
                            RGgreenRNs = solvedRG_RNs(:,2);
                        end
                        %--------------------------------------------------------------------------------------------------------------------

                        % RedGreenExtended patch
                        %--------------------------------------------------------------------------------------------------------------------
                        if ~isempty(solvedRGE_RNs(:))
                            RGEredRNs = solvedRGE_RNs(:,1);
                            RGEgreenRNs = unique(solvedRGE_RNs(:,2:3));
                            RGEgreenRNs = Row2Col(RGEgreenRNs);         % makes sure it's a column vector
                        end
                        %--------------------------------------------------------------------------------------------------------------------

                        % Apoptosis patch
                        %--------------------------------------------------------------------------------------------------------------------
                        if ~isempty(solvedA_RNs(:))
                            blackRNs = solvedA_RNs(:,1);
                        end
                        %--------------------------------------------------------------------------------------------------------------------

                        % Plot of all ANs at once
                        allRedRNs = [BredRNs; RGredRNs; RGEredRNs];
                        allGreenRNs = [BgreenRNs; RGgreenRNs; RGEgreenRNs];
                        allBlueRNs = [BblueRNs; RGblueRNs; RGEblueRNs];
                        PlotANs(allRedRNs, Correspondence, coalescedRNs, cellXYs, red, fontSizeCellNumbers*mFactor, 'bold')
                        PlotANs(allGreenRNs, Correspondence, coalescedRNs, cellXYs, green, fontSizeCellNumbers*mFactor, 'bold')
                        PlotANs(allBlueRNs, Correspondence, coalescedRNs, cellXYs, blue, fontSizeCellNumbers*mFactor, 'bold')
                        PlotANs(blackRNs, Correspondence, coalescedRNs, cellXYs, black, fontSizeCellNumbers*mFactor, 'bold')

                        % gathers all RNs (to avoid regular display of corresponding ANs)
                        allPatchRNs = [allRedRNs; allGreenRNs ; allBlueRNs ; blackRNs];
                    else
                        allPatchRNs = [];
                    end

                    % Displaying cell ANs (mod 1.12)
                    if displayCellNumbers
                        hold on
                        NBNPcells_RNs = setdiff(cellRNs, [allPatchRNs ; borderRNs]); % Non Border & Non Patched RNs
                        PlotANs(NBNPcells_RNs, Correspondence, coalescedRNs, cellXYs, black, fontSizeCellNumbers, 'normal')
                    end

                    %%% DEBUG
                    % hold on
                    % scatter(macroXs(:,n),macroYs(:,n),'bo')

                    % Plotting colorbar (1.30)
                    cmap = [colorApoptosis ; colorDivision];
%                     PlotColorBar('divisions', colorBarXYWH, [-1 nColorDivision-1], fontSizeInfo, colorInfo, cmap); % mod 2.5, 2.7
                    PlotColorBar('# of divisions', colorBarXYWH, [-1 nColorDivision-1], fontSizeInfo, colorInfo, cmap); % mod 2.5, 2.7

                    % Plotting info (time hAPF, animal and scalebar) (1.4,1.9):
                    textAnimal = '';
                    textQuantity = '';
                    if ~minimalInfoDisplay
                        textAnimal = [Animal ' # ' num2str(n)];
                        textQuantity = 'Cell Tracking'; % 1.14, 1.28
                    end
                    time = frame2time(n, timeRef, frameRef, dt,'str');     % 1.7, mod 1.15
                    PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5

                    % Saving image
                    print (printFormat, printResolution, CTDimageFilename); % use of "saveFolderTracking" (1.32)
                    close

                end 
                
                
                % Save CTD correction image  (2.29)
                if exist(pathFolderTMP,'dir') == 0
                    mkdir(pathFolderTMP);
                end
                pathCTimage_forcorrection = [pathFolderGUI filesep 'maskCTD_'];
                if exist(pathCTimage_forcorrection,'dir') == 0                
                    mkdir(pathCTimage_forcorrection);
                end
                Path2CTimage_forcorrection = ['maskCTD_' Animal '_' num2str(n, digitsFormat) '.' imageFormatOutput];
                imwrite(CTimage_forcorrection, [pathFolderGUI filesep 'maskCTD_' filesep Path2CTimage_forcorrection]);
                                             
                
            end
        end
        
        %% Making Tone levels Images of DELAMINATION (1.28)%%
        
        colorLevels = custom_white;
        
        delImageFilename = [saveFolderDelamination filesep 'Delamination_' Animal '_' num2str(n, digitsFormat) '.' imageFormatOutput]; % mod 1.32, 2.23
        
        if makeDelImages && ~exist(delImageFilename,'file') % mod 2.23
            
            % creating sub directory only if we got there (1.32)
            if n == startFrame
                mkdir(saveFolderDelamination);
            end
            
            fprintf('\nMaking gray level image of delamination...')
            delImage = zeros(imageSize); % image initialization (mod 2.5)
            %             delImage = zeros(imageSize) + greyLevelJunctions; % image initialization
            
            remainingRNs = cellRNs;
            for d = 1:nDelMax
                
                dInd = find(nDelRootANsPlot == d);
                dDelaminatingRootANs = delaminatingRootANs(dInd); % gets the root ANs with d divided cells
                
                frameRNs = Correspondence(:,1);
                frameRootANs = Correspondence(:,2);
                
                % getting corresponding RNs
                dRNsTF = ismember(frameRootANs, dDelaminatingRootANs);
                dRNs = frameRNs(dRNsTF);
                
                dPixelsTF = ismember(imageLabels, dRNs); % directly using imageLabels to find regions
                
                % filling image with appropriate graylevel
                dGray = d + 1;
                delImage(dPixelsTF) = grayLevelsDel(dGray);
                
                remainingRNs = setdiff(remainingRNs, dRNs);
            end
            clear dPixelsTF;
            
            remainingRNs = [remainingRNs; borderRNs]; % adding border cells
            remainingPixelsTF = ismember(imageLabels, remainingRNs);    % directly using imageLabels to find regions (1.28)
            delImage(remainingPixelsTF) = grayLevelsDel(1);             % corresponds to d == 0
            clear remainingPixelsTF;
            
            % Turning grey levels into colorDel levels (2.5)
            delImageR = 1-colorLevels(1)*delImage;
            delImageG = 1-colorLevels(2)*delImage;
            delImageB = 1-colorLevels(3)*delImage;
            delImageRGB = cat(3,delImageR,delImageG,delImageB);
            clear delImageR delImageG delImageB; % Victoire
%             clear delImage delImageR delImageG delImageB;
            
            %             % Making RGB version to add colors
            %             delImageRGB = repmat(delImage, [1 1 3]);
            %             clear delImage;
            
            %%% Coloring junction pixels with "colorJunctions" (2.5)
            junctionPixelsTF = ismember(imageLabels, 0);
            delImageRGB = Paint(delImageRGB, junctionPixelsTF, colorJunctions);
            
            %%% VICTOIRE PAPER %%%
            % making border cell contours thicker
%             [~, ~, borderRNs] = GetCellCategories(SIAbackup.CELLS.CategoryTags);
            borderFLcellsPixels = SIAbackup.CELLS.DilatedContourIndices(borderRNs);
            borderFLcellsPixels = cell2mat(borderFLcellsPixels);
            borderFLcellsPixels = SideDilator(imageSize, borderFLcellsPixels, 4);
            delImageRGB = Paint(delImageRGB, borderFLcellsPixels, grey);
            
            %%% Overriding colors for macrochaetes with "colorMacrochaetes" (1.25, 12.9)
            macrochaetesPixelsTF = ismember(imageLabels, macroFoundRNs);
            delImageRGB = Paint(delImageRGB, macrochaetesPixelsTF, colorMacrochaetes);   % mod 2.5
            
            % Overriding ALL borderCells colors with "colorBorderCells" by using Paint instead of Blend (2.4)
            BCpixelsTF = ismember(imageLabels, borderRNs);                    % directly using imageLabels to find regions
            delImageRGB = Paint(delImageRGB, BCpixelsTF, colorBorderCells); % mod 2.5
            
            % Saving image info displayed with "print"
            % ----------------------------------------------------
            figure('PaperPositionMode','auto', 'visible', PLOT.displayImages)
            imshow(delImageRGB,'Border', 'tight')
            
            % Plotting colorbar (1.30)
            cmap = 1-grayLevelsDel*colorLevels; % 2.5
            %             cmap = repmat(grayLevelsDel,1,3);
            PlotColorBar('apoptosis', colorBarXYWH, [0 nDelMax], fontSizeInfo, colorInfo, cmap);
%             PlotColorBar('# of delaminations', colorBarXYWH, [0 nDelMax], fontSizeInfo, colorInfo, cmap);
            
            % Plotting info (time hAPF, animal and scalebar)
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(n)];
                textQuantity = 'Delamination';
            end
            time = frame2time(n, timeRef, frameRef, dt,'str');
            PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
            
            % Saving image
%             print (printFormat, printResolution, delImageFilename); % use of "saveFolderDelamination" (1.32)
            imwrite(delImageRGB, [saveFolderDelamination filesep 'Delamination_' Animal '_iw_' num2str(n, digitsFormat) '.' imageFormatOutput])
%             export_fig([saveFolderDelamination filesep 'Delamination_' Animal '_' num2str(n, digitsFormat) '.' imageFormatOutput], '-pdf');             % overwrites existing file (1.28)
            close
            clear delImageRGB;
            fprintf('Done.\n')
            % ----------------------------------------------------
            
        end
                
        %% Making Tone levels Images of DIVISION (1.27, 1.28, 2.5)%%
        
        colorLevels = [1 1 1] - dark_green;
        
        divImageFilename = [saveFolderProliferation filesep 'Proliferation_' Animal '_' num2str(n, digitsFormat) '.' imageFormatOutput]; % mod 1.32, 2.23
        
        if makeDivImages && ~exist(divImageFilename,'file') % mod 2.23
            
            % creating sub directory only if we got there (1.32)
            if n == startFrame
                mkdir(saveFolderProliferation);
            end
            
            fprintf('\nMaking gray level image of proliferation...')
            divImage = zeros(imageSize); % image initialization (mod 2.5)
            %             divImage = zeros(imageSize) + greyLevelJunctions; % image initialization
            
            remainingRNs = cellRNs;
            for d = 1:nDivMax
                
                dInd = find(nDivRootANsPlot == d);
                dDividingRootANs = dividingRootANs(dInd); % gets the basic ANs with d divided cells
                
                frameRNs = Correspondence(:,1);
                frameRootANs = Correspondence(:,2);
                
                dRNsTF = ismember(frameRootANs,dDividingRootANs);
                dRNs = frameRNs(dRNsTF);
                
                dPixelsTF = ismember(imageLabels, dRNs); % directly using imageLabels to find regions (1.28)
                
                % filling image
                dGray = d + 1;
                divImage(dPixelsTF) = grayLevelsDiv(dGray); % 1.28
                
                remainingRNs = setdiff(remainingRNs, dRNs);
            end
            clear dPixelsTF;
            
            remainingRNs = [remainingRNs; borderRNs];                 % adding border cells
            remainingPixelsTF = ismember(imageLabels, remainingRNs);    % directly using imageLabels to find regions (1.28)
            divImage(remainingPixelsTF) = grayLevelsDiv(1);             % corresponds to d == 0
            clear remainingPixelsTF;
            
            % Turning grey levels into colorDiv levels (2.5)
            divImageR = 1-colorLevels(1)*divImage;
            divImageG = 1-colorLevels(2)*divImage;
            divImageB = 1-colorLevels(3)*divImage;
            divImageRGB = cat(3,divImageR,divImageG,divImageB);
            clear divImage divImageR divImageG divImageB;
            
            %             % Making RGB version to add colors
            %             divImageRGB = repmat(divImage, [1 1 3]);
            %             clear divImage;
            
%             %%% VICTOIRE PAPER %%% 
%             % Applying death mask:
%             delImageTF = logical(delImage);
%             divImageRGB = Paint(divImageRGB, delImageTF, dark_grey);
            
            %%% Coloring junction pixels with "colorJunctions" (2.5)
            junctionPixelsTF = ismember(imageLabels, 0);
            divImageRGB = Paint(divImageRGB, junctionPixelsTF, colorJunctions);
            
            %%% Overriding colors for macrochaetes with "colorMacrochaetes" (1.25,1.29)
            macrochaetesPixelsTF = ismember(imageLabels, macroFoundRNs);
            divImageRGB = Paint(divImageRGB, macrochaetesPixelsTF, colorMacrochaetes);
            
            % Overriding ALL borderCells colors with "colorBorderCells" by using Paint instead of Blend (2.4)
            BCpixelsTF = ismember(imageLabels, borderRNs);                      % directly using imageLabels to find regions
            divImageRGB = Paint(divImageRGB, BCpixelsTF, colorBorderCells);


            %%% VICTOIRE PAPER %%% 
            % making border cell contours thicker
%             [~, ~, borderRNs] = GetCellCategories(SIAbackup.CELLS.CategoryTags);
            borderFLcellsPixels = SIAbackup.CELLS.DilatedContourIndices(borderRNs);
            borderFLcellsPixels = cell2mat(borderFLcellsPixels);
            borderFLcellsPixels = SideDilator(imageSize, borderFLcellsPixels, 2);
            divImageRGB = Paint(divImageRGB, borderFLcellsPixels, grey);
            
            % Saving image info displayed with "print"
            % ----------------------------------------------------
            figure('PaperPositionMode','auto', 'visible', PLOT.displayImages)
            imshow(divImageRGB,'Border', 'tight')
            %             set(gcf,'GraphicsSmoothing','off')
            
            % Plotting colorbar (1.30)
            cmap = 1-grayLevelsDiv*colorLevels; % 2.5
%             cmap = repmat(grayLevelsDiv,1,3);
            PlotColorBar('# of divisions', colorBarXYWH, [0 nDivMax], fontSizeInfo, colorInfo, cmap); % mod 2.5
            
            % Plotting info (time hAPF, animal and scalebar)
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(n)];
                textQuantity = 'Proliferation';
            end
            time = frame2time(n, timeRef, frameRef, dt,'str');
            PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5, mod 2.5
            
            % Saving image
            print (printFormat, printResolution, divImageFilename); % use of "saveFolderDivision" (1.32)
%             imwrite(divImageRGB, [saveFolderProliferation filesep 'Proliferation_' Animal '_iw_' num2str(n, digitsFormat) '.' imageFormatOutput])
%             export_fig([saveFolderProliferation filesep 'Proliferation_' Animal '_' num2str(n, digitsFormat) '.' imageFormatOutput], '-pdf');             % overwrites existing file (1.28)
            close
            clear divImageRGB;
            fprintf('Done.\n')
            % ----------------------------------------------------
            
        end
        
       disp('---------------------------------------------------------------------------------');

        

        %% progressbar update %%
        if PLOT.displayImages == "on"
            progressbar(iterationIndex/nFrames)
        end
        
    end
    
    
    %% Saving backups for further analysis and replot (mod 2.1) %%
    
    if ~delBackupCompleteTF || ~divBackupCompleteTF || (~divSIAbackupTF && makeDivSIAbackupTF) ||...
       (foundMacroClickFileTF && ~macroBackupCompleteTF) || (~newJuctionBackupTF &&  makeNewJunctionsBackupTF)
        
        disp(' '); disp(' ');
        disp(['CTD' ' ' version  ': processing "' Animal '": saving completed backups']);
        disp('---------------------------------------------------------------------------------');
    end
    
    % Saving complete backup "allApopototicCells.mat" (including "allNBlastXYs") (1.17, 2.1)
    if ~delBackupCompleteTF
        
        allFirstTimesDel = frame2time(allFirstFramesDel,timeRef,frameRef,dt,'dec'); % turning firt frames numbers into times
        
        allDelaminatingRNsFilterLoc = find(allDelaminatingRNsFilterTF);         % rather ONLY saves indices to be switched off if needed, back in 2.19
        % NB: to exclude border, FL and coalesced RNs, just do : allDelaminatingRNs(allDelaminatingRNsFilterLoc) = NaN;

        fprintf('Saving final "allDelaminatingCells.mat" backup file (and erasing the "temp" one)...')
        save(allDelaminatingCellsFile,'allDelaminatingANs','allLastFramesDel','allLastTimesDel','delaminatingRootANs',...
            'nDelRootANs','allDelaminatingLastXYs','allDelaminatingRNs','allFirstFramesDel','allFirstTimesDel',... % 2.1, 2.2, 2.4, 2.6
            'allDelaminatingLastRNs', 'coreDelaminatingLastRNsTF','allDelaminatingRNsFilterLoc'); % 2.11, 2.12, use of "allDelaminatingRNsFilterLoc" (2.19)
        delete(allDelaminatingCellsTEMPfile);
        delBackupCompleteTF = true;
        fprintf('Done.\n')
    end
    
    % Saving complete backup "allDividingCells.mat" (including allDaughterOne/TwoCentroid/JunctionXYs) (2.1)
    if ~divBackupCompleteTF
        
        allFirstTimesDiv = frame2time(allFirstFramesDiv,timeRef,frameRef,dt,'dec'); % turning firt frames numbers into times
        
        % Getting round of division for each div ANs ("allnDivRounds") (2.7)
        allnDivRounds = GetnDivRounds(allDividingANs) + 1; % for each dividing AN, division round that it WILL acquire right AFTER division (2.9) 
        
        % Making "allDividedTooSoonTF" (2.7)
        allDeltaTimesDiv = allLastTimesDiv - allFirstTimesDiv;                  % duration of existence of each divided cell
        allDividedTooSoonTF = allDeltaTimesDiv < minCycleDuration;
        firstDivRoundsTF = allnDivRounds == 1;                                  % 1st division of cells
        allDividedTooSoonTF(firstDivRoundsTF) = false;                          % excluding first round of division
           
        allDividingRNsFilterLoc = find(allDividingRNsFilterTF);         % rather ONLY saves indices to be switched off if needed, back in 2.19
        % NB: to exclude border, FL and coalesced RNs, just do : allDividingRNs(allDividingRNsFilterLoc) = NaN;

        fprintf('Saving final "allDividingCells.mat" backup file (and erasing the "temp" one)...')
        save(allDividingCellsFile,'allDividingANs','allLastFramesDiv','allLastTimesDiv','dividingRootANs',... % loaded from TEMP backup
            'nDivRootANs','allSisterFirstRNs','allDividingLastRNs',...                                               % loaded from TEMP backup (2.10)
            'allDividingRNs','allFirstFramesDiv','allFirstTimesDiv','allDividedTooSoonTF',... % specific to *complete* backup  
            'allDividingRNsFilterLoc','allDividingLastXYs');     % 2.12, use of "allDividingRNsFilterLoc" (2.19), "allDividingLastXYs" (2.20)
        
         % Appends backup with "discarded" quantities (2.10)
        if exist('allDiscardedANs','var')
            
            save(allDividingCellsFile,'allDiscardedANs', 'allDiscardedLastRNs', 'allDiscardedSisterANs', 'allDiscardedSisterFirstRNs',...
                'allLastFramesDis', 'allLastTimesDis','-append');
        end
        
        delete(allDividingCellsTEMPfile);
        divBackupCompleteTF = true;
        fprintf('Done.\n')
    end
    
    % Saving division SIA backup "allDividingCellsSIA.mat" (2.8)
    if ~divSIAbackupTF && makeDivSIAbackupTF
        
        fprintf('Saving final "allDividingCells.mat" backup file (and erasing the "temp" one)...')
        save(allDividingCellsSIAfile,'allSisterCentroidXYs','allSisterJunctionXYs');       
        divSIAbackupTF = true;
        fprintf('Done.\n')
    end
    
    % Saving complete backup "macroCells.mat" (including "macroRNs") (2.2)
    if foundMacroClickFileTF && ~macroBackupCompleteTF
        
        fprintf('Saving final "macroCells.mat" backup file (and erasing the "temp" one)...')
        save(macroCellsFile,'macroANs','macroTypes','clickedMacroIndices','clickFrame','clickTime', 'macroRNs');
        delete(macroCellsTEMPfile);
        macroBackupCompleteTF = true;
        fprintf('Done.\n')
    end
    
    % Saving junction related backups (1.23, 2.16)
    if ~newJuctionBackupTF &&  makeNewJunctionsBackupTF % 2.16
       
        fprintf('Saving "allNewJunctions.mat" backup file...')
        save(allNewJunctionsFile,'allNewJunctionLengths','allNewJunctionCoupleANs','allNewCoupleANs','allNewFrames',... % 2.14, 2.15
                                'allNewDivCouplesTF','allNewDelCouplesTF','allNewT1CouplesTF');                         % 2.24 
        newJuctionBackupTF = true;
        fprintf('Done.\n')
    end
    
    disp('---------------------------------------------------------------------------------');

    
end

%% All-time Delamination map %%

disp(' '); disp(' ');
disp(['CTD' ' ' version  ': processing "' Animal '": creating all-time maps']);
disp('---------------------------------------------------------------------------------');


if delBackupCompleteTF && ~exist(delaminationMapFile,'file') % 2.1, 2.22
    
    % Initiate figure (1.29)
    cmap = [[1 1 1]; jet(nTones)];
    tBackground = InitiateColorMapImage(imageSize, tMin, tMax, cmap);
    [hc, valVector]= PlotColorBar('hAPF', colorBarXYWH, [tMin tMax], fontSizeInfo, colorInfo, cmap);
    
    caxis([tBackground tMax]);      % colormap will cover this range of values
    set(hc, 'XTick', valVector);    % specifies the values to display on colorbar
    
    % Spreads markers at stored CoMs
    scatter(allDelaminatingLastXYs(:,1), allDelaminatingLastXYs(:,2), markerSize, allLastTimesDel, 'Marker','.')
    
    % Plotting info (time hAPF, animal and scalebar) (1.4, 1.9):
    textAnimal = '';
    textQuantity = '';
    if ~minimalInfoDisplay
        textAnimal = [Animal ' # ' num2str(startFrame) '-' num2str(finalFrame)];
        textQuantity = 'Delamination';                                              % 1.28
    end
    timeRange = [frame2time(startFrame, timeRef, frameRef, dt,'str') '-' frame2time(finalFrame, timeRef, frameRef, dt,'str')]; % 1.7, 1.15
    PlotInfo(textQuantity, '',0, black, ['\mu' 'm'], textAnimal, timeRange, black, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth)
    
    % Saves image:
    fprintf('Saving delamination map...');
    print (printFormat, printResolution, delaminationMapFile); % saving in saveFolder (2.1)
    close
    fprintf('Done.\n');
    
else
    disp('No apoptosis/delamination detected OR map already exists.');
end

%% All-time Division (CoM) map (mod 2.1,2.3, 2.8) %%

if divBackupCompleteTF && divSIAbackupTF && ~exist(divisionMapCoMsFile,'file') % 2.1, 2.8, 2.22
    
    %%% Creates white image:
    alltimeSisterCentroidXs = ([allSisterCentroidXYs(:,1,1) allSisterCentroidXYs(:,1,2)])';
    alltimeSisterCentroidYs = ([allSisterCentroidXYs(:,2,1) allSisterCentroidXYs(:,2,2)])';
    
    divImage = ones(imageSize);
    divImageRGB = repmat(divImage, [1 1 3]); % making it RGB so colormap won't be applied
    
    figure('PaperPositionMode','auto', 'visible', PLOT.displayImages)
    imshow(divImageRGB,'Border', 'tight')
    
    % Plotting colorbar (1.30)
    cmap = [[1 1 1]; jet(nTones)];
    PlotColorBar('hAPF', colorBarXYWH, [tMin tMax], fontSizeInfo, colorInfo, cmap);
    
    %%% Setting up colors do draw division bars
    allLastTimesDivCapped = allLastTimesDiv;
    allLastTimesDivCapped(allLastTimesDiv < tMin) = tMin;
    allLastTimesDivCapped(allLastTimesDiv > tMax) = tMax;
    
    tStep = (tMax-tMin)/(nTones-1);
    ds = (allLastTimesDivCapped-tMin)/tStep;
    ds = int16(ds)+1+1;                                                   % defines position in colormap for each edge
    % NB: +1 so that minTplot (ds =0) corresponds to first tone in cmap; +1 again since white tone has been added as first tone for
    % background => edges must start at tone #2
    
    % FIRST sets the color that will be assigned to each bar by imposing color order in which bars will be drawn:
    set(gca,'ColorOrder',cmap(ds,:));     % replaces default color order by tones corresponding to each edge tension
    
    %%% Drawing bars (1.30)
    line(alltimeSisterCentroidXs, alltimeSisterCentroidYs,'LineStyle','-','LineWidth', JDClineWidth); % mod 2.4
    
    % Plotting info (time hAPF, animal and scalebar) (1.4, mod 1.9):
    textAnimal = '';
    textQuantity = '';
    if ~minimalInfoDisplay
        textAnimal = [Animal ' # ' num2str(startFrame) '-' num2str(finalFrame)];
        textQuantity = 'Divisions (CoMs)'; % 1.28
    end
    timeRange = [frame2time(startFrame, timeRef, frameRef, dt,'str') '-' frame2time(finalFrame, timeRef, frameRef, dt,'str')]; % 1.7, 1.15
    PlotInfo(textQuantity, '',0, black, ['\mu' 'm'], textAnimal, timeRange, black, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth)
    
    % Saves image:
    fprintf('Saving division map (CoMs)...');
    print (printFormat, printResolution, divisionMapCoMsFile); % saving in saveFolder (2.1)
    close
    fprintf('Done.\n');
else
    disp('No division detected OR no SIA backups OR map already exists.');
end

%% All-time Division (Junction) map (mod 2.1) %%

if divBackupCompleteTF && divSIAbackupTF && ~exist(divisionMapJsFile,'file') % 2.1, 2.8, 2.22
    
    %%% Creates white image:
    alltimeSisterJunctionXs = ([allSisterJunctionXYs(:,1,1) allSisterJunctionXYs(:,1,2)])';
    alltimeSisterJunctionYs = ([allSisterJunctionXYs(:,2,1) allSisterJunctionXYs(:,2,2)])';
    
    divImage = ones(imageSize);
    divImageRGB = repmat(divImage, [1 1 3]); % making it RGB so colormap won't be applied
    
    figure('PaperPositionMode','auto', 'visible', PLOT.displayImages)
    imshow(divImageRGB,'Border', 'tight')
    
    % Plotting colorbar (1.30)
    cmap = [[1 1 1]; jet(nTones)];
    PlotColorBar('hAPF', colorBarXYWH, [tMin tMax], fontSizeInfo, colorInfo, cmap);
    
    %%% Setting up colors do draw division bars
    allLastTimesDivCapped = allLastTimesDiv;
    allLastTimesDivCapped(allLastTimesDiv < tMin) = tMin;
    allLastTimesDivCapped(allLastTimesDiv > tMax) = tMax;
    
    tStep = (tMax-tMin)/(nTones-1);
    ds = (allLastTimesDivCapped-tMin)/tStep;
    ds = int16(ds)+1+1;                                                   % defines position in colormap for each edge
    % NB: +1 so that minTplot (ds =0) corresponds to first tone in cmap; +1 again since white tone has been added as first tone for
    % background => edges must start at tone #2
    
    % FIRST sets the color that will be assigned to each bar by imposing color order in which bars will be drawn:
    set(gca,'ColorOrder',cmap(ds,:));     % replaces default color order by tones corresponding to each edge tension
    
    %%% Drawing bars (1.30)
    line(alltimeSisterJunctionXs, alltimeSisterJunctionYs,'LineStyle','-','LineWidth', JDClineWidth); % mod 2.4
    
    % Plotting info (time hAPF, animal and scalebar) (1.4, mod 1.9):
    textAnimal = '';
    textQuantity = '';
    if ~minimalInfoDisplay
        textAnimal = [Animal ' # ' num2str(startFrame) '-' num2str(finalFrame)];
        textQuantity = 'Divisions (Js)'; % 1.28
    end
    timeRange = [frame2time(startFrame, timeRef, frameRef, dt,'str') '-' frame2time(finalFrame, timeRef, frameRef, dt,'str')]; % 1.7, 1.15
    PlotInfo(textQuantity, '',0, black, ['\mu' 'm'], textAnimal, timeRange, black, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth)
    
    % Saves image:
    fprintf('Saving division map (Junctions)...');
    print (printFormat, printResolution, divisionMapJsFile); % saving in saveFolder (2.1)
    close
    fprintf('Done.\n');
else
    disp('No division detected OR no SIA backups OR map already exists.');
end

disp('---------------------------------------------------------------------------------');

%% Creation of csv for ONEAT evaluation of MATLAB predictions

%if MakeONEATcsv
%    ONEAT_evaluation_csv_creation
%end 


%% History %%

% FUTURE C++ Tracking IMPROVEMENTS:
%------------------------------------------------------------------------------------------------------
% - fix CT "just_divided_cells_RN_XX.txt" files that do not pair daughter RNs AT ALL!!
% - fix CT "dividing_cells_RN_XX.txt" files that contains RNs corresponding to cells NOT dividing (most
% likely due to divisions cancelled by a tracking patch and not updated in the txt file)
% IMPORTANT: => canNOT directly use those txt files THAT CAN HAVE WRONG MOTHER RNs AND MISPAIRED
% COUPLES OF RNs
%------------------------------------------------------------------------------------------------------

% FUTURE IMPROVEMENTS:
%------------------------------------------------------------------------------------------------------
% - plot cell trajectories? rather do it in CTA?
% - global dnA and dnD rate curves (OR cropped to first 4 macro x2 so everything is comparable)
% - FIX MASSIVE REDUNDANCY between "allNewCoupleANs" and "allNewJunctionCoupleANs", the latter matching the matrix of
% junction histories "allNewJunctionLengths".
% - stop excluding coalesced RNs for macrochaetes because then they do not appear in yellow when a cell coalesces into
% them (save a TF matrix (like done for Div and Del) for them as well?
%------------------------------------------------------------------------------------------------------

% 04/04/2023: 2.31 (Boris)
% - made changes to display "delamination" and "ploliferation" images for
% Victoire's apoptosis article
% - regular junctions in CTD images are now colored with "colorJunctions"
% defined in SAP_parameters.

% 25/09/2020: 2.30 (Boris)
% - now saves first and last CTD images when "makeCTDimages" = false.

% 25/09/2020: 2.29 (Lucas)
% - Creation of new frames output for Correction Interface, to see
% CTD frames on it
% - Call ONEAT_evaluation_csv_creation Routine to create csv files for
% ONEAT evaluation of MATLAB predictions of Apoptosis and Divisions if
 MakeONEATcsv = 1;
% - Possiblity to only make CTD mask for correction and no other output.

% 26/04/2020: 2.28
% - minor changes to enable the processing of a single frame

% 18/10/2019: 2.27
% - adjustments to save a version of CTD images with "imwrite" for the
% segmentation interface

% 20/04/2019: 2.26
% - increased initial size of tables related to Other cells: nOtherANsMax = 20*nRow;
% - moved progressbar update outside of the CTD figure because was not updated otherwise

% 05/04/2019: 2.25
% - now display delaminations using function "DisplayAncestorDelRNs"

% 02/04/2019: 2.24
% - added display of new junctions formed after delamination (still
% displayed after division of cell involved)
% - now saving "allNewDivCouplesTF", "allNewDelCouplesTF" and
% "allNewT1CouplesTF" in the "allNewJunctions.mat" backup, thereby making
% the replot of new junctions fast and easy.
% - fixed bug that prevented last image from showing newly formed junctions
% - remove comments before version 2.0

% 24/07/2018: 2.23
% - now skipping generation of images when they already exist

% 17/05/2018: 2.22
% - fixed "macroClickFile" path that was not up to date
% - now also check that last CTD image exists before not running (when
% "makeCTDimage" is true).
% - stopped overwritting maps when the image already exists

% 13/03/2018: 2.21
% - now directly determining "nCells0" using function "GetnCells0".

% 31/01/2018: 2.20
% - finished fixing BIG mistake in "allOtherANs/RNs..." matrices: was due
% to a "startRow" in the "allOtherCells" part that was changed by the
% "allDividingCells" part! Now properly reinitilazing startRow for each
% cell category
% - now saving "allDividingLastXYs" in "allDividingCells.mat" backup
% - now consistently initialize tables with "NaN" rather than "zeros".
% - removed junction tag in CTD image folder name when SIA backups are NOT
% available (since it is then irrelevant)
% - increased initial "nOtherANsMax" from 8*nRow to 20*nRow and
% "nDividingANsMax" from 3*nRow to 8*nRow
% - increased initial "nJunctionsMax" from 18*nCells to 50*nCells

% 28/01/2018: 2.19
% - partly fixed BIG mistake in "allOtherRNs" and related matrices due to
% bad filtering of border, FL, and coalesced RNs => everything picked from
% this set of tables was wrong! Now gives right "allOther" matrices WHEN
% generated separately from "allDiv" backups.
% - now saves "allOtherRNsFilterLoc" for filtering that must be applied
% later on "allOtherRNs".
% - now for border, FL, and coalesced RNs filtering, saves again vector of
% locations rather than huge logical table ("allDividingRNsFilterLoc" and
% "allDelaminatingRNsFilterLoc").

% 25/01/2018: 2.18
% - changes for compatibility with SIA 3.2 and new function names

% 08/12/2017: 2.17 *WORKS WITH SIA 2.21*
% - possibility to display new junctions with different colors according to when they are created (parameter
% "newJuncDisplayTimes" in "AIA_parameters")
% - now using function "ColorNewJunctions" to color new junctions and make it easier to do the same in CPT
% - moved update/definition of "newJuncDisplayTimes/Frames" out to "AIA_parameters"
% - moved out determination of "nCells0Used" to "AIA_parameters"
% - accordingly moved up the saving of parameter txt file

% 07/12/2017: 2.16
% - replaced "displayNewJunctions" by "displayNewT1Junctions" and "displayNewDivJunctions"
% - use of new junction backup "allNewJunctions.mat" to plot newly formed junctions by T1s AND by division: now saves
% "allNewCoupleANs" and "allNewFrames" in backup, and use function "FindCoupleANs" right before plot to separate new
% junctions created by T1s or by Divisions.

% 07/12/2017: 2.15 BETA
% - use of new junction backup to plot newly formed junctions by T1s
% - BETA because does NOT work for junctions newly formed by divisions
% - loading all complete backups right at the beginning instead of at the end of 2nd iteration
% - stopped going through all the new junction part when the corresponding backup exists

% 04/12/2017: 2.14 BETA
% - BETA version because initially built to start considering new junction ONLY for n > newJunctionStartFrame, but then
% started to shift to determine all-time new junctions and keep track of when they appear to be able not to decide which
% ones to display)
% - accordingly starting to save "allNewT1CoupleANs" and "allNewT1Frames" in allNewJunctions.mat file to rebuild all new
% junctions from a backup file that could also be used by CPT...
% - now supports display of new junctions starting at arbitrary time "newJunctionStartTime"
% - in juction tracking, better separates new junctions created by T1s and those created by division.
% In particular, stopped adding new junctions between daughter cells to "initNeighborCoupleANs" just
% for those not to appear as new.

% 01/12/2017: 2.13
% - finally gathered determination of complete lists of delaminating, dividing and other cell ANs into
% a single loop over frames. This substantially increases execution time as many txt files were loaded
% several times in each iterations.
% - fixed bug in calculation of "allDelaminatingLastXYs"
% - now overrides display of non-core delaminating ANs with issues by the core ones (but delamination
% issues get overriden by regular delaminations that are more important to display).

% 01/12/2017: 2.12
% - added "coreDelaminatingLastRNsTF" boolean vector that contains 1 for delaminating cells that end
% with a CORE RNs, and 0 for the other ones. NON-CORE delaminating RNs are UNRELIABLE and mostly wrong.
% - accordingly excludes non-core del cells from del statistics (Del maps)
% - accordingly displays differently delaminating cells that end with non-core RNs
% ("colorDelaminationIssue") => overhaul of display of delaminating cells "timeB4Del" hours before
% delamination.
% - "nDelFrames" became "timeB4Del" in hours in AIA parameters
% - restored the saving of "allDividingRNsFilterTF" and "allDelaminatingRNsFilterTF" instead of
% directly applying filters while filling "allDelaminatingRNs" and "allDividingRNs"
% - "allNBlastXYs" became "allDelaminatingLastXYs" and ONLY includes XYs of CORE RNs (used to keep FL)

% 30/11/2017: 2.11
% - now saving "allDelaminatingLastRNs" (right from TEMP backup), which will enable to STOP loading
% "delaminating_cells_XX.txt" txt file (and later, to manually correct the tracking)

% 24/11/2017: 2.10 IMPORTANT CHANGES: MADE RELIABLE "allDividingLastRNs" and "allSisterFirstRNs" tables
% - those two tables replace the loading of "just_divided_cells_RN_XX.txt" and "dividing_cells_RN_XX.txt" files
% - completely stopped loading those two txt files. Now ONLY use "Correspondence" to build lists of cells that divide
% and their daughters ("allDividingANs", "allSisterFirstRNs"...)
% - created lists related to "discarded" ANs: these are ANs that were NOT listed allDividingANs because they yield ONLY
% one single sister ANs, which of course should NOT occur.
% - stopped saving other error log txt file than the one related to discarded cells
% - fixed bug where some sister junctions where not found (leading to 0 in "sisterRNsMatLoc")
% - now fills up "allSisterFirstRNs" when determining "allDividingANs" and saves it in "allDividingCellsTEMP.mat" backup
% - use of "MakeMothers" rather than "MakeAncestors(XXX,'youngest')
% - "allDividingLastRNs" now also saved in TEMP backup
% - changed the name of some quantities saved in backups

% 17/11/2017: 2.9 introduced "allOtherCells.mat" backup
% - could not rebuild daughter history for cells that divide only once => now get remaining cells and build their RNs
% histories as well => created "allOtherCells.mat" (see top for description)
% - moved saving of txt file containing parameters into loop over frames so it can contain nCells0 and nCells0Used
% - now using function "GetnDivRounds" to determine "allnDivRounds", which is NOT saved anylonger in backups.

% 16/11/2017: 2.8
% - symmetrized treatment of delamination and divisions
% - created an extra backup "allDividingCellsSIA.mat" that ONLY contains the quantities that requires SIA backups to be calculated.
% - a direct consequence is that almost everything now runs without SIA backups (new CTD maps showing division that
% occurred too soon,...). ONLY calculations of "allSisterCentroidXYs" and "allSisterJunctinonXYs" (and anything related
% to new junctions).

% 15/11/2017: 2.7
% - made display of division round more robust (removed hard-coded numbers), automatically detecting maximum of division
% based on length of "colorDivision"
% - now displays cells with cell cycle < "minCycleDuration" in orange
% - now saving "allDividedTooSoonTF" and "allnDivRounds" in "allDividingCells.mat" backup

% 13/11/2017: 2.6
% - added "allFirstFramesDiv" and "allFirstFramesDel", as well as "allFirstTimesDiv" and "allFirstTimesDel"
% - changes to work with latest versions of "MakeAncestors" AND new "MakeDaughters"

% 08/11/2017: 2.5
% - improvements for the display of formerly gray scale Del and Div images that can now be plotted with shades of chosen color (parameter
% "colorLevels" in AIA_parameters.
% - those images can nowdisplay junctions in color (parameter "colorJunctions")
% - those images now also apply "colorMacrochaetaes" and "colorBorderCells" to help separate the different channels.

% 06/11/2017: 2.4 *** NOW saving matrices "allSisterRNs" and "allLastDividingRNs" to be used with TA ***
% - now saving "allSisterRNs" (divCutRow x 2) matrix listing all couples of RNs as they appear for each dividing AN
% (sister 1 listed first). This will be used instead of unreliable "just_divided_cells_RN_XX.txt", and "daughterRNsMat" that's built on it.
% - now saving "allLastDividingRNs" (divCutRow x 1) matrix listing all LAST RNs of dividing cells. This will be used
% instead of unreliable "dividing_cells_RN_XX.txt" file.
% - quantities "allDaughtersXXX" became "allSisterXXX" (no "s")
% - stopped saving "allDividingRNsFilterIndices" and "allDelaminatingRNsFilterIndices" by directly applying filter while
% filling "allDelaminatingRNs" and "allDividingRNs"
% - moved definition of tMin, tMax, tRange and nTones to AIA_parameters
% - use of "JDClineWidth" to set link thickness between sisters in all-time maps
% - now also using "colorBorderCells" to color border cells in DEL and DIV greyscale images

% 25/10/2017: 2.3
% - use of 3D matrices to store centroids and junction XYs of BOTH daughters (allDaughterCentroid/JunctionXYs)
% - fixed mistake using "delCutRow" instead of "divCutRow" in section determining dividing cells ANs.

% 24/10/2017: 2.2 **Building history of RNs for delaminating, dividing and macrochaetae cells**
% - builds tables storing history of RNs for delaminating cells (allDelaminatingRNs), dividing cells (allDividingRNs),
% and macrochaetaes (macroRNs)
% - using function "macroANs2macroRNs"
% - saving "macroRNs" (RNs matching macroANs at each time point) in macroCells.mat (RN=NaN for border or coalesced RNs)
% - also creates TEMP backup file for macroCells.mat (since "macroRNs" is filled during iteration)
% - "macroX/Ys" are no longer calculated and saved in macroCells.mat
% - saves filters "allDelaminatingRNsFilterIndices" "allDividingRNsFilterIndices" to switch off RNs that either are
% borderRNs, or FLRNs or coalescedRNs in "allDelaminatingRNs" and "allDividingRNs", respectively
% - removed all parts commented in 2.1

% 18/10/2017: 2.1
% - making TEMP version of backups as long as they are NOT complete
% - fixed bug in displayNewJunction part where "motherCellsANs = unique(motherCellANs,'rows');" was NOT used at all
% - now display new junction from division dilated as well (like for T1s)
% - stop saving global backup that ONLY contained "imageSize" and "alltime_L_D1D2_XYs",
% - now saves the equivalent of "alltime_L_D1D2_XYs" (now "allDaughterOneCentroidXYs") "in allDividingCells.mat"
% - removed "global" subfolder
% - stopped iterating over frames when no plot is selected OR when backups exist AND are complete 
% - stopped using "dividing_cells_RN_XX"
% - stopped using sister couples defined by "just_divided_cells_RN_XX"
% - removed "globalReplot" that is now automatically assessed by "frameIterationTF"

% 13/10/2017: 2.0 **BECAME CellTrackingDisplay (CTD)**
% - use of function "GetImageLabels"
% - adjusting all path and filenames accordingly
