% AverageOverTime
%
% From backups associated to average in space over a specific grid (STP, AOS, TA), this will carry out an additional
% average over time. Backups generated inside the grid folder.
%
version = '4.12';
% Boris Guirao


%% Defines path to existing Grid folder and creates Average folder %%

%%% Checks gridType value (2.0)
if isempty(gridType)
    fprintf('\nAOT ERROR: parameter "gridType" in "SAP_parameters" must either by "E" or "L"!!\n')
    disp('---------------------------------------------------------------------------------------------------------------');
    return
end

%%% Reformat "timeStart/Stop" from HH:MM to HHhMM for folder naming (1.13):
timeStart = regexprep(timeStart, ':', 'h');
timeStop = regexprep(timeStop, ':', 'h');

%%% Display info (1.5, mod 1.16, 1.21)
disp(' '); disp(' ');
disp(['AOT ' version  ': ' averageOver ' averaging "' Animal '" between ' timeStart ' and ' timeStop ' with ' ...
    num2str(timeWidth) 'h width and ' num2str(timeOverlap) ' overlap'  ]);
disp('---------------------------------------------------------------------------------------------------------------');

%%% Loading GridDef backup from CPT backup (3.0)
GRID_DEF = load(pathGridDefFile);
GRID_DEF.Color = gridColor; % overridding saved value with the one from SAP_parameters!
nx = GRID_DEF.Size(2);
ny = GRID_DEF.Size(1);
nBoxes = nx*ny;

if ~cloneTracking
    xywh = GRID_DEF.xywh;
end

%%% Defines "gridFolder", "Average folder" (1.9, 3.0):
pPathFolder = eval(['pathFolder' averageOver]); % program "pathFolder"
gridFolder = [pPathFolder filesep gridSpecs];

gridBackupFolder = [gridFolder filesep 'Backups'];
gridBackupRootFilename = eval(['filename' averageOver]); % 1.9

% defines gridFolder_AOT to store common backup (1.28) AND "alltime" backups (3.0)
gridFolderAOT = [pathFolderAOT filesep gridSpecs]; % 1.28


%% Defines list of structure/tensors to stack according to program to average (mod 1.26)%%

fprintf(['Determining "stackList' averageOver '" based on fields listed in ' averageOver ' backup files...'])

if ~strcmp(averageOver,'VM')            % NOT VM case (4.2)
    firstBackupFound = 0;             % 4.12
    for n = startFrame:finalFrame
        fullPath = [gridBackupFolder filesep gridBackupRootFilename '_' num2str(n,digitsFormat) '.mat']; % 1.9
        if exist(fullPath,'file')                                % skipping frames without backups because they could not be processed (1.9)
            pGRID = load(fullPath);     % 3.0
            firstBackupFound = n;    % 4.12
            break % stops when one backup was found
%         else
%             disp(' ');disp(['AOT ERROR: backup ' fullPath ' could NOT be found!!']); % 1.28
%             disp('---------------------------------------------------------------------------------------------------------------');
%             return
        end
    end
    % if NO backup was found, skipping averaging (4.12):
    if firstBackupFound == 0
        disp(' ');disp(['AOT ERROR: NO "' averageOver '" backup was found => Skipped "' averageOver '" averaging!']); % 1.28
        disp('---------------------------------------------------------------------------------------------------------------');
        return
    end
    pGRIDfields = fieldnames(pGRID);
    
else % VM case (4.2)
    
    gridSpecsVM = gridSpecs;
    if strcmp(gridType,'L') && ~strcmp(modeVM,'CT') && ~cloneTracking
        gridSpecsVM = substr(gridSpecsVM, 0, 1, 'E');             % replaces "L" by "E"
        gridSpecsVM = substr(gridSpecsVM, 0, -6);              % removes last characters specifying grid time hAPF when using L grid
    end
    gridFolderAOT = [pathFolderAOT filesep gridSpecsVM];
    alltimeBackupFileVM = [gridFolderAOT filesep 'alltime_' gridBackupRootFilename '.mat'];
    
    if exist(alltimeBackupFileVM,'file') % 4.2
        if strcmp(modeVM, 'PIV') % 4.10
            pGRIDfields = {'AreaRatios';'EpsilonPIV';'OmegaPIV'; 'UPIV';}; % 4.10
        else
            pGRIDfields = {'AreaRatios';'EpsilonCT';'OmegaCT'; 'UCT';}; % 4.10
        end
%       pGRIDfields = {'AreaRatios';'EpsilonVM';'OmegaVM'; 'UVM';}; % added "VM" suffix (4.9)
    else
        disp(' ');disp(['AOT ERROR: VM alltime backup ' alltimeBackupFileVM ' could NOT be found!!']);
        disp('---------------------------------------------------------------------------------------------------------------');
        return
    end
end

% fields to exclude from the stack:
fields2removeTA = {'LINKS';'HLC';'HLCold';'LijPlots';'Wijs';'maskTF';'LiokoPlots';'Wiokos'};    % mod 3.5
fields2removeSM = {'CAs' ; 'CEs' ; 'CXYs';'ShujiRNs';'nShujiRNs'};                              % list update (3.4)
fields2removeAOS = {'BoxCellArea'; 'CellU'; 'ResetXYs'; 'ContourDistance' ; 'PatchRadius' };    % excluding "BoxCellArea" because pointless to average (3.5)

%%% Adds extra fields to REMOVE related to "A_signals" (AOS) (2.3, mod 2.4)
if strcmp(averageOver,'AOS')
    nRaw = length(filenameRaw);
    for r = 1:nRaw
        fields2removeAOS = [fields2removeAOS ; ['A' signalName{r}]];  % removing "Acad", "Amyo"... quantities from averaging (mod 2.8)
    end
end             

fields2remove = [ fields2removeAOS ; fields2removeTA ; fields2removeSM]; % mod 1.28

pGRIDfields = setdiff(pGRIDfields, fields2remove);         
eval(['stackList' averageOver ' = pGRIDfields;']);

fprintf('Done\n')
fprintf(['Here are the fields listed in "stackList' averageOver '" that will be stacked over time:\n\n']);
eval(['disp(stackList' averageOver ')']);


%% Defines all plot parameters based on values used in native program (AOS, SM...) (1.4)%%

eval(['QnameList = stackList' averageOver ';']); % 1.23

nQ = length(QnameList);

% Loads specific possible quantities, colors and units (1.4, mod 1.22):
AllQsColorsUnits;
nQtoduplicate = eval(['numel(allQs' averageOver ')']);
eval(['allQs = allQs' averageOver ';']);
eval(['allColors = allColors' averageOver ';']);
eval(['allUnits = allUnits' averageOver ';']);
eval(['allScaleRatios = scaleRatio' averageOver ';']);
eval(['allScaleBarLengths = scaleBarLength' averageOver ';']);
eval(['allKillMeanTraces = killMeanTrace' averageOver ';']);

% adding "modVM" suffix ("PIV" or "CT") to VM quantities (4.10)
if strcmp(averageOver, 'VM')
    for q = 1:length(allQs)
        allQs{q} = [allQs{q} modeVM]; %#ok<SAGROW>
    end
end

% Repeat values when a single value was provided (1.13, 1.22):
Ps = {'Units';'ScaleRatios';'ScaleBarLengths';'KillMeanTraces'};
nPs = length(Ps);
for p = 1:nPs
    Pname = Ps{p};
    P = eval(['all' Pname]); % 1.22
    if length(P)==1 && ~strcmp(Pname,'Colors')
        if iscell(P)
            newP = cell(nQtoduplicate,1); % made it a column cell (2.3)
            newPvalue = eval(['all' Pname '{1};']);         % value to repeat (1.20), 1.22
            newP(:) = num2cell(repmat(newPvalue,1,nQtoduplicate),1);   % 1.20
%             newP(:) = cellstr(repmat(newPvalue,nQ,1));      % use of "cellstr" (2.3)   
        else
            newP = zeros(nQtoduplicate,1);                 % made it a column vector (2.3)
            newP(:) = eval(['all' Pname ';']);  % 1.22
        end
        eval(['all' Pname '= newP;']); % 1.22
    end
end

% Gets list of things to PLOT in program section, defines printFormat/resolution (1.4)
eval(['QnamePlot = plotTensors' averageOver ';']); % 1.23
if any(strcmp(QnamePlot,'all'))
    QnamePlot = allQs;    % "all" case (1.13)
end

% removes tensors specified in "skipTensors_TA" (1.25, 4.8)
if  strcmp(averageOver,'TA') && ~isempty(skipTensorsTA) % 4.8
    % removes tensors to skip WITHOUT changing the order in "plotTensorsXXX" (4.8)
    keepTensorsTAloc = ~ismember(QnamePlot, skipTensorsTA); % 0s where tensors to skip
    QnamePlot = QnamePlot(keepTensorsTAloc);                
%     QnamePlot = setdiff(QnamePlot, skipTensorsTA);
end
nQplot = length(QnamePlot);


%% Builds "alltime" backup (mod 1.19, 4.1) %%

% Defines "alltimeBackupFile":
alltimeBackupFile = [gridFolderAOT filesep 'alltime_' gridBackupRootFilename '.mat'];  % using "gridFolder_AOT" instead of "gridFolder" (3.0)

% Checks existence of "alltime_backup" and defines "makeAlltimeBackup" accordingly (1.19):
makeAlltimeBackup = ~exist(alltimeBackupFile,'file');                                   % 1 if does NOT exist => will be generated

if makeAlltimeBackup
    
    fprintf(['Building ' averageOver ' "alltime" backup for "' Animal '"...\n'])        % added Animal (1.10)
    pause(1);
    
    mkdir(gridFolderAOT); % 3.0
    
    %%% Iteration over frames to build stacks for Qs listed in average_prog list
    virtualMissingFrames = [];                                                            % "MissingFrames" will list frames in [startFrame finalFrame] that could not be processed by native program (1.9)
    progressbar(['Building ' averageOver ' "alltime" backup for "' Animal '"...']) % added Animal (1.10)
    for n = startFrame:finalFrame
        fullPath = [gridBackupFolder filesep gridBackupRootFilename '_' num2str(n,digitsFormat) '.mat']; % 1.9
        if exist(fullPath,'file')                                                                               % skipping frames without backups because they could not be processed (1.9)
            pGRID = load(fullPath); % 3.0
        else
            virtualMissingFrames = [virtualMissingFrames n]; % 1.9
            disp(['Warning: backup "' fullPath '" was not found and was skipped.'])
            continue
        end
        
        % Iteration over Qs listed in QnameList (overhaul 4.1)
        for q = 1:nQ
            
            Qname = QnameList{q};
            
            if isfield(pGRID,Qname)
                
                Q = pGRID.(Qname);  % Q CAN ONLY BE A nD-matrix of scalars, vectors, or tensors (4.0)
                Qdepth = size(Q,3); % determines depth of Q
                
                if n == firstBackupFound % 4.12
                    if strcmp(Qname, 'AreaRatios')
                        Qstack = zeros(ny, nx, Qdepth, finalFrame);  % initializes Q 4D matrix with zeros
                    else
                        Qstack = NaN(ny, nx, Qdepth, finalFrame);    % initializes Q 4D matrix with NaNs
                    end
                    % Check added to avoid NaNs
                    % in animals with a startframe above 1 for area ratios which propagate to AOA/DBA afterwards and mess up calculations 
                else
                    eval(['Qstack = ' Qname 'Stack;']);         % loads
                end
                Qstack(:,:,:,n) = Q;
                eval([Qname 'Stack = Qstack;']); % updates stack of Q for each Q
            end
        end
        ProgRatio = (n+1-startFrame)/nFrames;       % 1.8
        progressbar(ProgRatio);                     % 1.8
    end
    
    %%% Storage in "alltimeGRID"
    alltimeGRID.startFrame = startFrame;                % 1.9
    alltimeGRID.finalFrame = finalFrame;                % 1.9
    alltimeGRID.MissingFrames = virtualMissingFrames;   % 1.10
    for q = 1:nQ
        Qname = QnameList{q};
        if isfield(pGRID,Qname)
            eval(['Qstack = ' Qname 'Stack;']);         % puts stack for quantity Qname in Qstack
            alltimeGRID.([Qname 'Stack']) = Qstack;     % storage in GRID
        end
    end
    
    %%% Correcting "AreaRatios" of "startFrame" in "AreaRatiosStack" in TA case (2.1):
    if strcmp(averageOver,'TA')
        alltimeGRID.AreaRatiosStack(:,:,startFrame) = zeros(ny,nx); %#ok<STRNU>
    end
    % NB: doing this because first TA backup was NOT meant for calculations and AreaRatios stored are irrelevant for calculation
    
    eval(['alltimeGRID_' averageOver '= alltimeGRID;']); % renames GRID before saving it

    %%% Saves program alltime backup in *AOT* grid folder
    save(alltimeBackupFile,'-struct', ['alltimeGRID_' averageOver]); % 3.0
    
    clear Qstack Q3D Q QXYs3D QXYs alltimeGRID pGRID; % clearing "alltimeGRID" (4.1)
    fprintf('Done.\n')
    pause(1);
else
    disp('"alltime_backup" was found and will be loaded.')
end


%% Converts "time" variables into frame numbers with "MakeFrameIntervals", defining "frame_intervals" (1.3, 3.0, 3.2)%%

%%% Assigning values for "time_start/stop" when left empty by user (1.9)
if exist(alltimeBackupFile,'file')              % 1.19, 3.2
    alltimeGRID = load(alltimeBackupFile);     % no substructure to load (3.0, 3.2)
    startFrame = alltimeGRID.startFrame;       % loads ACTUAL startFrame
    finalFrame = alltimeGRID.finalFrame;       % loads ACTUAL finalFrame
end

% COMMENTED  4.5
% % Shifts "frameStart" of 1 when averaging over dynamic quantities (TA,VM) (4.2)
% if (strcmp(averageOver,'TA') || strcmp(averageOver,'VM')) && frameStart == startFrame
%     frameStart = frameStart + 1;
%     interframeWidth = interframeWidth - 1;
% end
% % NB: for dynamic quantities calculated over INTERframes, the first
% % calculated quantities are between startFrame and startFrame+1

[frameMin, frameMax] = MakeFrameIntervals(frameStart, frameStop, interframeWidth, timeOverlap);
% NB: frameMin/Max can be 0 or even negative, they just correspond to "frameStart/Stop"

% Shifts "frameMin" of 1 when averaging over dynamic quantities (TA) (1.14, 4.1)
if (strcmp(averageOver,'TA') || strcmp(averageOver,'VM')) && ~noAverage               % mod 4.1, added VM case (4.2)
    frameMin = frameMin + 1;
end
% Exemple: average over 10 min movie starting at frame #7:
% - STATIC quantities (areas, stress...): average values over *3* frames 7(t=0),8(t=5 min),9(t=10 min)
% - DYNAMIC quantities (EG,ER...): average values over *2* INTERframes 8(t=0-5 min),9(t=5-10 min)
% NB: on maps will be specified average over "5-10" although it will actually be between "0-10"
%     More generally averages over static and dynamic quantities are done on n+1 frames and n INTERframes, respectively

frameIntervals = [frameMin frameMax];
frameIntervalCenters = mean(frameIntervals,2);       % Taking centers of intervals:
nSteps = size(frameIntervalCenters,1);                % ACTUAL nsteps


%% Supporting out-of-bounds (virtual) frames (2.0) %%

% putting back frameMin to 1 so it can correspond to a matrix:
deltaFrame = frameMin(1) - 1;                           % scalar to go from ACTUAL TO VIRTUAL
virtualFrameIntervals = frameIntervals - deltaFrame;    % starts at vframe = 1
virtualFrameMin = virtualFrameIntervals(1);             % should always be 1
virtualFrameMax = virtualFrameIntervals(end);

% looking for indices such that: vQstack(:,:,vQstart:vQend) = Qstack(:,:,Qstart:Qend)
% indices corresponding to 1st and last rows of Qstack matrices:
Qstart = max(frameMin(1), startFrame);      % no info below startFrame, and no relevant info below frameMin for the requested average
Qend = min(frameMax(end), finalFrame);      % no info beyond finalFrame, and no relevant info beyond frameMax for the requested average
% corresponding vQ indices
vQstart = Qstart - deltaFrame;
vQend = Qend - deltaFrame;
% NB: vQstart>0 since frameMin(1) - deltaFrame = 1;
% NB: vQstack has size "virtualFrameMax" in its last dimension relative to time/frame


%% Loading "alltime" backup and defining "WeightStack3D/WeightStack4D" (moved 3.2) %%

%%% Loading alltime backup (mod 3.0):
fprintf(['Loading ' averageOver ' "alltime" backup...'])
alltimeGRID = load(alltimeBackupFile);                                                     % 3.2

%%% Defining 3D/4D matrices of Weights based on AreaRatios AND RConds (1.14):
%-------------------------------------------------------------------------------------------------------------------
% NB: these will only be used to calculate weighted averages of quantities, the average AreaRatios being calculated separately
% NB: vWeightStack3D and vWeightStack4D only contains 0 < NUMBERS < 1
WeightStack3D = alltimeGRID.AreaRatiosStack;                  % loads area ratios for weights (3D matrix)
% Includes "RConds" in Weights when exists (1.14)
if isfield(alltimeGRID,'RCondsStack')
    WeightStack3D = WeightStack3D.*(alltimeGRID.RCondsStack); % Weights(ky,kx) = AreaRatios(ky,kx)*RConds(ky,kx) (1.14)
end
WeightStack3D = WeightStack3D.^2;                   % takes SQUARE to sharpen decrease at animal boundaries (1.14)
WeightStack4D = repmat(WeightStack3D,[1 1 4 1]);    % repeats weight matrix 4 times along 3rd dimension (4.1)
%-------------------------------------------------------------------------------------------------------------------
fprintf('Done\n')


%% Time & Cumulative plots in case of clone or L/R symmetry (3.2, 3.3) %%

if cloneTracking && matchingWTclone
    
    fprintf('Making plots of average clone cumulated over time...')
    
    dtH = dt/60;                                                                                % time interval IN HOURS
    cumulBackupFile = [gridFolderAOT filesep 'timePlots_' gridBackupRootFilename '.mat'];       % Defines "cumulBackupFile"
    
    % Quantities that will averaged over clone parts:
    Qs2averageOverCloneParts =  {'dnD','dnA','nCoreRNs', 'Rho','M','I','V','CDcad','CDmyo','S','SP','ST'};
    % quantities that will be SUMMED *OVER CLONE PARTS* NOT AVERAGED 
    Qs2sumOverCloneParts = {'dnD','dnA','nCoreRNs'}; % NB: if also listed in "Qs2averageOverCloneParts" => will override "Qs2average" for those Qs
%     Qs2sumOverCloneParts = {}; 
    
    % Quantities that should be cumulated over time:
%     Qs2cumulateOverTime =       {};                           % will ONLY process quantities listed here
%     Qs2cumulateOverTimeUnits =  {};
    Qs2cumulateOverTime =       {'dnD','dnA'};                  % will ONLY process quantities listed here
    Qs2cumulateOverTimeUnits =  {  '' ,  '' };
 
    
    % Iteration over Qs listed in QnameList:
    saveCumulBackup = false; % 3.4
    for q = 1:nQ
        
        Qname = [QnameList{q} 'Stack'];
        Qs2cumulateOTtf = ismember(Qs2cumulateOverTime, QnameList{q});
        Q2cumulIndex = find(Qs2cumulateOTtf);      
        Qs2averageOCPtf = ismember(Qs2averageOverCloneParts, QnameList{q}); % TO BE REMOVED
        Qs2sumOCPtf = ismember(Qs2sumOverCloneParts, QnameList{q}); % TO BE REMOVED
                
        if isfield(alltimeGRID, Qname)
            
            Qstack = alltimeGRID.(Qname);               % loading stack of quantity Q
            QstackDim = size(Qstack,3);                 % gets depth of Qstack (4.11)
%             QstackDim = length(size(Qstack));           % gets dimension of Qstack

            WeightStack4Dcum = repmat(WeightStack3D,[1 1 QstackDim 1]);    % repeats weight matrix 4 3rd dimension (4.11)
            
            if any(Qs2sumOCPtf) || any(Qs2averageOCPtf) %  Qname has to be in one list or the other ***TO BE REMOVED WHEN ALL QUANTITIES WILL BE SUPPORTED***
                
                if ~ismember(QnameList{q}, Qs2sumOverCloneParts)    % deformation for instance should NOT been summed between clone parts BUT AVERAGED
                                  
                    % Calculating *WEIGHTED MEAN* OVER CLONE PARTS (mo 4.1):
                    QW = Qstack.*WeightStack4Dcum;
                    Wsum = sum(WeightStack4Dcum, 1);   % sum over all clone parts, for a given clone (clone vs WTclone), at a given time
                    QWsum = nansum(QW,1);           % weighted sum
                    QWmean = QWsum./Wsum;           % weighted mean OVER CLONE PARTS (1st dimension)
                    Qout = QWmean;
                    
                    QtagClone = 'mean';         % string tag specifying whether CLONE parts were SUMMED OR AVERAGED
                else                            % Quantity listed in "sumNotAverage"
                    Qout = nansum(Qstack,1);    % takes the *SUM* OVER CLONE PARTS:
                    QtagClone = 'total';
                end 
                
                % Defining file name early to check its existence (moved up 3.4)
                QtagTime = '';              % string tag specifying whether values over TIME were SUMMED OR AVERAGED
                if any(Qs2cumulateOTtf)
                    QtagTime = 'Cumulative';
                end
                thisImageName = [QtagClone '.' QnameList{q} '.time.' QtagTime '.' Animal '.png'];
                thisFilename = [gridFolderAOT filesep  thisImageName];
                
                if ~exist(thisFilename,'file') % skips otherwise (3.4)
                    
                    saveCumulBackup = true; % 3.4
                    
                    % Removing NaNs
                    QoutNoNaN = Qout;
                    nanTF = isnan(Qout);
                    QoutNoNaN(nanTF) = 0;
                    
                    QplotRaw = QoutNoNaN;          % default Qplot: NO TIME CUMUL
%                     QtagTime = '';              % string tag specifying whether values over TIME were SUMMED OR AVERAGED
                    QtagUnits = ['(' GetQuantityInfo(QnameList{q},'units')  ')'];
                    
                    if any(Qs2cumulateOTtf)
                        
                        % Cumulated values
                        QTimeCumul = cumsum(QoutNoNaN, 4); % time always has 4th dimension (4.11)
%                         QTimeCumul = cumsum(QoutNoNaN, QstackDim);
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        QTimeCumul = QTimeCumul*dtH;              % rates must be re-multiplied by time interval duration dtH
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        
                        QplotRaw = QTimeCumul;
%                         QtagTime = 'Cumulative';
                        QtagUnits = ['(' Qs2cumulateOverTimeUnits{Q2cumulIndex} ')'];
                    end
                    
                    QplotRaw(nanTF) = NaN;         % putting back the NaNs
                    if QstackDim < 4
                         Qplot = squeeze(QplotRaw);
                         Qplot = Qplot';
%                         Qplot = squeeze(Qplot)';
                        % NB: 1st column = Clone; 2nd column = WT
                    else
                        Qplot = squeeze(QplotRaw);
                        QplotXX = squeeze(Qplot(:,1,:))';
                        QplotYX = squeeze(Qplot(:,2,:))';
                        QplotXY = squeeze(Qplot(:,3,:))';
                        QplotYY = squeeze(Qplot(:,4,:))';
                        
                        % Rather expressing matrix Q in Pauli matrix base:
                        QplotSigma0 = (QplotXX + QplotYY)/2; % iso part
                        QplotSigma3 = (QplotXX - QplotYY)/2; % symmetric dev part
                        QplotSigma1 = (QplotYX + QplotXY)/2; % symmetric dev part
                        QplotSigma2 = (QplotYX - QplotXY)/2; % antisymmetric part
                        
                        plotSigma2 = false; % NOT plotting antisymmetric part by default
                        if any(QplotSigma2(:))
                            plotSigma2 = true;
                        end
                    end
                    
                    cumulPlotGRID.([QnameList{q} QtagTime]) = Qplot;
                    
                    %%% Plot
                    % ---------------------------------------------------------------------------------------------
                    curveLineWidth = 1.5;
                    Xs = (1:finalFrame)';
                    Xs = frame2time(Xs,timeRef,frameRef,dt,'dec');
                    
                    if QstackDim < 4
                        
                        Ys = Qplot;
                        nCol = size(Ys,2);
                        
                        % plotting data
                        plot(Xs,Ys(:,1),'Color',colorClone,'LineWidth',curveLineWidth);
                        legendNames = {'clone'};
                        
                        if nCol == 2    % if WT counterpart exists
                            hold on
                            plot(Xs,Ys(:,2),'Color',colorWT,'LineWidth',curveLineWidth);
                            legendNames = [legendNames ; 'WT'];  %#ok<*AGROW>
                        end
                        
                    else % TENSOR CASE
                        
                        nCol = size(QplotSigma0,2);
                        
                        rootLegendName = [QnameList{q} '.\sigma_'];
                        
                        % plotting data
                        plot(Xs,QplotSigma0(:,1),'Color',colorClone,'LineWidth',curveLineWidth);
                        legendNames = {['clone ' rootLegendName '0']};
                        hold on
                        plot(Xs, QplotSigma3(:,1),'Color',colorClone,'LineWidth',curveLineWidth, 'LineStyle','--');
                        legendNames = [legendNames ; ['clone ' rootLegendName '3']];
                        plot(Xs, QplotSigma1(:,1),'Color',colorClone,'LineWidth',curveLineWidth, 'LineStyle','-.');
                        legendNames = [legendNames ; ['clone ' rootLegendName '1']];
                        
                        if plotSigma2
                            plot(Xs, QplotSigma2(:,1),'Color',colorClone,'LineWidth',curveLineWidth, 'LineStyle',':');
                            legendNames = [legendNames ; ['clone ' rootLegendName '2']];
                        end
                        
                        if nCol == 2    % if WT counterpart exists
                            
                            plot(Xs,QplotSigma0(:,2),'Color',colorWT,'LineWidth',curveLineWidth);
                            legendNames = [legendNames ; ['WT ' rootLegendName '0']];
                            plot(Xs, QplotSigma3(:,2),'Color',colorWT,'LineWidth',curveLineWidth, 'LineStyle','--');
                            legendNames = [legendNames ; ['WT ' rootLegendName '3']];
                            plot(Xs, - QplotSigma1(:,2),'Color',colorWT,'LineWidth',curveLineWidth, 'LineStyle','-.'); % MINUS SIGN TO MAKE COMPARISON BETTER
                            legendNames = [legendNames ; ['WT - ' rootLegendName '1']];
                            if plotSigma2
                                plot(Xs, - QplotSigma2(:,2),'Color',colorWT,'LineWidth',curveLineWidth, 'LineStyle',':'); % MINUS SIGN TO MAKE COMPARISON BETTER
                                legendNames = [legendNames ; ['WT - ' rootLegendName '2']];
                            end
                        end
                    end                  
                    
                    % title, legend, and other graphic plot tweak
                    title(QnameList{q}, 'Color', GetQuantityInfo(QnameList{q},'color'), 'FontWeight', 'bold');
                    ylabel([QtagClone ' ' QnameList{q} ' ' QtagTime ' ' QtagUnits])
                    xlabel('Time ( hAPF )')
                    legend(legendNames,'Location','NorthEast','FontSize',7)
                    mainH = figure(1);
                    set(mainH, 'color', 'white');
                    print(printFormat, printResolution, thisFilename);
                    close
                    % ---------------------------------------------------------------------------------------------
                    
                else
                    disp(['Warning: plot "' thisImageName '" already exists and will not be recalculated!']); % 3.4
                end
            end
        end
    end
    %%% Saves program alltime backup in *AOT* grid folder (mod 3.4)
    if saveCumulBackup
        save(cumulBackupFile,'-struct', 'cumulPlotGRID');
    end
    
    fprintf('Done\n')
end


%% Averaging over time using "alltimeGRID" and 3D/4D matrices (1.1)%%

% NB: as of 1.16, AOT ALWAYS redo the average from alltime_backup.
% NB: as of 3.0, stopped duplicating the "mean" backups in programs being averaged (AOS, TA, SM) and only saves them in AOT average folder

fprintf('Calculating averages over time...')

%%% Defining folder for average (mod 4.0):
averageFolderStart = ['Average_' num2str(roundn(timeWidth,-2)) 'h_'];
averageFolderMiddle = [timeStart '_to_' timeStop];
averageFolderEnd = ['_olap_' num2str(roundn(timeOverlap,-2))];
if noAverage
    averageFolderStart = 'noAverage_';
    averageFolderEnd = '';
end
singleFrameTF = false;          % are we analyzing a SINGLE frame? (4.1)
if strcmp(timeStart,timeStop)
    averageFolderMiddle = timeStart;
    singleFrameTF = true;       % 4.1
end
averageFolderName = [averageFolderStart  averageFolderMiddle averageFolderEnd]; % mod (4.0)
averageFolderAOT = [gridFolderAOT filesep averageFolderName];                   % 1.28

%%% Defining path to backup and txt files (mod 3.0)
fullPathAOT = [averageFolderAOT filesep 'mean_' filenameAOT '.mat']; % 1.28
fullPathTXT = [averageFolderAOT filesep 'performed.on.' averageOver '.on.' today  '.txt']; % 3.0

% Creates "virtualWeightStack4D" out of "WeightStack4D" (2.0):
vWeightStack4D = zeros(ny,nx,4,virtualFrameMax); 
vWeightStack4D(:,:,:,vQstart:vQend) = WeightStack4D(:,:,:,Qstart:Qend);

%%% Initializes array indicating time ranges, and GRIDall (1.5):
FrameArray = frameIntervals;            % will indicate frame range used for the average at each timepoint (4.2)


TimeArray = cell(nSteps,2);             % times hAPF EXACLTY CORRESPONDING to FrameArray
GRIDall = GRID_DEF;                     % initializes GRIDall with basic grid specs

%%% Iterating over intervals of average:
% mkdir(averageFolder);                             % creating Average_folder at last moment before iteration (1.9)
mkdir(averageFolderAOT);                           % 1.28 
eval(['QnameList = stackList' averageOver ';']);   % 1.23


%%% Building resized "vQstack" adapted to "frameMin/Max" and initializig "QWmeanAll" for each Q (overhaul 4.1)
%-------------------------------------------------------------------------------------------------------------------
nQ = length(QnameList);
for q = 1:nQ
    
    Qname = [QnameList{q} 'Stack'];
    
    if isfield(alltimeGRID, Qname)
        
        Qstack = alltimeGRID.(Qname);                      % loading stack of quantity Q
        
        Qdepth = size(Qstack,3);                        % determines depth of 3rd dimension = number of components of Q(ky,kx)
        QWmeanAll = NaN(ny,nx,Qdepth,nSteps);           % creates QWmeanAll (1.5)
        vQstack = NaN(ny,nx,Qdepth,virtualFrameMax);    % 2.0
        
        if strcmp(Qname,'AreaRatiosStack')                     % **ONLY "AreaRatios" will be impacted by missing frames NOT "RConds"**
            vQstack = zeros(ny,nx,Qdepth,virtualFrameMax);     % 2.0 initializes with ZEROS so that frames where animal is not available weighs on average
        end
        
        vQstack(:,:,:,vQstart:vQend) = Qstack(:,:,:,Qstart:Qend);   % 2.0
        
        eval(['v' Qname ' = vQstack;']);                    % creates vEAstack, vEDstack... in workspace (2.0)
        GRIDall.(QnameList{q}) = QWmeanAll;                 % initializes QWmeanAll for this Q (moved into "isfield" if, 1.13)
    end
end
%-------------------------------------------------------------------------------------------------------------------

%missingFrames = alltimeGRID.MissingFrames;         % retrieves list of missing frames (1.10)
missingFrames = [];
virtualMissingFrames = missingFrames - deltaFrame;  % 2.0

for i = 1:nSteps
    
    vfmin = virtualFrameIntervals(i,1);             % min frame number (2.0)
    vfmax = virtualFrameIntervals(i,2);             % min frame number (2.0)
    vfseq = vfmin:vfmax;                            % frame sequence
    vfseq = round(vfseq);                           % makes sure vfseq is an integer (4.11)
    vfseq = setdiff(vfseq, virtualMissingFrames);   % removes unprocessed frames from list to avoid layers of NaNs (1.9)
    
    
    if ~isempty(vfseq) % 4.2
    
        % Iteration over quantities Q to average (1.3,2.0, major changes 4.1)
        for q = 1:nQ

            Qname = [QnameList{q} 'Stack'];

            if exist(['v' Qname], 'var')

                eval(['vQstack = v' Qname ';']);                % loading virtual stack of quantity Q to operate on it (2.0)
                Qdepth = size(vQstack,3);                        % determines depth of 3rd dimension = number of components of Q(ky,kx) (4.1)
                QWmeanAll = GRIDall.(QnameList{q});             % loading right Q in "QWmeanAll"

                Qfs = vQstack(:,:,:,vfseq);                     % Crop of Q values to this frame sequence
                Wfs = vWeightStack4D(:,:,1:Qdepth,vfseq);       % Crop of Weights to this frame sequence AND Qdepth (4.1)
                QW = Qfs.*Wfs;                                  % Applying weights
                QWsum = nansum(QW,4);                           % sum over timepoints AVOIDING NaNs
                Wsum = sum(Wfs,4);                              % sum of weights

                if ~strcmp(Qname,'AreaRatiosStack') && ~strcmp(Qname,'RCondsStack')

                    QWmean = QWsum./Wsum;                           % calculates weighted mean along 4TH dimension (time)
                    % NB: NaN values in QW should correspond to 0s in Wsum otherwise this weighted mean with Weights = ones() will give a
                    % different result that regular function "mean".

                elseif strcmp(Qname,'AreaRatiosStack')

                    QWmean = mean(Qfs,4);                   % mean weight = SIMPLE average over frame sequence for AreaRatios (1.8)
                    % NB: no need for nanmean in principle as AreaRatios are initialized with zeros and not NaNs

                elseif strcmp(Qname,'RCondsStack')

                    QWmean = nanmean(Qfs,4);                % simple average avoiding NaNs
                    QWmean(QWmean==0) = NaN;                % put back NaNs in locations where only NaNs were found
                    % NB: use of "nanmean" (2.0) => AreaRatios and RConds are treated differently since RConds was built with NaNs and NOT 0s
                end

                % Case where no frame were available
                if ~isempty(Qfs)                                    % 4.0
                    QWmeanAll(:,:,:,i) = QWmean;                    % stores QWmean in ith layer (1.5)
                else
                    QWmeanAll(:,:,:,i) = NaN(1,Qdepth);             % 4.0, 4.1
                end
                GRIDall.(QnameList{q}) = QWmeanAll;                 % updates QWmeanAll for this Q (moved into "isfield" if, 1.13)
            end
        end

        fmin = frameIntervals(i,1);            % min frame number
        fmax = frameIntervals(i,2);            % max frame number
        tmin = frame2time(fmin, timeRef, frameRef, dt,'str'); % 1.29
        tmax = frame2time(fmax, timeRef, frameRef, dt,'str'); % 1.29
        TimeArray(i,:) = {tmin tmax};                                               % 1.5

        clear Qname QWMean QW Qfs Wfs QWsum Wsum QWmeanAll
    else
        "No values in the vfseq that are not missing frames"
        %TimeArray(i,:) = {NaN NaN};          % 4.2
        %FrameArray(i,:) = [NaN NaN];         % replace frame interval with NaNs when "vfseq" empty(4.2) 

        
    end
end

%%% Saves "GRID_animal" that contains all averaged timepoints in higher dimension matrices (1.5):
GRIDall.TimeArray = TimeArray;
GRIDall.FrameArray = FrameArray; % 4.2
% GRIDall.FrameArray = frameIntervals;
GRIDname = ['GRID_' averageOver '_' Animal]; % 1.28
eval([GRIDname ' = GRIDall;']);

% saving GRID_AOT *FIELDS* directly in AOT backup and then appending new fields to existing one (1.28)
GRID_AOT = eval(GRIDname);
GRID_AOT.(['AreaRatios_' averageOver]) = GRIDall.AreaRatios;    % changing name of AreaRatios by adding '_TA', '_SM', '_AOS' (1.28)
GRID_AOT = rmfield(GRID_AOT,'AreaRatios');                      %#ok<NASGU> % removes AreaRatios (1.28)
if ~exist(fullPathAOT,'file')
    save(fullPathAOT,'-struct', 'GRID_AOT'); % 1.28
else
    save(fullPathAOT,'-struct', 'GRID_AOT','-append'); % 1.28
end

% saving txt file indicating on which backups it was run (and when) (3.0)
timeAOT = datestr(now,16);
dlmwrite(fullPathTXT,['at ' timeAOT], 'delimiter', '', 'newline','pc');

clear WeightStack3D WeightStack4D GRID GRID_AOT % stopped erasing GRIDall that was loaded right after for plots and added GRID_AOT (1.28)
clear alltimeGRID;                              % clears "alltimeGRID" (4.1)
fprintf('Done.\n')


%% Plots using native program parameters (1.4)%%

if makePlotsAOT % 1.16
    if ~isempty(QnamePlot) && ~strcmp(QnamePlot{1},'none') % 1.8
        
        %%% creates Frame_folder:
        gridTag = '';
        if strcmp(gridType,'L') && forceEGrid % when Lagrangian calculations plotted on Egrid (1.18)
            gridTag = 'EGrid_';
        end
        frameFolderAOT = [averageFolderAOT filesep gridTag plotType]; % 1.28
        mkdir(frameFolderAOT); % 1.28
        
        [frameMin, frameMax] = MakeFrameIntervals(frameStart, frameStop, interframeWidth, timeOverlap);
        
        % Shifts "frameMin" of 1 when averaging over dynamic quantities (TA) (1.14, 4.1)
        if (strcmp(averageOver,'TA') || strcmp(averageOver,'VM')) && ~noAverage               % mod 4.1, added VM case (4.2)
            frameMin = frameMin + 1;    % NB: see above for explanation
        end
        frameIntervals = [frameMin frameMax];
        framePlots = frameMin;                                  % taking FIST image of interval for display now
%         framePlots = frameMax;                              % taking LAST image of interval for display now (1.17)
        nSteps = size(framePlots,1);                            % ACTUAL nsteps
        
        %%% Compares value found with stored ones (1.5)
        FrameArray = GRIDall.FrameArray;
        deltaFrames = FrameArray - frameIntervals;
        if any(any(deltaFrames))
            disp('ERROR: found discrepancy between stored values of frame intervals ("FrameArray") and the ones caculated with AOT parameters ("frame_intervals")!!');
            disp('Please regenerate the backups of averages.')
            return
        else
            disp(['Good match between "FrameArray" that was saved in "GRID_' averageOver '_' Animal ...
                '", and "frame_intervals" that was just recalculated using AOT parameters.']);
        end
        
        %%% Starting to fill DISPLAY structure (1.4)
        DISPLAY.Animal = Animal;
        DISPLAY.scaleBarWidth = scaleBarWidth;
        DISPLAY.fontSizeInfo = fontSizeInfo;
        DISPLAY.plotType = plotType;
        DISPLAY.EVstyles = EVstyles;
        DISPLAY.signOpacities = signOpacities;
        DISPLAY.lineWidth = lineWidth;
        DISPLAY.gridDisplay = gridDisplay;
        DISPLAY.minimalInfoDisplay = minimalInfoDisplay;    % 1.21
        DISPLAY.xyOffset = xyOffset;                        % 1.22
        DISPLAY.gridBulkThreshold = gridBulkThreshold;                % 2.2
        DISPLAY.cloneTracking = cloneTracking;              % 3.0
        DISPLAY.displayImages = displayImages
        
        % Adding parameters specific to TA (1.14, 1.27)
        if strcmp(averageOver,'TA')
            DISPLAY.errorPsMin = errorPsMin;
            DISPLAY.errorDnPsMin = errorDnPsMin;
            DISPLAY.errorFontSize = errorFontSize;
        end
        
        % Correction of TimeRange values for display (mod 4.2)
        dfmin = 0; % default value. Will be used to ONLY correct DISPLAY of time ranges with TA and VM quantities (1.27)
        if strcmp(averageOver,'TA') || strcmp(averageOver,'VM')
            dfmin = 1; % 1.27
        end
        
        %%% Iteration over timesteps:
        fminAll = frameIntervals(1,1);
        fmaxAll = frameIntervals(nSteps,2);
        tminAll = frame2time(fminAll, timeRef, frameRef, dt,'str'); % 1.29
        tmaxAll = frame2time(fmaxAll, timeRef, frameRef, dt,'str'); % 1.29
        
        for i = 1:nSteps
            
            %% Determining frame and time parameters %%
            
            fmin = frameIntervals(i,1);        % min frame number
            fmax = frameIntervals(i,2);        % max frame number
            fplot = framePlots(i);             % frame that SHOULD be used for plot (can't if doesn't exist
            
            tmin = frame2time(fmin-dfmin, timeRef, frameRef, dt,'str'); % uses dfmin (1.27), 1.29
            tmax = frame2time(fmax, timeRef, frameRef, dt,'str'); % 1.29
            
            % Defines "timeStr" (4.1)
            timeStr = [tmin '-' tmax]; % display of time range (default)
            if strcmp(tmin,tmax)
                timeStr = tmin; % only shows one time if the same (4.1)
            end

            % Further filling of DISPLAY (1.5)
            DISPLAY.nReal = []; % 2.0
            DISPLAY.n = fplot;
            DISPLAY.time = timeStr;  % mod 4.1
            if nSteps > 1 % (1.11)
                DISPLAY.step = i;                   % creates "step" field with ith step to plot ith slice of Q stack in PlotField
            end
            
            
            %% Checking fplot is not out of bounds (overhaul 3.4) %%
            
            % adjusting fplot if out of bounds:
            fplotOld = fplot;
            if fplot < startFrame 
                fplot = startFrame;
            elseif fplot > finalFrame
                fplot = finalFrame;
            end
            
            if fplotOld ~= fplot
                fprintf(['\nAOT WARNING: image #' num2str(fplotOld, digitsFormat) ' does not exist => will use ' num2str(fplot, digitsFormat) ' instead!\n'])
                DISPLAY.nReal = fplot;
            end
            
            imageFile = [pathFolder filesep filename num2str(fplot, digitsFormat) '.' imageFormat];
  
            % NB: before using CPT, there used to be issues with the need to load backups corresponding to the program
            % being averaged (especially SM for which some frames cannot be analyzed) to get cells in grid compartment
            % and other grid parameters. Now, with CPT, for each frame, there is a backup available, hence substantially
            % simplifying this part.

                
            %% Loading segmented image and further filling of DISPLAY with Lcentroids, contourIndices and macroRNs %%
                
            if ~(strcmp(averageOver,'VM') && strcmp(modeVM,'PIV')) && ~strcmp(averageOver,'GEP') % mod 4.6,4.10
                
                if strcmp(gridType,'L') && ~forceEGrid          % mod 4.2, 4.6
                    
                    fullPath = [pathCPTbackupFiles '_' num2str(fplot, digitsFormat) '.mat'];    % moved into if (4.2)
                    
                    if exist(fullPath,'file')
                        iGRID = load(fullPath);                                                     % moved into if (4.2)
                        DISPLAY.Lcentroids = iGRID.Lcentroids;                                      % overrides Eulerian centroids
                        DISPLAY.ContourIndices = iGRID.ContourIndices;                              % mod 3.0, 3.5
                        % NB: should use last used values of BU when finalFrame is reached (1.28)
                    else
                        disp(['AOT ERROR: CPT backup "' fullPath '" could not be found! Stopped execution.'])
                        return
                    end
                end
                
                if exist(imageFile,'file')
                    
                    imagePlot = imread(imageFile);  % loading segmented image (moved 2.0)
                    
                    % determining macroRNs in imagePlot (3.4)
                    %-------------------------------------------------------------------------------------------
                    % Loading macroANs from CTD backup ONLY in first iteration:
                    if i == 1
                        macroANs = FindMacroANs(pathFolderCTD);
                    end
                    
                    % Getting macroRNs in this frame
                    macroRNs = FindMacroRNs(trackingFolder, nColTotal, macroANs, fplot);
                    
                    DISPLAY.macroRNs = macroRNs;
                    DISPLAY.colorMacrochaetes = colorMacrochaetes;
                    %-------------------------------------------------------------------------------------------
                    
                elseif ~strcmp(averageOver,'GEP') % 2.7
                    disp(['Segmented image "' imageFile '" not found!'])
                end
            end
            
            
            %% PLOT of each tensor fields on separate images OR ALL tensors on a single image (when in "fullImage" mode) (1.20) %%
            
            nBoxes = length(GRIDall.AreaRatios(:,:,1));
            
            if nBoxes == 1  && nQplot > 1         % added "&& nQplot > 1": no need to use the "ALL" plot when only one quantity to plot! (1.25), mod 4.4
                %% "fullImage" case (1.20) %%

                disp('AOT WARNING: "fullImage" case...')
                               
                % creates a plot grid on which all Qs will be plotted
                H = imageSize(1)*0.9;
                W = imageSize(2)*0.9;
                
                % Determining grid on which ALL tensors will be plotted (1.24) 
                Qn = ceil(sqrt(nQplot)); % still plotting on a 3x3 grid if nQplot = 8,7,6 or 5; 
                Qw = floor(W/Qn);
                Qh = floor(H/Qn);
                QboxSize = [Qw Qh];
                QgridSize = [Qn Qn];
                xLeeway = W - Qw*Qn;
                yLeeway = H - Qh*Qn;
                QxyStart = [xLeeway/2 yLeeway/2];
                QGRID = MakeGrid(imageSize, QboxSize, QxyStart, QgridSize, gridColor, gridLineWidth, 0);

                QGRID.Centroids = (QGRID.Centroids)';       % getting transpose
                QGRID.ULCs = (QGRID.ULCs)';                 % getting transpose
               
                % Taking features of FIRST "plotTensorXXX" quantity for ALL (mod 4.8)
                Qfirst = QnamePlot{1}; % 4.8
                [~,QfirstLoc] = ismember(Qfirst, allQs); % 4.8
                Qunits = allUnits{QfirstLoc};
                Qsr = allScaleRatios{QfirstLoc};            % now a matrix (1.13), back to cell array (1.18)
                Qscalebar = allScaleBarLengths(QfirstLoc);  % now a matrix (1.13)
                QkillTr = allKillMeanTraces(QfirstLoc);
                DISPLAY.imageFading = imageFading;
                
                for q = 1:nQplot
                    Qname = QnamePlot{q};
                    if isfield(GRIDall,Qname)                  % checking if Qname is among GRID fields (1.13)
                        
                        [~,Qind] = ismember(Qname, allQs); % mod 4.8
                        Qcolor = allColors{Qind};
                        
                        qthQGRID = QGRID;
                        qthQGRID.(Qname) = GRIDall.(Qname);
                        qthQGRID.Centroids = QGRID.Centroids(q);
                        qthQGRID.ULCs = QGRID.ULCs(q);
                        qthQGRID.Size = [1 1];
                        qthQGRID.AreaRatios = GRIDall.AreaRatios; % 1.24
                        qthQGRID.fullImage = true;
                        DISPLAY.Lcentroids = QGRID.Centroids(q);
                        
                        if q == 1
                            PlotField(Qname, QkillTr, Qcolor, Qunits, Qsr, Qscalebar, qthQGRID, imagePlot, DISPLAY);
                        else
                            PlotField(Qname, QkillTr, Qcolor, Qunits, Qsr, Qscalebar, qthQGRID, [], DISPLAY);
                        end
                    end
                end
                
                %%% Saving image "frameFolderAOT" (4.0):
                thisFilename = ['ALL_' averageOver '_' Animal '_' timeStr];                             % simplified and added "averageOver" in name (4.0), "timeStr" (4.1)
                print(printFormat, printResolution, [frameFolderAOT filesep thisFilename '.png']);      % saving in "frameFolderAOT" (4.0)
                if ~isempty(resultsFolder)                                                              % 4.3
                    print(printFormat, printResolution, [resultsFolder filesep thisFilename '.png']);   % also saving in results folder (4.3)
                end
                if saveSVG
                    plot2svg([frameFolderAOT filesep thisFilename '.svg']);       % saving in "frameFolderAOT" (4.0)
                    if ~isempty(resultsFolder)                                    % 4.3
                        plot2svg([resultsFolder filesep thisFilename '.svg']);    % saving in "frameFolderAOT" (4.0)   % also saving in results folder (4.3)
                    end
                end
                close
 
                %%% Writing txt file (mod 4.0)
                %------------------------------------------------------------------------------------------
                today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style
                txtFilename = [today '_AOT.on.' averageOver '_' version '.txt']; % mod 4.0
                
                QsrTag = num2str(Qsr(1),2);
                if length(Qsr)==2 && Qsr(1) ~= Qsr(2)
                    QsrTag = [num2str(Qsr(1),2) '-' num2str(Qsr(2),2)];
                end
                
                parameterCell = {   'killMeanTrace = ', QkillTr;
                                    'scaleRatio = ', QsrTag};
                % Adding error thresholds for TA
                if strcmp(averageOver,'TA')
                    parameterCellTA = { 'errorPsMin = ', errorPsMin;
                                        'errorDnPsMin = ', errorDnPsMin};
                    parameterCell = [parameterCell ; parameterCellTA];
                end
                dlmcell([frameFolderAOT filesep txtFilename], parameterCell,' ');
                %------------------------------------------------------------------------------------------                

            else               
                %% Regular case %%

                % Iteration over MEAN Q to PLOT (1.3)
                signalPrefixes = ['CD' ; signalName]; % removed mCD, added ID (2.3), use of signalName (2.7)
                for q = 1:nQplot
                    Qname = QnamePlot{q}; 
                    if strcmp(averageOver,'VM') % 4.10
                        Qname = [Qname modeVM]; % adding "PIV" or "CT" to name
                    end

                    if isfield(GRIDall,Qname)
                        
                        Qtf = ismember(allQs,Qname);
                        Qind = find(Qtf);
                        Qcolor = allColors{Qind};
                        Qunits = allUnits{Qind};
                        Qsr = allScaleRatios{Qind};            % now a matrix (1.13), back to cell array (1.18)
                        Qscalebar = allScaleBarLengths(Qind);  % now a matrix (1.13)
                        QkillTr = allKillMeanTraces(Qind);
                        DISPLAY.imageFading = imageFading;
                        
                        % tag indicating mean Tr = 0 for naming files (3.12):
                        KillTrTag = '';
                        if QkillTr
                            KillTrTag = '_Tr=0';
                        end
   
                        % if CD or GEP signals OR VM.PIV to plot, chooses corresponding raw image (2.4,4.2)
                        if any(strcmp(Qname,allQsAOScds)) || (strcmp(averageOver,'VM') && strcmp(modeVM,'PIV')) || strcmp(averageOver,'GEP') % 4.2 % 4.7
                            
                            iRaw = 1; % default case (4.2)
                            if any(strcmp(Qname,allQsAOScds))               % processing CD signals from AOS
                                
                                Qsignal = substr(Qname,  2);                % removes 'CD' from 'CDCad', 'CDMyo'... (4.2)
                                [~,iRaw] = ismember(Qsignal, signalName);   % gets index in signalName list (4.2)
                                DISPLAY.Animal = filenameRaw{iRaw};         % used to display on image, stopped formatting filenames (4.2)
                                
                            elseif strcmp(averageOver,'VM') && isfield(DISPLAY,'Lcentroids')
                                
                                DISPLAY = rmfield(DISPLAY,'Lcentroids');
                            end
                            imageFile = [pathFolderRaw filesep filenameRaw{iRaw} num2str(fplot, digitsFormat) '.' imageFormatRaw];
                                                        
                            roifilename = [roiname num2str(fplot,digitsFormat) '.png']; % 4.2
                            roifile = [pathFolderROI filesep roifilename];
                            
                            if exist(imageFile,'file')
                                imagePlot = imread(imageFile);  % loading segmented image (moved 2.0)
                                imagePlot = imadjust(imagePlot); % 4.7
                                imagePlot = imcomplement(imagePlot);
                                
                                % Applying RoI mask when available (4.2)
                                if exist(roifile,'file')
                                    roiPlot = imread(roifile);
                                    roiPlot = logical(roiPlot);
                                    imagePlot(~roiPlot) = intmax(class(imagePlot)); % 4.7
                                end
                            else
                                disp(['ERROR: Raw image "' imageFile '" not found!'])
                            end
                        end
                        
                        % Plot tensors using PlotField:
                        imagePlotOut = PlotField(Qname, QkillTr, Qcolor, Qunits, Qsr, Qscalebar, GRIDall, imagePlot, DISPLAY); % imagePlotOut as output (2.10,3.0)
                        % NB: "imagePlotOut" is now a 8bit grayscale RGB image
                        
                        %%% Saving image:
                        % adding Qsr values in filename (1.18)
                        QsrTag = num2str(Qsr(1),2);
                        if length(Qsr)==2 && Qsr(1) ~= Qsr(2)
                            QsrTag = [num2str(Qsr(1),2) '-' num2str(Qsr(2),2)];
                        end
                        
                        thisFilename = [Qname '_' Animal '_' timeStr  KillTrTag '_sr=' QsrTag];  % 1.20, removed TAtag (1.27), use QnameSave (2.4), "timeStr" (4.1)                      
                        if strcmp(imageFormatOutput,'pdf')                     % 1.20, 1.25
                            thisFilename = [Qname '_' Animal '_' tminAll '_to_' tmaxAll  KillTrTag '_sr=' QsrTag];  % 1.20, removed TAtag (1.27), use QnameSave (2.4)
                            if i == 1
                                export_fig([frameFolderAOT filesep thisFilename '.pdf'], '-pdf');             % overwrites existing file (1.28)
                            else
                                export_fig([frameFolderAOT filesep thisFilename '.pdf'], '-pdf','-append');   % appends following pages (1.28)
                            end
                        else
                            print(printFormat, printResolution, [frameFolderAOT filesep thisFilename '.png']);
                            if ~isempty(resultsFolder)                                                              % 4.3
                                print(printFormat, printResolution, [resultsFolder filesep thisFilename '.png']);   % also saving in results folder (4.3)
                            end
                            if saveSVG
                                plot2svg([frameFolderAOT filesep thisFilename '.svg']);
                                imwrite(imagePlotOut,[frameFolderAOT filesep thisFilename '001.png']);  % overwritting useless blank png file with 8bit grayscale RGB background image (2.10)
                                if ~isempty(resultsFolder)                                               % also saving in results folder (4.3)
                                    plot2svg([resultsFolder filesep thisFilename '.svg']);
                                    imwrite(imagePlotOut,[resultsFolder filesep thisFilename '001.png']); % overwritting useless blank png file with 8bit grayscale RGB background image (2.10)
                                end
                            end
                        end
                        close
                        
                        % Saving txt file indicating error thresholds (1.27)
                        if strcmp(averageOver,'TA')
                            today = datestr(now,29);                                % format 29 displays date yyyy-mm-dd style.
                            txtFilename = [today '_eP=' num2str(errorPsMin,2) '_eDnP=' num2str(errorDnPsMin,2) '.txt'];
                            dlmwrite([frameFolderAOT filesep txtFilename], ['AverageOverTime version ' version], 'delimiter', '', 'newline','pc')
                        end
                    end
                end
            end 
        end
    elseif (isempty(QnamePlot) || strcmp(QnamePlot{1},'none'))
        disp(['AOT WARNING: Please select at least one quantity to plot in ' averageOver '!!'])
    end
end

clear DISPLAY % 4.3

disp('---------------------------------------------------------------------------------------------------------------');

%% Python compatibility layer

% I catch these messages in python to know what happened exactly 
%(this is very suboptimal but will do for now )
disp(strcat("python_AOT:", averageFolderAOT));


%% History %%

% FUTURE IMPROVEMENTS:
%------------------------------------------------------------------------------------------------------
% - when midlineSymmetry, plot right part vs left part like for clone
%------------------------------------------------------------------------------------------------------



% 19/09/2019: 4.12
% - fixed issue where backups were skipped when the first one
% (corresponding to "startFrame") was missing, assuming that the program
% was run on no frame at all and that no averaging was possible.
% Accordingly defined "firstBackupFound" to only skip averaging when NO
% backup could be found.

% 25/01/2019: 4.11
% - fixed the comparative plots of clone part and their WT symmetric
% counterparts.

% 17/09/2018: 4.10
% - bug fix: stopped trying to load segmented images when processing GEP
% - changes to support VM 4.3 that now directly adds "PIV" or "CT" suffix
% to U, Epsilon, Omega according to parameter "modeVM".

% 06/09/2018: 4.9
% - every U, Epsilon, Omega gained a "VM" suffix so as not to be confused with AOS quantities

% 26/07/2018: 4.8
% - now removes tensors listed in "skipTensorsTA" WITHOUT changing their
% order in "plotTensorsXXX", which matters when processing in "fullImage" mode.
% - takes features of FIRST quantity in "plotTensorXXX" (Units,
% scaleRatio...) to plot ALL the other quanitites.

% 06/07/2018: 4.7
% - fixed issue when displaying raw 16b image instead of segmented image, 
%   display was not adapted 

% 02/07/2018: 4.6
% - fixed issue where macrochaetes where trying to be loaded whereas AOT
% was processing a VM average with PIV.

% 26/06/2018: 4.5
% - stopped making a specific case when frameStart == startFrame: used to
% introduce a mismatch between animals' "TimeArray" resulting in a crash.

% 26/06/2018: 4.4
% - reverted a change made in 4.3 preventing "fullImage" treatment when
% "cloneTracking" mode since now clones are processed with single box grid
% (when no WT counterpart).

% 18/06/2018: 4.3
% - now also saving images in a results folder created by user
% - now prevents "fullImage" treatment when in cloneTracking mode
% - clears DISPLAY at the end of execution

% 31/05/2018: 4.2
% - fixed several issues related to "noAverage" mode
% - fixed crash when "vfseq" is empty (when no frames are available)
% - accordingly stores NaNs in FrameArray and TimeArray when this occurs
% - now supports the averaging of VM quantities (VM alltime backup is
% direclty generated by VM, unlike other programs).
% - for TA and VM, now properly excluding "startFrame" from the average
% - updated part plotting CD quantities from AOS, and now VM, so it uses
% raw images rather than segmented ones.
% - now VM averaging also working without segmented images (GEP not tested)
% - applying RoI mask when available and when displaying raw images rather
% than segmented images

% 03/03/2018: 4.1 *** MAJOR CHANGES ***
% - NOW ALL MATRICES ARE 4D MATRICES (SOMETIMES WITH SINGLETON DIMENSIONS)
% REGARDLESS OF THE QUANTITIE BEGIN AVERAGED! => SUBSTENTIAL SIMPLIFICATION
% OF CODE
% - supports SINGLE IMAGE PROCESSING (direct consequence of the above)
% - supports NO AVERAGING (when timeWidth = 0)
% - fixed issue where all TA, SM and AOS quantities were stored in every
% alltime backup
% - when building "alltime" backup, moved question dialog asking user to
% check first and last frames to be considered.
% - now ONLY prompts frame-checking message when segmented images BEFORE
% startFrame or AFTER finalFrame are found, otherwise build alltime backups
% right away.

% 01/03/2018: 4.0 *** MAJOR CHANGES ***
% - stopped supporting structure or cell array now => only nD-matrices
% should be listed in "QnameList"
% - now saves "ALL_" images in the frame folder, and specify program being
% plotted
% - removed many tags in image names that were too long and instead saves
% more info in txt files.
% - added a "noAverage" mode (AIA paramters) that enables to generate
% maps for each frame without time averaging
% - even in "noAverage" mode, now supports cases where some frames could
% NOT be processed (like in STPE, SM)
% - no need to use the "ALL" plot when only one quantity to plot =>
% switching to regular case => plotting value at Lcenter of clone

% 28/02/2018: 3.5
% - changes for compatibility with Matlab 2017 and new variable and function names
% - removed many quantities from "fields2remove" as many of them are now in "GRID_DEF" and won't be averaged
% - now AOS, TA, SM ".mat" backups ALL direclty contain variables, without sub-structure "GRID_AOS/TA/SM"

% 13/10/2017: 3.4
% - thanks to use of CPT backups rather than AOS,SM or TA backusp, drastically simplified part looking for alternate
% frames and backups when fplot was out of bounds.
% - supports averaging of SM backups
% - display of macrochaetaes in color
% - CppTD became CTD

% 29/09/2017: 3.3
% - started to add time plot of cumulated and UNcumulated quantities

% 28/09/2017: 3.2
% - added a cumulative plot of clone vs WT matching part for dnA, dnD, rBoxCellArea (when "cloneTracking" AND
% "matchingWTclone" are true) right after performing "alltime_..." stack

% 07/08/2017: 3.1
% - cleaned up code by removing parts commented in 3.0

% 01/08/2017: 3.0 *MADE REQUIRED CHANGES FOR COMPATIBILITY WITH "CellPatchTracking" v3.5 and "AOS" v4.1...
% - stopped RE-defining grid but rather loads "GridDef.mat" file
% - saves "alltime_AOS/TA/SM..." backups in the AOT folder and NOT in the folder of program being averaged
% - stopped duplicating AOT folders "Average_..." in the folder of program being averaged
% - added txt file in "Average" folder indicating on which program the average has been run and when
% - stop creating sub-structure in ALL "alltime_AOS/TA/SM..." backups

% 18/07/2017: 2.10
% - when saving image as .svg, now overwrites the blank image that used to be saved and displayed as white background by the
% grayscale image showing the cells and patches that now makes up the right background when opening in Adobe Illustrator.

% 21/04/2017: 2.9

% 16/12/2016: 2.8
% - adjustments to match AOS update 3.25 in which CD1, CD2 became CDcad, CDmyo...

% 14/12/2016: 2.7
% - adjustments to match GEP update 1.1 where ID1, ID2 were dropped in favor of signal names "cad", "esg", "myo"...

% 13/12/2016: 2.6
% - fixed bug when asking to plot out of bounds raw image

% 07/12/2016: 2.5
% - added "gridTag" in gridSpecs specifying parameter "gridTime" used to draw grid

% 24/06/2016: 2.4
% - full support of GEP outputs (average AND display)
% - support of new AOS outputs that now use CD1, CD2... to make average over animals easy => substantially simplified code!

% 14/06/2016: 2.3

% 09/06/2016: 2.2
% - added storage of parameter "gridOnlyBulk" in DISPLAY to be able ton ONLY display "bulk" values with AreaRatios = 1 in PlotField.

% 26/05/2016: 2.1
% - now average "RConds" have NaNs where they used to have 0s AFTER time-average: they are NOT treated as "AreaRatios" anymore consistently
% in space and time. Indeed NaNs => unavailable values do NOT weigh in the time (and space) average anymore
% - now directly fixing irrelevant "AreaRatios" in first TA backup (corresponding to "startFrame") by correcting the alltime stack with a
% slice of zeros, thereby fixing the 0s we used to get in the bulk of the animal because of these non-zero weights (since nansum or nanmean
% = 0 when only NaNs). Those 0s were surrounded by NaNs because 0/0=NaN.

% 23/05/2016: 2.0
% - supports of any "timeStart/Stop" specified in AIA_parameters, even those leading to negative "frameStart" and "frameStart" beyond
% existing movie frames. When frames are missing for an animal, the "AreaRatios" (NOT THE "RConds" for TA) will be impacted, leading to
% partially faded display even in the bulk of the animal.
% NB: updated "MakeFrameIntervals" accordingly to allow for beyond limit "frameMin/Max", therby making it looser.

%---------------------------------------------------------- 2.0 ------------------------------------------------------------------

% 28/04/2016: 1.29
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage
% NB: this did NOT impact any calculation done before this update

% 04-12/04/2016: 1.28
% - fixed infinite while loop when looking for an available backup (to get Lcentroids) past finalFrame
% - stopped saving images in TA,SM,AOS folders (just saving them in AOT folder now)

% 01/03/2016: 1.27
% - corrected erroneous DISPLAY (only) of time range for TA quantities (that deal with interframes and not frames)
% - cleaning: removed some commented parts
% - shortened names of saved TA images by removing TAtag containing info on error
% - instead, now saving error info as filename of a txt file (look up "txtFilename") in same folder as images
% - now uses roundn(...,-2) to limit to 2 decimals values of timeWidth and timeOverlap in folder names

% 20/01/2016: 1.26
% - defines lists stackListTA,AOS,SM according to the fields listed in TA, AOS and SM backups, respectively.
% - now defines default values of timeStart, timeStop, timeWidth and corresponding frameStart, frameStop and
% interframeWidth in AIA_parameters

% 03/09/2015: 1.25
% - removed if "strcmp(imageFormatOutput,'svg')" to instead ALWAYS save a svg copy when png format is selected
% - added "Ustar" and "PhiUstar" in "stackListTA"
% - use of new parameter "skipTensors_TA" specifying which tensor NOT to plot

% 26/06/2015: 1.24
% - added EU, EGstar, EPSI, PhiU in stackListTA
% - fixed and simplified the plot of ALL contributions on a single grid: always plot on a nxn grid

% 29/05/2015: 1.23  became "AverageOverTime"
% - fixed bug where plots of AOS averages of cortical signal (CD,mCD) were skipped

% 26/05/2015: 1.22 
% - started changing parameter names to match AIA 6.0, TA 2.2.1

% 30/04/2015: 1.21 
% - loading of "minimalInfoDisplay" to only display time APF and scalebar (and not the quantity being plotted nor the frame number)

% 19-20/04/2015: 1.20 
% - supports saving of pdf files (with append option)

% 14/04/2015: 1.19 
% - parameter "makeAlltimeBackup" now defined internally: automatically builds "alltime_backup" when not found on disk.

% 07/04/2015: 1.18
% - "alltime_backup" now supports 3D matrices of tensors (or tensors) stacked together, like EG,ES... coming from TA 2.1.7+
% (that are not structures containing 3D matrices of XYs,Es,Angles anymore).
% - added parameter "forceEGrid" that will enable to plot fields on Eulerian grid even though calculations were made
% using a Lagrangian one.
% - now name frame folder to "EGrid_split+" (instead of just "split+") when calculations were made on Lagrangian grid
% and the plot is done on an Eulerian one (forceEGrid = true).
% - supports the saving of images in svg format that supports transparency of vector objects
% - support of different scale ratios for isotropic an anisotropic parts
% - accordingly "allScaleRatios" is now a cell array (again)
% - both scale ratios now appears in the saved filename

% 02/04/2015: 1.17 
% - support of Lagrangian grid plot: will load Grid backup corresponding to plotted image and put "Lcentroids" and "contour_indices" into
% structure DISPLAY that will be used in PlotField (accordingly updated to 1.11).
% - now takes LAST image of frame_intervals for display (rather than the one in the middle of the interval) since results comes from average
% over the whole time period.

% 01/04/2015: 1.16 
% - now ALWAYS (re)calculate the average from alltime_backup
% - accordingly renamed "replot_AOT" to "plot_AOT" that now only controls the plot

% 23/03/2015: 1.15 
% - removed "Frames_" to shorten paths to figures which was causing issues.

% 28/02/2015: 1.14 (Boris)
% - added 'RConds'; 'errorPs' ; 'errorDnPs' to TA_list
% - included matrix of (r)conditional values "RConds" in weights that are now AreaRatios.*RConds (when RConds exists in GRID)
% - takes SQUARE of weights to sharpen decrease at animal boundaries
% - fixed small error on averages: now shifts starting frame of averages "frame_min" of +1 when dealing with DYANMIC
% quantities (averageOver = TA)! See explanation above in the code
% - shortened scale ratio tag in saved filenames
% - TA use: added specification of thresholds used for error display in figure filenames.

% 23/02/2015: 1.13 (Boris)
% - support of TA backups
% - reformat "time_start/stop" from HH:MM to HHhMM for folder naming (1.13):

% 22/01/2015: 1.12 (Boris)
% - removed the several "round" added and updated MakeFrameIntervals to v1.3 instead.

% 21/01/2015: 1.11 (Stephane)
% - fixed bug when nb of time points in 4D matrices of averages = 1 because Matlab then turn them into 3D matrices.
% - added several "round" to overcome a bug in MakeFrameIntervals resulting in wrong determination of frame ranges for the average (Ex: TRBL4 average over 4h between 14h and 26h)

% 4/11/2014: 1.10
% - fixed "MissingFrames" bug

% 14/10/2014: 1.9
% - if time_start/stop empty, take full available range by loading actual Start/finalFrame and taking corresponding times
% - support of SM backups

% 10/10/2014: 1.8
% - now plotting after calculation even when replot_AOT = 0
% - fixed time averaging of "AreaRatios" that was processed exactly as the others (and contained NaNs) while it has to be simply averaged
% over time with function "mean" to get the average weight, unlike the other quantities that must be weighted.
% - adde progress bar when building "alltime" backup

% 09/10/2014: 1.7
% - changed naming of figures: "Qname_animal_tmin_to_tmax_Tr=0_sr=0.X.png"
% - exception when Qname=(m)CD: do not repeat signal name if only one signal processed to avoid repeating the animal name.

% 08/10/2014: 1.6
% - removed compatibility with old AOG backups: useless

% 06/10/2014: 1.5
% - now ONLY saves a GRID structure of 3D/4D matrices that contains averages for every timepoints ("GRID_program_animal")
% - added a matrix and cell array indicating the time range around each timepoint in str HHhMM and frame format, respectively.
% - compatibility with old AOG backups

% 15/09-06/10/2014: creation & 1.1 to 1.4
