% AverageOverSpace (AOS)
%
% Will perform the AVERAGE OVER CORE CELLS (no longer the SUM as of 3.19) of cell STATIC quantities (inertia I, texture M, cortical
% distribution CD) treating each image independently in each compartment of an Eulerian OR Lagrangian grid.
%
% NB: for Lagrangian grid, requires the existence of TA backups for corresponding grid before running
%
% NB: added calculation of rates (f = frame #) (3.25); 1/2 factor (5.5)
% - for some state-function quantities (like Rho, PatchArea, M...): rQ(f) = 1/2 * 1/dtH * [Q(f)-Q(f-1)]/Q(f-1)
%   NB: importantly, taking frame f, one has correspondence with TA backups: for instance, G(f) (namely G stored in backup
%   #f) matches rQ(f) (changes that occurred between f-1 & f).
%
% - for dynamic quantites that can only be measured between two time points (like nA, nD...).
%   In this case dnA = nA(f-1 -> f)/dtH
%   NB: dQ(f) = [Q(f)-Q(f-1)]/dtH => rQ(f) = dQ(f)/Q(f-1);
%
% - "rPatchArea" is zero with E grids as the patch area is taken
% to be the square box size that does not vary in time. One cannot just
% use the same formula as for L grids since in E grids the set of cells
% within a box often vary between two time points as it is just based on
% cell positions with respect to the box, and the cumulated cell area vary
% accordingly.
%
version = '6.4';
% Boris Guirao


%% Additional Information and Notations %%

program = 'AOS';

rateQs = {'PatchArea', 'CellArea' };            % will calculate rate for the listed quantities Q -> rQ (3.25)
% rateQs = {'Rho' 'PatchArea' 'M' 'I' };
nRateQs = length(rateQs);                   % 3.25

% Defines possible quantities to average and their colors (3.0):
% NB: I = Inertia, CD = Cortical Distribution; V = Vertex distribution; M = texture
%**********************************************************************************
% NB: "CD" MUST ALWAYS BE LISTED LAST!!! (3.1)
%**********************************************************************************
% ALL possible quantities on which averages can be made:

% Use of "AllQsColorsUnits" file to load all_Qs, all_colors, all_units (3.12)
AllQsColorsUnits;
allQs = allQsAOS;
allColors = allColorsAOS;
allUnits = allUnitsAOS;

allSR = scaleRatioAOS;              % additional scale_ratio (3.0.5)
allSBL = scaleBarLengthAOS;
allKMT = killMeanTraceAOS;         % 3.12
nAllQs = size(allQs,1);             % 3.1
nAllQsNoCD = nAllQs-2;              % -1 became -2 because of mCD addition (3.7)

%%% Preliminary loading of frame to determine image size (mod 3.24):
if strcmp(gridType,'E')
    gridFrame = finalFrame; % taks LAST for Eulerian
end
image = imread([pathFolder filesep filename num2str(gridFrame, digitsFormat) '.' imageFormat]);
imageSize = size(image);

% Defines "filenameRawMod" (2.0,mod 3.23):
nRaw = length(filenameRaw); % 3.23
filenameRawMod = cell(nRaw,1);
% indPolarityRawImages = find(polarityRawImages);                        % gets non-zero indices
for r = 1:nRaw
    %     this_raw_image_index = indPolarityRawImages(r);
    filenameRawMod{r} = FormatFilename(filenameRaw{r}); % first removes last '_', then crops it to its first 15 characters.
end


%% LOADING Grid to be used with all images, and paths (3.15, 5.1, 5.3) %%

%%% Defining directory paths (3.15):
saveFolder = [pathFolderAOS filesep gridSpecs];             % AOS directory:
backupFolder = [saveFolder filesep 'Backups'];               % "Backup" folder
frameFolder = [saveFolder filesep plotType];

%%% Loading GridDef backup from CPT backup (4.1)
GRID_DEF = load(pathGridDefFile);
nx = GRID_DEF.Size(2); % 5.3
ny = GRID_DEF.Size(1); % 5.3
nBoxes = nx*ny;

if ~cloneTracking
    xywh = GRID_DEF.xywh;
    BoxArea = xywh(3)*xywh(4);
end


%% Checking Existence of last backup before running (3.17, 5.0) %%

lastFilename = [filenameAOS '_' num2str(finalFrame, digitsFormat) '.mat'];
lastBackup = [backupFolder filesep lastFilename];
if exist(lastBackup,'file')
    fprintf(['\n' program ' WARNING: LAST backup already exists. Skipping AOS execution...\n']);
    close; % closes grid figure
    return
end


%% Creating directories ONLY if Grid was validated by user (3.15) %%

% Parent save folder
if ~exist(pathFolderAOS,'dir')
    mkdir(pathFolderAOS);
end

% SUB directory with Grid/Clone specs
if ~exist(saveFolder,'dir')
    mkdir(saveFolder);
end

% "Backup" folder
if ~exist(backupFolder,'dir')
    mkdir(backupFolder);
end

% Saving txt file indicating date and version used in "saveFolder" (3.19)
txtFilename = [today '_AOS_' version '.txt'];
dlmwrite([saveFolder filesep txtFilename], 'AOS only involves display parameters!', 'delimiter', '', 'newline','pc')


%% ITERATION OVER FRAMES %%

% iterationIndex = 0;
progressbar(['AOS iteration over ' Animal ' frames...'])

for n = startFrame:finalFrame
    
    iterationIndex = n-startFrame+1;                        % 5.0    
    
    %% Displaying info, loading SIA backups and checking parameter values %%
    
    %%% Display info:
    disp(' '); disp(' ');
    disp([program ' ' version  ': processing "' Animal '" frame # ' num2str(n) ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);
    disp('---------------------------------------------------------------------------------');
    
    %%% Defining "nthBackupFile" (5.0)
    nthBackupFilename = [filenameAOS '_' num2str(n,digitsFormat) '.mat'];
    nthBackupFile = [backupFolder filesep nthBackupFilename];
    nextBackupFile = [backupFolder filesep filenameAOS '_' num2str(n+1,digitsFormat) '.mat'];
    
    if ~exist(nthBackupFile,'file')
        
        %% Loading of SIA backup and raw images:
        fprintf(['Loading SIA backup file ' filenameSIA  '_' num2str(n, digitsFormat) '.mat and raw image(s)...']); % 3.20
        SIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n, digitsFormat),'.mat']; % 4.2
        SIAbackup = load(SIAbackupFile);        % loads SIA backups
        
        %%% Extractions from SIA backups:
        ExtractData(SIAbackup);                     % loads structures CELLS, SIDES, VERTICES and FRAME in workspace
        ExtractData(CELLS,'cell');                  % loads all arrays contained in CELLS, adding prefix 'cell' to all names
        [~, FLRNs, borderRNs] = GetCellCategories(cellCategoryTags); % 5.2
        nonCoreCells = sort([FLRNs ; borderRNs]);   % 3.18
        scale1DAIA = scale1D;                       % change name of scale1D defined in AIA BEFORE to avoid overwritting by the one in SIA backups (3.0m)
        
        %%% if no intensity was computed in SIA, removes polarity P from possible quantities to plot (3.1):
        if nRawImages == 0
            allQs = allQs(1:nAllQsNoCD);
            allColors = allColors(1:nAllQsNoCD);
            allUnits = allUnits(1:nAllQsNoCD);
            allSR = scaleRatioAOS(1:nAllQsNoCD);
            allSBL = scaleBarLength_AOS(1:nAllQsNoCD);
            nAllQs = nAllQsNoCD;
        end
        
        %%% Check of "scale1D" values (1.1,3.21):
        if scale1DAIA ~= scale1D
            warndlg({['Value saved in backup file (' num2str(scale1D) ' micron/pixel) differs from value entered in AIA (' num2str(scale1DAIA) ' micron/pixel).'];'';
                'Please either correct value entered in AIA if it is wrong, or fully re-run SIA with the proper value.'}, '"scale1D" value mismatch!!');
            return
        end
        
        %%% reformatting cellMs to 4 columns if only 3 columns (3.0.1):
        if size(cellMs,2)==3
            cellMs = [cellMs(:,1:2) cellMs(:,2) cellMs(:,3)]; % duplicating column 3 to mak
        end
        fprintf('Done.\n'); % 3.20
        
        
        %% Determination of cell numbers (Core cells) in compartments, cell density (Rho), AreaRatios... %%
        
        
        % Initializations:
        gridPatchArea = NaN(ny,nx);                  % 3.25
        griddnA = NaN(ny,nx);                        % number of cells delaminating in each compartement IN THIS FRAME (3.24)
        griddnD = NaN(ny,nx);                        % number of cells division (3.24)
        gridCellArea = NaN(ny,nx);                   % 5.1 
        gridCellIaniso = NaN(ny,nx);                 % 5.1, 5.3
        gridAreaDisorder = NaN(ny,nx);                % 6.3
        % NB: "gridRho" is calculated at once
        
        
        %% Loading CPT backups (3.18, 4.0, 4.1) %%
        
        fprintf(['Loading CPT backup ' filenameCPT '_' num2str(n, digitsFormat) '.mat...'])
        fileCPT = [pathCPTbackupFiles '_' num2str(n, digitsFormat) '.mat'];
        buCPT = load(fileCPT);
        
        gridCoreRNs = buCPT.CoreRNs;
        gridMaskTF = buCPT.MaskTF;
        gridContourIndices = buCPT.ContourIndices;
        gridnCoreRNs = buCPT.nCoreRNs;
        gridAreaRatios = buCPT.AreaRatios;
        
        if strcmp(gridType,'L')   
            gridLcentroids = buCPT.Lcentroids;
        end
        
        fprintf('Done.\n')
        
        
        %% Loading of "delaminating_cells_n.txt" and "" file (3.24)
        
        try                                                                                              % try to read txt file
            delaminatingRNs = dlmread([trackingFolder filesep 'delaminating_cells_' num2str(n) '.txt']);      % List of cell RNs that WILL undergo apoptosis between n and n+1
            delaminatingRNs = delaminatingRNs(delaminatingRNs > 0);
        catch err                                                                                        % dlmread error when txt file is EMPTY or MISSING
            delaminatingRNs = [];
        end
        
        try
            dividedRNs = dlmread([trackingFolder filesep 'just_divided_cells_RN_' num2str(n) '.txt']);      % List of cell RNs that HAVE divided between n-1 and n
            dividedRNs = dividedRNs(dividedRNs > 0);
        catch err                                                                                        % dlmread error when txt file is EMPTY or MISSING
            dividedRNs = [];
        end
        
        
        %% Iteration over grid compartments %%
        
        fprintf('Iteration over grid compartments to determine AOS quantities in each region...'); % 3.16
        
        for b = 1:nBoxes
            
            [ky,kx] = ind2sub([ny nx],b);                           % turns linear index b into (i,j) grid coordinate (3.24)
            
            %% Determination of cell RNs having their centroids in this box AND cell Density Rho (mod 3.18)%%
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            boxCoreRNs = gridCoreRNs{ky,kx};          % retrieving list loaded from CPT
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            if strcmp(gridType,'L') && ~isempty(boxCoreRNs)
                
                gridPatchArea(ky,kx) = sum(cellAreas(boxCoreRNs)); % cumulated area of core cells in E OR L box
                
            elseif strcmp(gridType,'E') && ~isempty(boxCoreRNs)
                
                gridPatchArea(ky,kx) = BoxArea*scale1D^2;
                
            end
            gridCellArea(ky,kx) = gridPatchArea(ky,kx) ./ gridnCoreRNs(ky,kx);          % using "gridnCoreRNs" (5.3)
            gridAreaDisorder(ky,kx) = std(cellAreas(boxCoreRNs))/gridCellArea(ky,kx);    % area disorder: cell area std renormalized by mean cell area (6.3)

            
            %% Number of delaminatING & dividED cells in compartment (3.24) %%
            
            % delaminatING cells: 
            boxDelaminatingRNsTF = ismember(boxCoreRNs, delaminatingRNs);   % finding delaminating cells in this compartment
            dnA = sum(boxDelaminatingRNsTF)/dtH;                           % counting them; added division by dtH (3.25)
            griddnA(ky,kx) = dnA;                                          % storing
            
            % dividED cells: 
            boxDividedRNsTF = ismember(boxCoreRNs, dividedRNs);             % finding divided cells in this compartment
            dnD = sum(boxDividedRNsTF)/dtH;                                 % counting them; added division by dtH (3.25)
            dnD = dnD/2;                                                    % because 2 daughters give 1 division (4.3)
            griddnD(ky,kx) = dnD;                                           % storing
            
            
        end
        fprintf('Done.\n');
        
        % Cell density "Rho" (3.18,4.0)
        gridRho = gridnCoreRNs./gridPatchArea;          % in micron^-2
        
        
        %%  storage in GRID %%
        
        GRID_AOS.AreaRatios = gridAreaRatios;          % 3.2
        GRID_AOS.Rho = gridRho;                        % cell density in nb_cells/?m? (if scale1D in ?m/pixel) (3.6)
        GRID_AOS.dnA = griddnA;                        % instantaneous number of delaminations (3.24),mod 5.1,5.3; stopped renormalizing by "nCoreRNsGridTime" (5.4)
        GRID_AOS.dnD = griddnD;                        % instantaneous number of divisions (3.24), mod 5.1,5.3; stopped renormalizing by "nCoreRNsGridTime" (5.4)
        GRID_AOS.PatchArea = gridPatchArea;         % total area of cells making up the compartment (3.25)
        GRID_AOS.CellArea = gridCellArea;               % 5.1 , 5.3
        GRID_AOS.nCoreRNs = gridnCoreRNs;               % 5.3
        GRID_AOS.AreaDisorder = gridAreaDisorder;       % 6.3
        
        
        %% AVERAGE of selected quantities over CORE cells in each grid compartment (NOT calculating sums as of 3.19, mod 3.23) %%
        
        % ITERATION OVER QUANTITIES LISTED IN "allQs" (+ all selected raw images):
        
        
        %CDsignalName = [repmat('CD',nRaw,1) cell2mat(signalName)]; % making [CDcad ; CDesg;...] out of [cad ; esg] (3.25)
        % The line above does not handle well image sets with more than 2
        % channels
        
        CDsignalName = cell(nRaw, 1);
        for i = 1:nRaw
            CDsignalName{i} = ['CD', signalName{i}];
        end
        CDsignalName = cellstr(CDsignalName); % turn back character string into cell array (3.25)
        
        for q = 1:nAllQs
            qQ = allQs{q};                  % now contains CD1, CD2... as of 3.23
            qColor = allColors{q};
            Q = NaN(ny,nx,4); % 3.20
            
            % For Cortical Distributions:
            if any(strcmp(qQ, CDsignalName))            % 3.25
                [~,iRaw] = ismember(qQ, CDsignalName);  % 3.25
                
                if iRaw <= nRaw
                    A = cell(ny,nx);                                                % 3.7
                    cellAs = eval(['cellPolarityModes' signalName{iRaw}]);  % mod 3.23, 5.0
                    
                    for b = 1:nBoxes
                        [ky,kx] = ind2sub([ny nx],b);                                    % turns linear index b into (i,j) grid coordinate (3.23)
                        boxCoreRNs = gridCoreRNs{ky,kx};                                 % ONLY KEEPS CORE CELLS IN SUM (3.1,3.2)
                        if ~isempty(boxCoreRNs)                                          % checks compartment not empty before (3.1)
                            boxAs = cellAs(boxCoreRNs,:);                           % gets corresponding lines of M components Mxx, Mxy, Myy
                            NaNsTF = isnan(boxAs(:,1));                                    % looks for NaNs in first column
                            boxAs = boxAs(~NaNsTF,:);                                  % removes lines where NaN was found IN THE FIRST COLUMN
                            if ~isempty(boxAs)                                              % in case where As of all core cells in box have NaNs (3.13)
                                meanBoxA = mean(boxAs,1);                                 % 3.7
                                A{ky,kx} = meanBoxA;
                                % Building cortical distribution tensor CD from As:
                                [A0,A2,B2] = deal(meanBoxA(1), meanBoxA(4), meanBoxA(5)) ;
                                meanBoxCD = 1/2*[A0+A2 B2 B2 A0-A2];
                                % Storage of mean (3.20):
                                Q(ky,kx,:) = meanBoxCD;
                            end
                        end
                    end
                    % storage in GRID with proper name:
                    GRID_AOS.(['A' signalName{iRaw}]) = A; % removed '_' and uses "signalName" (3.25)
                    GRID_AOS.(qQ) = Q;                      % keeps CD1, CD2... (3.23)
                end
                
                % For quantities other than polarity:
            elseif ismember(qQ,{'I' 'M' 'V'}) % 3.7
                cellQs = eval(['cell' qQ 's']);                                          % cellMs, cellIs
                
                for b = 1:nBoxes
                    [ky,kx] = ind2sub([ny nx],b);                           % turns linear index b into (i,j) grid coordinate (3.23)
                    boxCoreRNs = gridCoreRNs{ky,kx};                      % ONLY KEEPS CORE CELLS IN SUM (3.1,3.2)
                    if ~isempty(boxCoreRNs)                                          % checks compartment not empty before (3.1)
                        Qs_in_box = cellQs(boxCoreRNs,:);                           % gets corresponding lines of M components Mxx, Mxy, Myy
                        box_mean_Q = mean(Qs_in_box,1);                                     % 3.7
                        % storage of mean (3.20):
                        Q(ky,kx,:) = box_mean_Q;
                        
                        % Computation of inertia anisotropy
                        if strcmp(qQ,'I') % 5.1   
                            TD = TensorData(Q(ky,kx,:));
                            gridCellIaniso(ky,kx) = 1 - sqrt(TD.Es(2)/TD.Es(1));
                        end
                    end
                end
                % storage of Q and mQ in GRID with proper name:
                GRID_AOS.(qQ) = Q;
            end
        end
        GRID_AOS.CellIaniso = gridCellIaniso; % 5.1 
        
        
        %% Determining rates (3.25) %%
        
        for r = 1:nRateQs
            
            rQname = rateQs{r};
            
            if n > startFrame
                gridQ = eval(['grid' rQname]);
                gridQold = eval(['grid' rQname 'OLD']);
                rQ = (gridQ - gridQold)./ gridQold;         % NB: only works for SCALAR quantities
%                 rQ = (gridQ - gridQold)./ (gridQold+gridQ)/2;         % NB: only works for SCALAR quantities TEST
                rQ = rQ/dtH;
            else
                rQ = NaN(ny,nx);                            % NaN-filled matrix for startFrame
            end
            GRID_AOS.(['r' rQname]) = 1/2*rQ;               % added 1/2 factor (5.5)
            % NB: 1/2 factor comes from the fact that, for an isotropic
            % expansion, tissue strain E = 1/2*(Af/Ai - 1) = rPatchArea*dtH
        end
        
        %% Determining Velocity, Strain & Rotation rates (6.0) %%
        
        % loading required tracking txt files
        CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
        Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal); 
        clear CorrespondenceRaw;
        
        coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
        coalescedRNs = coalescedRNs(coalescedRNs > 0);                                               % removes -1 stored when empty txt file
        
        % Removing coalesced RNs and ANs from "gridCoreRNs" and "gridCoreANs"
        gridCoreUncoalRNs = cellfun(@(x) setdiff(x, coalescedRNs), gridCoreRNs, 'UniformOutput',false);         % removing coalesced RNs
        gridCoreUncoalRNs = cellfun(@sort, gridCoreUncoalRNs, 'UniformOutput',false);                           % making sure RNs are sorted in ascending order
        gridCoreUncoalANs = cellfun(@(x) RNs2ANs(x, Correspondence), gridCoreUncoalRNs, 'UniformOutput',false); % gets corresponding ANs with matching rows
        
        if n > startFrame

            % Finding ANs BOTH found in "gridCoreUncoalANs" and % "gridCoreUncoalANsOLD"
            [gridCommonCoreANsTF, gridCommonCoreANsLoc] = cellfun(@(x,c) ismember(x,c,'rows'), gridCoreUncoalANs, gridCoreUncoalANsOLD, 'UniformOutput',false);
            gridCommonCoreRNs = cellfun(@(x,c) x(c), gridCoreUncoalRNs, gridCommonCoreANsTF, 'UniformOutput',false);        % cropping RN list to ANs also found in OLD
%             gridCommonCoreANs = cellfun(@(x,c) x(c,:), gridCoreUncoalANs, gridCommonCoreANsTF, 'UniformOutput',false);    % cropping lists to those found in OLD **DEBUG**
            
            % cropping OLD lists to common ANs
            gridCommonCoreANsLoc = cellfun(@(x,c) x(c), gridCommonCoreANsLoc, gridCommonCoreANsTF, 'UniformOutput',false);  % removes 0s corresponding to ANs unfound in OLD
            gridCommonCoreRNsOLD = cellfun(@(x,c) x(c), gridCoreUncoalRNsOLD, gridCommonCoreANsLoc, 'UniformOutput',false); % REordering common old RNs so they math current RNs ordering
%             gridCommonCoreANsOLD = cellfun(@(x,c) x(c,:), gridCoreUncoalANsOLD, gridCommonCoreANsLoc, 'UniformOutput',false); % REordering common old RNs **DEBUG**
            
            % Replacing RNs by cellXYs (IN MICRONS):
            gridCommonXYs = cellfun(@(x) cellXYs(x,:), gridCommonCoreRNs, 'UniformOutput',false); 
            gridCommonXYsOLD = cellfun(@(x) cellXYsOLD(x,:), gridCommonCoreRNsOLD, 'UniformOutput',false); 
            
            % Each cell displacement during interframe
            gridCellU = cellfun(@(x,c) 1/dtH*(x-c), gridCommonXYs, gridCommonXYsOLD, 'UniformOutput',false);    % in micron/h
            
            % Resetting box cell INITIAL coordinates with respect to each box center (IN MICRONS):
            gridCenters = cellfun(@(xy) mean(xy,1), gridCommonXYs, 'UniformOutput',false); 
            gridResetXYs = cellfun(@(xyo,c) xyo - repmat(c,size(xyo,1),1), gridCommonXYsOLD, gridCenters, 'UniformOutput',false);  % INITIAL coordinates of each cell % its box center
            
            % Determining CIRCULAR subpatch to CROP cell patch to estimate U, Epsilon, Omega (6.2, COMMENTED in 6.3)
            %-------------------------------------------------------------------------------------------------------------------------------------------------
%             [gridContourYs, gridContourXs]  = cellfun(@(x) ind2sub(imageSize,x), gridContourIndices, 'UniformOutput',false); % IN PIXELS
%             gridContourResetXs = cellfun(@(gXs, gCs) gXs*scale1D - gCs(1), gridContourXs, gridCenters, 'UniformOutput',false); % IN MICRONS
%             gridContourResetYs = cellfun(@(gYs, gCs) gYs*scale1D - gCs(2), gridContourYs, gridCenters, 'UniformOutput',false);            
%             gridPatchRadius = cellfun(@(x,y) GetMinPatchContourDistance(x,y), gridContourResetXs, gridContourResetYs, 'UniformOutput',false);  % IN MICRONS (6.3)
%             % OLD
% %             gridContourDistance = cellfun(@(x,y) sqrt(x.^2 + y.^2), gridContourResetXs, gridContourResetYs, 'UniformOutput',false); % IN MICRONS
% %             gridPatchRadius = cellfun(@(x) min(x), gridContourDistance, 'UniformOutput',false);  % IN MICRONS
%             
%             % Cropping patch to cells located within each region disk (6.2)
%             gridCellDistance = cellfun(@(xy) sqrt(sum(xy.^2,2)), gridResetXYs, 'UniformOutput',false);              % IN MICRONS
% %             gridSelectedCellTF = cellfun(@(d) d > 0, gridCellDistance, 'UniformOutput',false);                    % DEBUG: NO SELECTION
%             gridSelectedCellTF = cellfun(@(d,r) d < r, gridCellDistance, gridPatchRadius, 'UniformOutput',false);   % IN MICRONS
%             gridResetXYs = cellfun(@(x,s) x(s,:), gridResetXYs, gridSelectedCellTF, 'UniformOutput',false);
%             gridCellU = cellfun(@(u,s) u(s,:), gridCellU, gridSelectedCellTF, 'UniformOutput',false);
            %-------------------------------------------------------------------------------------------------------------------------------------------------
            
            % Determining where there is data (even with small areaRatio)
            gridDataTF = cellfun(@(x) ~isnan(x(1)), gridCenters); % 0s where no data
            
            % LINEAR FIT: polOut = mmpolyfit(Xs, Ys, 1); % polOut = [a b] corresponding to y = a*x + b;
            warning off MATLAB:polyfit:PolyNotUnique
            gridPolOutxx = cellfun(@(XY,U) mmpolyfit(XY(:,1), U(:,1), 1), gridResetXYs, gridCellU, 'UniformOutput',false); % dUx/dx; element (1,1)
            gridPolOutyx = cellfun(@(XY,U) mmpolyfit(XY(:,1), U(:,2), 1), gridResetXYs, gridCellU, 'UniformOutput',false); % dUy/dx; element (2,1)
            gridPolOutxy = cellfun(@(XY,U) mmpolyfit(XY(:,2), U(:,1), 1), gridResetXYs, gridCellU, 'UniformOutput',false); % dUx/dy; element (1,2)
            gridPolOutyy = cellfun(@(XY,U) mmpolyfit(XY(:,2), U(:,2), 1), gridResetXYs, gridCellU, 'UniformOutput',false); % dUy/dy; element (2,2)
            
            % Getting slopes "a" for each linear fit:
            gridLxx = cellfun(@(x) x(1), gridPolOutxx); % dUx/dx; element (1,1)
            gridLyx = cellfun(@(x) x(1), gridPolOutyx); % dUy/dx; element (2,1)
            gridLxy = cellfun(@(x) x(1), gridPolOutxy); % dUx/dy; element (1,2)
            gridLyy = cellfun(@(x) x(1), gridPolOutyy); % dUy/dy; element (2,2)
                    
            
%             % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             [gridLxx, ~, gridR2xx] = cellfun(@(XY,U) InertiaMatrixFit(XY(:,1), U(:,1), []), gridResetXYs, gridCellU); % dUx/dx; element (1,1)
%             [gridLyx, ~, gridR2yx] = cellfun(@(XY,U) InertiaMatrixFit(XY(:,1), U(:,2), []), gridResetXYs, gridCellU); % dUy/dx; element (2,1)
%             [gridLxy, ~, gridR2xy] = cellfun(@(XY,U) InertiaMatrixFit(XY(:,2), U(:,1), []), gridResetXYs, gridCellU); % dUx/dy; element (1,2)
%             [gridLyy, ~, gridR2yy] = cellfun(@(XY,U) InertiaMatrixFit(XY(:,2), U(:,2), []), gridResetXYs, gridCellU); % dUy/dy; element (2,2)
%             % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
            % Setting locations without data to NaN:
            gridLxx(~gridDataTF) = NaN;
            gridLyx(~gridDataTF) = NaN;
            gridLxy(~gridDataTF) = NaN;
            gridLyy(~gridDataTF) = NaN;
            
            gridL = cat(3,gridLxx, gridLyx, gridLxy, gridLyy);  % velocity gradient
            gridLt = cat(3,gridLxx, gridLxy, gridLyx, gridLyy); % transpose
 
            gridEpsilon = 1/2*(gridL + gridLt); % infinitesimal strain rate tensor
            gridOmega = 1/2*(gridL - gridLt);   % infinitesimal rotation
            gridOmega = gridOmega(:,:,2);       % Omega = Omega0 * sigma2 with sigma2 = (0 -1; 1 0) => component (2,1) gives the right sign of Omega0
            
            % Building velocity matrix gridU (better than getting intercepts from linear fit)
            gridU = cellfun(@(x) mean(x,1), gridCellU, 'UniformOutput',false);                                  % average cell velocity in each patch
            gridUx = cellfun(@(x) x(1), gridU); 
            gridUy = cellfun(@(x) x(2), gridU); 
            gridU = cat(3, gridUx, gridUy); 
            
            % Determination of R2 coeff (6.1)            
%             polOut = mmpolyfit(Xs, Ys, 1); % polOut = [a b] corresponding to y = a*x + b;
%             R2_value(Xs, Ys, polOut,[]);
            gridR2xx = cellfun(@(XY,U,PolOut) R2_value(XY(:,1), U(:,1), PolOut, []), gridResetXYs, gridCellU, gridPolOutxx); % dUx/dx; element (1,1)
            gridR2yx = cellfun(@(XY,U,PolOut) R2_value(XY(:,1), U(:,2), PolOut, []), gridResetXYs, gridCellU, gridPolOutyx); % dUy/dx; element (2,1)
            gridR2xy = cellfun(@(XY,U,PolOut) R2_value(XY(:,2), U(:,1), PolOut, []), gridResetXYs, gridCellU, gridPolOutxy); % dUx/dy; element (1,2)
            gridR2yy = cellfun(@(XY,U,PolOut) R2_value(XY(:,2), U(:,2), PolOut, []), gridResetXYs, gridCellU, gridPolOutyy); % dUy/dy; element (2,2)
%             
            % Setting locations without data to NaN:
            gridR2xx(~gridDataTF) = NaN;
            gridR2yx(~gridDataTF) = NaN;
            gridR2xy(~gridDataTF) = NaN;
            gridR2yy(~gridDataTF) = NaN;
            
            gridR2 = cat(3,gridR2xx, gridR2yx, gridR2xy, gridR2yy);     % velocity gradient
            gridR2t = cat(3,gridR2xx, gridR2xy, gridR2yx, gridR2yy);    % transpose
            gridR2 = 1/2*(gridR2 + gridR2t);                            % final symmetrix matrix
            
        else
            gridU = NaN(ny,nx,2);
            gridEpsilon = NaN(ny,nx,4);
            gridOmega = NaN(ny,nx,1);
            gridR2 = NaN(ny,nx,4); % 6.1
            
            % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             gridCellU = cell(ny,nx,1);
%             gridResetXYs = cell(ny,nx,1);
%             gridPatchRadius = cell(ny,nx,1); % 6.3
%             gridContourDistance = cell(ny,nx,1); % 6.3
            % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        
        % Storage in "GRID_AOS"
        GRID_AOS.U = gridU;
        GRID_AOS.Epsilon = gridEpsilon;
        GRID_AOS.Omega = gridOmega;
        GRID_AOS.R2 = gridR2; % 6.1
        
        % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         GRID_AOS.CellU = gridCellU;
%         GRID_AOS.ResetXYs = gridResetXYs;
%         GRID_AOS.PatchRadius = gridPatchRadius; % 6.3
%         GRID_AOS.ContourDistance = gridContourDistance; % 6.3
        % DEBUG %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        %% Updating OLD quantities (3.25) %%
        
        gridPatchAreaOLD = gridPatchArea;
        gridCellAreaOLD = gridCellArea;     % 6.4
%         gridRhoOLD = gridRho;
        
        % Defining quanities for U, Epsilon and Omega calculation (6.0)
        gridCoreUncoalRNsOLD = gridCoreUncoalRNs;
        gridCoreUncoalANsOLD = gridCoreUncoalANs;
        cellXYsOLD = cellXYs;

        
        %% Saving backup file %%
        
        fprintf(['Saving backup file "' nthBackupFilename '"...']);
        save(nthBackupFile, '-struct','GRID_AOS');  %  added "-struct" (4.0), mod 5.0
        fprintf('Done.\n');
        
    else 
        
        % Loading current found backup if next one does NOT exist to define
        % OLD quantities:
        if ~exist(nextBackupFile,'file')
            
            fprintf(['Backup "' nthBackupFilename '" was found but next one is missing => loading backup...']);
            nthBackup = load(nthBackupFile);
            gridRhoOLD = nthBackup.Rho;
            gridPatchAreaOLD = nthBackup.PatchArea ;
            
            % Loading quanities for U, Epsilon and Omega calculation (6.0)
            % Loading required tracking txt files:
            fprintf(['Loading tracking txt files for frame #'  num2str(n, digitsFormat) '...'])
            CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
            Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal);
            clear CorrespondenceRaw;
            
            coalescedRNs = dlmread([trackingFolder filesep 'coalesced_cells_RN_' num2str(n) '.txt']);
            coalescedRNs = coalescedRNs(coalescedRNs > 0);                                               % removes -1 stored when empty txt file
            fprintf('Done.\n');
            
            % Loading of CPT backup and raw images:
            fprintf(['Loading CPT backup ' filenameCPT '_' num2str(n, digitsFormat) '.mat...'])
            fileCPT = [pathCPTbackupFiles '_' num2str(n, digitsFormat) '.mat'];
            buCPT = load(fileCPT);
            fprintf('Done.\n');
            
            % Loading of SIA backup and raw images:
            fprintf(['Loading SIA backup file ' filenameSIA  '_' num2str(n, digitsFormat) '.mat and raw image(s)...']); % 3.20
            SIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n, digitsFormat),'.mat']; % 4.2
            SIAbackup = load(SIAbackupFile);        % loads SIA backups
            fprintf('Done.\n');
            
            % Removing coalesced RNs and ANs from "gridCoreRNs" and "gridCoreANs" 
            gridCoreRNs = buCPT.CoreRNs;
            gridCoreUncoalRNs = cellfun(@(x) setdiff(x, coalescedRNs), gridCoreRNs, 'UniformOutput',false);         % removing coalesced RNs
            gridCoreUncoalRNs = cellfun(@sort, gridCoreUncoalRNs, 'UniformOutput',false);                           % making sure RNs are sorted in ascending order
            gridCoreUncoalANs = cellfun(@(x) RNs2ANs(x, Correspondence), gridCoreUncoalRNs, 'UniformOutput',false); % gets corresponding ANs with matching rows
            
            gridCoreUncoalRNsOLD = gridCoreUncoalRNs;
            gridCoreUncoalANsOLD = gridCoreUncoalANs;
            cellXYsOLD = SIAbackup.CELLS.XYs;

            clear Correspondence buCPT SIAbackup
        else
            disp(['Backups "' nthBackupFilename '" and the next one were found => skipped iteration!'])
        end 
    end

    disp('---------------------------------------------------------------------------------');
    
    % Updates progressbar
    progressbar(iterationIndex/nFrames)
    
end


%% History %%

% IMPROVEMENTS/KNOWN ISSUES:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% - define reliable variations of patch areas and anisotropy to be compared
% to G. NB: to do this, critical to only consider the same set of cells
% from one frame to the other.
% - check density by manually calculating it separately
% - check E and L area ratios
% - comment saving of "CellU" and "ResetXYs" (used for Epsilon debug purposes)
% - in elongated patches with substantial rotation, Epsilon values can be inaccurate!
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 08/02/2024: 6.5
% - Fixed issue in the generation of signal names when there is more than 2
% channels (~line 300)

% 07/02/2019: 6.4
% - added "CellArea" in "rateQs"

% 31/10/2018: 6.3
% - STOPPED cropping patch for Epsilon calcuation because, even after
% fixing the determination of the circle radius to crop, was still
% introducing too much noise => in elongated patches with substantial
% rotation, Epsilon values can be inaccurate!
% - implemented calculation of "AreaDisorder"

% 27/09/2018: 6.2
% - fixed Epsilon issue: now cropping cell patch used to calculate Epsilon
% to a DISK because the anisotropy of the patch can substantially bias the
% linear fits used to calculate it (example of rotating elliptic patch of
% cells processed in simulation W02).
% - added saving of "CellU" and "ResetXYs" for Epsilon debug purposes

% 06/09/2018: 6.1
% - determination of R2 coefficients to assess quality of linear fit to
% determine velocity gradient within each region (gridR2, stored as R2 in GRID_AOS)

% 24/07/2018: 6.0
% - implemented Kabla-Blanchard calculation of patch velocity "U",
% infinitesimal strain rate "Epsilon" and infinitesimal rotation rate "Omega".

% 19/07/2018: 5.5
% - "BoxCellArea" became "PatchArea" ("rBoxCellArea" -> "rPatchArea")
% - % added 1/2 factor for rates "rQ"
% NB: 1/2 factor comes from the fact that, for an isotropic expansion,
% tissue strain E = 1/2*(Af/Ai - 1) = 1/2*rPatchArea, A being the patch area.

% 15/06/2018: 5.4
% - STOPPED renormalizing dnA and dnD by "nCoreRNsGridTime" or any other
% cell number because it is VERY DIFFICULT at AOS stage to chose a time to
% use for this renormalization.
% - accordingly removed parameter "nCoreRNsGridTime" and its saving in in
% GridDef backup.

% 14/06/2018: 5.3
% - now renormalizing dnA, dnD quantities with number of cells in each
% compartment at "gridTime" and NOT "startTime"
% - now saving "nCoreRNsGridTime" in GridDef backup if not already there
% - now also storing "nCoreRNs" in backups saved at each timepoint to be
% able to average it in AOT and AOA
% - Stopped specifying "Avg" in some quantities: "AvgCellArea" became
% "CellArea"; "AvgCellIaniso" became "CellIaniso"

% 04/05/2018: 5.2
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"

% 24/04/2018: 5.1 (stephane)
% - add new values AvgCellArea, AvgCellIaniso, ...
% - normalize dnD and dnA by the number of cell per box defined at starting frame

% 08/02/2018: 5.0
% - adjustments to match new function names and new programs
% - totally removed the display part (was NOT up to date anyway)
% - accordingly removed parameter "replotAOS"
% - now skipping calculation when backup is found. Loading existing backup
% when next one is missing to define OLD quantities.
% - dtH = dt/60 is now defined in AIA_parameters

% 27/09/2017: 4.3
% - removed many commented parts to clean up code
% - replaced "CppTFolder" by "trackingFolder" to match AIA_parameters v7.3
% - fixed mistake (factor 2) that used to count divided daughters rather than divisions!

% 25/09/2017: 4.2
% - removed commented parts that used to define and validate grid
% - adjustments to work with shorter backup filenames of SIA

% 25/07/2017: 4.1 *CHANGES TO ADAPT TO CPT 3.5*
% - removed "today" now defined in AIA_parameters

% 23/07/2017: 4.0 **NOW USING CPT BACKUPS FOR LAGRANGIAN GRIDS**
% - improving similarity between "E" or "L" grid treatements
% - in "L" grid mode, cells in each box compartments are now determined before in CPT (and no longer by TA)
% - "Lcentroids" and "contourIndices" are no longer save here but are now saved by CPT
% - stopped saving backups in a sub-backup "GRID_AOS" but directly in the .m file
% - stopped creating "frameFolder" when no images saved

% 15/03/2017:
% - put "gridTag" BEFORE "olapTag" in "gridSpecs" (like it is in TA and elsewhere)

% 16/07/2016: 3.25
% - changed name of cortical distributions now using "signalName" => CD1 -> "CDcad" for instance
% - did the same for "A_wt2NEW" that becomes "Acad"

% 16/07/2016: 3.25 BETA
% - checked calculation of cell density Rho
% - added storage of "BoxCellArea" matrix (mostly relevant for L grid)
% - added rates for Rho and BoxCellArea: rQ(F) = [Q(F)-Q(F-1)]/[dtH*Q(F-1)]
% NB: importantly, taking frame F, one has correspondence with TA backups: for instance, G(F) (namely G stored in backup
% #F) matches rQ(F) (changes that occurred between F-1 & F).
% - corrected the badly defined nA and nD (they were NOT divided by dtH) into dnA and dnD since they are intrinsically
% quantities that are measured between time points and canNOT be measured at a given timepoint (unlike the other
% quantities Rho, M...). In this case dnA = nA(F-1 -> F)/dtH
% NB: dQ(F) = [Q(F)-Q(F-1)]/dtH => rQ(F) = dQ(F)/Q(F-1);


% 12/07/2016: 3.24
% - added instantaneous number of delaminatING cells (nA) and of dividED cells (nD) in GRID_AOS (Lagrangian only)
% - displays final image for eulerian grids and first image for lagrangian ones
% - removed calls to "background_removal" and "printResolutionOR"

% 24/06/2016: 3.23
% - now saves cortical distributions named CD1, CD2 to make the AOT processing closer to GEP (ID1,ID2...) and enable averages over animals
% - linear iteration over grid compartments

% 28/04/2016: 3.22
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage

% 11/04/2016:
% - fixed hybrid case where scale1D and not (scale_1D) is stored in FRAME from SIA

% 03/06/2015: 3.21
% - supports loading of old SIA backups

% 02/06/2015: 3.20
% - M,I,V,CD have become 3D matrices containing cartesian "XY" coordinates of tensors: not diagonalizing and saving Es and Angles anymore.
% - changes made in 3.18, 3.19 and 3.20 significantly simplified the code
% - removed many comments

% 02/06/2015: 3.19 ONLY CALCULATING AVERAGE QUANTITIES Rho, I, M, V, CD!
% - stopped calculating sum "Q" quantities to only keep mean "mQ" quantities (average over CORE cells in grid compartments).
% - renamed "mQ" quantities to "Q": mI,mM,mV,mCD became M,I,V,CD.
% - saving txt file indicating which version of AOS was used

% 29/05/2015: 3.18 LAGRANGIAN GRID SUPPORT + HARMONIZATION OF AreaRatios CALCULATION!
% - support of Lagrangian grid: loading TA backups
% - harmonized the way AreaRatios are calculated: use of "Normalizer" to calculate them for both E and L grids

% 27-29/05/2015: 3.17
% - changed many parameter names to match AIA 6.0
% - PLOTS CAN ONLY BE MADE IN REPLOT MODE
% - skips execution when last backup is found
% - added progress bar

% 14/01/2015: 3.16
% - handles when "display_AOS" is empty
% - stopped displaying warnings when no core cells was found in the compartment
% - removed some commented lines

% 14/10/2014: 3.15
% - improved definition & creation of paths, now using "Path_folder_AOS" and "Filename_AOS" defined in AIA_parameters

% 09/10/2014: 3.14
% - changed naming of figures to "Q_animal_frame_Tr=0_sr=0.X.png" so they are sorted by quantity first, then by frame number
% - exception when Q=(m)CD: do not repeat signal name if only one signal processed to avoid repeating the animal name.

% 08/10/2014: 3.13
% - removed "|| ~replotAOS" so that "grid_validation_AOS" is the only parameter used to validate grid
% - fixed bug when all core cells in box have all NaNs for polarity modes
% - stopped defining "fade_color" and "time_color" now that they can be automatically generated in "PlotField"

% 04/10/2014:
% - use of "AllQsColorsUnits" file to load all_Qs, all_colors, all_units
% - took out all format, resolution parameters to AIA_parameters

% 29/09/2014: 3.12 CHANGED NAME TO "Average Over Space"
% - definition of vector "kill_mean_trace_AOS" that specifies whether trace should be removed
% - use of function "PlotField" for all plots, displays info of removed trace
% - STOPPED using "scale1D" anylonger for M,I plots since they are in micromiter^2

% 21/09/2014: 3.11
% - introduced parameter "kill_mean_trace_AOG" to plot CD tensors without average trace by removing the weighted average over all compartments of
% their trace. Relevant when tensors are known up to an additive constant or to look at relative values of their isotropic part.
% - uses AreaRatios to blend tensor color with background color to make lesss accurate boundary contributions less visible.

% 17/09/2014:
% - always prompt user for grid validation in NON-replot mode, regardless of "grid_validation_AOG" parameter value.

% 23/07/2014: 3.10
% - use of filesep for mac compatibility

% 09/04/2014: 3.9.1
% - compatibility with overlapping grids "GridMaker" (1.7) and new "Tensor_Plotter" (1.7) displaying signs with disk transparency
% - includes grid overlap in name folder
% - now fading segmented image to improve tensor display

% 25/02/2014: 3.9
% - Now allows plot of characterizations of each protein cortical distribution with different colors using new AIA parameter "CD_colors_AOG".

% 29/01/2014: 3.8
% - test presence of core cell centroid in box before assigning non-zero AreaRatio value in this box
% - now defines list of indices of core cells and core cell sides BEFORE loop on grid compartements, hence speeding up code

% 23/01/2014: 3.7
% - now both computes, store and plots SUM AND MEAN over cells for all quantities in each compartments (Q and mQ)
% - accordingly, list of possible quantities to plot extended to: {'Rho' ; 'I' ; 'mI'; 'M' ; 'mM' ;  'V' ;  'mV' ;'CD' ; 'mCD' };
% - display of exectution time for grid processing ("no replot" mode)

% 22/01/2014: 3.6
% - added storage of matrices of number (nCoreCells) and density (Rho, in nb_cells/?m2 if scale1D in ?m/pixel) of cells in grid compartments in GRID_AOG
% - storage of BoxArea (in pixels) and scale1D
% - change name of quantity quantifying cortical distribution to CD from P
% - added treatment and plot of vertex distribution tensor V
% - plot of density (Rho) map

% 22/01/2014: 3.5
% - thorough recalculation of AreaRatios matrix with AreaCellsFull now including the fractions of AREAS AND EDGES of core cells => value = 1 when the box is full of core
% cells, lower value as soon as the box contains a fraction of first-layer edge or cell.
% - accordingly removed renormalization of AreaRatios to get max value = 1
% - removed comments on previous ways of storing XYs, Es and Angles in Ms,Is,Ps and plotting info on maps

% 21/01/2014: 3.4
% - now indicates the grid size (ny*nx) in directory name (matching TA): ...'_nynx_' num2str(ny) 'x' num2str(nx)];) to avoid loading of wrong backups
% with same xy_start and wh but different nx,ny.
% - finalized and tested changes with cortical distribution (P, to be renamed CD)

% 17/01/2014: 3.3
% - set all "Border_parameter" to "tight"
% - use of "Info_Plotter" to plot info about quantity plotted, time, animal and scalebar
% - loading of last image to validate grid instead of 1st image
% - removed some commented parts (older parts of code)
% - change the way tensor data are stored in GRID_AOG: now M,I are structures that each contain nx*ny matrix/arrays: "XYs", "Es" and "Angles" (matching STP analysis)

% 17/01/2014: 3.2
% - now calling "Tensor_Plotter" instead of "Tensor_Plotter_BETA"
% - defined "grid_core_cellRNs" that only contains Core_cells
% - removed renormalization of tensor values by AreaCells/BoxArea and created instead a new array "AreaRatios" (BASED ON CORE CELLS) containing this value in each grid compartment.
% NB: since the SUM of M, I was used instead of the AVERAGE (as of 3.1), there was a "implicit" renormalization and it did NOT need the extra renormalization by AreaCells/BoxArea

% 12/11/2013: 3.1 REPLACED AVERAGE BY SUM IN COMPARTMENTS
% - now uses "BoxRNsFinder" to determine cell numbers in each compartment
% - fixed bug when some grid compartments are empty
% - changed display_AOG to display_AOG{1} when comparing it to 'none' or 'all'
% - if no intensity was computed in SIA, removes polarity P from possible quantities to plot
% - REPLACED AVERAGE BY SUM IN COMPARTMENTS BECAUSE I,M WERE DECREASING SIGNIFICANTLY OVER TIME SINCE CELLS BECOME SMALLER.
% - ONLY KEEPS IMAGE CORE CELLS TO MAKE SUM IN GRID COMPARTMENTS (TEXTURE M NOT ACCURATE OTHERWISE)

% 26/07/2013: 3.0.6
% - not creating directories if grid not validated

% 25/07/2013: 3.0.5
% - addition of scale bar displaying scale and scale ratio (see TA)
% - display of time hAPF on images
% - added scale_ratio in filenames BUT removed it from scalebar

% 24/07/2013: 3.0.3, 3.0.4
% - implementation replot mode

% 23/07/2013: 3.0.2
% - finalization fof display of polarities

% 18/07/2013: 3.0.1
% - solving of the NaN bug that killed the mean of polarity modes in some grid compartments
% - addition of average of Inertia tensor
% - revamp of display with circle and bar (using Tensor_Plotter 1.4+)

% 5/12/2012: 2.2
% - calculates "mean_cellIs", the average I0,I1,I2 over single cells to get average polarization of single cells
% - display figure showing "mean_cellIs"

% 3/12/2012: 2.1
% - now doing averages AGAIN instead of sum that depend on the number of cell within each compartment

% 28/11/2012: 2.0
% - adaptation to changes made in all functions used and to support several raw images as input

% 09/02/2011: 1.1
% - added xy_start (when not empty) in the folder name.
% - added check of "backgroundRemoval" value
% - moved several display parameters to AIA
% - grid displayed only if "Grid_display = 1"
% - added 'LineStyle',line_style to grid drawing
% - only one number of digits specified now: "digits" + "digit_format" now defined in AIA.

% 07/02/2011: creation and renaming to "Average_Over_Grid" (previously Grid_Average)

