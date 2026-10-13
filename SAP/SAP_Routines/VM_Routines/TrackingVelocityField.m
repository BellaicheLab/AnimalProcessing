function [UStack, AreaRatiosStack, MissingFrames] = TrackingVelocityField (SAPparameterFile)
%
% [UStack, AreaRatiosStack, MissingFrames] = TrackingVelocityField (SAPparameterFile)
%
% Calculate velocity from cell tracking, "AreaRatios" weights are loaded
% from CPT backups.
%
% NB: supports L grids
% NB: UStack UNITS ARE SET BY "scale1D" and "dt" IN MICRON PER HOURS!!
%
% version 4.1
% Boris Guirao
% Anais Bailles


%% Initialization %%

load(SAPparameterFile); %#ok<LOAD>

if exist(pathGridDefFile,'file')
    GRID_DEF = load(pathGridDefFile);
else
    disp('PIV2GridInterpolator ERROR: "pathGridDefFile" could not be found! Stopped execution.')
end

nx = GRID_DEF.Size(2);
ny = GRID_DEF.Size(1);
nBoxes = nx*ny;
sizeANs = nColTotal-1;

% Data will be store in 4D matrices
AreaRatiosStack = zeros(ny,nx,1,finalFrame);
UStack = NaN(ny,nx,2,finalFrame);
MissingFramesTF = true(finalFrame,1); % 2.0


%% Compute spatial mean of velocity field %%

progressbar(['Calculating velocity field from ' VMtag ' over ' Animal ' frames...']); % mod 1.1

fprintf('Calculating velocity field from cell tracking...')

need2initialize = true;
for f = startFrame:finalFrame-1
        
    % Initialization (3.0)
    if f == startFrame || need2initialize
        
        SIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(f,digitsFormat) '.mat'];
        
        if exist(SIAbackupFile,'file')
            
            SIAbackup = load(SIAbackupFile);
            cellXYs = SIAbackup.CELLS.XYs/scale1D; % in pixels
            cellRNs = SIAbackup.CELLS.Numbers;
            coreRNs = GetCellCategories(SIAbackup.CELLS.CategoryTags);
            
            correspondence = dlmread([trackingFolder filesep 'correspondence_' num2str(startFrame) '.txt']); % 2.1
            correspondence = FormatCorrespondence(correspondence, nColTotal);
            
            need2initialize = false; % initialization done
            MissingFramesTF(f) = false; 
        else
            continue % skips iteration when startFrame not found: still need to initialize
        end
    end

    SIAbackupFileNext = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(f+1,digitsFormat) '.mat'];
    
    if exist(SIAbackupFileNext,'file')
        
        fnextStr = num2str(f+1);
        Ux = NaN(ny,nx);
        Uy = NaN(ny,nx);
        
        SIAbackupNext = load(SIAbackupFileNext);
        
        % Positions of the centers of mass before (initial) and after (final):
        cellXYsNext = SIAbackupNext.CELLS.XYs/scale1D; % in pixels
        cellRNsNext = SIAbackupNext.CELLS.Numbers;
        coreRNsNext = GetCellCategories(SIAbackupNext.CELLS.CategoryTags);
        
        % Double column vector with relative numbers in first and
        correspondenceNext = dlmread([trackingFolder filesep 'correspondence_' fnextStr '.txt']); % 2.1
        correspondenceNext = FormatCorrespondence(correspondenceNext, nColTotal);
        
        
        %% Find cell ANs of CURRENT and NEXT image %%
        
        % CURRENT image:
        % Remove border cells, first layer cells and huge cells (not nest cells)
        nonCoreRNsTF = ~ismember(correspondence(:,1), coreRNs); % 3.0
        correspFilt = correspondence(~nonCoreRNsTF,:);
        % Remove coalesced cells (tracking errors)
        coalTF = zeros(size(correspFilt, 1),1);
        for i = 1:1:size(correspFilt,1)-1
            if correspFilt(i,1)==correspFilt(i+1,1)
                coalTF(i)= 1;
                coalTF(i+1)= 1;
            end
        end
        correspFilt = correspFilt(~coalTF,:);
        % Remove first layer cells and double from CoM too
        coreTF = ismember (cellRNs, correspFilt(:,1));
        coreXYs = cellXYs(coreTF,:);
        % Match
        cellANsFeatures = [coreXYs cellRNs(coreTF) correspFilt(:,2:end)] ; % 3.0
        
        % NEXT image:
        % Remove border cells and first layer cells and huge cells (not nest cells)
        nonCoreRNsTF = ~ismember(correspondenceNext(:,1), coreRNsNext); % 3.0
        correspFiltNext = correspondenceNext(~nonCoreRNsTF,:); % 3.0
        % Remove coalesced cells (tracking errors)
        coalTF = zeros (size(correspFiltNext, 1),1);
        for i = 1:1:size(correspFiltNext,1)-1
            if correspFiltNext(i,1)==correspFiltNext(i+1,1)
                coalTF(i)= 1;
                coalTF(i+1)= 1;
            end
        end
        correspFiltNext = correspFiltNext(~coalTF,:);
        % Remove first layer cells and double from CoM too
        coreTF = ismember(cellRNsNext, correspFiltNext(:,1));
        coreXYsNext = cellXYsNext(coreTF,:); % change name not to modify CoM_fin
        % Match
        cellANsFeaturesNext = [coreXYsNext cellRNsNext(coreTF) correspFiltNext(:,2:end)]; % 3.0
        
        % Match initial centers of mass with final ones :
        % Remove cells not existing in both
        currANsFoundInNextANsTF = ismember(cellANsFeatures(:,4:4+sizeANs-1), cellANsFeaturesNext(:,4:4+sizeANs-1), 'rows');
        nextANsFoundInCurrANsTF = ismember(cellANsFeaturesNext(:,4:4+sizeANs-1), cellANsFeatures(:,4:4+sizeANs-1), 'rows');
        
        cellANsFeatures = cellANsFeatures(currANsFoundInNextANsTF,:);
        cellANsFeaturesNext = cellANsFeaturesNext(nextANsFoundInCurrANsTF,:);
        
        % Sorting according to absolute number
        cellANsFeatures = sortrows(cellANsFeatures,4:4+sizeANs-1);
        cellANsFeaturesNext = sortrows(cellANsFeaturesNext,4:4+sizeANs-1);
        
        % Calculate displacement vectors IN PIXELS for each cell still existing
        cellDeltaXs = cellANsFeaturesNext(:,1) - cellANsFeatures(:,1); % displacement in pixel
        cellDeltaYs = cellANsFeaturesNext(:,2) - cellANsFeatures(:,2);
        
        % Velocity IN MICRON PER HOURS IF delta_t IN MINUTES AND scale_1D IN MICRON/PIXEL.
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        uq = cellDeltaXs * scale1D*60/dt;% in IN MICRON PER HOURS
        vq = cellDeltaYs * scale1D*60/dt;% in IN MICRON PER HOURS
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        %% Loading (f+1)th CPT backups (4.0)%%
        
        fileCPT = [pathCPTbackupFiles '_' num2str(f+1, digitsFormat) '.mat'];
        buCPT = load(fileCPT);
        
        gridCoreRNsNext = buCPT.CoreRNs; % may contain some FL cells
        gridAreaRatiosNext = buCPT.AreaRatios;
        
          
        %% Calculating average velocity in each box compartment %%
        
        for b = 1:nBoxes
            
            [ky,kx] = ind2sub([ny nx],b);
            
            boxCoreRNsNext = gridCoreRNsNext{b}; % only cells inside the box on the NEXT IMAGE are taken into account
            % boxCoreRNs = FindBoxRNs(ky, kx, GRID, cellANsFeaturesNext(:,3) , cellANsFeaturesNext(:,1:2), 1); % only cells inside the box on the NEXT IMAGE are taken into account
            inBoxTF = ismember(cellANsFeaturesNext(:,3), boxCoreRNsNext);
            nBoxCoreRNs = sum(inBoxTF);
            
            % Average over selected cells in box
            Ux(ky,kx) = sum(uq(inBoxTF))/nBoxCoreRNs;
            Uy(ky,kx) = sum(vq(inBoxTF))/nBoxCoreRNs;
        end

        AreaRatiosStack(:,:,1,f) = gridAreaRatiosNext ;
        UStack(:,:,1,f) = Ux ;
        UStack(:,:,2,f) = Uy ;

        % Updating recent quantities with former "next" ones (3.0)
        cellXYs = cellXYsNext; % in pixels
        cellRNs = cellRNsNext;
        coreRNs = coreRNsNext;
        correspondence = correspondenceNext;
        
        MissingFramesTF(f) = false;
    end
    
    progressbar(f/(finalFrame-1));
end

MissingFrames = find(MissingFramesTF); % 

fprintf('Done.\n')


%% History

% 11/06/2018: 4.1 (Boris)
% - now "SAPparameterFile" is the only input argument

% 07/06/2018: 4.0 overhaul (Boris)
% - use of CPT backups => NOW supports L grids!

% 30/05/2018: 3.1(Boris)
% - removed all parts related to inertia calculation
% - removed all parts related to lagrangian grid (was NOT supported anyway!)
% - commented most of generated backups

% 29/05/2018: 3.0(Boris)
% - made many changes to make it work with new SAP structure

% 15/01/2016: 2.5 changed name to "TrackingVelocityField" (Boris)

% 24/02/2015: 2.4 (Boris)
% - thorough use of "filesep"

% 23/02/2015: 2.3
% - save backup matrix for each time point

% 13/10/2014: 2.2 suppressed "Instantaneous" from the name
% - cleaned up code by removing commented part for non-parfor loop, only leaving the more general parts
% - took retrieval of Start/finalFrame from GRID out of loop

% 10/10/2014: 2.1
% - restored parallel computing
% - removed hard-coded references => had to load Start/finalFrame in GRID

% 26/09/2014 : 2.0 Lagrangian grid added
% 03/09/2014 : 1.2 adapted to AIA_parameters
% 04/04/2014 : 1.1 Inertia information added
% 21/03/2014 : 1.0 creation