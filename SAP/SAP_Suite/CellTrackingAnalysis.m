% CellTrackingAnalysis (CTA)
%
% Requires SIA and CTD backups.
%
% NB: there is a BIAS in the sorting of daughters: on average, daughters "1" have larger areas than daughters "2".
% This is because in the tracking, regions are first sorted according to their amount of overlap area with a region
% in the previous frame (the mother region in the case of dividing cells).
%
% Boris Guirao
version = '2.8';


%% Definition of paths and filenames %%

%%% Displaying info:
disp(' '); disp(' ');
disp(['CTA ' version  ': processing "' Animal '"']);
disp('---------------------------------------------------------------------------------');

fprintf('Defining paths to backups & images...');


% NO plots if "noDisplayCTA" is true (1.15)
if noDisplayCTA
    displayDeltaAngleData = false;
    displayDeltaAreaData = false;
    displayCellCycleData = false;
    displayDelaminationData = false;
end

%%% Defining paths to CTD BACKUPS:
CTDbackupDivFile = [pathFolderCTD filesep 'allDividingCells.mat'];
CTDbackupDivSIAfile = [pathFolderCTD filesep 'allDividingCellsSIA.mat'];    % 1.5
CTDbackupDelFile = [pathFolderCTD filesep 'allDelaminatingCells.mat'];
CTDbackupOtherFile = [pathFolderCTD filesep 'allOtherCells.mat'];           % 1.6
% macroANsFile = [pathFolderCTD filesep 'macroCells.mat'];

%%% Defining folders:
% Defines "frameFolder" (1.15)
saveFolder = pathFolderCTA;
if ~isempty(gridType) && (max(gridSize) == 1 || cloneTracking) % clone and ROI case (mod 1.21), added "cloneTracking" (2.4)
    saveFolder = [pathFolderCTA filesep gridSpecs]; % defines grid subfolder
    
elseif ~isempty(gridType) && (max(gridSize) > 1 && ~cloneTracking)  % actual grid case (1.21, 2.3, 2.4)
    gridFrameFolder = [pathFolderCTA filesep gridSpecs filesep 'Frames'];
    if ~exist(gridFrameFolder,'dir')
        mkdir(gridFrameFolder)
    end
end
frameFolder = [saveFolder filesep 'Frames'];

if ~exist(saveFolder,'dir')
    mkdir(saveFolder)
end

removeB4DelTag = ['.cut.' num2str(removeB4DelHours) 'h.B4Del']; % 2.0
nDivThreshTag = ['.nDivThresh.' num2str(nDivThreshold)];        % 2.0

%%% Defining paths to IMAGES:
shapeVsTCJsFullFile = [frameFolder filesep 'shapeVsTCJsFull.png'];                           % 1.7
shapeVsTCJsSmallAnglesFile = [frameFolder filesep 'shapeVsTCJsSmallAngles.png'];             % 1.7
shapeVsTCJsLargeAnglesFile = [frameFolder filesep 'shapeVsTCJsLargeAngles.png'];             % 1.7
shapeVsTCJsSmallAnisotropiesFile = [frameFolder filesep 'shapeVsTCJsSmallAnisotropies.png']; % 1.7
shapeVsTCJsLargeAnisotropiesFile = [frameFolder filesep 'shapeVsTCJsLargeAnisotropies.png']; % 1.7

deltaAnglesShapeTCJMapFile = [frameFolder filesep 'MAPdeltaAnglesShapeTCJ.png'];            % 1.7
deltaAnglesShapeTCJMapFile2 = [frameFolder filesep 'MAPdeltaAnglesShapeTCJ2.png'];          % 1.7
deltaAnglesDivTCJMapFile = [frameFolder filesep 'MAPdeltaAnglesDivTCJ.png'];                % 1.7
deltaAnglesDivTCJrawMapFile = [frameFolder filesep 'MAPdeltaAnglesDivTCJraw.png'];          % 1.11
nDivRoundsMapFile = [frameFolder filesep 'MAPnDivRounds.png'];                              % 1.9

cellCycleDuration2ndRoundMapFile = [frameFolder filesep 'MAPcellCycleDuration1-2.png'];      % 1.9
cellCycleDuration3rdRoundMapFile = [frameFolder filesep 'MAPcellCycleDuration2-3.png'];      % 1.9
cellFirstDivTimeMapFile = [frameFolder filesep 'MAPcellFirstDivTime.png'];                   % 1.9

if ~isempty(gridType) && (max(gridSize) > 1 && ~cloneTracking)  % 2.0, 2.3, ONLY in grid case (2.4)
    cellCycleDuration2ndRoundGridMapFile = [gridFrameFolder filesep 'gridMAPcellCycleDuration1-2.png'];      % 1.21
    cellFirstDivTimeGridMapFile = [gridFrameFolder filesep 'gridMAPcellFirstDivTime.png'];                   % 1.21
    cellCycleSTD2ndRoundGridMapFile = [gridFrameFolder filesep 'gridMAPcellCycleDurationSTD1-2.png'];      % 1.21
end

cellCycleDurationVSmeanAreasCORfile = [frameFolder filesep 'CORcellCycleDurationVSmeanAreasOver.[' num2str(averagingTimeRangeDIV) ']h.png']; % 2.0
BINcellCycleDurationVSmeanAreasCORfile = [frameFolder filesep 'BINcellCycleDurationVSmeanAreasOver.[' num2str(averagingTimeRangeDIV) ']h.png']; % 2.0

deltaAnglesDivCoMmapFile = [frameFolder filesep 'MAPdeltaAnglesDivCoM.png'];
deltaAnglesDivCoMrawMapFile = [frameFolder filesep 'MAPdeltaAnglesDivCoMraw.png']; % 1.11
deltaAnglesDivCoMpdfFile = [frameFolder filesep 'PDFdeltaAnglesDivCoM.png'];
deltaAnglesDivCoMtimeFile = [frameFolder filesep 'TIMEdeltaAnglesDivCoM.png'];

deltaSisterAreaMapFile = [frameFolder filesep 'MAPdeltaSisterArea.png'];          % 1.3

deltaSisterAreaTimeFile = [frameFolder filesep 'TIMEdeltaSisterArea.png'];

sisterCoupleLifeSpanCUMfile = [frameFolder filesep 'CUMsisterCoupleLifeSpan' removeB4DelTag '.png'];                    % 1.6, 2.0
sisterCoupleLifeSpanCUMnDivRoundsFile = [frameFolder filesep 'CUMsisterCoupleLifeSpanNdivRounds' removeB4DelTag nDivThreshTag '.png'];                    % 1.6, 2.0
deltaSisterAreaPDFallTimeFile = [frameFolder filesep 'PDFdeltaSisterAreaAllTime' removeB4DelTag '.png'];                    % 1.6, 2.0

% deltaMeanSisterAreaOverTimeFile = [frameFolder filesep 'TIMEdeltaMeanSisterArea' removeB4DelTag '.png'];                              % 1.6, 2.0
deltaMeanSisterAreaOverTimeFileDiv = [frameFolder filesep 'TIMEdeltaMeanSisterAreaDiv' removeB4DelTag '.png'];                          % 2.0
deltaMeanSisterAreaOverTimeFileDivSplit = [frameFolder filesep 'TIMEdeltaMeanSisterAreaDivSplit' removeB4DelTag nDivThreshTag '.png'];              	% 2.0
deltaMeanSisterAreaOverTimeFileDivDel = [frameFolder filesep 'TIMEdeltaMeanSisterAreaDivDel' removeB4DelTag '.png'];                    % 2.0
deltaMeanSisterAreaOverTimeFileDivSplitDelSplit = [frameFolder filesep 'TIMEdeltaMeanSisterAreaDivSplitDelSplit' removeB4DelTag nDivThreshTag '.png'];% 2.0

PDFdeltaSisterAreaDivFile = [frameFolder filesep 'PDFdeltaSisterAreaDiv.png'];
PDFdeltaSisterAreaDivDevFile = [frameFolder filesep 'PDFdeltaSisterAreaDivDev.png'];
PDFdeltaSisterAreaDivSplitFile = [frameFolder filesep 'PDFdeltaSisterAreaDivSplit' nDivThreshTag '.png'];
PDFdeltaSisterAreaDivSplitDevSplitFile = [frameFolder filesep 'PDFdeltaSisterAreaDivSplitDevSplit' nDivThreshTag '.png'];

deltaSisterAreaPDFdelSistersFile = [frameFolder filesep 'PDFdeltaSisterAreaDelSisters' nDivThreshTag '.png'];


deltaSisterAreaVSangleFile = [frameFolder filesep 'CORdeltaSisterAreaVSangle.png']; % 1.12

deltaSisterAreaPDFdelFile = [frameFolder filesep 'PDFdeltaSisterAreaDEL.png'];
cellCycleDurationPDFrawFile = [frameFolder filesep 'PDFcellCycleDurationRaw' nDivThreshTag '.png'];
cellCycleDurationPDFFile = [frameFolder filesep 'PDFcellCycleDuration' nDivThreshTag '.png'];
divisionRoundsPDFFile = [frameFolder filesep 'PDFdivisionRounds' nDivThreshTag '.png'];

% DEL related
divisionsAndDeathsPDFfile = [frameFolder filesep 'PDFdivisionsAndDeaths.png'];
deltaSisterAreaPDFallTimeDELfile = [frameFolder filesep 'PDFdeltaSisterAreaAllTimeDEL' removeB4DelTag '.png'];                    % 1.6, 2.0
delaminationTimeAfterLastDivPDFfile = [frameFolder filesep 'PDFdelaminationTimeAfterLastDiv' nDivThreshTag '.png'];% 1.12
delaminationAreasPDFfile = [frameFolder filesep 'PDFdelaminationAreas.png'];

time2deathALDVSnDivBOXfile = [frameFolder filesep 'BOXtime2deathALDVSnDiv' nDivThreshTag  '.png']; % box plot

time2deathALDVSdeltaSisterAreasFile = [frameFolder filesep 'CORtime2deathALDVSdeltaSisterAreas' nDivThreshTag  '.png'];                                 % 1.12
BINtime2deathALDVSdeltaSisterAreasFile = [frameFolder filesep 'BINtime2deathALDVSdeltaSisterAreas' nDivThreshTag  '.png'];                              % 1.12

time2deathVSmeanAreasCORfile = [frameFolder filesep 'CORtime2deathVSmeanAreasOver-[' num2str(averagingTimeRangeDEL) ']h' nDivThreshTag '.png'];         % 2.0
BINtime2deathVSmeanAreasCORfile = [frameFolder filesep 'BINtime2deathVSmeanAreasOver-[' num2str(averagingTimeRangeDEL) ']h.png'];                       % 2.0
BINtime2deathVSmeanAreasCORfileSPLIT = [frameFolder filesep 'BINtime2deathVSmeanAreasOver-[' num2str(averagingTimeRangeDEL) ']h' nDivThreshTag '.png']; % 2.0

PDFdelaminationMeanAreasFile = [frameFolder filesep 'PDFdelaminationMeanAreas' '.[' num2str(averagingTimeRangeDEL) ']h' nDivThreshTag '.png'];          % 2.1

TIMEmeanPSIareasFileDEL = [frameFolder filesep 'TIMEmeanPSIareasFileDEL' '.png'];                                                                       % 2.2
CORmeanPsiAreasVsAreasDELfile = [frameFolder filesep 'CORmeanPsiAreasVsAreasDEL' '.[' num2str(averagingTimeRangeDEL) ']h' nDivThreshTag '.png'];        % 2.2
PDFdelaminationMeanPSIareasFile = [frameFolder filesep 'PDFdelaminationMeanPSIareas' '.[' num2str(averagingTimeRangeDEL) ']h' nDivThreshTag '.png'];    % 2.2
PDFdelaminationMeanAreasPsiSortedFile = [frameFolder filesep 'PDFdelaminationMeanAreasPsiSorted' '.[' num2str(averagingTimeRangeDEL) ']h' '.png'];      % 2.2

TIMEmeanPSIbulkSignalsFileDEL = [frameFolder filesep 'TIMEmeanPSIbulkSignalsFileDEL' '.png'];                                                            % 2.7

TIMEmeanBulkSignalFileDEL = [frameFolder filesep 'TIMEmeanBulkSignalFileDEL' '.png'];                                                                     % 2.5
TIMEmeanBulkSignalFileDIV = [frameFolder filesep 'TIMEmeanBulkSignalFileDIV' '.png'];                                                                     % 2.5
TIMEmeanBulkSignalFileDIVsplit = [frameFolder filesep 'TIMEmeanBulkSignalFileDIVsplit' '.png'];                                                           % 2.6
TIMEmeanBulkSignalFileDIVdel = [frameFolder filesep 'TIMEmeanBulkSignalFileDIVdel' '.png'];                                                               % 2.6
TIMEmeanBulkSignalFileDIVsplitDELsplit = [frameFolder filesep 'TIMEmeanBulkSignalFileDIVsplitDELsplit' '.png'];                                           % 2.6

TIMEmeanBulkSignalFileDIVdelNonDelSplit = [frameFolder filesep 'TIMEmeanBulkSignalFileDIVdelNonDelSplit' '.png'];                                           % 2.7

TIMEallBulkSignalFileDEL = [frameFolder filesep 'TIMEallBulkSignalFileDEL' '.png'];   

fprintf('Done.\n');

%% FULL PROCESSING %%

if ~exist(CTAbackupFile,'file')
    
    %% Loading CTD backups %%
    
    load(CTDbackupDivFile)
    load(CTDbackupDivSIAfile)       % 1.5
    load(CTDbackupDelFile)      % 1.4
    load(CTDbackupOtherFile)             % 1.6
    
    nDivCells = size(allDividingANs,1);
    nDelCells = size(allDelaminatingANs,1); % 1.6
    
    % Applying filters to set border or coalesced RNs to NaN (1.7)
    allDividingRNs(allDividingRNsFilterLoc) = NaN;         % Re-using locations rather than logical table (1.12) 
    allDelaminatingRNs(allDelaminatingRNsFilterLoc) = NaN;
    allOtherRNs(allOtherRNsFilterLoc) = NaN; % 1.12
        
    %% Initializing matrices %%
    
    % ALL-TIME Is & Vs (1.7)
    allDividingIs = NaN(nDivCells,finalFrame,4);
    allDividingVs = NaN(nDivCells,finalFrame,4);
   
    % ALL-TIME Areas (1.12)    
    allDividingAreas = NaN(nDivCells,finalFrame);
    
    % Sister FIRST areas at birth (1.3)
    allSisterFirstAreas = NaN(nDivCells,2);                  % areas RIGHT at division
    
    % ALL-TIME Sister areas (1.6)
    allSister1Areas = NaN(nDivCells,finalFrame);     % will store all time sister 1 areas
    allSister2Areas = NaN(nDivCells,finalFrame);     % sister 2
    allSister1FrameSpan = NaN(nDivCells,2);                 % 1st and last frame of existence for sister 1
    allSister2FrameSpan = NaN(nDivCells,2);                 % sister 2
    allSister1BulkSignals = NaN(nDivCells,finalFrame);       % will store all time sister 1 bulk signal average value (2.6)
    allSister2BulkSignals = NaN(nDivCells,finalFrame);       % 2.6
    
    % ALL-TIME Average cortex intensity & perimeter (1.17)  
    allDividingCortexIntensities = NaN(nDivCells,finalFrame);
    allDividingPerimeters = NaN(nDivCells,finalFrame);    % fixed name (2.0)
    allDividingBulkSignals = NaN(nDivCells,finalFrame);    % 2.5
    
    % ALL-TIME delaminating cell areas (1.3)
    allDelaminatingAreas = NaN(nDelCells,finalFrame);
    allDelaminatingPSIareasRaw = NaN(nDelCells,finalFrame);                % 2.2
    allDelaminatingPSIareas = NaN(nDelCells,finalFrame);                   % 2.2
    allDelaminatingBulkSignals = NaN(nDelCells,finalFrame);                % 2.5
    allDelaminatingPSIbulkSignals = NaN(nDelCells,finalFrame);             % 2.7
    
    % ALL-TIME Average cortex intensity & perimeter (1.17)  
    allDelaminatingCortexIntensities = NaN(nDelCells,finalFrame);
    allDelaminatingPerimeters = NaN(nDelCells,finalFrame);
      
    %% Determining division angles (centroids & junctions) (radians) %%
    
    % new JUNCTION angle (about pi/2 from spindle)
    allSisterJunctionZs = squeeze(allSisterJunctionXYs(:,1,:) + 1i*allSisterJunctionXYs(:,2,:));   % Z = X + iY
    allDeltaJunctionZs = allSisterJunctionZs(:,2) - allSisterJunctionZs(:,1);                      % dZ = (X2-X1) + i(Y2 - Y1)
    allJunctionAngles = angle(allDeltaJunctionZs);                                                 % angles in radians in [-pi pi]
    allJunctionAngles = FixAnglesRAD(allJunctionAngles);                                           % puts angles in [-pi/2 pi/2]
    allJunctionAngles = - allJunctionAngles;                                                       % applying convention: bars like / have POSITIVE angle
    
    allSisterCentroidZs = squeeze(allSisterCentroidXYs(:,1,:) + 1i*allSisterCentroidXYs(:,2,:));   % Z = X + iY
    allDeltaCentroidZs = allSisterCentroidZs(:,2) - allSisterCentroidZs(:,1);                      % dZ = (X2-X1) + i(Y2 - Y1)
    allCentroidAngles = angle(allDeltaCentroidZs);                                                 % angles in radians in [-pi pi]
    allCentroidAngles = FixAnglesRAD(allCentroidAngles);                                           % puts angles in [-pi/2 pi/2]
    allCentroidAngles = - allCentroidAngles;                                                       % applying convention: bars like / have POSITIVE angle
    
    % NB: very important to apply right angle convention to match cell orientation angles!! Bars tilted like this "/" have POSITIVE angle
        
    %% ITERATION over frames %%
    
    progressbar(['CTA: iteration over ' Animal ' frames...'])
    
    for n = startFrame:finalFrame
        
        %% Loading SIA backup %%
        
        nthSIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat) '.mat'];
        load(nthSIAbackupFile,'CELLS')
        
        nthAreas = CELLS.Areas;
        
        if bulkSignalProcessing
            % Loading signal image:
            nthBulkSignalImagePath = [pathFolderRaw filesep bulkSignalFilename num2str(n, digitsFormat) '.' imageFormatRaw];
            nthBulkSignalImage = imread(nthBulkSignalImagePath);
            nthIndices = CELLS.Indices; % 2.5
            nthBulkSignals = cellfun(@(cIs) mean(nthBulkSignalImage(cIs)),nthIndices,'UniformOutput',true); % bulk signal for all RNs (2.6)
            
            % overwritting "CELLS" that will now contain "BulkSignals"
            CELLS.BulkSignals = nthBulkSignals; % storage into CELLS for Psi calculation (2.7)
            save(nthSIAbackupFile, 'CELLS','-append')
        end
        

        %% Building Quantity histories for DIVIDING cells (mod 1.7) %%
        
        nthDivRNs = allDividingRNs(:,n);

        %%% Replaces RNs with SIA quantity values using "RNs2RFeatures" (1.7)        
        allDividingIs(:,n,:) = RNs2RFeatures(nthDivRNs, CELLS, 'Is');
        allDividingVs(:,n,:) = RNs2RFeatures(nthDivRNs, CELLS, 'Vs');
        
        allDividingAreas(:,n) = RNs2RFeatures(nthDivRNs, CELLS, 'Areas'); % 1.12
        
        % adding cell mean cortex intensities (1.17)
        CELLS.CortexIntensities = CELLS.PolarityModesCad(:,1);                    % only considering A0s (NB: cell background intensity has been removed)
        allDividingCortexIntensities(:,n) = RNs2RFeatures(nthDivRNs, CELLS, 'CortexIntensities'); % 1.17
        allDividingPerimeters(:,n) = RNs2RFeatures(nthDivRNs, CELLS, 'Perimeters'); % 1.17
        
        % adding bulk signal average intensity
        if bulkSignalProcessing
            
            nthDivRNsTF = ~isnan(nthDivRNs);            % locations with RNs
            nthDivRNsFound = nthDivRNs(nthDivRNsTF);    % crop
            
            allDividingBulkSignals(nthDivRNsTF,n) = nthBulkSignals(nthDivRNsFound); % using "nthBulkSignals" now (2.6)
            
%             nthDivIndices = nthIndices(nthDivRNsFound);
%             allDividingBulkSignals(nthDivRNsTF,n) = cellfun(@(cIs) mean(nthBulkSignalImage(cIs)),nthDivIndices,'UniformOutput',true);
        end
        
        %%% Filling allSisterAreas (1.3)
        nthSistersTF = allLastFramesDiv == n - 1;                       % sister RNs correspond to the frame after last frame of existence of mother cells
        nthSisterRNs = allSisterFirstRNs(nthSistersTF,:);               % no NaNs in "allSisterFirstRNs" loaded from CTD backup in principle      
        allSisterFirstAreas(nthSistersTF,:) = nthAreas(nthSisterRNs);    % replacing RNs with areas


        %%% Filling "allSister1/2Areas" with "allDividingCells" data (1.6)
        %--------------------------------------------------------------------------------------------------------------------------------------
        [allSister1ANs, allSister2ANs] = MakeDaughters(allDividingANs); % gets list of all daughter ANs

        % finding sister ANs 1&2 in allDividingANs
        % sister 1
        [foundSister1ANsDivTF, foundSister1ANsDivLoc] = ismember(allSister1ANs, allDividingANs, 'rows'); % finds sisters 1 that will divide again
        foundSister1ANsDivLoc = RemoveZeros(foundSister1ANsDivLoc);
        foundSister1ANsDivRows = find(foundSister1ANsDivTF);                % rows in "allSister1ANs" where ANs were found in "allDividingANs"
        % sister 2
        [foundSister2ANsDivTF, foundSister2ANsDivLoc] = ismember(allSister2ANs, allDividingANs, 'rows');
        foundSister2ANsDivLoc = RemoveZeros(foundSister2ANsDivLoc);
        foundSister2ANsDivRows = find(foundSister2ANsDivTF);
        
        % Retrieving RNs for frame # n
        nthFoundSister1RNsDiv = allDividingRNs(foundSister1ANsDivLoc,n); % gets sister 1 RNs for this frame
        nthFoundSister2RNsDiv = allDividingRNs(foundSister2ANsDivLoc,n); % gets sister 2 RNs for this frame
        
        % Filtering out rows with NaNs in "nthFoundSister1/2RNsDiv"
        % sister 1
        sister1NaNtf = isnan(nthFoundSister1RNsDiv);                    % finds rows in "foundSister1ANsDivLoc" that corresponds to NaN      
        sister1Rows2kill = foundSister1ANsDivRows(sister1NaNtf);        % finds corresponding rows in  "foundSister1ANsDivTF"
        foundSister1ANsDivTF(sister1Rows2kill) = false;                 % set those rows to false
        nthFoundSister1RNsDiv = nthFoundSister1RNsDiv(~sister1NaNtf);   % cropping to non NaN values
        foundSister1ANsDivLoc = foundSister1ANsDivLoc(~sister1NaNtf);
        % sister 2
        sister2NaNtf = isnan(nthFoundSister2RNsDiv);
        sister2Rows2kill = foundSister2ANsDivRows(sister2NaNtf);
        foundSister2ANsDivTF(sister2Rows2kill) = false;
        nthFoundSister2RNsDiv = nthFoundSister2RNsDiv(~sister2NaNtf); % cropping to non NaN values
        foundSister2ANsDivLoc = foundSister2ANsDivLoc(~sister2NaNtf);
        
        % Storing sister areas
        allSister1Areas(foundSister1ANsDivTF,n) = nthAreas(nthFoundSister1RNsDiv);
        allSister2Areas(foundSister2ANsDivTF,n) = nthAreas(nthFoundSister2RNsDiv);
        
        % Storing sister bulk signal (2.6)
        if bulkSignalProcessing
            allSister1BulkSignals(foundSister1ANsDivTF,n) = nthBulkSignals(nthFoundSister1RNsDiv);
            allSister2BulkSignals(foundSister2ANsDivTF,n) = nthBulkSignals(nthFoundSister2RNsDiv);
        end
        
%         % DEBUG (1.12):
%         allSister1RNs(foundSister1ANsDivTF,n) = nthFoundSister1RNsDiv;
%         allSister2RNs(foundSister2ANsDivTF,n) = nthFoundSister2RNsDiv;
        
        % Storing life span in frames
        allSister1FrameSpan(foundSister1ANsDivTF,:) = [allFirstFramesDiv(foundSister1ANsDivLoc) allLastFramesDiv(foundSister1ANsDivLoc)];
        allSister2FrameSpan(foundSister2ANsDivTF,:) = [allFirstFramesDiv(foundSister2ANsDivLoc) allLastFramesDiv(foundSister2ANsDivLoc)];
        %--------------------------------------------------------------------------------------------------------------------------------------
        
        
        %%% Filling "allSister1/2Areas" with "allOtherCells" data (1.6)
        %-------------------------------------------------------------------------------------------------------------------------------------- 
        % finding sister ANs 1&2 in allOtherANs
        % sister 1
        [foundSister1ANsOtherTF, foundSister1ANsOtherLoc] = ismember(allSister1ANs, allOtherANs, 'rows'); % finds sisters 1 that will NOT divide again
        foundSister1ANsOtherLoc = RemoveZeros(foundSister1ANsOtherLoc);
        foundSister1ANsOtherRows = find(foundSister1ANsOtherTF);
        % sister 2
        [foundSister2ANsOtherTF, foundSister2ANsOtherLoc] = ismember(allSister2ANs, allOtherANs, 'rows');
        foundSister2ANsOtherLoc = RemoveZeros(foundSister2ANsOtherLoc);
        foundSister2ANsOtherRows = find(foundSister2ANsOtherTF);
        
        % Retrieving RNs for frame # n
        nthFoundSister1RNsOther = allOtherRNs(foundSister1ANsOtherLoc,n); % gets sister 1 RNs for this frame
        nthFoundSister2RNsOther = allOtherRNs(foundSister2ANsOtherLoc,n); % gets sister 2 RNs for this frame
               
        % Filtering out rows with NaNs in "nthFoundSister1/2RNsOther"
        % sister 1
        sister1NaNtf = isnan(nthFoundSister1RNsOther);                    % finds rows in "foundSister1ANsOtherLoc" that corresponds to NaN      
        sister1Rows2kill = foundSister1ANsOtherRows(sister1NaNtf);        % finds corresponding rows in  "foundSister1ANsOtherTF"
        foundSister1ANsOtherTF(sister1Rows2kill) = false;                 % set those rows to false
        nthFoundSister1RNsOther = nthFoundSister1RNsOther(~sister1NaNtf);   % cropping to non NaN values
        foundSister1ANsOtherLoc = foundSister1ANsOtherLoc(~sister1NaNtf);
        % sister 2
        sister2NaNtf = isnan(nthFoundSister2RNsOther);                    % finds rows in "foundSister1ANsOtherLoc" that corresponds to NaN      
        sister2Rows2kill = foundSister2ANsOtherRows(sister2NaNtf);        % finds corresponding rows in  "foundSister1ANsOhterTF"
        foundSister2ANsOtherTF(sister2Rows2kill) = false;                 % set those rows to false
        nthFoundSister2RNsOther = nthFoundSister2RNsOther(~sister2NaNtf);   % cropping to non NaN values
        foundSister2ANsOtherLoc = foundSister2ANsOtherLoc(~sister2NaNtf);
        
        % Storing sister areas
        allSister1Areas(foundSister1ANsOtherTF,n) = nthAreas(nthFoundSister1RNsOther);
        allSister2Areas(foundSister2ANsOtherTF,n) = nthAreas(nthFoundSister2RNsOther);
        
        % Storing sister bulk signal (2.6)
        if bulkSignalProcessing
            allSister1BulkSignals(foundSister1ANsOtherTF,n) = nthBulkSignals(nthFoundSister1RNsOther);
            allSister2BulkSignals(foundSister2ANsOtherTF,n) = nthBulkSignals(nthFoundSister2RNsOther);
        end
        
%          % DEBUG (1.12)
%         allSister1RNs(foundSister1ANsOtherTF,n) = nthFoundSister1RNsOther/1000;
%         allSister2RNs(foundSister2ANsOtherTF,n) = nthFoundSister2RNsOther/1000;
        
        % Storing life span in frames
        allSister1FrameSpan(foundSister1ANsOtherTF,:) = [allFirstFramesOther(foundSister1ANsOtherLoc) allLastFramesOther(foundSister1ANsOtherLoc)];
        allSister2FrameSpan(foundSister2ANsOtherTF,:) = [allFirstFramesOther(foundSister2ANsOtherLoc) allLastFramesOther(foundSister2ANsOtherLoc)];
        %------------------------------------------------------------------------------------------------------------------------------------------

        
        %%% Filling "allSister1/2Areas" with "allDelaminatingCells" data (1.6)
        %-------------------------------------------------------------------------------------------------------------------------------------- 
        % finding sister ANs 1&2 in "allDelaminatingANs"
        % sister 1
        [foundSister1ANsDelTF, foundSister1ANsDelLoc] = ismember(allSister1ANs, allDelaminatingANs, 'rows'); % finds sisters 1 that will NOT divide again
        foundSister1ANsDelLoc = RemoveZeros(foundSister1ANsDelLoc);
        foundSister1ANsDelRows = find(foundSister1ANsDelTF);
        % sister 2
        [foundSister2ANsDelTF, foundSister2ANsDelLoc] = ismember(allSister2ANs, allDelaminatingANs, 'rows');
        foundSister2ANsDelLoc = RemoveZeros(foundSister2ANsDelLoc);
        foundSister2ANsDelRows = find(foundSister2ANsDelTF);
        
        % Retrieving RNs for frame # n
        nthFoundSister1RNsDel = allDelaminatingRNs(foundSister1ANsDelLoc,n); % gets sister 1 RNs for this frame
        nthFoundSister2RNsDel = allDelaminatingRNs(foundSister2ANsDelLoc,n); % gets sister 2 RNs for this frame
               
        % Filtering out rows with NaNs in "nthFoundSister1/2RNsDel"
        % sister 1
        sister1NaNtf = isnan(nthFoundSister1RNsDel);                    % finds rows in "foundSister1ANsDelLoc" that corresponds to NaN      
        sister1Rows2kill = foundSister1ANsDelRows(sister1NaNtf);        % finds corresponding rows in  "foundSister1ANsDelTF"
        foundSister1ANsDelTF(sister1Rows2kill) = false;                 % set those rows to false
        nthFoundSister1RNsDel = nthFoundSister1RNsDel(~sister1NaNtf);   % cropping to non NaN values
        foundSister1ANsDelLoc = foundSister1ANsDelLoc(~sister1NaNtf);
        % sister 2
        sister2NaNtf = isnan(nthFoundSister2RNsDel);                    % finds rows in "foundSister1ANsDelLoc" that corresponds to NaN      
        sister2Rows2kill = foundSister2ANsDelRows(sister2NaNtf);        % finds corresponding rows in  "foundSister1ANsOhterTF"
        foundSister2ANsDelTF(sister2Rows2kill) = false;                 % set those rows to false
        nthFoundSister2RNsDel = nthFoundSister2RNsDel(~sister2NaNtf);   % cropping to non NaN values
        foundSister2ANsDelLoc = foundSister2ANsDelLoc(~sister2NaNtf);
        
        % Storing sister areas
        allSister1Areas(foundSister1ANsDelTF,n) = nthAreas(nthFoundSister1RNsDel);
        allSister2Areas(foundSister2ANsDelTF,n) = nthAreas(nthFoundSister2RNsDel);
        
        % Storing sister bulk signal (2.6)
        if bulkSignalProcessing
            allSister1BulkSignals(foundSister1ANsDelTF,n) = nthBulkSignals(nthFoundSister1RNsDel);
            allSister2BulkSignals(foundSister2ANsDelTF,n) = nthBulkSignals(nthFoundSister2RNsDel);
        end
        
%         % DEBUG 1.12
%         allSister1RNs(foundSister1ANsDelTF,n) = - nthFoundSister1RNsDel;
%         allSister2RNs(foundSister2ANsDelTF,n) = - nthFoundSister2RNsDel;
        
        % Storing life span in frames
        allSister1FrameSpan(foundSister1ANsDelTF,:) = [allFirstFramesDel(foundSister1ANsDelLoc) allLastFramesDel(foundSister1ANsDelLoc)];
        allSister2FrameSpan(foundSister2ANsDelTF,:) = [allFirstFramesDel(foundSister2ANsDelLoc) allLastFramesDel(foundSister2ANsDelLoc)];
        %------------------------------------------------------------------------------------------------------------------------------------------
        
        %% Building Quantity histories for DELAMINATING cells (1.6, mod 1.12) %%
        
        nthDelRNs = allDelaminatingRNs(:,n);
        allDelaminatingAreas(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'Areas');
        
        % adding cell mean cortex intensities (1.17)
        allDelaminatingCortexIntensities(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'CortexIntensities'); % 1.17    
        allDelaminatingPerimeters(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'Perimeters'); % 1.17
        
        % adding Psi_Raw(A) (2.2)
        cellPsiAreasRaw = CalculatePSI(CELLS,'Areas',[]); % "Raw" because ONLY excluding borderRNs
        CELLS.PsiAreasRaw = cellPsiAreasRaw;
        allDelaminatingPSIareasRaw(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'PsiAreasRaw');
        % adding Psi(A):  (2.2)                  
        cellPsiAreas = CalculatePSI(CELLS,'Areas', nthDelRNs); % now ALSO excluding DEL cells (at ALL times)
        CELLS.PsiAreas = cellPsiAreas;
        allDelaminatingPSIareas(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'PsiAreas');
        
        % adding bulk signal average intensity
        if bulkSignalProcessing
            
            nthDelRNsTF = ~isnan(nthDelRNs);            % locations with RNs
            nthDelRNsFound = nthDelRNs(nthDelRNsTF);    % crop
            nthDelIndices = nthIndices(nthDelRNsFound); % get corresponding indices listed accordig to nthDelRNs order
            allDelaminatingBulkSignals(nthDelRNsTF,n) = cellfun(@(cIs) mean(nthBulkSignalImage(cIs)),nthDelIndices,'UniformOutput',true);

            % adding Psi(Signal):  (2.7)
            cellPsiBulkSignals = CalculatePSI(CELLS,'BulkSignals', nthDelRNs); % now ALSO excluding DEL cells (at ALL times)
            CELLS.PsiBulkSignals = cellPsiBulkSignals;
            allDelaminatingPSIbulkSignals(:,n) = RNs2RFeatures(nthDelRNs, CELLS, 'PsiBulkSignals');
        end
        
           
        %% Progressbar update %%
        
        progressRatio = (n-startFrame+1)/(finalFrame-startFrame+1);
        progressbar(progressRatio)
        
    end
       
    %% Saving backup file %%
    
    save(CTAbackupFile, 'allCentroidAngles','allJunctionAngles','allSisterFirstAreas','allDividingIs','allDividingVs', 'allDividingAreas',...
                        'allSister1Areas','allSister2Areas','allSister1FrameSpan','allSister2FrameSpan','allDelaminatingAreas',...                % 1.6
                        'allDividingCortexIntensities','allDelaminatingCortexIntensities', 'allDividingPerimeters', 'allDelaminatingPerimeters',... % 1.17
                        'allDelaminatingPSIareasRaw','allDelaminatingPSIareas'); % 2.2
%                         ,'allSister1RNs', 'allSister2RNs'); % DEBUG 1.12

    if bulkSignalProcessing
        save(CTAbackupFile, 'allDelaminatingBulkSignals','allDividingBulkSignals','allSister1BulkSignals','allSister2BulkSignals',...
                            'allDelaminatingPSIbulkSignals','-append'); % 2.5, 2.6, 2.7
        
    end

    % Saving txt file (1.7, mod 1.13)
    today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style
    txtFilename = [today '_CTA_' version '.txt'];
    dlmwrite([pathFolderCTA filesep txtFilename], 'CTA only involves display parameters!', 'delimiter', '', 'newline','pc') % 1.13
    
end

%% LOADING CTA BACKUPS (mod 1.15)%%

clear all*; % clears all variables starting with "all" (1.15)

fprintf('Loading CTD & CTA backup files...')

% CTD backups
CTDbackupDiv = load(CTDbackupDivFile);
CTDbackupDel = load(CTDbackupDelFile);            % 1.4
% CTA backup
CTAbackup = load(CTAbackupFile);

% loading macrochaete info (1.21)
[allMacroRNs, allMacroANs] = LoadMacroBackup(pathFolderCTD);      % 1.21

fprintf('Done.\n')

%% DEFINITION OF SET OF CELLS TO CONSIDER ("plot[Qname]" quantities): FULL vs GRID (1.15) %%

if  isempty(gridType) || (max(gridSize) > 1 && ~cloneTracking) % also when actual grid processing (mod 1.21), added "~cloneTracking" (2.4)
    
    % full image case: "plot" quantities are just "all" quantities   
    % CTD Div quantities
    plotDividingANs = CTDbackupDiv.allDividingANs;
    plotDividedTooSoonTF = CTDbackupDiv.allDividedTooSoonTF;
    plotDividingLastXYs = CTDbackupDiv.allDividingLastXYs;  
    plotFirstFramesDiv = CTDbackupDiv.allFirstFramesDiv;
    plotLastFramesDiv = CTDbackupDiv.allLastFramesDiv;
    plotFirstTimesDiv = CTDbackupDiv.allFirstTimesDiv;
    plotLastTimesDiv = CTDbackupDiv.allLastTimesDiv;
    % CTD Del quantities
    plotDelaminatingANs = CTDbackupDel.allDelaminatingANs;
    plotFirstFramesDel = CTDbackupDel.allFirstFramesDel;
    plotLastFramesDel = CTDbackupDel.allLastFramesDel;
    plotFirstTimesDel = CTDbackupDel.allFirstTimesDel;
    plotLastTimesDel = CTDbackupDel.allLastTimesDel;
    plotCoreDelaminatingLastRNsTF = CTDbackupDel.coreDelaminatingLastRNsTF; % 1.20
    
    % CTA quantities
    plotCentroidAngles = CTAbackup.allCentroidAngles;
    plotDelaminatingAreas = CTAbackup.allDelaminatingAreas;
    plotDividingAreas = CTAbackup.allDividingAreas;
    plotDividingIs = CTAbackup.allDividingIs;
    plotDividingVs = CTAbackup.allDividingVs;
    plotJunctionAngles = CTAbackup.allJunctionAngles;
    plotSister1Areas = CTAbackup.allSister1Areas;
    plotSister2Areas = CTAbackup.allSister2Areas;
    plotSister1FrameSpan = CTAbackup.allSister1FrameSpan;
    plotSister2FrameSpan = CTAbackup.allSister2FrameSpan;
    plotSisterFirstAreas = CTAbackup.allSisterFirstAreas;
    plotDelaminatingPSIareas = CTAbackup.allDelaminatingPSIareas;           % 2.2
    plotDelaminatingPSIareasRaw = CTAbackup.allDelaminatingPSIareasRaw;     % 2.2
    % NB: "allDeltaTimesDiv" is defined below
    
    if bulkSignalProcessing
        plotDelaminatingBulkSignals = CTAbackup.allDelaminatingBulkSignals;       % 2.5
        plotDividingBulkSignals = CTAbackup.allDividingBulkSignals;               % 2.5
        plotDelaminatingPSIbulkSignals = CTAbackup.allDelaminatingPSIbulkSignals;       % 2.7
        
        plotSister1BulkSignals = CTAbackup.allSister1BulkSignals;       % 2.6
        plotSister2BulkSignals = CTAbackup.allSister2BulkSignals;       % 2.6
    end
    
    % Loading CPT backup and determining "gridDividingANs" (1.21):
    if ~isempty(gridType)
        
        % loading "startFrame" CPT backup
        CPTstartBackupFile = [pathCPTbackupFiles  '_' num2str(startFrame, digitsFormat) '.mat'];
        load(CPTstartBackupFile,'CoreANs'); % loading START CoreANs
        
        gridDividingANsRows = cell(ny,nx);
        
        for b = 1:nBoxes
            
            bCoreANs = CoreANs{b};
            bOffspringCoreANs = MakeOffspring(bCoreANs);
            bAllCoreANs = [bCoreANs ; bOffspringCoreANs]; % all possible core ANs in bth box EXCEPT new cells that will enter the box AFTER time of grid drawing
   
            bDividingANsTF = ismember(plotDividingANs, bAllCoreANs, 'rows');
            gridDividingANsRows{b} = find(bDividingANsTF); % rows in "plotDividingANs" where "bAllCoreANs" are found
        end
        
        % loading "gridMapFrame" CPT backup
        CPTgridMapBackupFile = [pathCPTbackupFiles  '_' num2str(gridMapFrame, digitsFormat) '.mat'];
        CPTgridMapBackup = load(CPTgridMapBackupFile);
        gridMapCoreRNs = CPTgridMapBackup.CoreRNs;
        gridMapContourIndices = CPTgridMapBackup.ContourIndices;
        
        macroRNs = [];                      % default (3.18)
        if ~isempty(allMacroANs)
            macroRNs = allMacroRNs(:,gridMapFrame);    % 3.14
        end
        
        % loading "final" SEG image
        gridMapSegImage = imread([pathFolder filesep filename num2str(gridMapFrame, digitsFormat) '.' imageFormat]);
        
        % loading SIA final backup (1.21)
        SIAgridMapBackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(gridMapFrame, digitsFormat) '.mat'];
        SIAgridMapBackup = load(SIAgridMapBackupFile); 
        [~, ~, gridMapBorderRNs] = GetCellCategories(SIAgridMapBackup.CELLS.CategoryTags);
    end
    
else % ROI case: clone OR single-box grid
    
    % loading "startFrame" CPT backup
    CPTstartBackupFile = [pathCPTbackupFiles  '_' num2str(startFrame, digitsFormat) '.mat'];
    load(CPTstartBackupFile,'CoreANs'); % loading START CoreANs
    
    % Determining cells of "allDividingANs" and "allDelaminatingANs" that belong to the clone
    ROIcoreANs = cell2mat(CoreANs(:,1));                   % gather coreANs from ALL ROI parts (clone or single box) into a single matrix
    allROIoffspringANs = MakeOffspring(ROIcoreANs);
    allPossibleROIANs = [ROIcoreANs ; allROIoffspringANs];
    
    allDividingANs = CTDbackupDiv.allDividingANs;
    ROIdividingANsTF = ismember(allDividingANs, allPossibleROIANs, 'rows');
    allDelaminatingANs = CTDbackupDel.allDelaminatingANs;
    ROIdelaminatingANsTF = ismember(allDelaminatingANs, allPossibleROIANs, 'rows');
    % NB: by doing so we're excluding the "new" cells integrated in the
    % clone later in the tracking.
    
    % CROPPING all relevant matrices to "clone" (or unique grid box) cells: 
    % CTD Div quantities
    plotDividingANs = CTDbackupDiv.allDividingANs(ROIdividingANsTF,:);
    plotDividedTooSoonTF = CTDbackupDiv.allDividedTooSoonTF(ROIdividingANsTF);
    plotDividingLastXYs = CTDbackupDiv.allDividingLastXYs(ROIdividingANsTF,:);
    plotFirstFramesDiv = CTDbackupDiv.allFirstFramesDiv(ROIdividingANsTF);
    plotLastFramesDiv = CTDbackupDiv.allLastFramesDiv(ROIdividingANsTF);
    plotFirstTimesDiv = CTDbackupDiv.allFirstTimesDiv(ROIdividingANsTF);
    plotLastTimesDiv = CTDbackupDiv.allLastTimesDiv(ROIdividingANsTF);
    % CTD Del quantities
    plotDelaminatingANs = CTDbackupDel.allDelaminatingANs(ROIdelaminatingANsTF,:);
    plotFirstFramesDel = CTDbackupDel.allFirstFramesDel(ROIdelaminatingANsTF);
    plotLastFramesDel = CTDbackupDel.allLastFramesDel(ROIdelaminatingANsTF);
    plotFirstTimesDel = CTDbackupDel.allFirstTimesDel(ROIdelaminatingANsTF);
    plotLastTimesDel = CTDbackupDel.allLastTimesDel(ROIdelaminatingANsTF);
    plotCoreDelaminatingLastRNsTF = CTDbackupDel.coreDelaminatingLastRNsTF(ROIdelaminatingANsTF); % 1.20
    
    % CTA quantities
    % 1D matrices
    plotCentroidAngles = CTAbackup.allCentroidAngles(ROIdividingANsTF);
    plotJunctionAngles = CTAbackup.allJunctionAngles(ROIdividingANsTF);
    % 2D
    plotDividingAreas = CTAbackup.allDividingAreas(ROIdividingANsTF,:);
    plotSister1Areas = CTAbackup.allSister1Areas(ROIdividingANsTF,:);
    plotSister2Areas = CTAbackup.allSister2Areas(ROIdividingANsTF,:);
    plotSister1FrameSpan = CTAbackup.allSister1FrameSpan(ROIdividingANsTF,:);
    plotSister2FrameSpan = CTAbackup.allSister2FrameSpan(ROIdividingANsTF,:);
    plotSisterFirstAreas = CTAbackup.allSisterFirstAreas(ROIdividingANsTF,:);
    
    % 3D
    plotDividingIs = CTAbackup.allDividingIs(ROIdividingANsTF,:,:);
    plotDividingVs = CTAbackup.allDividingVs(ROIdividingANsTF,:,:);
    % Del
    plotDelaminatingAreas = CTAbackup.allDelaminatingAreas(ROIdelaminatingANsTF,:);
    plotDelaminatingPSIareas = CTAbackup.allDelaminatingPSIareas(ROIdelaminatingANsTF,:);           % 2.2
    plotDelaminatingPSIareasRaw = CTAbackup.allDelaminatingPSIareasRaw(ROIdelaminatingANsTF,:);     % 2.2
    
    if bulkSignalProcessing
        
        plotDelaminatingBulkSignals = CTAbackup.allDelaminatingBulkSignals(ROIdelaminatingANsTF,:);         % 2.5
        plotDelaminatingPSIbulkSignals = CTAbackup.allDelaminatingPSIbulkSignals(ROIdelaminatingANsTF,:);   % 2.7
        
        plotDividingBulkSignals = CTAbackup.allDividingBulkSignals(ROIdividingANsTF,:); % 2.5
        plotSister1BulkSignals = CTAbackup.allSister1BulkSignals(ROIdividingANsTF,:);   % 2.6
        plotSister2BulkSignals = CTAbackup.allSister2BulkSignals(ROIdividingANsTF,:);   % 2.6
    end
    
    % Saving backup for this subset of cells:
    CTAbackupFileGrid = [saveFolder filesep filenameCTA '.mat'];
    if ~exist(CTAbackupFileGrid, 'file')
        save(CTAbackupFileGrid,'ROIdividingANsTF','ROIdelaminatingANsTF'); % ONLY saving boolean allowing to crop lists (1.16)
    end  
end
clear CTAbackup CTDbackup;

%% FILTERING DEL CELLS (2.0) %%

% NB: DIV cells are NOT filtered at this stage (but rather all along
% the process) to enable the plot of the raw distribution and check the
% determination of parameter "minCycleDuration"

% % DIV ANs: cropping according to "plotDividedTooSoonTF"
% plotDividingANs = plotDividingANs(~plotDividedTooSoonTF,:);
% plotDividingLastXYs = plotDividingLastXYs(~plotDividedTooSoonTF,:);
% plotFirstFramesDiv = plotFirstFramesDiv(~plotDividedTooSoonTF);
% plotLastFramesDiv = plotLastFramesDiv(~plotDividedTooSoonTF);
% plotFirstTimesDiv = plotFirstTimesDiv(~plotDividedTooSoonTF);
% plotLastTimesDiv = plotLastTimesDiv(~plotDividedTooSoonTF);
% plotCentroidAngles = plotCentroidAngles(~plotDividedTooSoonTF);
% plotJunctionAngles = plotJunctionAngles(~plotDividedTooSoonTF);
% plotDividingAreas = plotDividingAreas(~plotDividedTooSoonTF,:);
% plotSister1Areas = plotSister1Areas(~plotDividedTooSoonTF,:);
% plotSister2Areas = plotSister2Areas(~plotDividedTooSoonTF,:);
% plotSister1FrameSpan = plotSister1FrameSpan(~plotDividedTooSoonTF,:);
% plotSister2FrameSpan = plotSister2FrameSpan(~plotDividedTooSoonTF,:);
% plotSisterFirstAreas = plotSisterFirstAreas(~plotDividedTooSoonTF,:);
% plotDividingIs = plotDividingIs(~plotDividedTooSoonTF,:,:);
% plotDividingVs = plotDividingVs(~plotDividedTooSoonTF,:,:);

% DEL ANs: cropping according to "plotCoreDelaminatingLastRNsTF"
plotDelaminatingANs = plotDelaminatingANs(plotCoreDelaminatingLastRNsTF,:);
plotFirstFramesDel = plotFirstFramesDel(plotCoreDelaminatingLastRNsTF);
plotLastFramesDel = plotLastFramesDel(plotCoreDelaminatingLastRNsTF);
plotFirstTimesDel = plotFirstTimesDel(plotCoreDelaminatingLastRNsTF);
plotLastTimesDel = plotLastTimesDel(plotCoreDelaminatingLastRNsTF);
plotDelaminatingAreas = plotDelaminatingAreas(plotCoreDelaminatingLastRNsTF,:);
plotDelaminatingPSIareas = plotDelaminatingPSIareas(plotCoreDelaminatingLastRNsTF,:);       % 2.2
plotDelaminatingPSIareasRaw = plotDelaminatingPSIareasRaw(plotCoreDelaminatingLastRNsTF,:); % 2.2

if bulkSignalProcessing
    plotDelaminatingBulkSignals = plotDelaminatingBulkSignals(plotCoreDelaminatingLastRNsTF,:);         % 2.5
    plotDelaminatingPSIbulkSignals = plotDelaminatingPSIbulkSignals(plotCoreDelaminatingLastRNsTF,:);   % 2.7
end

% Updating total numbers of DIV and DEL
nDivCells = size(plotDividingANs,1);     % 1.4, 1.15
nDelCells = size(plotDelaminatingANs,1); % 1.5, 1.15

%% DEFINITION OF QUANTITIES FOR UPCOMING PLOTS %%
  
    fprintf('Defining additional quantities for upcoming plots... ')
    
    framesAfterDIVcutOff = round(timeAfterDIVcutOff*60/dt + 1);    % mod 2.2
    framesBeforeDELcutOff = round(timeBeforeDELCutOff*60/dt + 1);  % 2.2
    
    % Determining "timeBeforeDIV" (2.5)
    %-------------------------------------------------------------------------------------------------------------------
    plotDividingAreasSync = SyncCellHistories(plotDividingAreas, plotFirstFramesDiv, plotLastFramesDiv,'last'); % early definition
    maxDIVlifeSpan = size(plotDividingAreasSync,2);
    framesBeforeDIVflip = (1:maxDIVlifeSpan)';        
    timeBeforeDIVflip = (framesBeforeDIVflip-1)*dt/60;
    clear plotDividingAreasSync
    %-------------------------------------------------------------------------------------------------------------------

    %%% Getting location of divisions
    plotDivisionXYs = plotDividingLastXYs; % using mother last position from CTD (1.13) 

    %%% COMPARING DIVISION, CELL ELONGATION AND TCJ POLARITY ANGLES (1.7, moved 1.9)
    %--------------------------------------------------------------------------
    if displayDeltaAngleData
        
        %%% Getting approx spindle angle at division (90° from junction) for cells
        plotJunctionDivisionAngles = FixAnglesRAD(plotJunctionAngles + pi/2); %#ok<*UNRCH>
        
        %%% Averaging cell Is and Vs over time:
        %--------------------------------------------------------------------------
        % Initialization of tables:
        plotMeanShapeAnisotropies = NaN(nDivCells,1);
        plotMeanShapeAngles = NaN(nDivCells,1);
        plotMeanTCJanisotropies = NaN(nDivCells,1);
        plotMeanTCJangles = NaN(nDivCells,1);
        
        % Building synchronized tables (Sync at division time):
        plotDividingIsSync = SyncCellHistories(plotDividingIs, plotFirstFramesDiv, plotLastFramesDiv,'last');
        plotDividingVsSync = SyncCellHistories(plotDividingVs, plotFirstFramesDiv, plotLastFramesDiv,'last');
        
        % Flipping time:
        plotDividingIsSyncFlip = fliplr(plotDividingIsSync);
        plotDividingVsSyncFlip = fliplr(plotDividingVsSync);
        
        % Cropping to relevant time range:
        averagingFrameRangeDivAngles = averagingTimeRangeDivAngles*60/dt; % [0.5 1] becomes [6 12] when dt = 5 min
        plotDividingIsSyncFlipCrop = plotDividingIsSyncFlip(:,averagingFrameRangeDivAngles(1):averagingFrameRangeDivAngles(2),:);
        plotDividingVsSyncFlipCrop = plotDividingVsSyncFlip(:,averagingFrameRangeDivAngles(1):averagingFrameRangeDivAngles(2),:);
        
        % Making time averages
        plotDividingIsSyncMean = squeeze(nanmean(plotDividingIsSyncFlipCrop,2));
        plotDividingVsSyncMean = squeeze(nanmean(plotDividingVsSyncFlipCrop,2));
        
        % Extracting MeanShape and MeanTCJ anisotropies and angles for each cell
        % NB: need to make this evolve to avoid loop over cells => create
        % "TensorDataMat" that will use formulae for 2x2 matrices for all elements.
        for c = 1:nDivCells
            
            % NB: TensorData(T) returns Es and Angles. Es and Angles list 1st the
            % eigenvalue and angle corresponding to the + bar of Tdev, which
            % corresponds to the largest one when both Es are positive (which is
            % the case for I and V tensors). Angles in degrees.
            
            % Extracting mean cell I anisotropies and angles
            cI = plotDividingIsSyncMean(c,:);
            cIdata = TensorData(cI);
            plotMeanShapeAnisotropies(c) = 1 - sqrt(cIdata.Es(2)/cIdata.Es(1));      % NB: I and V are positive matrices => 1st eigenvalue correspond to the one with largest Eigen
            plotMeanShapeAngles(c) = -deg2rad(cIdata.Angles(1));                     % applying convention: bars like / have POSITIVE angles
            
            % Extracting mean cell V anisotropies and angles
            cV = plotDividingVsSyncMean(c,:);
            cVdata = TensorData(cV);
            plotMeanTCJanisotropies(c) = 1 - cVdata.Es(2)/cVdata.Es(1);
            plotMeanTCJangles(c) = -deg2rad(cVdata.Angles(1));                       % applying convention: bars like / have POSITIVE angle
        end
        
        %%% Making angle differences
        plotDeltaAnglesDivShape = FixAnglesRAD(plotMeanShapeAngles - plotJunctionDivisionAngles);
        plotDeltaAnglesDivTCJ = FixAnglesRAD(plotMeanTCJangles - plotJunctionDivisionAngles);
        plotDeltaAnglesShapeTCJ = FixAnglesRAD(plotMeanShapeAngles - plotMeanTCJangles);
        %--------------------------------------------------------------------------
    end
    
    % 2.5
    if bulkSignalProcessing
        plotDividingBulkSignalSync = SyncCellHistories(plotDividingBulkSignals, plotFirstFramesDiv, plotLastFramesDiv,'last');
        plotDividingBulkSignalSync = [plotDividingBulkSignalSync NaN(nDivCells,1)]; % add an extra column of NaNs
        plotDividingBulkSignalSyncFlip = fliplr(plotDividingBulkSignalSync); % reversing time
    end

    
    %%% Calculating relative difference in sister areas
    plotSisterFirstAreasMax = max(plotSisterFirstAreas,[],2);                                       % selects largest sister area
    plotDeltaFirstAreas = abs(plotSisterFirstAreas(:,1) - plotSisterFirstAreas(:,2))./plotSisterFirstAreasMax;  % dimensionless ratio in [0,1]
    % NB:  = 0 if a1 = a2; = 0.5 if a2 = 0.5*a1 (or a1 = 0.5*a2); 1 if a1 or a2 = 0.
    
    %%% Calculating time of existence for dividing & delaminating cells:
    plotDeltaTimesDiv = plotLastTimesDiv - plotFirstTimesDiv + 1/60*dt; % a cell in start frame dividing in the next frame exist 1 frame (not 0) (1.11)
    plotDeltaTimesDEL = plotLastTimesDel - plotFirstTimesDel + 1/60*dt; % same for delamination (NB: last frame is last frame OF EXISTENCE)
    
    %%% Getting round of UPCOMING division for each div ANs (1.4)
    %-------------------------------------------------------------------------------------------------------------------
    plotnDivRounds = GetnDivRounds(plotDividingANs) + 1; % for each dividing AN, division round that it WILL acquire right AFTER division (1.6)
    % getting corresponding green shade:
    nDivColorMax = size(colorDivision,1);
    plotnDivRoundColorIndex = plotnDivRounds+1;                                       % 1st color listed being white cells
    plotnDivRoundColorIndex(plotnDivRoundColorIndex>nDivColorMax) = nDivColorMax;     % saturating index values to last color available
    plotnDivRoundColors = colorDivision(plotnDivRoundColorIndex,:);                   % assigning colors
    %-------------------------------------------------------------------------------------------------------------------
    
    plotnDivRoundsDEL = GetnDivRounds(plotDelaminatingANs); % 1.6
    
    %%% Getting location (in plotDividingANs) of delaminating ANs that divided (1.4)
    %-------------------------------------------------------------------------------------------------------------------
    plotDelANs1stDivTag = plotDelaminatingANs(:,2);
    plotDelANsResultingFromDivisionTF = logical(plotDelANs1stDivTag);                             % 1s for those that result from 1+ division
    plotDelANsResultingFromDivision = plotDelaminatingANs(plotDelANsResultingFromDivisionTF,:);
    plotDelMotherANs = MakeAncestors(plotDelANsResultingFromDivision, 'youngest');                % make mothers that can be found in plotDividingANs
    plotDelMotherANs = unique(plotDelMotherANs,'rows');                                           % removes duplicates
    [~,plotDelMotherANsLoc] = ismember(plotDelMotherANs, plotDividingANs, 'rows');                 % locate them in "plotDividingANs"
    % Filtering out suspiscious divisions (nDiv >=  4)
    suspiciousDivRoundsLoc = find(plotnDivRounds >= 4);
    plotDelMotherANsLoc = setdiff(plotDelMotherANsLoc, suspiciousDivRoundsLoc);
    %-------------------------------------------------------------------------------------------------------------------
    
    
    %%% Getting sisters of delaminating ANs (1.4)
    %-------------------------------------------------------------------------------------------------------------------
    [plotSister1ANs, plotSister2ANs] = MakeDaughters(plotDividingANs);
    % Finding delaminating ANs among daughter cells
    plotDelaminatingSister1ANsTF = ismember(plotSister1ANs, plotDelaminatingANs, 'rows');
    plotDelaminatingSister2ANsTF = ismember(plotSister2ANs, plotDelaminatingANs, 'rows');
    
    bothDelaminatingSisterANsTF = all([plotDelaminatingSister1ANsTF plotDelaminatingSister2ANsTF],2);
    atLeastOneSisterDelaminatesANsTF = any([plotDelaminatingSister1ANsTF plotDelaminatingSister2ANsTF],2); % 2.0
    onlyOneSisterDelaminatesANsTF = atLeastOneSisterDelaminatesANsTF; % temp, 2.0
    onlyOneSisterDelaminatesANsTF(bothDelaminatingSisterANsTF) = false;                                % turning off rows where both sister delaminate

    onlySister1delaminatesANsTF = all([plotDelaminatingSister1ANsTF onlyOneSisterDelaminatesANsTF],2);
    onlySister2delaminatesANsTF = all([plotDelaminatingSister2ANsTF onlyOneSisterDelaminatesANsTF],2);
        
    onlySister1delaminatesAreas = plotSisterFirstAreas(onlySister1delaminatesANsTF,1);
    sister2staysAreas = plotSisterFirstAreas(onlySister1delaminatesANsTF,2);
    
    onlySister2delaminatesAreas = plotSisterFirstAreas(onlySister2delaminatesANsTF,2);
    sister1staysAreas = plotSisterFirstAreas(onlySister2delaminatesANsTF,1);

    plotDeltaFirstAreasDEL = NaN(nDivCells,1);
    plotDeltaFirstAreasDEL(onlySister1delaminatesANsTF) = sister2staysAreas - onlySister1delaminatesAreas; % expected > 0 if delaminating cells is smaller
    plotDeltaFirstAreasDEL(onlySister2delaminatesANsTF) = sister1staysAreas - onlySister2delaminatesAreas;
    plotDeltaFirstAreasDEL = plotDeltaFirstAreasDEL./plotSisterFirstAreasMax; 
    %-------------------------------------------------------------------------------------------------------------------
    
    %%% Getting corresponding life span (2.0)
    %-------------------------------------------------------------------------------------------------------------------
    % Getting locations of each delaminating sister in "plotDelaminatingANs"
    [~, delSister1Loc] = ismember(plotSister1ANs, plotDelaminatingANs, 'rows');
    [~, delSister2Loc] = ismember(plotSister2ANs, plotDelaminatingANs, 'rows');
    
    % cropping to found cells AND to CASES of SINGLE delaminating sister
    delSister1Loc = delSister1Loc(onlySister1delaminatesANsTF);
    delSister2Loc = delSister2Loc(onlySister2delaminatesANsTF);
    
    % Retrieving corresponding lifespans
    delSister1LifeSpan = plotDeltaTimesDEL(delSister1Loc);
    delSister2LifeSpan = plotDeltaTimesDEL(delSister2Loc);
    
    % Defining "onlyDELsisterLifeSpan"
    onlyDELsisterLifeSpan = NaN(nDivCells,1);
    onlyDELsisterLifeSpan(onlySister1delaminatesANsTF) = delSister1LifeSpan;
    onlyDELsisterLifeSpan(onlySister2delaminatesANsTF) = delSister2LifeSpan;
    %-------------------------------------------------------------------------------------------------------------------
    

    %%% Loading starFrame Correspondence txt file to get "nCells0" (1.5,1.14)
    %-------------------------------------------------------------------------------------------------------------------
    nCells0 = GetnCells0(trackingFolder, startFrame); % 1.14
    %-------------------------------------------------------------------------------------------------------------------
    
    %%% Filtering
    %-------------------------------------------------------------------------------------------------------------------
    % 1st divisions of NEW cells: inaccurate for cell cycle (other rounds are ok)
    newDivANsTF = plotDividingANs(:,1) > nCells0;
    plotFirstDivRoundsTF = plotnDivRounds == 1;
%     newANs2excludeTF = all([newANsTF plotFirstDivRoundsTF],2); % rows to exclude
    
    %%% Filtering out cells for which 2+ division rounds occur before 4h
    % "allDividedTooSoonTF" now loaded from "allDividingCellsFile" backups
    plotDividingANs2excludeTF = any([newDivANsTF plotDividedTooSoonTF],2);  % directly uses "newANsTF" without "plotFirstDivRoundsTF" that gets sorted afterwards (mod 1.18)
    nDivANsExcluded = sum(plotDividingANs2excludeTF);                    % mod 1.18
    %-------------------------------------------------------------------------------------------------------------------
    
    
    %%% Calculating ALL-TIME relative difference in sister's area (1.6, 1.9)
    %-------------------------------------------------------------------------------------------------------------------
    % replacing last frame NaNs by finalFrame when not listed as first frame
    % NB: this is becaues cells that remain until the end of movie have NaN as last frame
    replaceTF = ~isnan(plotSister1FrameSpan(:,1)) & isnan(plotSister1FrameSpan(:,2));
    plotSister1FrameSpan(replaceTF,2) = finalFrame;
    
    replaceTF = ~isnan(plotSister2FrameSpan(:,1)) & isnan(plotSister2FrameSpan(:,2));
    plotSister2FrameSpan(replaceTF,2) = finalFrame;
    
    %%% Cropping life span of daughters WITH AT LEAST ONE DELAMINATING SISTER (2.0)
    removeB4DelFrames = round(removeB4DelHours*60/dt);
    
    % Sister 1:
    plotSister1FrameSpan(atLeastOneSisterDelaminatesANsTF,2) = plotSister1FrameSpan(atLeastOneSisterDelaminatesANsTF,2) - removeB4DelFrames;
    % Fixing "firstFrames" that became larger then "lastFrames":
    endB4startTF = plotSister1FrameSpan(:,1) > plotSister1FrameSpan(:,2);
    plotSister1FrameSpan(endB4startTF,:) = NaN;
    
    % Sister 2:
    plotSister2FrameSpan(atLeastOneSisterDelaminatesANsTF,2) = plotSister2FrameSpan(atLeastOneSisterDelaminatesANsTF,2) - removeB4DelFrames;
    % Fixing "firstFrames" that became larger then "lastFrames":
    endB4startTF = plotSister2FrameSpan(:,1) > plotSister2FrameSpan(:,2);
    plotSister2FrameSpan(endB4startTF,:) = NaN;
    % NB: this is the LAST time that "plotSister1/2FrameSpan" are called
    
    % Synchronizing "plotSister1/2Areas" at FIRST frame of existence
    plotSister1AreasSync = SyncCellHistories(plotSister1Areas, plotSister1FrameSpan(:,1), plotSister1FrameSpan(:,2),'first');
    plotSister2AreasSync = SyncCellHistories(plotSister2Areas, plotSister2FrameSpan(:,1), plotSister2FrameSpan(:,2),'first');
    
    if bulkSignalProcessing
        plotSister1BulkSignalsSync = SyncCellHistories(plotSister1BulkSignals, plotSister1FrameSpan(:,1), plotSister1FrameSpan(:,2),'first');   % 2.6
        plotSister2BulkSignalsSync = SyncCellHistories(plotSister2BulkSignals, plotSister2FrameSpan(:,1), plotSister2FrameSpan(:,2),'first');   % 2.6
    end
%     
%     % DEBUG (1.12)
%     plotSister1RNsSync = SyncCellHistories(plotSister1RNs,plotSister1FrameSpan(:,1),plotSister1FrameSpan(:,2),'first');
%     plotSister2RNsSync = SyncCellHistories(plotSister2RNs,plotSister2FrameSpan(:,1),plotSister2FrameSpan(:,2),'first');
    
    % cropping longer table to size of shorter one (1.9)
    nCol1 = size(plotSister1AreasSync,2);
    nCol2 = size(plotSister2AreasSync,2);
    maxDivLifeSpan = min(nCol1, nCol2); % keeping smaller one for simplicity
    
    % moved here (2.0)
    framesAfterDivision = (1:maxDivLifeSpan)';
    timeAfterDivision = (framesAfterDivision-1)*dt/60;
    
    % cropping AND flipping back
    plotSister1AreasSync = plotSister1AreasSync(:,1:maxDivLifeSpan);
    plotSister2AreasSync = plotSister2AreasSync(:,1:maxDivLifeSpan);
    
    if bulkSignalProcessing
        plotSister1BulkSignalsSync = plotSister1BulkSignalsSync(:,1:maxDivLifeSpan);
        plotSister2BulkSignalsSync = plotSister2BulkSignalsSync(:,1:maxDivLifeSpan);
    end
    
    % sets NaN in BOTH daughters when data on EITHER of them is not available
    plotSister1AreasSyncNaNloc = find(isnan(plotSister1AreasSync));
    plotSister2AreasSyncNaNloc = find(isnan(plotSister2AreasSync));
    plotBothSisterAreasSyncNaNloc = unique([plotSister1AreasSyncNaNloc ; plotSister2AreasSyncNaNloc]); % gather all locations
    
    plotSister1AreasSync(plotBothSisterAreasSyncNaNloc) = NaN;
    plotSister2AreasSync(plotBothSisterAreasSyncNaNloc) = NaN;
    
    if bulkSignalProcessing
        plotSister1BulkSignalsSync(plotBothSisterAreasSyncNaNloc) = NaN;
        plotSister2BulkSignalsSync(plotBothSisterAreasSyncNaNloc) = NaN;
        
        plotMeanSisters12BulkSignalsSync = mean(cat(3,plotSister1BulkSignalsSync,plotSister2BulkSignalsSync),3); % averaging daughters signal
    end
    
    plotSisterAreasSyncMax = max(cat(3,plotSister1AreasSync,plotSister2AreasSync),[],3);
    plotDeltaSisterAreasSync = abs((plotSister1AreasSync - plotSister2AreasSync)) ./ plotSisterAreasSyncMax;
    %-------------------------------------------------------------------------------------------------------------------
    
    % Defining "nCellsDivRounds" taking into account all filterings(2.0)
    %-------------------------------------------------------------------------------------------------------------------
    % determining how many cells are left after filtering (2.0)
    cellsWithSomeHistoryLeftTF = any(~isnan(plotDeltaSisterAreasSync),2); % 1 on rows where at least one value remains
    
    nCellsDivRounds = zeros(nDivThreshold,1);
    for nDiv = 1:nDivThreshold   
        if nDiv == nDivThreshold
            nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
        else
            nthDivRoundTF = plotnDivRounds == nDiv;
        end
        nthDivRoundFilteredTF = all([nthDivRoundTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % excluding problematic ANs
        nCellsDivRounds(nDiv) = sum(nthDivRoundFilteredTF);
    end
    %-------------------------------------------------------------------------------------------------------------------
    
    %%% "plotnDivRoundsSisters" (1.6)
    plotnDivRoundsSisters = GetnDivRounds(plotSister1ANs); % would get same result with sister 2
    
    
    % Determining "plotDividingAreasMean" (1.12)
    %-------------------------------------------------------------------------------------------------------------------
    plotDividingAreasSync = SyncCellHistories(plotDividingAreas, plotFirstFramesDiv, plotLastFramesDiv,'last');
    % NB: all cell listed in plotDividingANs have ALL a well-defined first and last frames

    % Reversing time in matrix:
    plotDividingAreasSyncFlip = fliplr(plotDividingAreasSync);
    
    % Cropping to relevant time range:
    averagingFrameRangeDIV = averagingTimeRangeDIV * 60/dt; % [0.5 1] becomes [6 12] when dt = 5 min
    if averagingFrameRangeDIV(2) == Inf
        averagingFrameRangeDIV(2) = size(plotDividingAreasSync,2);
    end
    plotDividingAreasSyncFlipCrop = plotDividingAreasSyncFlip(:, averagingFrameRangeDIV(1):averagingFrameRangeDIV(2)); % averaging over all cell lifes
    
    % Making time averages
    plotMeanDividingAreas = nanmean(plotDividingAreasSyncFlipCrop,2);
    plotMeanDividingWeights = sum(~isnan(plotDividingAreasSyncFlipCrop),2); % gets number of area values available in average
    %------------------------------------------------------------------------------------------------------------------- 
    
    
    % ALL-TIME analysis of DEL sisters  (1.6)
    %-------------------------------------------------------------------------------------------------------------------
    % cropping plotSister1/2RNsAreasSync to rows where ONLY ONE sister delaminates
    onlySister1DelaminatesRNsAreas = plotSister1AreasSync(onlySister1delaminatesANsTF,:);
    sister2staysRNsAreas = plotSister2AreasSync(onlySister1delaminatesANsTF,:);
    
    onlySister2DelaminatesRNsAreas = plotSister2AreasSync(onlySister2delaminatesANsTF,:);
    sister1staysRNsAreas = plotSister1AreasSync(onlySister2delaminatesANsTF,:);
    
    % Rows of plotSister1/2ANs with ONLY ONE sister that delaminates:
    keepTF = all([onlyOneSisterDelaminatesANsTF cellsWithSomeHistoryLeftTF],2); % removing rows whithout history left (2.0)
    
    plotDeltaSisterAreasDEL = NaN(nDivCells, maxDivLifeSpan);
    plotDeltaSisterAreasDEL(onlySister1delaminatesANsTF,:) = sister2staysRNsAreas - onlySister1DelaminatesRNsAreas; % expected > 0 if delaminating cells is smaller
    plotDeltaSisterAreasDEL(onlySister2delaminatesANsTF,:) = sister1staysRNsAreas - onlySister2DelaminatesRNsAreas;
    
    plotDeltaSisterAreasDEL = plotDeltaSisterAreasDEL./plotSisterAreasSyncMax; % exact same renorm
    
    plotDeltaSisterAreasDEL = plotDeltaSisterAreasDEL(keepTF,:); % cropping to ONLY relevant rows
%     plotDeltaSisterAreasDEL = plotDeltaSisterAreasDEL(onlyOneSisterDelaminatesANsTF,:); % cropping to ONLY relevant rows
    %-------------------------------------------------------------------------------------------------------------------
    
    
    % Turning "plotDelaminatingAreas" into "plotDelaminatingAreasSync" (mod 1.9)
    %-------------------------------------------------------------------------------------------------------------------
    plotDelaminatingAreasSync = SyncCellHistories(plotDelaminatingAreas, plotFirstFramesDel, plotLastFramesDel,'last');
    plotDelaminatingAreasSync = [plotDelaminatingAreasSync zeros(nDelCells,1)]; % add an extra column of 0s (as last DEL cell area)
    %-------------------------------------------------------------------------------------------------------------------
    
    % Determining "timeBeforeDEL" (2.2)
    %-------------------------------------------------------------------------------------------------------------------
    maxDELlifeSpan = size(plotDelaminatingAreasSync,2);
    framesBeforeDELflip = (1:maxDELlifeSpan)';         % "flip" because, for DEL, time will be listed before 0
    timeBeforeDELflip = (framesBeforeDELflip-1)*dt/60;
    %-------------------------------------------------------------------------------------------------------------------
    
    % Defining "averagingFrameRangeDEL" (from "averagingTimeRangeDEL") (moved 2.2)
    %-------------------------------------------------------------------------------------------------------------------
    averagingFrameRangeDEL = averagingTimeRangeDEL * 60/dt; % [0.5 1] becomes [6 12] when dt = 5 min
    if averagingFrameRangeDEL(2) == Inf
        averagingFrameRangeDEL(2) = size(plotDelaminatingAreasSync,2);
    end
    %-------------------------------------------------------------------------------------------------------------------
    
    % Determining "plotMeanDelaminatingAreas": time-averaged area over DEL cells life (MINUS the "averagingTimeRangeDEL" range before death) (1.12)
    %-------------------------------------------------------------------------------------------------------------------
    plotDelaminatingAreasSyncFlip = fliplr(plotDelaminatingAreasSync); % reversing time
    
    % Cropping to relevant time range:
    plotDelaminatingAreasSyncFlipCrop = plotDelaminatingAreasSyncFlip(:, averagingFrameRangeDEL(1):averagingFrameRangeDEL(2));

    % Making time averages
    plotMeanDelaminatingAreas = nanmean(plotDelaminatingAreasSyncFlipCrop,2);
    %-------------------------------------------------------------------------------------------------------------------
      
    %%% Completing PLOT structure with common variables for MAP plots (1.8)
    PLOT.textAnimal = [Animal ' # ' num2str(startFrame) '-' num2str(finalFrame)];
    fadingValues = fliplr(0:0.1:0.9);       % 1.9
    nFadingValues = length(fadingValues);   % 1.11
    
    %%% Getting all Macro ALL-TIME pixel indices for display in maps
    nSisterCouples0 = sum(~isnan(plotDeltaSisterAreasSync(:,1)),1); % moved 1.12
    
    % Defining "colorDelamination" (2.0)
    colorDelamination = [grey; dark_grey; black];
    nDelColorMax = size(colorDelamination,1);
    
    if bulkSignalProcessing % 2.8
        
        % Synchronizing "plotDelaminatingBulkSignals" (2.5)
        plotDelaminatingBulkSignalSync = SyncCellHistories(plotDelaminatingBulkSignals, plotFirstFramesDel, plotLastFramesDel,'last');
        plotDelaminatingBulkSignalSync = [plotDelaminatingBulkSignalSync NaN(nDelCells,1)]; % add an extra column of NaNs
        plotDelaminatingBulkSignalSyncFlip = fliplr(plotDelaminatingBulkSignalSync); % reversing time
        
        % Turning "plotDelaminatingPSIbulkSignals" into "plotDelaminatingPSIbulkSignalsSync" (2.7)
        %-------------------------------------------------------------------------------------------------------------------
        plotDelaminatingPSIbulkSignalsSync = SyncCellHistories(plotDelaminatingPSIbulkSignals, plotFirstFramesDel, plotLastFramesDel,'last');
        plotDelaminatingPSIbulkSignalsSync = [plotDelaminatingPSIbulkSignalsSync NaN(nDelCells,1)]; % add an extra column of NaNs (as last DEL cell PSIbulkSignal)
        plotDelaminatingPSIbulkSignalsSyncFlip = fliplr(plotDelaminatingPSIbulkSignalsSync);        % reversing time
        %-------------------------------------------------------------------------------------------------------------------
    end
    

    % Turning "plotDelaminatingPSIareas" into "plotDelaminatingPSIareasSync" (2.2)
    %-------------------------------------------------------------------------------------------------------------------
    plotDelaminatingPSIareasSync = SyncCellHistories(plotDelaminatingPSIareas, plotFirstFramesDel, plotLastFramesDel,'last');
    plotDelaminatingPSIareasSync = [plotDelaminatingPSIareasSync zeros(nDelCells,1)]; % add an extra column of 0s (as last DEL cell PSIarea)
    %-------------------------------------------------------------------------------------------------------------------
    
    % Determining "plotMeanDelaminatingPSIareas": time-average area over DEL cells life (MINUS the "averagingTimeRangeDEL" range before death) (2.2)
    %-------------------------------------------------------------------------------------------------------------------
    plotDelaminatingPSIareasSyncFlip = fliplr(plotDelaminatingPSIareasSync); % reversing time
    
    % Cropping to relevant time range:
    plotDelaminatingPSIareasSyncFlipCrop = plotDelaminatingPSIareasSyncFlip(:, averagingFrameRangeDEL(1):averagingFrameRangeDEL(2));

    % Making time averages for each DEL cell:
    plotMeanDelaminatingPSIareas = nanmean(plotDelaminatingPSIareasSyncFlipCrop,2);
    %-------------------------------------------------------------------------------------------------------------------
    
    fprintf('Done.\n')
   
%% Completing CTA backup (1.13) and creating "frameFolder" (1.15)%%

%%% Saving other quantities for plot outside of CTA (1.15)
if isempty(gridType) % mod 1.15
    allDeltaTimesDiv = plotDeltaTimesDiv;                   % in the full image case "plotDeltaTimesDiv" corresponds to all cells
    allDividingANs2excludeTF = plotDividingANs2excludeTF;   % 1.18
    save(CTAbackupFile, 'allDeltaTimesDiv','allDividingANs2excludeTF','-append'); % 1.16, stopped saving "plotFirstDivRoundsTF" (1.18)
    clear allDeltaTimesDiv allDividingANs2excludeTF
    
% COM 1.18
% else
%     save(CTAbackupFileGrid, 'firstDivRoundsTF','dividingANs2excludeTF','-append'); % 1.16
end

% creating "frameFolder" (1.15)
if ~exist(frameFolder,'dir')
    mkdir(frameFolder)
end
   
%% SISTER DIVISION ANGLES PLOTS %%

if displayDeltaAngleData
    
    fprintf('Comparing division, cell elongation and TCJ polarity angles...\n ')
    
    %% POLAR Plots: ThetaShape-ThetaDiv VS ThetaTCJ-ThetaDiv (1.8)

    %%% Full plot
    %--------------------------------------------------------------------------
    if ~exist(shapeVsTCJsFullFile,'file') 

        titleText = '\Delta\theta_{TCJ} & \Delta\theta_{shape}';
        [p1, p2] = ComparePolarPlots(plotDeltaAnglesDivTCJ, plotDeltaAnglesDivShape, red, blue, pi/10, titleText);
        legend([p1 p2],'\theta_{TCJ} - \theta_{div}','\theta_{shape} - \theta_{div}','Location','southeastoutside')
        print(printFormat, printResolution, shapeVsTCJsFullFile);
        close
    end
    %--------------------------------------------------------------------------

    %%% Filtering according to SMALL OR LARGE "plotDeltaAnglesShapeTCJ" (Fig 3e)
    %--------------------------------------------------------------------------
    if ~exist(shapeVsTCJsLargeAnglesFile,'file') 

        % Selecting angles corresponding to SMALL "plotDeltaAnglesShapeTCJ"
        angleLimit = deg2rad(10);
        smallDeltaAnglesShapeTCJtf = -angleLimit < plotDeltaAnglesShapeTCJ & plotDeltaAnglesShapeTCJ < angleLimit;
        selectedDeltaAnglesDivTCJ = plotDeltaAnglesDivTCJ(smallDeltaAnglesShapeTCJtf);
        selectedDeltaAnglesDivShape = plotDeltaAnglesDivShape(smallDeltaAnglesShapeTCJtf);
        % Plot
        titleText = '\Delta\theta_{TCJ} & \Delta\theta_{shape} for  |\theta_{TCJ} - \theta_{shape}| < 10 ';
        [p1, p2] = ComparePolarPlots(selectedDeltaAnglesDivTCJ, selectedDeltaAnglesDivShape, red, blue, pi/10, titleText);
        legend([p1 p2],'\theta_{TCJ} - \theta_{div}','\theta_{shape} - \theta_{div}','Location','southeastoutside')
        print(printFormat, printResolution, shapeVsTCJsSmallAnglesFile);
        close

        % Selecting angles corresponding to LARGE "plotDeltaAnglesShapeTCJ"
        angleLimit = deg2rad(45);
        largeDeltaAnglesShapeTCJtf = angleLimit < plotDeltaAnglesShapeTCJ | plotDeltaAnglesShapeTCJ < -angleLimit;
        selectedDeltaAnglesDivTCJ = plotDeltaAnglesDivTCJ(largeDeltaAnglesShapeTCJtf);
        selectedDeltaAnglesDivShape = plotDeltaAnglesDivShape(largeDeltaAnglesShapeTCJtf);
        % Plot
        titleText = '\Delta\theta_{TCJ} & \Delta\theta_{shape} for  |\theta_{TCJ} - \theta_{shape}| > 45 ';
        [p1, p2] = ComparePolarPlots(selectedDeltaAnglesDivTCJ, selectedDeltaAnglesDivShape, red, blue, pi/10, titleText);
        legend([p1 p2],'\theta_{TCJ} - \theta_{div}','\theta_{shape} - \theta_{div}','Location','southeastoutside')
        print(printFormat, printResolution, shapeVsTCJsLargeAnglesFile);
        close
    end
    %--------------------------------------------------------------------------

    %%% Filtering according to SMALL OR LARGE "plotMeanShapeAnisotropies" (Fig 3f)
    %--------------------------------------------------------------------------
    if ~exist(shapeVsTCJsLargeAnisotropiesFile,'file') 

        % Selecting angles corresponding to SMALL "plotMeanShapeAnisotropies"
        anisotropyLimit = 0.2;
        smallAnisotropiesTF = plotMeanShapeAnisotropies < anisotropyLimit;
        selectedDeltaAnglesDivTCJ = plotDeltaAnglesDivTCJ(smallAnisotropiesTF);
        selectedDeltaAnglesDivShape = plotDeltaAnglesDivShape(smallAnisotropiesTF);
        % Plot
        titleText = '\Delta\theta_{TCJ} & \Delta\theta_{shape} for  \eta_{shape} < 0.2 ';
        [p1, p2] = ComparePolarPlots(selectedDeltaAnglesDivTCJ, selectedDeltaAnglesDivShape, red, blue, pi/10, titleText);
        legend([p1 p2],'\theta_{TCJ} - \theta_{div}','\theta_{shape} - \theta_{div}','Location','southeastoutside')
        print(printFormat, printResolution, shapeVsTCJsSmallAnisotropiesFile);
        close

        % Selecting angles corresponding to LARGE "plotMeanShapeAnisotropies"
        anistropyLimit = 0.5;
        largeAnisotropiesTF = anistropyLimit < plotMeanShapeAnisotropies;
        selectedDeltaAnglesDivTCJ = plotDeltaAnglesDivTCJ(largeAnisotropiesTF);
        selectedDeltaAnglesDivShape = plotDeltaAnglesDivShape(largeAnisotropiesTF);
        % Plot
        titleText = '\Delta\theta_{TCJ} & \Delta\theta_{shape} for  \eta_{shape} > 0.5 ';
        [p1, p2] = ComparePolarPlots(selectedDeltaAnglesDivTCJ, selectedDeltaAnglesDivShape, red, blue, pi/10, titleText);
        legend([p1 p2],'\theta_{TCJ} - \theta_{div}','\theta_{shape} - \theta_{div}','Location','southeastoutside')
        print(printFormat, printResolution, shapeVsTCJsLargeAnisotropiesFile);
        close
    end
    %--------------------------------------------------------------------------
    
    %% MAP plot: angle difference "plotDeltaAnglesShapeTCJ" (1.8, 1.9) %%
    
    if ~exist(deltaAnglesShapeTCJMapFile,'file')
        
        %%% Calculating angle differences
        plotDeltaAnglesShapeTCJscaled = abs(plotDeltaAnglesShapeTCJ)/(pi/2);   % scales results into [0 1]
        plotDeltaAnglesShapeTCJDEG = rad2deg(abs(plotDeltaAnglesShapeTCJ));
        
        textAveragingTimeRange = [num2str(averagingTimeRangeDivAngles(1)) '-' num2str(averagingTimeRangeDivAngles(2)) 'h'];                   % 1.11
        PLOT.textQuantity = ['\theta_{Shape}^{' textAveragingTimeRange '} - \theta_{TCJ}^{' textAveragingTimeRange '}'];    % mod 1.11
        PLOT.scaleCircleValue = 1; % must be same units as "plotDeltaAnglesShapeTCJPlot"
        PLOT.scaleCircleText = '90^o';
        
        PLOT.vMin = 20;
        PLOT.vMax = 70;
        PLOT.colorBarUnits = '\Delta\theta';
        PLOT.cmap = FadeColor(dark_purple,fadingValues);
        MakePointMap(plotDivisionXYs, plotDeltaAnglesShapeTCJscaled, plotDeltaAnglesShapeTCJDEG, PLOT);
        
        % Saves image:
        fprintf('\nSaving map of angle differences "plotDeltaAnglesShapeTCJ"...');
        print(printFormat, printResolution, deltaAnglesShapeTCJMapFile);
        close
        fprintf('Done.\n');
        
        % OTHER colormap
        PLOT.vMin = 0;
        PLOT.vMax = 90;
        PLOT.cmap = [FadeColor(blue,0.7) ; red];
        MakePointMap(plotDivisionXYs, plotDeltaAnglesShapeTCJscaled, plotDeltaAnglesShapeTCJDEG, PLOT);
        
        % Saves image 2:
        fprintf('Saving other map of angle differences "plotDeltaAnglesShapeTCJ"...');
        print(printFormat, printResolution, deltaAnglesShapeTCJMapFile2);
        close 
        fprintf('Done.\n');
    end
       
    %% MAP plot: Division angle difference (centroid vs junctions) (1.2-1.11) %%

    if ~exist(deltaAnglesDivCoMmapFile,'file')
        
        %%% Converting junction angles into division angles based on junctions:
        plotJunctionAnglesDIV = FixAnglesRAD(plotJunctionAngles + pi/2); % adding pi/2 and putting angles back into [-pi/2 pi/2]
        
        %%% Calculating angle differences
        plotDeltaAngles = FixAnglesRAD(plotCentroidAngles - plotJunctionAnglesDIV);  % results in [0 pi/2]
        plotDeltaAnglesDEG = rad2deg(abs(plotDeltaAngles));
        plotDeltaAnglesScaled = abs(plotDeltaAngles)/(pi/4);                                    % scales back results in [0 2]
        % NB: extreme angles are equal (-pi/2 <=> pi/2) => deltaAngle = FixAngle( pi/2-(-pi/2) ) = FixAngle(pi) = 0
        
        PLOT.textQuantity = '\theta_{CoM} - \theta_{div}';
        PLOT.scaleCircleValue = 1;          % must be same units as "plotDeltaAnglesShapeTCJPlot"
        PLOT.scaleCircleText = '45^o';
        
        PLOT.vMin = 10; % 1.9
        PLOT.vMax = 40;
        PLOT.colorBarUnits = '\Delta\theta';
        PLOT.cmap = FadeColor(dark_orange,fadingValues);
        MakePointMap(plotDivisionXYs, plotDeltaAnglesScaled, plotDeltaAnglesDEG, PLOT);
        
        % Saves image:
        fprintf('Saving map of division angle difference (CoMs vs Junctions)...');
        print(printFormat, printResolution, deltaAnglesDivCoMmapFile);
        close
        fprintf('Done.\n');
        
        % OTHER colormap (raw angles)
        plotDeltaAnglesRawDEG = rad2deg(plotDeltaAngles);
        PLOT.vMin = -40;
        PLOT.vMax = 40;
        PLOT.cmap = makeColorMap(crimson, custom_white, dark_orange, 2*nFadingValues+1);
        MakePointMap(plotDivisionXYs, plotDeltaAnglesScaled, plotDeltaAnglesRawDEG, PLOT);
        
        % Saves image 2:
        fprintf('Saving map of RAW division angle difference (CoMs vs Junctions)');
        print(printFormat, printResolution, deltaAnglesDivCoMrawMapFile);
        close

        fprintf('Done.\n');
    end
     
    %% MAP plot: angle difference "plotDeltaDivAnglesTCJ" (1.11) %%
    
    if ~exist(deltaAnglesDivTCJMapFile,'file')
        
        %%% Calculating angle differences
        plotDeltaAnglesTCJscaled = abs(plotDeltaAnglesDivTCJ)/(pi/2);   % scales results into [0 1]
        plotDeltaAnglesTCJDEG = rad2deg(abs(plotDeltaAnglesDivTCJ));
        
        textAveragingTimeRange = [num2str(averagingTimeRangeDivAngles(1)) '-' num2str(averagingTimeRangeDivAngles(2)) 'h'];                   % 1.11
        PLOT.textQuantity = ['\theta_{TCJ}^{' textAveragingTimeRange '} - \theta_{div}'];    % mod 1.11
        PLOT.scaleCircleValue = 1; % must be same units as "plotDeltaAnglesShapeTCJPlot"
        PLOT.scaleCircleText = '90^o';
        
        PLOT.vMin = 20; % 20 if taking absolute values
        PLOT.vMax = 70;
        PLOT.colorBarUnits = '\Delta\theta';
        PLOT.cmap = FadeColor(turquoise,fadingValues);
        MakePointMap(plotDivisionXYs, plotDeltaAnglesTCJscaled, plotDeltaAnglesTCJDEG, PLOT);
        
        % Saves image:
        fprintf('Saving map of angle differences "plotDeltaDivAnglesTCJ"...');
        print(printFormat, printResolution, deltaAnglesDivTCJMapFile);
        close
        fprintf('Done.\n');

        % OTHER colormap (raw angles)
        plotDeltaAnglesTCJrawDEG = rad2deg(plotDeltaAnglesDivTCJ);
        PLOT.vMin = -70;
        PLOT.vMax = 70;
        PLOT.cmap = makeColorMap(turquoise, custom_white, dark_orange, 2*nFadingValues+1);
        MakePointMap(plotDivisionXYs, plotDeltaAnglesTCJscaled, plotDeltaAnglesTCJrawDEG, PLOT);
        
        % Saves image 2:
        fprintf('Saving map of RAW angle differences "plotDeltaDivAnglesTCJ"...');
        print(printFormat, printResolution, deltaAnglesDivTCJrawMapFile);
        close
        
        fprintf('Done.\n');
    end
        
    %% PDF plot: Division angle differences (1.2) %%
    
    if ~exist(deltaAnglesDivCoMpdfFile, 'file') 
        
        plotDeltaAnglesDEG = rad2deg(abs(plotDeltaAngles)); % taking abs (1.11)
        h = PlotPDF(plotDeltaAnglesDEG,100,0,1,[]);
        set(h, 'LineWidth',1);
        hold on 
        PlotPDF(plotDeltaAnglesDEG,100,10,1,[]); % smoothing over 10 points
        xlabel('angles')
        title('Differences in division angles (centroids vs junctions)','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, deltaAnglesDivCoMpdfFile);
        close
    end
    
    %% TIME plot: Division angle differerence (1.2) %%
    
    if ~exist(deltaAnglesDivCoMtimeFile, 'file') 
        
        plot(plotLastTimesDiv,plotDeltaAnglesDEG,'bo')
        xlabel('time hAPF')
        ylabel('angles')
        title('Differences in division angles (centroids vs junctions) over time','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, deltaAnglesDivCoMtimeFile);
        close
    end
    
    fprintf('Done.\n')
end

%% SISTER AREA PLOTS %%
  
if displayDeltaAreaData
    
    %% MAP: Sister area difference (1.3, 1.9) %%
    
    if ~exist(deltaSisterAreaMapFile,'file') 
        
        plotDeltaAreasMap = abs(plotDeltaFirstAreas); % always take absolute values
        
        PLOT.textQuantity = ['\Delta' 'A_{sisters}'];
        PLOT.scaleCircleValue = 1;          % must be same units as "plotDeltaAnglesShapeTCJPlot"
        PLOT.scaleCircleText = '100%';
        
        PLOT.vMin = 20;
        PLOT.vMax = 70;
        PLOT.colorBarUnits = ['\Delta' 'A (%)'];
        PLOT.cmap = FadeColor(blue,fadingValues);
        MakePointMap(plotDivisionXYs, plotDeltaAreasMap, plotDeltaAreasMap*100, PLOT);
             
        % Saves image:
        fprintf('Saving map of sister area difference...');
        print(printFormat, printResolution, deltaSisterAreaMapFile); 
        close
        fprintf('Done.\n');
    end
       
    %% PDF: Sister area difference (1.3,1.4,2.0) %%

    % When taking absolute value of differences
    xRange = [0 100];
    yMax = 0.030;
    nPoints = 40; % 1 point every 100/nPoints %: 50-> every 2%, 20-> every 5%
    nSmooth = 0;
    nRounds = 1;
    
    nPointsLow = 20;
    
        %% All divisions lumped together: DIV
        
        if ~exist(PDFdeltaSisterAreaDivFile,'file') 

            % global pdf
            plotDeltaAreasMean = nanmean(plotDeltaFirstAreas(~plotDividingANs2excludeTF)); % now filtering (e (2.0)

            h = PlotPDF(plotDeltaFirstAreas*100,nPoints,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
            set(h,'Color',blue);
            hold on

            line([plotDeltaAreasMean plotDeltaAreasMean]*100, [0 yMax],'Color',blue,'LineStyle','--');

            %%% Setting legend for specified curves
            legend(h, ['nDivTot (' num2str(sum(nCellsDivRounds)) ')']);

            axis([xRange(1) xRange(2) 0 yMax]);
            xlabel('%')
            title('Distribution of relative sister area difference','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, PDFdeltaSisterAreaDivFile);
            close
        end
        
        %% All divisions lumped together + delaminations: DIV + DEL (2.0) %%
     
        if ~exist(PDFdeltaSisterAreaDivDevFile,'file') 

            % global pdf
            plotDeltaAreasMean = nanmean(plotDeltaFirstAreas(~plotDividingANs2excludeTF)); % now filtering (e (2.0)

            h0 = PlotPDF(plotDeltaFirstAreas*100,nPoints,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
            set(h0,'Color',blue);
            hold on

            line([plotDeltaAreasMean plotDeltaAreasMean]*100, [0 yMax],'Color',blue,'LineStyle','--');


            % for delaminating cells (1.4)
            delSisterDeltaAreas = plotDeltaFirstAreas(plotDelMotherANsLoc);
            delSisterDeltaAreasMean = nanmean(delSisterDeltaAreas);

            hDel = PlotPDF(delSisterDeltaAreas*100,nPointsLow,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
            set(hDel,'Color',black);

            line([delSisterDeltaAreasMean delSisterDeltaAreasMean]*100, [0 yMax],'Color',black,'LineStyle','--');

            %%% Setting legend for specified curves
            legend([h0 hDel], ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],['nDel (' num2str(nDelCells) ')']);

            axis([xRange(1) xRange(2) 0 yMax]);
            title('Distribution of relative sister area difference','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, PDFdeltaSisterAreaDivDevFile);
            close
        end
         
        %% All divisions lumped together + split: DIV + DIV SPLIT (2.0) %%
        
    if ~exist(PDFdeltaSisterAreaDivSplitFile,'file')   
        
        % global pdf
        plotDeltaAreasMean = nanmean(plotDeltaFirstAreas(~plotDividingANs2excludeTF)); % now filtering (e (2.0)
        
        h0 = PlotPDF(plotDeltaFirstAreas*100,nPoints,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
        set(h0,'Color',blue);
        hold on
        
        line([plotDeltaAreasMean plotDeltaAreasMean]*100, [0 yMax],'Color',blue,'LineStyle','--');

        % Split according to division round
        for nDiv = 1:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRounds == nDiv;
            end
            nthDivRoundFilteredTF = all([nthDivRoundTF ~plotDividingANs2excludeTF],2); % excluding problematic ANs % 2.0
            
            nthDivRoundDeltaAreas = plotDeltaFirstAreas(nthDivRoundFilteredTF); % using filtered version (2.0)
            nthDivRoundDeltaAreasMean = nanmean(nthDivRoundDeltaAreas);
 
            nthDivColor = min(nDiv+1,nDivColorMax);
            
            h = PlotPDF(nthDivRoundDeltaAreas*100,nPointsLow,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
            hold on
            set(h,'Color',colorDivision(nthDivColor,:));
            line([nthDivRoundDeltaAreasMean nthDivRoundDeltaAreasMean]*100, [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
            
            eval(['h' num2str(nDiv) '= h;' ])
        end
        
        %%% Setting legend for specified curves
        if nDivThreshold == 3
            legend([h0 h1 h2 h3], ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')']);           
        elseif nDivThreshold == 2
            legend([h0 h1 h2], ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')']);
        end
        
        % Finalization and saving
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('%')
        title('Distribution of relative sister area difference','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, PDFdeltaSisterAreaDivSplitFile);

    end
              
        %% All divisions split and delaminations: DIV SPLIT + DEL SPLIT (2.0) %%
        
        if ~exist(PDFdeltaSisterAreaDivSplitDevSplitFile,'file')
            
            nDelDivRounds = zeros(nDivThreshold,1);
            
            % Split according to division round
            for nDiv = 1:nDivThreshold
                
                nthDivColor = min(nDiv+1,nDivColorMax);
                
                if nDiv == nDivThreshold
                    nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
                else
                    nthDivRoundTF = plotnDivRounds == nDiv;
                end
                
                % Div cells
                nthDivRoundFilteredTF = all([nthDivRoundTF ~plotDividingANs2excludeTF],2); % excluding problematic ANs % 2.0
                
                nthDivRoundDeltaAreas = plotDeltaFirstAreas(nthDivRoundFilteredTF); % using filtered version (2.0)
                nthDivRoundDeltaAreasMean = nanmean(nthDivRoundDeltaAreas);

                h = PlotPDF(nthDivRoundDeltaAreas*100,nPointsLow,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
                hold on
                set(h,'Color',colorDivision(nthDivColor,:));
                line([nthDivRoundDeltaAreasMean nthDivRoundDeltaAreasMean]*100, [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
                
                eval(['h' num2str(nDiv) '= h;' ])
                
                
                % Del cells
                keepTF = all([onlyOneSisterDelaminatesANsTF nthDivRoundFilteredTF],2); % Only keep divisions with ONLY one sister delaminating
                nDelDivRounds(nDiv) = sum(keepTF);
                
                nthDivRoundDeltaAreasDEL = plotDeltaFirstAreas(keepTF); % using filtered version (2.0)
                nthDivRoundDeltaAreasDELmean = nanmean(nthDivRoundDeltaAreasDEL);
                
                h = PlotPDF(nthDivRoundDeltaAreasDEL*100,nPointsLow,nSmooth,nRounds,xRange); % smoothing over 10 points, nRounds times
                hold on
                set(h,'Color',colorDelamination(nDiv,:));
                line([nthDivRoundDeltaAreasDELmean nthDivRoundDeltaAreasDELmean]*100, [0 yMax],'Color',colorDelamination(nDiv,:),'LineStyle','--');
                
                eval(['hDel' num2str(nDiv) '= h;' ])
                
            end

            %%% Setting legend for specified curves
            if nDivThreshold == 3
                legend([h1 h2 h3 hDel1 hDel2 hDel3], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2) (' num2str(nDelDivRounds(2)) ')'],['nDel(3+) (' num2str(nDelDivRounds(3)) ')']...
                    ,'Location','Best');
            elseif nDivThreshold == 2
                legend([h1 h2 hDel1 hDel2], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2+) (' num2str(nDelDivRounds(2)) ')'],'Location','Best');
            end
            
            axis([xRange(1) xRange(2) 0 yMax]);
            title('Distribution of relative sister area difference','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, PDFdeltaSisterAreaDivSplitDevSplitFile);
            close
        end
        
    %% Sister area difference vs time (1.3,1.4) %%
    
    if ~exist(deltaSisterAreaTimeFile,'file') 
        
        scatter(plotLastTimesDiv,plotDeltaFirstAreas*100,10,plotnDivRoundColors,'filled')
        box on
        xlabel('time hAPF')
        ylabel('%')
        title('Relative sister area difference vs time','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, deltaSisterAreaTimeFile);
        close
    end
      
    %% ALL-TIME Sister area difference (1.6) %%
    
         %% Cumulated distribution of div cells vs life span (1.6)%%

%         %%% Global
%         %--------------------------------------------------------------------------------------------------------
%         if ~exist(sisterCoupleLifeSpanCUMfile,'file')
%                        
%             nSisterCouples = sum(~isnan(plotDeltaSisterAreasSync),1)';
%             
%             ratioSisterCouples = nSisterCouples/nSisterCouples0;
% 
%             
%             h1 = plot(timeAfterDivision, ratioSisterCouples);
%             set(h1,'Color',dark_green,'LineWidth',2);
%             hold on
%             
%             axis([0 timeAfterDivision(end) 0 1]);
%             xlabel('life span (h)')
%             title(['Cumulated distribution of sister couple life span (nSisCouples0 = ' num2str(nSisterCouples0) ') '],'FontWeight','bold','FontSize',12)
%             print(printFormat, printResolution, sisterCoupleLifeSpanCUMfile);
%             close
%         end
%         %--------------------------------------------------------------------------------------------------------
%         
%         
%         %%% Per division round
%         %--------------------------------------------------------------------------------------------------------
%         if ~exist(sisterCoupleLifeSpanCUMnDivRoundsFile,'file')
%             
%             nSisterCouples0 = sum(~isnan(plotDeltaSisterAreasSync(:,1)),1);
% 
%             plotRatioSisterCouples = zeros(maxDivLifeSpan,1);
%             for nDiv = 1:nDivThreshold
%                 
%                 nDivTF = plotnDivRoundsSisters == nDiv;
%                 nDivFilteredTF = all([nDivTF ~plotDividingANs2excludeTF],2); % excluding problematic ANs (2.0)
%                 
%                 nthDivDeltaSisterAreas = plotDeltaSisterAreasSync(nDivFilteredTF,:);
%                 nthDivnSisterCouples = sum(~isnan(nthDivDeltaSisterAreas),1)';
%                 
%                 nthRatioSisterCouples = nthDivnSisterCouples/nSisterCouples0;
%                 
%                 plotRatioSisterCouples = nthRatioSisterCouples;
%                 %             plotRatioSisterCouples = plotRatioSisterCouples + nthRatioSisterCouples;
%                 
%                 nthDivColor = min(nDiv+1,nDivColorMax);
%                 
%                 h = plot(timeAfterDivision, plotRatioSisterCouples);
%                 set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2);
%                 hold on
%                 
%                 eval(['h' num2str(nDiv) '= h;' ])
%                 
%             end
%             
%             %%% Setting legend for specified curves
%             if nDivThreshold == 3
%                 legend([h1 h2 h3], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
%                     ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')']);
%             elseif nDivThreshold == 2
%                 legend([h1 h2], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')']);
%             end
%             
%             axis([0 timeAfterDivision(end) 0 1]);
%             xlabel('life span (h)')
%             title('Cumulated distribution of sister couple life span ','FontWeight','bold','FontSize',12)
%             print(printFormat, printResolution, sisterCoupleLifeSpanCUMnDivRoundsFile);
%             close
%         end
%         %--------------------------------------------------------------------------------------------------------
                     
        %% TIME plot: Mean area difference:  DIV ALONE %%
        
        if ~exist(deltaMeanSisterAreaOverTimeFileDiv,'file')
            
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff);
            plotDeltaSisterRNsAreasCrop = plotDeltaSisterAreasSync(:,1:framesAfterDIVcutOff);
            
            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            plotDeltaSisterRNsAreasGlobal = plotDeltaSisterRNsAreasCrop(keepTF,:); % filtering (2.0)
            plotDeltaSisterAreasMean = nanmean(plotDeltaSisterRNsAreasGlobal,1)';
            plotDeltaSisterAreasSTD = nanstd(plotDeltaSisterRNsAreasGlobal,1,1)'; % flag 1 renomalizes by n (not n-1)
                      
            h0 = plot(timeAfterDivisionCrop, plotDeltaSisterAreasMean*100);
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
            axis([timeAfterDivisionCrop(1) timeAfterDivisionCrop(end) 0 yMaxTimeALD]);
           
            %%% Setting legend for specified curves
            legend(h0, ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],'Location','Best');
            
            xlabel('life span (h)')
            title('Average sister area relative difference over TAD ','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, deltaMeanSisterAreaOverTimeFileDiv);
            close
        end
        
        %% TIME plot: Mean area difference:  DIV + DIV SPLIT f(nDiv) %%
        
        if ~exist(deltaMeanSisterAreaOverTimeFileDivSplit,'file')

            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff);
            plotDeltaSisterRNsAreasCrop = plotDeltaSisterAreasSync(:,1:framesAfterDIVcutOff);
            
            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            plotDeltaSisterRNsAreasGlobal = plotDeltaSisterRNsAreasCrop(keepTF,:); % filtering (2.0)
            plotDeltaSisterAreasMean = nanmean(plotDeltaSisterRNsAreasGlobal,1)';
            plotDeltaSisterAreasSTD = nanstd(plotDeltaSisterRNsAreasGlobal,1,1)'; % flag 1 renomalizes by n (not n-1)
                      
            h0 = plot(timeAfterDivisionCrop, plotDeltaSisterAreasMean*100);
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
            axis([timeAfterDivisionCrop(1) timeAfterDivisionCrop(end) 0 yMaxTimeALD]);
            
%             nCellsLeftNthDiv = zeros(nDivThreshold,1);
            for nDiv = 1:nDivThreshold
                
                nDivTF = plotnDivRoundsSisters == nDiv;
                nDivFilteredTF = all([nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % excluding problematic ANs (2.0)

                nthDivDeltaSisterRNsAreasMean = nanmean(plotDeltaSisterRNsAreasCrop(nDivFilteredTF,:),1)';  % filtering (2.0)

                nthDivColor = min(nDiv+1,nDivColorMax);
                
                h = plot(timeAfterDivisionCrop, nthDivDeltaSisterRNsAreasMean*100);
                set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2)
                
                eval(['h' num2str(nDiv) '= h;' ])
            end           
            
            %%% Setting legend for specified curves
            if nDivThreshold == 3
                legend([h1 h2 h3 h0], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],'Location','Best');
            elseif nDivThreshold == 2
                legend([h1 h2 h0], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],'Location','Best');
            end
            
            xlabel('life span (h)')
            title('Average sister area relative difference over TAD ','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, deltaMeanSisterAreaOverTimeFileDivSplit);
            close
        end
        
        %% TIME plot: Mean area difference:  DIV + DEL %%
        
        if ~exist(deltaMeanSisterAreaOverTimeFileDivDel,'file')
            
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff);
            plotDeltaSisterRNsAreasCrop = plotDeltaSisterAreasSync(:,1:framesAfterDIVcutOff);
            
            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            plotDeltaSisterRNsAreasGlobal = plotDeltaSisterRNsAreasCrop(keepTF,:); % filtering (2.0)
            plotDeltaSisterAreasMean = nanmean(plotDeltaSisterRNsAreasGlobal,1)';
            plotDeltaSisterAreasSTD = nanstd(plotDeltaSisterRNsAreasGlobal,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            h0 = plot(timeAfterDivisionCrop, plotDeltaSisterAreasMean*100);
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
            axis([timeAfterDivisionCrop(1) timeAfterDivisionCrop(end) 0 yMaxTimeALD]);            
            
            % cells with ONLY one delaminating sister:
            keepTF = all([onlyOneSisterDelaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            plotDeltaSisterRNsAreasDELcrop = plotDeltaSisterRNsAreasCrop(keepTF,:);
            plotDeltaSisterRNsAreasDELmean = nanmean(plotDeltaSisterRNsAreasDELcrop,1)';
            nDel = sum(keepTF);
            
            hDel = plot(timeAfterDivisionCrop, plotDeltaSisterRNsAreasDELmean*100);
            set(hDel,'Color',black,'LineWidth',2)
            
            %%% Setting legend for specified curves
            legend([h0 hDel], ['nDivTot = 1 (' num2str(sum(nCellsDivRounds)) ')'],['nDel (' num2str(nDel) ')'],'Location','Best');
            
            xlabel('life span (h)')
            title('Average sister area relative difference over TAD ','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, deltaMeanSisterAreaOverTimeFileDivDel);
            close
        end
        
        %% TIME plot: Mean area difference: DIV SPLIT f(nDiv) + DEL SPLIT f(nDiv)%%
        
        if ~exist(deltaMeanSisterAreaOverTimeFileDivSplitDelSplit,'file')
     
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff);
            plotDeltaSisterRNsAreasCrop = plotDeltaSisterAreasSync(:,1:framesAfterDIVcutOff);          

            % Del specific

            nDelDivRounds = zeros(nDivThreshold,1);
            
            for nDiv = 1:nDivThreshold
                
                nDivTF = plotnDivRoundsSisters == nDiv;
                
                % Div
                keepTF = all([nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % cells with ONLY one delaminating sister AND nth Div round
                nthDivDeltaSisterRNsAreasMean = nanmean(plotDeltaSisterRNsAreasCrop(keepTF,:),1)';
                nthDivColor = min(nDiv+1,nDivColorMax);
                
                h = plot(timeAfterDivisionCrop, nthDivDeltaSisterRNsAreasMean*100);
                hold on
                set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2)
                eval(['h' num2str(nDiv) '= h;' ])
                

                % Del
                keepTF = all([onlyOneSisterDelaminatesANsTF nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % cells with ONLY one delaminating sister AND nth Div round
                nthDivPlotDeltaSisterRNsAreasDELmean = nanmean(plotDeltaSisterRNsAreasCrop(keepTF,:),1)';
                nDelDivRounds(nDiv) = sum(keepTF);
                
                nthDelColor = min(nDiv,nDelColorMax);
                
                h = plot(timeAfterDivisionCrop, nthDivPlotDeltaSisterRNsAreasDELmean*100);
                hold on
                set(h,'Color',colorDelamination(nthDelColor,:),'LineWidth',2)
                eval(['hDel' num2str(nDiv) '= h;' ])
            end
            
            axis([timeAfterDivisionCrop(1) timeAfterDivisionCrop(end) 0 yMaxTimeALD]);
            
            %%% Setting legend for specified curves
            if nDivThreshold == 3
                legend([h1 h2 h3 hDel1 hDel2 hDel3], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2) (' num2str(nDelDivRounds(2)) ')'],['nDel(3+) (' num2str(nDelDivRounds(3)) ')']...
                    ,'Location','Best');
            elseif nDivThreshold == 2
                legend([h1 h2 hDel1 hDel2], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2+) (' num2str(nDelDivRounds(2)) ')'],'Location','Best');
            end
            
            xlabel('life span (h)')
            title('Average sister area relative difference over TAD ','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, deltaMeanSisterAreaOverTimeFileDivSplitDelSplit);
            close
        end
             
        %% PDF %%
        
        if ~exist(deltaSisterAreaPDFallTimeFile,'file')
            
            %%% Global
            %--------------------------------------------------------------------------------------------------------
            xRange = [0 100];
            yMax = 0.030;
            nPoints = 20; % 1 point every 100/nPoints %: 50-> every 2%, 20-> every 5%
            nSmooth = 0;
            nRounds = 1;
            
            % Plot
            nTones = framesAfterDIVcutOff;
            cmap = jet(nTones);
            
            for f = 1:framesAfterDIVcutOff
                
                h = PlotPDF(plotDeltaSisterAreasSync(:,f)*100,nPoints,nSmooth,nRounds,xRange);
                
                fLineWidth = 1;
                if f==1 || f==framesAfterDIVcutOff(end)
                    fLineWidth = 2;
                end
                set(h,'Color',cmap(f,:),'LineWidth',fLineWidth);
                hold on
                
                %                 meanDeltaSis = nanmean(plotDeltaSisterAreas(:,f)*100);
                %                 line([meanDeltaSis meanDeltaSis], [0 yMax],'Color',cmap(f,:),'LineStyle','--');
            end
            
            thisColorBarXYWH = [0.75 0.85 0.1 0.03]; % in % of image width and height
            PlotColorBar('TALD (h)', thisColorBarXYWH, [0 timeAfterDIVcutOff], fontSizeInfo, colorInfo, cmap);
            
            axis([xRange(1) xRange(2) 0 yMax]);
            xlabel('%')
            title(['Evolution of relative sister area difference (nSisCouples0 = ' num2str(nSisterCouples0) ') '],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, deltaSisterAreaPDFallTimeFile);
            close
            
        end
        
        %% COR: Sister area difference vs angle difference (CoMs vs Js) (1.3) %%

%     plot(plotDeltaAnglesDEG,plotDeltaAreas*100,'bo')
%     xlabel('difference in division angles')
%     ylabel('relative sister area difference (%)')
%     title('Relative sister area difference vs difference in division angles (CoMs vs Js)','FontWeight','bold','FontSize',12)
%     print(printFormat, printResolution, deltaSisterAreaVSangleFile);
%     close
%     

        %% TIME plot: Mean bulkSignal DIV  (2.5,2.6) %%
        
        if ~exist(TIMEmeanBulkSignalFileDIV,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDIVflipCut = timeBeforeDIVflip(1:framesBeforeDELcutOff);
            plotDividingBulkSignalSyncFlipCut = plotDividingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDIVCut= - fliplr(timeBeforeDIVflipCut')';
            plotDividingBulkSignalSyncCut = fliplr(plotDividingBulkSignalSyncFlipCut);

            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % rows of divided cells that will be kept BEFORE AND AFTER division
%             keepTF = any(~isnan(plotDividingBulkSignalSyncCut),2);
            plotKept = plotDividingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % AFTER DIVISION (2.6)
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff*2);
            plotMeanSisters12BulkSignalsSyncCrop = plotMeanSisters12BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            
%             keepSistersTF = any(~isnan(plotMeanSisters12BulkSignalsSyncCrop),2);
            plotSistersKept = plotMeanSisters12BulkSignalsSyncCrop(keepTF,:); % filtering (2.0)
            plotSistersMean = nanmean(plotSistersKept,1)';
            plotSistersSTD = nanstd(plotSistersKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            % Gathering all
            timeDIVfull = [timeBeforeDIVCut(1:end-1) ; timeAfterDivisionCrop];
            plotMeanFull = [plotMean(1:end-1) ; plotSistersMean];
            plotSTDfull = [plotSTD(1:end-1) ; plotSistersSTD];
            
            CurveFill(timeDIVfull, plotMeanFull-plotSTDfull, plotMeanFull+plotSTDfull, blue,0.8);
            h0 = plot(timeDIVfull, plotMeanFull);         
            set(h0,'Color',blue,'LineWidth',2)
            hold on

%             maxY = ylim;
            line([0 0], [signalMin signalMax],'Color',black,'LineStyle','--');
%             line([timeBeforeDIVCut(1) timeAfterDivision(end)], [1 1],'Color',blue,'LineStyle','--');
            
            xlim([timeDIVfull(1) timeDIVfull(end)]);
%             xlim([timeBeforeDIVCut(1) timeBeforeDIVCut(end)]);
  
            %%% Setting legend for specified curves
            legend(h0, ['nDivTot (' num2str(sum(keepTF)) ')'],'Location','Best');
            
            xlabel('time before & after division (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDIV);
            close
        end
        
        %% TIME plot: Mean bulkSignal DIV + DIV SPLIT f(nDiv) (2.6) %%
        
        if ~exist(TIMEmeanBulkSignalFileDIVsplit,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDIVflipCut = timeBeforeDIVflip(1:framesBeforeDELcutOff);
            plotDividingBulkSignalSyncFlipCut = plotDividingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDIVCut= - fliplr(timeBeforeDIVflipCut')';
            plotDividingBulkSignalSyncCut = fliplr(plotDividingBulkSignalSyncFlipCut);

            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % rows of divided cells that will be kept BEFORE AND AFTER division
            plotKept = plotDividingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % AFTER DIVISION (2.6)
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff*2);
            plotMeanSisters12BulkSignalsSyncCrop = plotMeanSisters12BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            
            keepSistersTF = any(~isnan(plotMeanSisters12BulkSignalsSyncCrop),2);
            plotSistersKept = plotMeanSisters12BulkSignalsSyncCrop(keepSistersTF,:); % filtering (2.0)
            plotSistersMean = nanmean(plotSistersKept,1)';
            plotSistersSTD = nanstd(plotSistersKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            % Gathering all
            timeDIVfull = [timeBeforeDIVCut(1:end-1) ; timeAfterDivisionCrop];
            plotMeanFull = [plotMean(1:end-1) ; plotSistersMean];
            plotSTDfull = [plotSTD(1:end-1) ; plotSistersSTD];
            
            h0 = plot(timeDIVfull, plotMeanFull);         
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
            for nDiv = 1:nDivThreshold
                
                nDivTF = plotnDivRoundsSisters == nDiv;
                nDivFilteredTF = all([nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % excluding problematic ANs (2.0)

                % before div
                nthDivDividingBulkSignalSyncCut = nanmean(plotDividingBulkSignalSyncCut(nDivFilteredTF,:),1)';  % filtering (2.0)
                % after div
                nthDivMeanSisters12BulkSignalsSyncCrop = nanmean(plotMeanSisters12BulkSignalsSyncCrop(nDivFilteredTF,:),1)';  % filtering (2.0)
                % both
                nthDivBulkSignalFull = [nthDivDividingBulkSignalSyncCut(1:end-1) ;  nthDivMeanSisters12BulkSignalsSyncCrop];

                nthDivColor = min(nDiv+1,nDivColorMax);
                
                h = plot(timeDIVfull, nthDivBulkSignalFull);
                set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2)
                
                eval(['h' num2str(nDiv) '= h;' ])
            end           
            
            %%% Setting legend for specified curves
            if nDivThreshold == 3
                legend([h1 h2 h3 h0], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],'Location','Best');
            elseif nDivThreshold == 2
                legend([h1 h2 h0], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],'Location','Best');
            end

            line([0 0], [signalMin signalMax],'Color',black,'LineStyle','--');
            
            xlim([timeDIVfull(1) timeDIVfull(end)]);
        
            xlabel('time before & after division (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDIVsplit);
            close
        end
        
        %% TIME plot: Mean bulkSignal DIV + DEL (2.6) %%
        
        if ~exist(TIMEmeanBulkSignalFileDIVdel,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDIVflipCut = timeBeforeDIVflip(1:framesBeforeDELcutOff);
            plotDividingBulkSignalSyncFlipCut = plotDividingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDIVCut= - fliplr(timeBeforeDIVflipCut')';
            plotDividingBulkSignalSyncCut = fliplr(plotDividingBulkSignalSyncFlipCut);

            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % rows of divided cells that will be kept BEFORE AND AFTER division
            plotKept = plotDividingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % AFTER DIVISION (2.6)
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff*2);
            plotMeanSisters12BulkSignalsSyncCrop = plotMeanSisters12BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            
            plotSistersKept = plotMeanSisters12BulkSignalsSyncCrop(keepTF,:); % filtering (2.0)
            plotSistersMean = nanmean(plotSistersKept,1)';
            plotSistersSTD = nanstd(plotSistersKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            % Gathering all
            timeDIVfull = [timeBeforeDIVCut(1:end-1) ; timeAfterDivisionCrop];
            plotMeanFull = [plotMean(1:end-1) ; plotSistersMean];
            plotSTDfull = [plotSTD(1:end-1) ; plotSistersSTD];
            
            h0 = plot(timeDIVfull, plotMeanFull);         
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
             % cells with AT LEAST one delaminating sister:
            keepTF = all([atLeastOneSisterDelaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
%             keepTF = all([onlyOneSisterDelaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            nDel = sum(keepTF);
            
            % before div
            delDividingBulkSignalSyncCut = nanmean(plotDividingBulkSignalSyncCut(keepTF,:),1)';
            % after div
            delMeanSisters12BulkSignalsSyncCrop = nanmean(plotMeanSisters12BulkSignalsSyncCrop(keepTF,:),1)';  % filtering (2.0)
            % both
            delBulkSignalFull = [delDividingBulkSignalSyncCut(1:end-1) ;  delMeanSisters12BulkSignalsSyncCrop];
   
            hDel = plot(timeDIVfull, delBulkSignalFull);
            set(hDel,'Color',black,'LineWidth',2)
            
            line([0 0], [signalMin signalMax],'Color',black,'LineStyle','--');
            
            %%% Setting legend for specified curves
            legend([h0 hDel], ['nDivTot = 1 (' num2str(sum(nCellsDivRounds)) ')'],['nDel (' num2str(nDel) ')'],'Location','Best');

            xlim([timeDIVfull(1) timeDIVfull(end)]);

            xlabel('time before & after division (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDIVdel);
            close
        end
      
        %% TIME plot: Mean bulkSignal DIV SPLIT f(nDiv) + DEL SPLIT f(nDiv) (2.6) %%
        
        if ~exist(TIMEmeanBulkSignalFileDIVsplitDELsplit,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDIVflipCut = timeBeforeDIVflip(1:framesBeforeDELcutOff);
            plotDividingBulkSignalSyncFlipCut = plotDividingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDIVCut= - fliplr(timeBeforeDIVflipCut')';
            plotDividingBulkSignalSyncCut = fliplr(plotDividingBulkSignalSyncFlipCut);

            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % rows of divided cells that will be kept BEFORE AND AFTER division
            plotKept = plotDividingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % AFTER DIVISION (2.6)
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff*2);
            plotMeanSisters12BulkSignalsSyncCrop = plotMeanSisters12BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            
            keepSistersTF = any(~isnan(plotMeanSisters12BulkSignalsSyncCrop),2);
            plotSistersKept = plotMeanSisters12BulkSignalsSyncCrop(keepSistersTF,:); % filtering (2.0)
            plotSistersMean = nanmean(plotSistersKept,1)';
            plotSistersSTD = nanstd(plotSistersKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            % Gathering all
            timeDIVfull = [timeBeforeDIVCut(1:end-1) ; timeAfterDivisionCrop];
            plotMeanFull = [plotMean(1:end-1) ; plotSistersMean];
            plotSTDfull = [plotSTD(1:end-1) ; plotSistersSTD];
 
            nDelDivRounds = zeros(nDivThreshold,1);
            for nDiv = 1:nDivThreshold
                
                nDivTF = plotnDivRoundsSisters == nDiv;
                
                %%% DIV
                nDivFilteredTF = all([nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2); % excluding problematic ANs (2.0)

                % before div
                nthDivDividingBulkSignalSyncCut = nanmean(plotDividingBulkSignalSyncCut(nDivFilteredTF,:),1)';  % filtering (2.0)
                % after div
                nthDivMeanSisters12BulkSignalsSyncCrop = nanmean(plotMeanSisters12BulkSignalsSyncCrop(nDivFilteredTF,:),1)';  % filtering (2.0)
                % both
                nthDivBulkSignalFull = [nthDivDividingBulkSignalSyncCut(1:end-1) ;  nthDivMeanSisters12BulkSignalsSyncCrop];

                nthDivColor = min(nDiv+1,nDivColorMax);
                
                h = plot(timeDIVfull, nthDivBulkSignalFull);
                hold on
                set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2)
                
                eval(['h' num2str(nDiv) '= h;' ])
                
                
                %%% DEL
                % cells with AT LEAST one delaminating sister:
                keepTF = all([atLeastOneSisterDelaminatesANsTF nDivTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
                nDelDivRounds(nDiv) = sum(keepTF);
                
                % before div
                delDividingBulkSignalSyncCut = nanmean(plotDividingBulkSignalSyncCut(keepTF,:),1)';
                % after div
                delMeanSisters12BulkSignalsSyncCrop = nanmean(plotMeanSisters12BulkSignalsSyncCrop(keepTF,:),1)';  % filtering (2.0)
                % both
                delBulkSignalFull = [delDividingBulkSignalSyncCut(1:end-1) ;  delMeanSisters12BulkSignalsSyncCrop];
                
                nthDelColor = min(nDiv,nDelColorMax);
                
                h = plot(timeDIVfull, delBulkSignalFull);
                hold on
                set(h,'Color',colorDelamination(nthDelColor,:),'LineWidth',2)
                eval(['hDel' num2str(nDiv) '= h;' ])
            end
            
            line([0 0], [signalMin signalMax],'Color',black,'LineStyle','--');
            
            %%% Setting legend for specified curves
            if nDivThreshold == 3
                legend([h1 h2 h3 hDel1 hDel2 hDel3], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2) (' num2str(nDelDivRounds(2)) ')'],['nDel(3+) (' num2str(nDelDivRounds(3)) ')']...
                    ,'Location','Best');
            elseif nDivThreshold == 2
                legend([h1 h2 hDel1 hDel2], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],...
                    ['nDel(1) (' num2str(nDelDivRounds(1)) ')'],['nDel(2+) (' num2str(nDelDivRounds(2)) ')'],'Location','Best');
            end

            xlim([timeDIVfull(1) timeDIVfull(end)]);
        
            xlabel('time before & after division (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDIVsplitDELsplit);
            close
        end
        
        %% TIME plot: Mean bulkSignal DIV NOT dying + DEL split only 1 dying + DEL both dying (2.7) %%
        
        if ~exist(TIMEmeanBulkSignalFileDIVdelNonDelSplit,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDIVflipCut = timeBeforeDIVflip(1:framesBeforeDELcutOff);
            plotDividingBulkSignalSyncFlipCut = plotDividingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDIVCut= - fliplr(timeBeforeDIVflipCut')';
            plotDividingBulkSignalSyncCut = fliplr(plotDividingBulkSignalSyncFlipCut);

            % global
            keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF ~atLeastOneSisterDelaminatesANsTF],2); % now removing cells with 1 or more del daughters (2.7)
            nDivNonDel =  sum(keepTF); % 2.7
            
            plotKept = plotDividingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % AFTER DIVISION (2.6)
            % applying cut off
            timeAfterDivisionCrop = timeAfterDivision(1:framesAfterDIVcutOff*2);
            plotMeanSisters12BulkSignalsSyncCrop = plotMeanSisters12BulkSignalsSync(:,1:framesAfterDIVcutOff*2);

            plotSister1BulkSignalsSyncCrop = plotSister1BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            plotSister2BulkSignalsSyncCrop = plotSister2BulkSignalsSync(:,1:framesAfterDIVcutOff*2);
            
            plotSistersKept = plotMeanSisters12BulkSignalsSyncCrop(keepTF,:); % filtering (2.0)
            plotSistersMean = nanmean(plotSistersKept,1)';
            plotSistersSTD = nanstd(plotSistersKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            % Gathering all
            timeDIVfull = [timeBeforeDIVCut(1:end-1) ; timeAfterDivisionCrop];
            plotMeanFull = [plotMean(1:end-1) ; plotSistersMean];
            plotSTDfull = [plotSTD(1:end-1) ; plotSistersSTD];
            
            h0 = plot(timeDIVfull, plotMeanFull);         
            set(h0,'Color',blue,'LineWidth',2)
            hold on
            
             % cells with ONLY ONE delaminating sister:
            keepTF = all([onlyOneSisterDelaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            keepSister1TF = all([onlySister1delaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            keepSister2TF = all([onlySister2delaminatesANsTF ~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            nDel = sum(keepTF);
            
            % before div
            delDividingBulkSignalSyncCut = nanmean(plotDividingBulkSignalSyncCut(keepTF,:),1)';
            % after div
%             delMeanSisters12BulkSignalsSyncCrop = nanmean(plotMeanSisters12BulkSignalsSyncCrop(keepTF,:),1)';  % filtering (2.0)
            delSister1BulkSignalsSyncCrop = plotSister1BulkSignalsSyncCrop(keepSister1TF,:);       
            nonDeldelSister2BulkSignalsSyncCrop = plotSister2BulkSignalsSyncCrop(keepSister1TF,:);  % signal for sister 2 NOT dying
            
            delSister2BulkSignalsSyncCrop = plotSister2BulkSignalsSyncCrop(keepSister2TF,:);  
            nonDeldelSister1BulkSignalsSyncCrop = plotSister1BulkSignalsSyncCrop(keepSister2TF,:);  % signal for sister 2 NOT dying
            
            % merging dying vs non-dying cells
            delSister1or2BulkSignalsSyncCrop = nanmean([delSister1BulkSignalsSyncCrop ; delSister2BulkSignalsSyncCrop],1)';
            nonDelSister1or2BulkSignalsSyncCrop = nanmean([nonDeldelSister2BulkSignalsSyncCrop ; nonDeldelSister1BulkSignalsSyncCrop],1)';
            
            % both
            delBulkSignalFull = [delDividingBulkSignalSyncCut(1:end-1) ;  delSister1or2BulkSignalsSyncCrop];
            nonDelBulkSignalFull = [delDividingBulkSignalSyncCut(1:end-1) ;  nonDelSister1or2BulkSignalsSyncCrop];
   
            hDel = plot(timeDIVfull, delBulkSignalFull);
            set(hDel,'Color',black,'LineWidth',2)
            
            hNonDel = plot(timeDIVfull, nonDelBulkSignalFull);
            set(hNonDel,'Color',colorDivision(2,:),'LineWidth',2)
            
            line([0 0], [signalMin signalMax],'Color',black,'LineStyle','--');
            
            %%% Setting legend for specified curves
            legend([h0 hDel hNonDel], ['divNonDel (' num2str(nDivNonDel) ')'],['sisDel (' num2str(nDel) ')'],['sisNonDel (' num2str(nDel) ')'],'Location','Best');

            xlim([timeDIVfull(1) timeDIVfull(end)]);

            xlabel('time before & after division (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDIVdelNonDelSplit);
            close
        end
  
end

%% CELL CYCLE DURATION (1.5) %%

if displayCellCycleData

    %% MAP of division rounds (1.9)
    
    if ~exist(nDivRoundsMapFile,'file') 
    
        PLOT.textQuantity = 'Div Rounds';       
        PLOT.vMin = 1;
        PLOT.vMax = 3;
        PLOT.colorBarUnits = 'nDiv';
        PLOT.cmap = [mid_dark_green; mid_blue; mid_red];
        
        if isfield(PLOT,'scaleCircleValue')
            PLOT = rmfield(PLOT,{'scaleCircleValue','scaleCircleText'});
        end
        
        MakePointMap(plotDivisionXYs, 0.5, plotnDivRounds, PLOT);
    
        % Saves image:
        fprintf('Saving map of division rounds...');
        print(printFormat, printResolution, nDivRoundsMapFile); 
        close
        fprintf('Done.\n');
    end
      
    %% MAPs of cell cycle durations (1.9)
       
    % Removes point scaling for cell cycle plots
    if isfield(PLOT,'scaleCircleValue')
        PLOT = rmfield(PLOT,{'scaleCircleValue','scaleCircleText'});
    end
    
    % Map of time before FIRST division:
    if ~exist(cellFirstDivTimeMapFile,'file')
        
        plotDividingANs2excludeHereTF = any([~plotFirstDivRoundsTF plotDividingANs2excludeTF],2); % excluding all 1st division rounds AND issues, mod 1.19
        plotDeltaTimesDivFilt = plotDeltaTimesDiv;
        plotDeltaTimesDivFilt(plotDividingANs2excludeHereTF) = NaN;
        
        PLOT.textQuantity = '1st division time';

        PLOT.vMin = 2;
        PLOT.vMax = 6;
        PLOT.colorBarUnits = '1st division (h)';
        PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
        MakePointMap(plotDivisionXYs, 0.5, plotDeltaTimesDivFilt, PLOT);
             
        % Saves image:
        fprintf('Saving map of 1st division time...');
        print(printFormat, printResolution, cellFirstDivTimeMapFile); 
        close
        fprintf('Done.\n');
    end
    
    secondDivRoundsTF = plotnDivRounds == 2;
    thirdDivRoundsTF = plotnDivRounds == 3;
    
    % Map of duration between 1st-2nd rounds of divisison (cell cycle)
    if ~exist(cellCycleDuration2ndRoundMapFile,'file')
        
        plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF thirdDivRoundsTF plotDividingANs2excludeTF],2); % excluding all 1st division rounds AND issues, mod 1.19
        plotDeltaTimesDivFilt = plotDeltaTimesDiv;
        plotDeltaTimesDivFilt(plotDividingANs2excludeHereTF) = NaN;
        
        PLOT.textQuantity = 'Cycle duration (1-2)';
        
        PLOT.vMin = 4;
        PLOT.vMax = 10;
        PLOT.colorBarUnits = 'cell cycle (h)';
        PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
        MakePointMap(plotDivisionXYs, 0.5, plotDeltaTimesDivFilt, PLOT);
             
        % Saves image:
        fprintf('Saving map of cell cycle duration (1st-2nd round)...');
        print(printFormat, printResolution, cellCycleDuration2ndRoundMapFile); 
        close
        fprintf('Done.\n');
    end
    
    
    % Map of duration between 2nd-3rd rounds of divisison (cell cycle)
    if ~exist(cellCycleDuration3rdRoundMapFile,'file')
        
        plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF secondDivRoundsTF plotDividingANs2excludeTF],2); % excluding plot 1st division rounds AND issues, mod 1.19
        plotDeltaTimesDivFilt = plotDeltaTimesDiv;
        plotDeltaTimesDivFilt(plotDividingANs2excludeHereTF) = NaN;
        
        PLOT.textQuantity = 'Cycle duration (2-3)';
        
        PLOT.vMin = 4;
        PLOT.vMax = 10;
        PLOT.colorBarUnits = 'cell cycle (h)';
        PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
        MakePointMap(plotDivisionXYs, 0.5, plotDeltaTimesDivFilt, PLOT);
             
        % Saves image:
        fprintf('Saving map of cell cycle duration (2nd-3rd round)...');
        print(printFormat, printResolution, cellCycleDuration3rdRoundMapFile); 
        close
        fprintf('Done.\n');
    end
          
    %% GRID MAPs of cell cycle durations (1.21)    
    
    if ~isempty(gridType) && (max(gridSize) > 1 && ~cloneTracking) % 2.0, 2.4
        
        % Map of MEAN time before FIRST division: (1.21)
        if ~exist(cellFirstDivTimeGridMapFile) && exist('gridDividingANsRows','var')
            
            plotDividingANs2excludeHereTF = any([~plotFirstDivRoundsTF plotDividingANs2excludeTF],2); % excluding when NOT 1st division rounds AND issues, mod 1.19
            plotDividingANs2excludeHereRows = find(plotDividingANs2excludeHereTF);
            
            gridFirstDivTimes = NaN(ny,nx);
            
            for b = 1:nBoxes
                bRows = setdiff(gridDividingANsRows{b}, plotDividingANs2excludeHereRows);
                bDeltaTimesDiv = plotDeltaTimesDiv(bRows);
                gridFirstDivTimes(b) = mean(bDeltaTimesDiv);
            end
            
            PLOT.textQuantity = 'Mean 1st division time';
            PLOT.vMin = 2;
            PLOT.vMax = 6;
            PLOT.colorBarUnits = '1st division (h)';
            %         PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
            PLOT.ContourIndices = gridMapContourIndices;
            PLOT.borderRNs = gridMapBorderRNs;
            PLOT.gridColor = gridColor;
            PLOT.macroRNs = macroRNs;
            PLOT.colorJunctions = colorJunctions;
            
            % for "jet" colormap
            PLOT.cmap = flipud(jet(10));
            PLOT.colorMacrochaetes = custom_white;
            
            MakeGridMap(gridMapSegImage, gridMapCoreRNs, gridFirstDivTimes, PLOT);
            
            % Saves image:
            fprintf('Saving average map of 1st division time...');
            print(printFormat, printResolution, cellFirstDivTimeGridMapFile);
            close
            fprintf('Done.\n');
        end
        
        
        % Map of MEAN duration between 1st-2nd  rounds of divisison (cell cycle) (1.21)
        if ~exist(cellCycleDuration2ndRoundGridMapFile) && exist('gridDividingANsRows','var')
            
            plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF thirdDivRoundsTF plotDividingANs2excludeTF],2); % excluding plot 1st division rounds AND issues, mod 1.19
            plotDividingANs2excludeHereRows = find(plotDividingANs2excludeHereTF);
            
            gridDeltaTimesDiv = NaN(ny,nx);
            
            for b = 1:nBoxes
                bRows = setdiff(gridDividingANsRows{b}, plotDividingANs2excludeHereRows);
                bDeltaTimesDiv = plotDeltaTimesDiv(bRows);
                gridDeltaTimesDiv(b) = mean(bDeltaTimesDiv);
            end
            
            PLOT.textQuantity = 'Mean cycle duration (1-2)';
            PLOT.vMin = 6;
            PLOT.vMax = 10;
            PLOT.colorBarUnits = 'cell cycle (h)';
            %         PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
            PLOT.ContourIndices = gridMapContourIndices;
            PLOT.borderRNs = gridMapBorderRNs;
            PLOT.gridColor = gridColor;
            PLOT.macroRNs = macroRNs;
            PLOT.colorJunctions = colorJunctions;
            
            % for "jet" colormap
            PLOT.cmap = flipud(jet(10));
            PLOT.colorMacrochaetes = custom_white;
            
            MakeGridMap(gridMapSegImage, gridMapCoreRNs, gridDeltaTimesDiv, PLOT);
            
            % Saves image:
            fprintf('Saving average map of cell cycle duration (1st-2nd round)...');
            print(printFormat, printResolution, cellCycleDuration2ndRoundGridMapFile);
            close
            fprintf('Done.\n');
        end
        
        
        % Map of STD of duration between 1st-2nd  rounds of divisison (cell cycle) (1.21)
        if ~exist(cellCycleSTD2ndRoundGridMapFile) && exist('gridDividingANsRows','var')
            
            plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF thirdDivRoundsTF plotDividingANs2excludeTF],2); % excluding plot 1st division rounds AND issues, mod 1.19
            plotDividingANs2excludeHereRows = find(plotDividingANs2excludeHereTF);
            
            gridSTDofDeltaTimesDiv = NaN(ny,nx);
            
            for b = 1:nBoxes
                bRows = setdiff(gridDividingANsRows{b}, plotDividingANs2excludeHereRows);
                bDeltaTimesDiv = plotDeltaTimesDiv(bRows);
                gridSTDofDeltaTimesDiv(b) = std(bDeltaTimesDiv);
            end
            
            PLOT.textQuantity = 'STD of cycle duration (1-2)';
            PLOT.vMin = 0;
            PLOT.vMax = 3;
            PLOT.colorBarUnits = 'cell cycle STD (h)';
            %         PLOT.cmap = FadeColor(dark_green,fliplr(fadingValues)); % small values will apear darker
            PLOT.ContourIndices = gridMapContourIndices;
            PLOT.borderRNs = gridMapBorderRNs;
            PLOT.gridColor = gridColor;
            PLOT.macroRNs = macroRNs;
            PLOT.colorJunctions = colorJunctions;
            
            % for "jet" colormap
            PLOT.cmap = flipud(jet(10));
            PLOT.colorMacrochaetes = custom_white;
            
            MakeGridMap(gridMapSegImage, gridMapCoreRNs, gridSTDofDeltaTimesDiv, PLOT);
            
            % Saves image:
            fprintf('Saving map of STD of cell cycle duration (1st-2nd round)...');
            print(printFormat, printResolution, cellCycleSTD2ndRoundGridMapFile);
            close
            fprintf('Done.\n');
        end
    end
             
    %% PDF (no filtering)

if ~exist(cellCycleDurationPDFrawFile,'file') 
    
    xRange = [0 13];
    yMax = 0.5;
    nPoints = 26; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
    nSmooth = 0;
    nRounds = 1;
   
    nCellsDivRoundsRaw = zeros(nDivThreshold,1);
    
    for nDiv = 1:nDivThreshold
        
        if nDiv == nDivThreshold
            nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
        else
            nthDivRoundTF = plotnDivRounds == nDiv;
        end
        
        nCellsDivRoundsRaw(nDiv) = sum(nthDivRoundTF);
        
        nthDivRoundDeltaTimes = plotDeltaTimesDiv(nthDivRoundTF);
        nthDivRoundDeltaTimesMean = nanmean(nthDivRoundDeltaTimes);
        
        nthDivColor = min(nDiv+1,nDivColorMax);
        
        h = PlotPDF(nthDivRoundDeltaTimes,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',colorDivision(nthDivColor,:));
        hold on
        line([nthDivRoundDeltaTimesMean nthDivRoundDeltaTimesMean], [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
        
        eval(['h' num2str(nDiv) '= h;' ])
    end
    
    %%% Setting legend for specified curves
    if nDivThreshold == 3
        legend([h1 h2 h3], ['nDiv = 1 (' num2str(nCellsDivRoundsRaw(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRoundsRaw(2)) ')'],...
            ['nDiv \geq 3 (' num2str(nCellsDivRoundsRaw(3)) ')']);
    elseif nDivThreshold == 2
        legend([h1 h2], ['nDiv = 1 (' num2str(nCellsDivRoundsRaw(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRoundsRaw(2)) ')']);
    end
    
    axis([xRange(1) xRange(2) 0 yMax]);
    xlabel('time (h)')
    title('Distributions of cell cycle duration','FontWeight','bold','FontSize',12)
    print(printFormat, printResolution, cellCycleDurationPDFrawFile);
    close
end

    %% PDF Filtered 

if ~exist(cellCycleDurationPDFFile,'file') 
    
    xRange = [0 13];
    yMax = 0.5;
    nPoints = 26; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
    nSmooth = 0;
    nRounds = 1;
        
    for nDiv = 1:nDivThreshold
        
        if nDiv == nDivThreshold
            nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
        else
            nthDivRoundTF = plotnDivRounds == nDiv;
        end
        nthDivRoundFilteredTF = all([nthDivRoundTF ~plotDividingANs2excludeTF],2); % excluding problematic ANs
                
        nthDivRoundDeltaTimes = plotDeltaTimesDiv(nthDivRoundFilteredTF);
        nthDivRoundDeltaTimesMean = nanmean(nthDivRoundDeltaTimes);
        
        nthDivColor = min(nDiv+1,nDivColorMax);
        
        h = PlotPDF(nthDivRoundDeltaTimes,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',colorDivision(nthDivColor,:));
        hold on
        line([nthDivRoundDeltaTimesMean nthDivRoundDeltaTimesMean], [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
        
        eval(['h' num2str(nDiv) '= h;' ])
    end
    
    %%% ***NOT*** Adding curve of exculded ANs
    
    %%% Setting legend for specified curves
    if nDivThreshold == 3
        legend([h1 h2 h3], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
            ['nDiv \geq  3 (' num2str(nCellsDivRounds(3)) ')']);
    elseif nDivThreshold == 2
        legend([h1 h2 ], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')']);
    end
    
%     %%% Adding curve of exculded ANs
%     excludedDeltaTimes = plotDeltaTimesDiv(plotDividingANs2excludeTF);
%     hpb = PlotPDF(excludedDeltaTimes,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
%     set(hpb,'Color', dark_orange);
%     line([minCycleDuration minCycleDuration], [0 yMax],'Color',dark_orange,'LineStyle','-');
%     
%     %%% Setting legend for specified curves
%     if nDivThreshold == 3
%         legend([h1 h2 h3 hpb], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
%             ['nDiv \geq  3 (' num2str(nCellsDivRounds(3)) ')'],['exluded ANs (' num2str(nDivANsExcluded) ')']);
%     elseif nDivThreshold == 2
%         legend([h1 h2 hpb], ['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],['exluded ANs (' num2str(nDivANsExcluded) ')']);
%     end
    
    axis([xRange(1) xRange(2) 0 yMax]);
    xlabel('time (h)')
    title('Distributions of cell cycle duration','FontWeight','bold','FontSize',12)
    print(printFormat, printResolution, cellCycleDurationPDFFile);
    close
    
end
    
    %% COR cycle duration vs mean cell apical size (1.12)
    
    if ~exist(cellCycleDurationVSmeanAreasCORfile,'file')
        
        plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF plotDividingANs2excludeTF],2); % excluding all 1st division rounds AND issues, mod 1.19
        plotDeltaTimesDivFilt = plotDeltaTimesDiv;
        plotDeltaTimesDivFilt(plotDividingANs2excludeHereTF) = NaN;
        plotMeanDividingAreasFilt = plotMeanDividingAreas;
        plotMeanDividingAreasFilt(plotDividingANs2excludeHereTF) = NaN;
        
        nDivCellsFilt = sum(all(~isnan([plotDeltaTimesDivFilt plotMeanDividingAreasFilt]),2),1);
        
        scatter(plotMeanDividingAreasFilt, plotDeltaTimesDivFilt,15, plotnDivRoundColors,'filled')
        box on
        
        ylabel('cell cycle duration (h)')
        xlabel('mean areas ({\mu}m^2)')
        title(['Cell cycle duration vs mean area ([' num2str(averagingTimeRangeDIV) '] h, n = ' num2str(nDivCellsFilt) ')'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, cellCycleDurationVSmeanAreasCORfile);
        close
    end
    
    %% BIN cycle duration vs mean cell apical size (2.0) %%
    
    if ~exist(BINcellCycleDurationVSmeanAreasCORfile,'file')
        
        plotDividingANs2excludeHereTF = any([plotFirstDivRoundsTF plotDividingANs2excludeTF],2); % excluding all 1st division rounds AND issues, mod 1.19
        plotDeltaTimesDivFilt = plotDeltaTimesDiv;
        plotDeltaTimesDivFilt(plotDividingANs2excludeHereTF) = NaN;
        plotMeanDividingAreasFilt = plotMeanDividingAreas;
        plotMeanDividingAreasFilt(plotDividingANs2excludeHereTF) = NaN;
        
        binVec = [0 5 60];
        [~, nDivCellsFilt] = BinPlot(plotMeanDividingAreasFilt, plotDeltaTimesDivFilt, binVec, dark_green,'std');                


        ylabel('cell cycle duration (h)')
        xlabel('mean areas ({\mu}m^2)')
        title(['Cell cycle duration vs mean area ([' num2str(averagingTimeRangeDIV) '] h, n = ' num2str(nDivCellsFilt) ')'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, BINcellCycleDurationVSmeanAreasCORfile);

        close
    end
       
end

%% PDF of DIVISION & DELAMINATION vs TIME APF (1.5) %%   

    %% PDF plot: Global %%
    
    if ~exist(divisionsAndDeathsPDFfile,'file') 
        
        xRange = [11 32];
        yMax = 0.2;
        nPoints = 40; % 1 point every 20/nPoints %: 80-> every 15min, 40-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        nPointsDel = 30;
        
        % all divisions and delaminations PDF (raw)
        [h,~,~,areaUCdiv] = PlotPDF(plotLastTimesDiv,nPoints,nSmooth,nRounds,xRange);
        set(h,'Color', dark_green);
        hold on
        if ~isempty(plotLastTimesDel)
            h = PlotPDF(plotLastTimesDel,nPointsDel,nSmooth,nRounds,xRange);
            set(h,'Color', black);
        end
        
        %%% Plotting division with cell cycle below "minCycleDuration" threshold
        excludedLastTimesDiv = plotLastTimesDiv(plotDividedTooSoonTF);
        [~,X,Y,areaUCpb] = PlotPDF(excludedLastTimesDiv,-nPoints,nSmooth,nRounds,xRange);
        Y = Y*areaUCpb/areaUCdiv;
        h = plot(X,Y);
        set(h,'Color', dark_orange, 'LineWidth',2);
        
        nExcluded = sum(plotDividedTooSoonTF);
        legend( ['divisions (' num2str(nDivCells) ')'], ['delaminations (' num2str(nDelCells) ')'],...
            ['divisions < ' num2str(minCycleDuration) 'h (' num2str(nExcluded) ')'],...
            'Location', 'Best');
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('time (hAPF)')
        title('Distributions of divisions and delaminations','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, divisionsAndDeathsPDFfile);
        close
    end
        
    %% PDF plot: Division PDF Broken down in division rounds
    
    if ~exist(divisionRoundsPDFFile,'file') 
        
        plotLastTimesDivFiltered = plotLastTimesDiv(~plotDividedTooSoonTF);
                
        xRange = [11 32];
        yMax = 0.2;
        nPoints = 40; % 1 point every 20/nPoints %: 80-> every 15min, 40-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        [h0,~,~,areaUCdiv] = PlotPDF(plotLastTimesDivFiltered,nPoints,nSmooth,nRounds,xRange);
        set(h0,'Color', blue,'LineStyle','-');
        hold on
        
        for nDiv = 1:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRounds == nDiv;
            end
            nthDivRoundFilteredTF = all([nthDivRoundTF ~plotDividingANs2excludeTF],2); % excluding problematic ANs (mod 2.0)
            
            nthDivRoundLastTimes = plotLastTimesDiv(nthDivRoundFilteredTF);
            
            nthDivColor = min(nDiv+1,nDivColorMax);

            [~,X,Y,areaUCnDiv] = PlotPDF(nthDivRoundLastTimes,-nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
            Y = Y*areaUCnDiv/areaUCdiv;
            h = plot(X,Y);
            
            set(h,'Color',colorDivision(nthDivColor,:), 'LineWidth',2);  
        end
        
        %%% Setting legend for specified curves
        if nDivThreshold == 3
            legend( ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv = 2 (' num2str(nCellsDivRounds(2)) ')'],...
                ['nDiv \geq 3 (' num2str(nCellsDivRounds(3)) ')'],'Location', 'Best');
        elseif nDivThreshold == 2
            legend( ['nDivTot (' num2str(sum(nCellsDivRounds)) ')'],['nDiv = 1 (' num2str(nCellsDivRounds(1)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRounds(2)) ')'],'Location', 'Best');
        end
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('time (hAPF)')
        title('Distributions of divisions','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, divisionRoundsPDFFile);
        close
    end
       
%% PLOTS RELATED TO DELAMINATIONS (1.6) %%

if displayDelaminationData
    
    %% PDF: Sister area difference WITH ONLY ONE DELAMINATING SISTER (1.4) %%

if ~exist(deltaSisterAreaPDFdelFile,'file') 
        
    xRange = [-100 100];
    yMax = 0.015;
    nPoints = 40;
    nSmooth = 1;
    nRounds = 1;
 
    % getting number of cells
    plotDeltaFirstAreasDELcrop = plotDeltaFirstAreasDEL(onlyOneSisterDelaminatesANsTF); % cropping to sisters with only one delaminating sister (2.0)
    plotDeltaFirstAreasDELcrop = RemoveNaNs(plotDeltaFirstAreasDELcrop); % 2.0
    nDelSis = size(plotDeltaFirstAreasDELcrop,1);

    plotDeltaAreasDelMean = nanmean(plotDeltaFirstAreasDEL);

    h = PlotPDF(plotDeltaFirstAreasDEL*100,nPoints,nSmooth,nRounds,xRange); % smoothing over 10 points,nRounds times
    set(h,'Color',black);
    hold on
    line([0 0], [0 yMax],'Color',grey,'LineStyle','--');
    line([plotDeltaAreasDelMean plotDeltaAreasDelMean]*100, [0 yMax],'Color',black,'LineStyle','--');
    
    axis([xRange(1) xRange(2) 0 yMax]);
    xlabel('%')
    title(['Relative sister area difference (nDelSis = ' num2str(nDelSis) ')'],'FontWeight','bold','FontSize',12)
    print(printFormat, printResolution, deltaSisterAreaPDFdelFile);
    close
end
    
    %% PDF: Delamination times After Last Division (ALD) DIV SPLIT 

    if ~exist(delaminationTimeAfterLastDivPDFfile,'file')
        
        xRange = [0 15];
        yMax = 0.25;
        nPoints = 25; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);
        
        [hAll,~,Yplot,aUCplot] = PlotPDF(plotDeltaTimesDEL,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(hAll,'Color',black)
        hold on
        
        YplotOLD = zeros(size(Yplot));
        for nDiv = 0:nDivThreshold % **STARTS AT 0**
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end
            
            nthDivRoundDeltaTimesDEL = plotDeltaTimesDEL(nthDivRoundTF);
            nthDivRoundDeltaTimesDELmean = nanmean(nthDivRoundDeltaTimesDEL);
            
            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nthDivRoundDeltaTimesDEL)); %2.2
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);
            
            nthDivColor = min(nDiv+1,nDivColorMax);
            
            [~,X,Y,aUC] = PlotPDF(nthDivRoundDeltaTimesDEL,-nPoints,nSmooth,nRounds,xRange);
            Y = Y*aUC/aUCplot;
            Yplot = YplotOLD + Y;
            CurveFill(X,YplotOLD,Yplot,colorDivision(nthDivColor,:),0.4);
            h = plot(X,Yplot);
            set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2);
            hold on
            
            line([nthDivRoundDeltaTimesDELmean nthDivRoundDeltaTimesDELmean], [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
            
            eval(['h' num2str(nDiv) '= h;' ])
            YplotOLD = Yplot;
        end
        % replots black line
        h = PlotPDF(plotDeltaTimesDEL,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',black)
        
        %%% Setting legend for specified curves
        if nDivThreshold == 3
            legend([h0 h1 h2 h3 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv = 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['nDiv \geq 3 (' num2str(nCellsDivRoundsDEL(4)) ')'], ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        elseif nDivThreshold == 2
            legend([h0 h1 h2 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        end
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('delamination time ALD (h)')
        title('Distributions of delamination times ALD','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, delaminationTimeAfterLastDivPDFfile);
        close
    end
    
    %% PDF: Time Evolution of Sister area difference WITH ONLY ONE DELAMINATING SISTER 

    if ~exist(deltaSisterAreaPDFallTimeDELfile,'file')
        
        xRange = [-100 100];
        yMax = 0.015;
        nPoints = 20; % 1 point every 200/nPoints %: 100-> every 2%, 40-> every 5%, 20-> every 10%
        nSmooth = 1;
        nRounds = 1;
        
        nDelSis = size(plotDeltaSisterAreasDEL,1);
        
        % Plot
        nTones = framesAfterDIVcutOff;
        cmap = jet(nTones);
        
        for f = 1:framesAfterDIVcutOff
            
            h = PlotPDF(plotDeltaSisterAreasDEL(:,f)*100,nPoints,nSmooth,nRounds,xRange);
            
            fLineWidth = 1;
            if f==1 || f==framesAfterDIVcutOff(end)
                fLineWidth = 2;
            end
            set(h,'Color',cmap(f,:),'LineWidth',fLineWidth);
            hold on
            
            meanDeltaSis = nanmean(plotDeltaSisterAreasDEL(:,f)*100);
            line([meanDeltaSis meanDeltaSis], [0 yMax],'Color',cmap(f,:),'LineStyle','--');
        end
        
        line([0 0], [0 yMax],'Color',black,'LineStyle','-','LineWidth',0.5);
        
        thisColorBarXYWH = [0.75 0.85 0.1 0.03]; % in % of image width and height
        hc = PlotColorBar('TALD (h)', thisColorBarXYWH, [0 timeAfterDIVcutOff], fontSizeInfo, colorInfo, cmap);
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('%')
        title(['Relative sister area difference (nDelSis = ' num2str(nDelSis) ') '],'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, deltaSisterAreaPDFallTimeDELfile);
        close
    end

    %% PDF: Areas of DEL cells a couple frame before extrusion (1.6)
    
    if ~exist(delaminationAreasPDFfile,'file') 
        
        xRange = [0 25];
        yMax = 0.5;
        nPoints = 50; % 1 point every 25/nPoints %: 25-> every 1 �m�, 50-> every 0.5 �m�
        nSmooth = 0;
        nRounds = 1;
        
        h = PlotPDF(plotDelaminatingAreasSync(:,end-48),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',white_grey)
        hold on
        
        h = PlotPDF(plotDelaminatingAreasSync(:,end-36),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',light_grey)
        
        h = PlotPDF(plotDelaminatingAreasSync(:,end-24),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',mid_grey)
        
        h = PlotPDF(plotDelaminatingAreasSync(:,end-12),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',grey)
        
        h = PlotPDF(plotDelaminatingAreasSync(:,end-6),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',dark_grey)
        
        [hAll,Xplot,Yplot,aUCplot] = PlotPDF(plotDelaminatingAreasSync(:,end-1),nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(hAll,'Color',black)
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel(['area (\mu' 'm^2)'])
        title('Distribution of cell areas right before delamination','FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, delaminationAreasPDFfile);
        close
    end
          
    %% BOX: times After Last Division (ALD) vs division round (2.0)%%
    
    if ~exist(time2deathALDVSnDivBOXfile,'file')
        
        nCellsDivRoundsDEL = zeros(nDivThreshold,1);
        
       	for nDiv = 1:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end
            
            nthDivRoundDeltaTimesDEL = plotDeltaTimesDEL(nthDivRoundTF);
            
            nCellsDivRoundsDEL(nDiv) = sum(~isnan(nthDivRoundDeltaTimesDEL)); %2.2
%             nCellsDivRoundsDEL(nDiv) = sum(nthDivRoundTF);
           
            boxplotx(nthDivRoundDeltaTimesDEL, nDiv);
%             boxplotx(nthDivRoundDeltaTimesDEL, nDiv,'lines','g-');
%             boxplot(stCellsFeaturePlot, 'positions', mean(stCellSignalPlot),'Width',std(stCellSignalPlot),'Colors',stColor);
            h2 = findobj('Type', 'line');
            set(h2, 'Color',colorDivision(4,:))
            hold on
        end
        
        xticks(0:1:nDivThreshold+1)
        
        ylabel('delamination time ALD (h)')
        xlabel('division round')
        
        print(printFormat, printResolution, time2deathALDVSnDivBOXfile);
        close
    end
    
    %% COR: times After Last Division (ALD) vs sister area difference (2.0)%%
    
    if ~exist(time2deathALDVSdeltaSisterAreasFile,'file')
        
        nCellsDivRoundsDEL = zeros(nDivThreshold,1);
        
       	for nDiv = 1:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRounds >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRounds == nDiv;
            end

            nDivDeltaAreasDEL = plotDeltaFirstAreasDEL(nthDivRoundTF);
            nDivOnlyDELsisterLifeSpan = onlyDELsisterLifeSpan(nthDivRoundTF);
            
            % removing nan rows
            keepTF = all([~isnan(nDivDeltaAreasDEL)  ~isnan(nDivOnlyDELsisterLifeSpan)],2);
            nDivDeltaAreasDEL = nDivDeltaAreasDEL(keepTF);
            nDivOnlyDELsisterLifeSpan = nDivOnlyDELsisterLifeSpan(keepTF);
            
            nCellsDivRoundsDEL(nDiv) = sum(keepTF);

            scatter(nDivDeltaAreasDEL, nDivOnlyDELsisterLifeSpan,15, colorDelamination(nDiv,:),'filled')
            box on
            hold on
 
        end
        
        if nDivThreshold == 3
            legend(['nDel(1) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(2) (' num2str(nCellsDivRoundsDEL(2)) ')'],['nDel(3+) (' num2str(nCellsDivRoundsDEL(3)) ')'],'Location','Best');
        elseif nDivThreshold == 2
            legend(['nDel(1) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(2+) (' num2str(nCellsDivRoundsDEL(2)) ')'],'Location','Best');
        end
        
        
        ylabel('delamination time ALD (h)')
        xlabel('sister area difference')
        title('Time to delamination vs sister area difference','FontWeight','bold','FontSize',12)
        
        print(printFormat, printResolution, time2deathALDVSdeltaSisterAreasFile);
        close
    end
         
    %% BIN: times After Last Division (ALD) vs sister area difference (2.0)%%
    
    if ~exist(BINtime2deathALDVSdeltaSisterAreasFile,'file')
        
        % removing nan rows
        keepTF = all([~isnan(plotDeltaFirstAreasDEL)  ~isnan(onlyDELsisterLifeSpan)],2);
        plotDeltaFirstAreasDELcrop = plotDeltaFirstAreasDEL(keepTF);
        onlyDELsisterLifeSpanCrop = onlyDELsisterLifeSpan(keepTF);
        
        binVec = [-1 0.1 1];
        [~, nCellsDEL] = BinPlot(plotDeltaFirstAreasDELcrop, onlyDELsisterLifeSpanCrop, binVec, black,'std');  
        
        
        ylabel('delamination time ALD (h)')
        xlabel('sister area difference')
        title(['Time to delamination vs sister area difference (nCells = ' num2str(nCellsDEL) ')'],'FontWeight','bold','FontSize',12)
        
        print(printFormat, printResolution, BINtime2deathALDVSdeltaSisterAreasFile);
        close
    end
    
    %% COR time to delamination vs mean cell apical size (2.0)
    
    if ~exist(time2deathVSmeanAreasCORfile,'file')
        
        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);
        
        colorDelaminationExt = [light_grey ; colorDelamination]; % adding 0th div color
        
        for nDiv = 0:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end

            nDivDeltaTimesDEL = plotDeltaTimesDEL(nthDivRoundTF);
            nDivMeanDELareas = plotMeanDelaminatingAreas(nthDivRoundTF);
            
            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nDivMeanDELareas)); % 2.2
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);
            
            scatter(nDivMeanDELareas, nDivDeltaTimesDEL,10, colorDelaminationExt(nDiv+1,:),'filled')
            box on 
            hold on
        end
        
        axis([0 40 0 16])
        
        if nDivThreshold == 3
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2) (' num2str(nCellsDivRoundsDEL(3)) ')'],['nDel(3+) (' num2str(nCellsDivRoundsDEL(4)) ')'],'Location','Best');
        elseif nDivThreshold == 2
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2+) (' num2str(nCellsDivRoundsDEL(3)) ')'],'Location','Best');
        end
        
        
        ylabel('time to delamination (h)')
        xlabel('mean areas ({\mu}m^2)')
        title(['Time to delamination vs mean area ([' num2str(averagingTimeRangeDEL) '] h before)'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, time2deathVSmeanAreasCORfile);
        close
    end
      
    %% BIN time to delamination vs mean cell apical size (2.0)
    
    if ~exist(BINtime2deathVSmeanAreasCORfile,'file')
        
        binVec = [0 5 35];
        [~, nCellsDEL] = BinPlot(plotMeanDelaminatingAreas, plotDeltaTimesDEL, binVec, black,'std');                

        ylabel('time to delamination (h)')
        xlabel('mean areas ({\mu}m^2)')
        title(['Time to delamination vs mean area ([' num2str(averagingTimeRangeDEL) '] h before, nCells = ' num2str(nCellsDEL) ')'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, BINtime2deathVSmeanAreasCORfile);
        close
    end
    
    %% BIN time to delamination vs mean cell apical size DIV SPLIT (2.0)
    
    if ~exist(BINtime2deathVSmeanAreasCORfileSPLIT,'file')
        
        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);
        
        colorDelaminationExt = [light_grey ; colorDelamination]; % adding 0th div color
        binVec = [0 5 35];
        
        for nDiv = 0:nDivThreshold
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end

            nDivDeltaTimesDEL = plotDeltaTimesDEL(nthDivRoundTF);
            nDivMeanDELareas = plotMeanDelaminatingAreas(nthDivRoundTF);
            
            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nDivMeanDELareas));
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);
            
            [~, nCellsDEL] = BinPlot(nDivMeanDELareas, nDivDeltaTimesDEL, binVec, colorDelaminationExt(nDiv+1,:),'');       
%             scatter(nDivMeanDELAreas, nDivDeltaTimesDEL,10, colorDelaminationExt(nDiv+1,:),'filled')
            box on 
            hold on
        end
        
        if nDivThreshold == 3
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2) (' num2str(nCellsDivRoundsDEL(3)) ')'],['nDel(3+) (' num2str(nCellsDivRoundsDEL(4)) ')'],'Location','Best');
        elseif nDivThreshold == 2
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2+) (' num2str(nCellsDivRoundsDEL(3)) ')'],'Location','Best');
        end
            

        ylabel('time to delamination (h)')
        xlabel('mean areas ({\mu}m^2)')
        title(['Time to delamination vs mean area ([' num2str(averagingTimeRangeDEL) '] h before)'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, BINtime2deathVSmeanAreasCORfileSPLIT);
        close
    end
    
    %% PDF: Delamination Mean Areas DIV SPLIT (2.1) %%

    if ~exist(PDFdelaminationMeanAreasFile,'file')
        
        xRange = [0 40];
        yMax = 0.15;
        nPoints = 25; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);
        
        [hAll,~,Yplot,aUCplot] = PlotPDF(plotMeanDelaminatingAreas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(hAll,'Color',black)
        hold on
        
        YplotOLD = zeros(size(Yplot));
        for nDiv = 0:nDivThreshold % **STARTS AT 0**
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end

            nthDivMeanDelaminatingAreas = plotMeanDelaminatingAreas(nthDivRoundTF);
            nthDivMeanDelaminatingAreasMean = nanmean(nthDivMeanDelaminatingAreas);
            
            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nthDivMeanDelaminatingAreas)); % 2.2
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);
            
%             nthDivRoundDeltaTimesDEL = plotDeltaTimesDEL(nthDivRoundTF);
%             nthDivRoundDeltaTimesDELmean = nanmean(nthDivRoundDeltaTimesDEL);
            
            nthDivColor = min(nDiv+1,nDivColorMax);
            
            [~,X,Y,aUC] = PlotPDF(nthDivMeanDelaminatingAreas,-nPoints,nSmooth,nRounds,xRange);
            Y = Y*aUC/aUCplot;
            Yplot = YplotOLD + Y;
            CurveFill(X,YplotOLD,Yplot,colorDivision(nthDivColor,:),0.4);
            h = plot(X,Yplot);
            set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2);
            hold on
            
            line([nthDivMeanDelaminatingAreasMean nthDivMeanDelaminatingAreasMean], [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
            
            eval(['h' num2str(nDiv) '= h;' ])
            YplotOLD = Yplot;
        end
        % replots black line
        h = PlotPDF(plotMeanDelaminatingAreas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',black)
        
        %%% Setting legend for specified curves
        if nDivThreshold == 3
            legend([h0 h1 h2 h3 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv = 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['nDiv \geq 3 (' num2str(nCellsDivRoundsDEL(4)) ')'], ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        elseif nDivThreshold == 2
            legend([h0 h1 h2 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        end
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('mean area ({\mu}m^2)')
        title(['Distributions of DEL cells mean areas ([' num2str(averagingTimeRangeDEL) '] h before)'],'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, PDFdelaminationMeanAreasFile);
        close
    end
     
    %% TIME plot: Mean PSIarea DEL  (2.2) %%
        
        if ~exist(TIMEmeanPSIareasFileDEL,'file')
            
            % applying cut off
            timeBeforeDELflipCut = timeBeforeDELflip(1:framesBeforeDELcutOff);
            plotDelaminatingPSIareasSyncFlipCut = plotDelaminatingPSIareasSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDELCut= - fliplr(timeBeforeDELflipCut')';
            plotDelaminatingPSIareasSyncCut = fliplr(plotDelaminatingPSIareasSyncFlipCut);
            
            % global
            keepTF = any(~isnan(plotDelaminatingPSIareasSyncCut),2);
%             keepTF = true(nDelCells,1);         % keeping all DEL cells as they've been already sorted
%             keepTF = all([~plotDividingANs2excludeTF cellsWithSomeHistoryLeftTF],2);
            plotDelPSIareasSyncCutKept = plotDelaminatingPSIareasSyncCut(keepTF,:); % filtering (2.0)
            plotDelPSIareasMean = nanmean(plotDelPSIareasSyncCutKept,1)';
            plotDelPSIareasSTD = nanstd(plotDelPSIareasSyncCutKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            CurveFill(timeBeforeDELCut, plotDelPSIareasMean-plotDelPSIareasSTD, plotDelPSIareasMean+plotDelPSIareasSTD,black,0.8);
            h0 = plot(timeBeforeDELCut, plotDelPSIareasMean);
            set(h0,'Color',black,'LineWidth',2)
            hold on
            
            line([timeBeforeDELCut(1) timeBeforeDELCut(end)], [1 1],'Color',blue,'LineStyle','--');
            
            axis([timeBeforeDELCut(1) timeBeforeDELCut(end) 0 1.5]);
           
            %%% Setting legend for specified curves
            legend(h0, ['nDelTot (' num2str(sum(keepTF)) ')'],'Location','Best');
            
            xlabel('time before delamination (h)')
            title('<\psi(a)>_{cells} over time','FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanPSIareasFileDEL);
            close
        end
        
    %% TIME plot: Mean bulkSignal DEL  (2.5) %%
        
        if ~exist(TIMEmeanBulkSignalFileDEL,'file') && bulkSignalProcessing
            
            % applying cut off
            timeBeforeDELflipCut = timeBeforeDELflip(1:framesBeforeDELcutOff);
            plotDelaminatingBulkSignalSyncFlipCut = plotDelaminatingBulkSignalSyncFlip(:,1:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDELCut= - fliplr(timeBeforeDELflipCut')';
            plotDelaminatingBulkSignalSyncCut = fliplr(plotDelaminatingBulkSignalSyncFlipCut);
            
            % global
            keepTF = any(~isnan(plotDelaminatingBulkSignalSyncCut),2);
            plotKept = plotDelaminatingBulkSignalSyncCut(keepTF,:); % filtering (2.0)
            plotMean = nanmean(plotKept,1)';
            plotSTD = nanstd(plotKept,1,1)'; % flag 1 renomalizes by n (not n-1)
            
            % plotting every single cell separately
            plot(timeBeforeDELCut,plotKept)
            axis([timeBeforeDELCut(1) timeBeforeDELCut(end) 0 260]);
            xlabel('time before delamination (h)')
            ylabel([bulkSignalName ' intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEallBulkSignalFileDEL);
            close
                
            CurveFill(timeBeforeDELCut, plotMean-plotSTD, plotMean+plotSTD,black,0.8);
            h0 = plot(timeBeforeDELCut, plotMean);
            set(h0,'Color',black,'LineWidth',2)
            hold on
            
            line([timeBeforeDELCut(1) timeBeforeDELCut(end)], [1 1],'Color',blue,'LineStyle','--');
            
            xlim([timeBeforeDELCut(1) timeBeforeDELCut(end)]);
  
            %%% Setting legend for specified curves
            legend(h0, ['nDelTot (' num2str(sum(keepTF)) ')'],'Location','Best');
            
            xlabel('time before delamination (h)')
            ylabel([bulkSignalName ' mean intensity'])
            title([bulkSignalName ' over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanBulkSignalFileDEL);
            close
        end
        
     %% TIME plot: Mean PSIbulkSignal DEL  (2.7) %%
        
        if ~exist(TIMEmeanPSIbulkSignalsFileDEL,'file') && bulkSignalProcessing
            
            % applying cut off
            % NB: STARTING AT INDEX 2 TO AVOID THE NaN VALUE !!
            timeBeforeDELflipCut = timeBeforeDELflip(2:framesBeforeDELcutOff);
            plotDelaminatingPSIbulkSignalsSyncFlipCut = plotDelaminatingPSIbulkSignalsSyncFlip(:,2:framesBeforeDELcutOff);
            
            % Unflipping
            timeBeforeDELCut = - fliplr(timeBeforeDELflipCut')';
            plotDelaminatingPSIbulkSignalsSyncCut = fliplr(plotDelaminatingPSIbulkSignalsSyncFlipCut);
            
            % global
            keepTF = any(~isnan(plotDelaminatingPSIbulkSignalsSyncCut),2);
            plotDelPSIbulkSignalsSyncCutKept = plotDelaminatingPSIbulkSignalsSyncCut(keepTF,:); % filtering (2.0)
            plotDelPSIbulkSignalsMean = nanmean(plotDelPSIbulkSignalsSyncCutKept,1)';
            plotDelPSIbulkSignalsSTD = nanstd(plotDelPSIbulkSignalsSyncCutKept,1,1)'; % flag 1 renomalizes by n (not n-1)
                
            CurveFill(timeBeforeDELCut, plotDelPSIbulkSignalsMean-plotDelPSIbulkSignalsSTD, plotDelPSIbulkSignalsMean+plotDelPSIbulkSignalsSTD,black,0.8);
            h0 = plot(timeBeforeDELCut, plotDelPSIbulkSignalsMean);
            set(h0,'Color',black,'LineWidth',2)
            hold on
            
            line([timeBeforeDELCut(1) timeBeforeDELCut(end)], [1 1],'Color',blue,'LineStyle','--');
            
            axis([timeBeforeDELCut(1) 0 0 2]); % 2.7
%             axis([timeBeforeDELCut(1) timeBeforeDELCut(end) 0 1.5]);
           
            %%% Setting legend for specified curves
            legend(h0, ['nDelTot (' num2str(sum(keepTF)) ')'],'Location','Best');
            
            xlabel('time before delamination (h)')
            title(['<\psi(' bulkSignalName ')>_{cells} over time'],'FontWeight','bold','FontSize',12)
            print(printFormat, printResolution, TIMEmeanPSIbulkSignalsFileDEL);
            close
        end
           
    %% COR plot: <Psi(a)>_time vs <a>_time DEL  (2.2) %%
        
    if ~exist(CORmeanPsiAreasVsAreasDELfile,'file')

        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);

        colorDelaminationExt = [light_grey ; colorDelamination]; % adding 0th div color

        for nDiv = 0:nDivThreshold

            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end

            nDivMeanDELareas = plotMeanDelaminatingAreas(nthDivRoundTF);
            nDivMeanDELPSIareas = plotMeanDelaminatingPSIareas(nthDivRoundTF);

            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nDivMeanDELareas));
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);

            scatter(nDivMeanDELareas, nDivMeanDELPSIareas,10, colorDelaminationExt(nDiv+1,:),'filled')
            box on
            hold on
        end
        
        % Linear fit to ALL data points
        Xs = RemoveNaNs(plotMeanDelaminatingAreas);
        Ys = RemoveNaNs(plotMeanDelaminatingPSIareas);
        polOut = mmpolyfit(Xs, Ys, 1); % polOut = [a b] corresponding to y = a*x + b;
        R2 = R2_value(Xs, Ys, polOut,[]);
        lineXs = [min(Xs) max(Xs)];
        lineYs = polOut(1)*lineXs + polOut(2);
        line(lineXs,lineYs,'Color',black,'LineStyle','-')
        

        axis([0 40 0 3])

        if nDivThreshold == 3
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2) (' num2str(nCellsDivRoundsDEL(3)) ')'],['nDel(3+) (' num2str(nCellsDivRoundsDEL(4)) ')'],'Location','Best');
        elseif nDivThreshold == 2
            legend(['nDel(0) (' num2str(nCellsDivRoundsDEL(1)) ')'],['nDel(1) (' num2str(nCellsDivRoundsDEL(2)) ')'],...
                ['nDel(2+) (' num2str(nCellsDivRoundsDEL(3)) ')'],'Location','Best');
        end


        ylabel('<\psi(a)>_{time}')
        xlabel('<a>_{time} ({\mu}m^2)')
        title([' <\psi(areas)>_{time} vs <areas>_{time} ([' num2str(averagingTimeRangeDEL) '] h before, R^2 = ' num2str(R2,2) ')'],...
            'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, CORmeanPsiAreasVsAreasDELfile);
        close
    end
    
    %% PDF: Delamination <Psi(a)>_time DIV SPLIT (2.2) %%

    if ~exist(PDFdelaminationMeanPSIareasFile,'file')
        
        xRange = [0 2];
        yMax = 2;
        nPoints = 25; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        nCellsDivRoundsDEL = zeros(nDivThreshold+1,1);
        
        [hAll,~,Yplot,aUCplot] = PlotPDF(plotMeanDelaminatingPSIareas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(hAll,'Color',black)
        hold on
        
        YplotOLD = zeros(size(Yplot));
        for nDiv = 0:nDivThreshold % **STARTS AT 0**
            
            if nDiv == nDivThreshold
                nthDivRoundTF = plotnDivRoundsDEL >= nDiv; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            else
                nthDivRoundTF = plotnDivRoundsDEL == nDiv;
            end
            
            nthDivMeanDelaminatingPSIareas = plotMeanDelaminatingPSIareas(nthDivRoundTF);
            nthDivMeanDelaminatingPSIareasMean = nanmean(nthDivMeanDelaminatingPSIareas);
            
            nCellsDivRoundsDEL(nDiv+1) = sum(~isnan(nthDivMeanDelaminatingPSIareas)); % 2.2
%             nCellsDivRoundsDEL(nDiv+1) = sum(nthDivRoundTF);
 
            nthDivColor = min(nDiv+1,nDivColorMax);
            
            [~,X,Y,aUC] = PlotPDF(nthDivMeanDelaminatingPSIareas,-nPoints,nSmooth,nRounds,xRange);
            Y = Y*aUC/aUCplot;
            Yplot = YplotOLD + Y;
            CurveFill(X,YplotOLD,Yplot,colorDivision(nthDivColor,:),0.4);
            h = plot(X,Yplot);
            set(h,'Color',colorDivision(nthDivColor,:),'LineWidth',2);
            hold on
            
            line([nthDivMeanDelaminatingPSIareasMean nthDivMeanDelaminatingPSIareasMean], [0 yMax],'Color',colorDivision(nthDivColor,:),'LineStyle','--');
            
            eval(['h' num2str(nDiv) '= h;' ])
            YplotOLD = Yplot;
        end
        % replots black line
        h = PlotPDF(plotMeanDelaminatingPSIareas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',black)
        
        line([1 1], [0 yMax],'Color',black,'LineStyle','-','LineWidth',0.25);
        
        %%% Setting legend for specified curves
        if nDivThreshold == 3
            legend([h0 h1 h2 h3 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv = 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['nDiv \geq 3 (' num2str(nCellsDivRoundsDEL(4)) ')'], ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        elseif nDivThreshold == 2
            legend([h0 h1 h2 hAll], ['nDiv = 0 (' num2str(nCellsDivRoundsDEL(1)) ')'], ['nDiv = 1 (' num2str(nCellsDivRoundsDEL(2)) ')'], ['nDiv \geq 2 (' num2str(nCellsDivRoundsDEL(3)) ')'],...
                ['all (' num2str(sum(nCellsDivRoundsDEL)) ')']);
        end
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('<\psi(areas)>_{time}')
        title(['<\psi(areas)>_{time}([' num2str(averagingTimeRangeDEL) '] h before)'],'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, PDFdelaminationMeanPSIareasFile);
        close
    end
    
    %% PDF: Delamination Mean Areas PSI SPLIT (<1 vs >1) (2.2) %%

    if ~exist(PDFdelaminationMeanAreasPsiSortedFile,'file')
        
        xRange = [0 40];
        yMax = 0.15;
        nPoints = 25; % 1 point every 13/nPoints %: 52-> every 15min, 26-> every 30 min
        nSmooth = 0;
        nRounds = 1;
        
        colorPsi = [light_purple; mid_purple; dark_purple];
        nCellsPsiSortedDEL = zeros(size(colorPsi,1),1);
        
        [hAll,~,Yplot,aUCplot] = PlotPDF(plotMeanDelaminatingAreas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(hAll,'Color',black)
        hold on
        
        YplotOLD = zeros(size(Yplot));
        for nPsi = 1:3
            
            if nPsi == 1
                psiSortedTF = plotMeanDelaminatingPSIareas > 1; % lumps together all division rounds having "nDivThreshold" and more (2.0)
            elseif nPsi == 2
                psiSortedTF = plotMeanDelaminatingPSIareas <= 1 & plotMeanDelaminatingPSIareas >= 0.8;
            else
                psiSortedTF = plotMeanDelaminatingPSIareas < 0.8;
            end
            % NB: NaN rows do NOT contribute to "psiSortedTF" (give 0)

            nCellsPsiSortedDEL(nPsi) = sum(psiSortedTF);
            
            
            psiSortedMeanDelaminatingAreas = plotMeanDelaminatingAreas(psiSortedTF);
            psiSortedMeanDelaminatingAreasMean = nanmean(psiSortedMeanDelaminatingAreas); 
            
            nthDivColor = min(nPsi+1,nDivColorMax);
            
            [~,X,Y,aUC] = PlotPDF(psiSortedMeanDelaminatingAreas,-nPoints,nSmooth,nRounds,xRange);
            Y = Y*aUC/aUCplot;
            Yplot = YplotOLD + Y;
            CurveFill(X,YplotOLD,Yplot,colorPsi(nPsi,:),0.4);
            h = plot(X,Yplot);
            set(h,'Color',colorPsi(nPsi,:),'LineWidth',2);
            hold on
            
            line([psiSortedMeanDelaminatingAreasMean psiSortedMeanDelaminatingAreasMean], [0 yMax],'Color',colorPsi(nPsi,:),'LineStyle','--');
            
            eval(['h' num2str(nPsi) '= h;' ])
            YplotOLD = Yplot;
        end
        % replots black line
        h = PlotPDF(plotMeanDelaminatingAreas,nPoints,nSmooth,nRounds,xRange); % smoothing over nSmooth points, nRounds times
        set(h,'Color',black)
        
        legend([h1 h2 h3 hAll], ['<\psi(a)>_t > 1 (' num2str(nCellsPsiSortedDEL(1)) ')'], ['<\psi(a)>_t \in [0.8 1] (' num2str(nCellsPsiSortedDEL(2)) ')'],...
            ['<\psi(a)>_t < 0.8 (' num2str(nCellsPsiSortedDEL(3)) ')'],['all (' num2str(sum(nCellsPsiSortedDEL)) ')']);
        
        axis([xRange(1) xRange(2) 0 yMax]);
        xlabel('mean area ({\mu}m^2)')
        title(['Distributions of <a>_t for DEL cells ([' num2str(averagingTimeRangeDEL) '] h before)'],'FontWeight','bold','FontSize',12)
        print(printFormat, printResolution, PDFdelaminationMeanAreasPsiSortedFile);
        close
    end
    
    %% HIST: % of delaminating daughters (only one or both) for each div round (2.3) %%
    
    
    % Use function "bar(y,'stacked')", see matlab help
    
    
end
 
disp('---------------------------------------------------------------------------------');


%% History %%

% IMPROVEMENTS:

% 20/10/2019: 
% - fixed bug when NOT using signal processing (by adding "&& bulkSignalProcessing" in severa "if" statements)

% 06/05/2019: 2.8
% - fixed bug occurring when bulkSignalProcessing = false
% - fixed bug when "plotLastTimesDel" was empty

% 27/02/2019: 2.7
% - added many plots processing cell cytoplasmic signal (referred to as
% "bulk" signal). This signal must be listed in CTA section of SAP_parameters.

% 25/02/2019: 2.6
% - added "TIMEmeanBulkSignalFileDIVsplit", "TIMEmeanBulkSignalFileDIVdel", and
% "TIMEmeanBulkSignalFileDIVsplitDELsplit" plots.

% 20/02/2019: 2.5
% - added possibility to process cell cytoplasmic signal => plot of
% "TIMEmeanBulkSignalFileDEL" and "TIMEmeanBulkSignalFileDIV" images

% 04/11/2018: 2.4
% - minor changes 
% - will now treat clone tracking case like ROI with single compartment by
% gathering all clone parts together.

% 16/10/2018: 2.3
% - fixed issue when max(gridSize) == 1 (roi or clone mode):
% "gridFrameFolder" was not defined

% 11/10/2018: 2.2
% - added calculation of "PsiAreas" (and a "Raw" version where delaminating
% cells are NOT excluded from the neighbors) and storage of
% "allDelaminatingPSIareasRaw" and "allDelaminatingPSIareas" in the backup.

% 09/10/2018: 2.1
% - added "PDF: Delamination Mean Areas DIV SPLIT" plot

% 01/10/2018: 2.0
% - major changes and addition of many plots
% - fixed bug when NOT running in grid mode

% 13-18/07/2018: 1.21
% - now can create "grid maps" of cell cycle duration (and 1st time of
% division) using function "MakeGridMap" at frame "gridMapFrame" defined in
% "SAP_parameters".

% 28/06/2018: 1.20
% - fixed bug where "coreDelaminatingLastRNsTF" was not loaded

% 07/05/2018: 1.19
% - updated number of arguments of "ComparePolarPlots"
% - fixed issue with "plotDividingANs2excludeTF" being wrongly redefined
% at each plot, hence messing up following plots.

% 27/03/2018: 1.18
% - fixed mistake where dividing cells about to divide for the first time
% were included in "allDividingANs2excludeTF" while they should only be
% excluded when relevant.
% - renamed "dividingANs2excludeTF" to "allDividingANs2excludeTF"
% - now, in GRID/CLONE MODE, ONLY saves the subsets of cells involved
% 'ROIdividingANsTF','ROIdelaminatingANsTF'.
% - stopped saving "firstDivRounds" that gets recalculated in following
% programs.

% 23/03/2018: 1.17

% 16/03/2018: 1.16
% - now also saving 'plotFirstDivRoundsTF','allDividingANs2excludeTF' in backups
% to be able to separate 1st division round.
% - now ONLY saving 'ROIdividingANsTF' and 'ROIdelaminatingANsTF' to be
% able to crop "allDividingANs" and "allDelaminatingANs" lists to cells in
% the tracked subregion (clone OR single box grid)

% 14/03/2018: 1.15
% - now saves images in a "Frames" folder
% - IN CONSTRUCTION: now can restrict the analysis to a clone OR a single
% compartment grid.
% - accordingly  replaced all "all" prefixes by "plot" prefixes after
% creation of backup, from the "Defining quantities for plot" onwards.

% 13/03/2018: 1.14
% - now directly determining "nCells0" using function "GetnCells0".

% 31/01/2018: 1.13
% - stopped saving 'allDividingIanisotropies','allDividingIorientations',
% 'allDividingVpolarities', 'allDividingVorientations'
% - edited txt parameter file.

% 26-28/01/2018: 1.12
% - for border, FL & coalesced RNs exclusion, now using location indices
% "allDividing/Delaminating/OtherRNsFilterLoc" rather than huge TF tables.
% - look up "1.12" for the many other changes made

% 26/01/2018: 1.11
% - changes to make it compatible with SIA 3.3
% - added maps of deltaAnglesDivTCJ (abs and raw) and map deltaAnglesDivCoM (raw)

% 23/01/2018: 1.10 **COMPATIBLE WITH SIA 2.21**
% - now splits Cell Cycle duration between rounds 1-2 and 2-3

% 15/01/2018: 1.9 **COMPATIBLE WITH SIA 2.21**
% - thorough use of "SyncCellHistories" to make Sync version of cell
% history tables
% - removed all "overwriteGraphs" (just delete the images to replot)
% - look up "1.9" for the many other changes made

% 12/01/2018: 1.8
% - look up "1.8" for changes made
% - works with "MakePointMap" version 1.0

% 09/01/2018: 1.7
% - added part reproducing data on prediction of ThetaDiv based on ThetaShape or ThetaTCJ (Figure 3 of Nature TCJ paper)
% - save txt file with version number
% - filter "allDelaminatingRNs" and "allDividingRNs" with corresponding filters
% - now replaces RNs with SIA quantity values (areas, Is, Vs...) using function "RNs2RFeatures"
% - renamed all "Reset" quantities into "Sync"
% - look up "1.7" for other changes made

% 21/11/2017: 1.6
% - evolution of area differences after division for all dividing cells and delaminating cells
% - look up "1.6" for other changes made

% 13/11/2017: 1.5
% - added plots of cell cycle durations (raw and filtered for 
% - added division & delamination vs time PDF plots
% - adjustments for compatibility with CTD 2.9

% 09/11/2017: 1.4
% - sister area difference for delaminating cells
% - broke down sister area difference pdf plot according to division round
% - improved all plots

% 07/11/2017: 1.3
% - added plot of map, PDF and time evolution of the difference between sister areas

% 06/11/2017: 1.2
% - adjustments to match changes made in CTD 2.4
% - added plot of map, PDF and time evolution of division angle difference (centroid vs junction)
% - moved definition of tMin, tMax, tRange and nTones to AIA_parameters

% 25/10/2017: 1.1
% - added "allCentroidAngles"

% 25/10/2017: creation
