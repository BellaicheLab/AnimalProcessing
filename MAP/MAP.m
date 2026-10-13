% MultiAnimalProcessing (MAP)
%
% version 4.11
% Stephane Rigaud
% Boris Guirao


%% Additional defintions %%

% moved from "parametersMAP"
MAPcall = 1;            % Flag preventing multiple grid validation after first validation (DO NOT MODIFY)
CustomColors;
AllQsColorsUnits;

%%% RA mode (4.1)
if RA == 1
    
    % NO existing grid at this point => NOT entering grid making part (4.1)
    SAPcall = true;        
    clear MAPcall;  % setting it to "false" is NOT enough
    
    % Overriding other program execuction: you're not doing RA and other stuff!
    AOA = 0;               % "AverageOverAnimals"
    POA = 0;               % "ProjectionOverAnimals"
    PTE = 0;               % "PlotTimeEvolution"
end

%%% calling any SAP_info to get first draft of parameters from SAP_parameters

if exist('cloneNameList','var') % 4.5
    cloneName = [cloneNameList{1} 'Final'];
end
evalc(['SAP_info_' allAnimals{1}]);

timeOverlapAll = roundn(timeOverlapAll,-2); % 4.3
uTimeOverlap = roundn(uTimeOverlap,-2);     % 4.3

% Processing ONE single animal OR average (2.6)
nAllAnimals = length(allAnimals);       % 2.2, moved here 2.6
nAvgAnimals = length(avgAnimals);       % 2.2, moved here 2.6
nQname = length(Qname);                 % 2.2

singleAnimal = false;      % default
% if nAllAnimals == 1
%     singleAnimal = true;
%     disp('*** SINGLE animal processing! ***')
% end

% defining fullTag (2.3)
fullTag = '';
if PLOT.makeItFull
    fullTag = '_full';
end

% defining tags
tagProjectionTime = [strrep(num2str(uTimeWidth),'.','') 'h_' strrep(num2str(uTimeOverlap),'.','') 'olap']; % 4.3

% Format, resolution, and extention
printFormat     = ['-d' PLOT.imageFormatOutput];
printResolution = ['-r' num2str(PLOT.resolution)];
imageExtension  = ['.'  PLOT.imageFormatOutput];

%%% display parameters to be used during plot
DISPLAY.boxSize = PLOT.refBoxSizeMicron/PLOT.refScale1D;
DISPLAY.path2BackgroundMap = path2BackgroundMap;

DISPLAY.makeItFull = PLOT.makeItFull;
DISPLAY.displayOrigin = PLOT.displayOrigin;
DISPLAY.drawMidline = PLOT.drawMidline;
DISPLAY.plotType = plotType;
DISPLAY.minimalInfoDisplay = false;
DISPLAY.scaleBarWidth = 5;
DISPLAY.gridDisplay = gridDisplay;
DISPLAY.lineWidth = lineWidth;
DISPLAY.pointSize = 2;
DISPLAY.Animal = mapAnimal;
DISPLAY.EVstyles = EVstyles;
DISPLAY.signOpacities = [0.7 0.15];
DISPLAY.fontSizeInfo = PLOT.fontSizeInfo; % use "fontSizeInfo" value from MAP_parameters (4.2)
% DISPLAY.fontSizeInfo = 20;
DISPLAY.imageFading = 0.6;
DISPLAY.errorPsMin = 1;
DISPLAY.errorDnPsMin = 1;
DISPLAY.errorFontSize = 5;
DISPLAY.fadeColor = custom_white; % dont know why but plotfield need it for VM
DISPLAY.midlineColor = grey;
DISPLAY.macroSize = PLOT.macroSize;
DISPLAY.colorMacrochaetes = colorMacrochaetes;
DISPLAY.gridBulkThreshold = PLOT.gridBulkThreshold;
DISPLAY.displayImages = PLOT.displayImages;
% 4.11
DISPLAY.gridColor = gridColor;
DISPLAY.gridLineWidth = gridLineWidth;
DISPLAY.refScale1D = PLOT.refScale1D; % storage in DISPLAY for convenience (2.1)


%%% Values that will NOT be averaged (taken out of AOA "if" and renamed in 2.5)
gridInfoList = {'xywh' ; 'Size' ; 'Lcentroids' ; 'Overlap' ; 'Color' ; 'Centroids' ; 'ULCs' ; 'LineWidth' ; 'TimeArray' ; 'FrameArray' ;...
    'fullImage' ; 'Coordinates'; 'Macrocaetes' ; 'REG' ; 'FULL'; 'FinalFrame' ; 'PatchColors'};
areaRatiosList = {'AreaRatios_TA';'AreaRatios_SM';'AreaRatios_AOS';'AreaRatios_GEP';'AreaRatios_VM'; 'RConds';'errorDnPs';'errorPs'}; % will only average common "AreaRatios" (2.2)
rejectListNew = {'EDM'; 'EGeig'; 'EPSIeig'; 'ESeig'; 'Eeig' ; 'Phieig' ;'RCondsRaw'}; % 2.2
rejectList = [gridInfoList ; areaRatiosList ; rejectListNew]; % 2.2

%%% Default scalebar and scale ratio value for unknown quantities plot
Pname = 'RND';
idx = 1;
scaleBarLengthRND = 1;
scaleRatioRND = 1;
killMeanTraceRND = 0;

%% PATR (PlotAllTimeRanges) (4.8) %%

PATRfile = [PathName filesep 'allTimeRanges.' mapAnimal '.png'];
if ~exist(PATRfile,'file')
    
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    disp(['Plotting all "' mapAnimal '" animals time ranges...'])
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    fprintf('\n')
    
    PlotAllTimeRanges
    disp('Done!')
end


%% RA - Advanced %%
if RA
    originType = 2;    % 2 to use macro center as coordinate origin, 1 to use the y midline, 0 to use the first macrochaetae
    
    % Defining "rescalingOutputFile" to check existence before running
    originTypeTag = ''; % default: empty when originType = 2
    if originType ~= 2
        originTypeTag = ['_' num2str(originType)];
    end
    
    % Full path to archetype (to create or use):
    archetypeFolder = [parentArchetypeFolder filesep archetypeName 'archetype_' clickTimeAll '_nMacroUsed=' num2str(nMacroMin)]; % 1.0, 3.0
    
    if strcmp(rescaleMode,'Archetype')
        pathFolderRA = archetypeFolder;
        
    elseif strcmp(rescaleMode,'Rescale')
        pathFolderRA = [parentRescaledAnimalsFolder filesep rescaleName 'rescaled_' clickTimeAll '_nMacroUsed=' num2str(nMacroMin)]; % 1.0, 3.0
    else
        disp('ERROR: parameter "rescaleMode" can only be "Archetype" or "Rescale"!')
        return
    end
    
    rescalingOutputFile = [pathFolderRA filesep 'rescalingOutput' originTypeTag '.mat'];
    
    if ~exist(rescalingOutputFile,'file') % ONLY runs if file does NOT exist
        
        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
        disp('Starting RA processing ...')
        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
        
        fprintf(['\nRunning RA in ' rescaleMode ' mode...\n'])
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        RescaleAnimals
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        disp('Done!')
        return
    else
        disp('WARNING: "rescalingOutput" backup was found => skipped RA execution!')
    end
end


%% AOA - Advanced %%

if AOA
    
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    disp('Starting AOA processing ...')
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    fprintf('\n')
    
    nTimeAvg = length(timeWidthAll);
    for t = 1:nTimeAvg
        
        %%% Defining quantities for THIS time averaging (2.5)%%
        TIME.animalTimeOverlap = timeOverlapAll(t);
        TIME.animalTimeWidth   = timeWidthAll(t);
        TIME.timeStart = timeStart;
        TIME.timeStop = timeStop;
        PLOT.plot = makePlotsAllAOT(t);
        
        %%% Defining average folder to use :
        averageFolderStart = ['Average_' num2str(roundn(timeWidthAll(t),-2)) 'h_'];
        averageFolderMiddle = [timeStart '_to_' timeStop];
        averageFolderEnd = ['_olap_' num2str(roundn(timeOverlapAll(t),-2))];
        if timeWidthAll(t) == 0
            averageFolderStart = 'noAverage_';
            averageFolderEnd = '';
        end
        singleFrameTF = false; % are we analyzing a SINGLE frame? (4.1)
        if strcmp(timeStart,timeStop)
            averageFolderMiddle = timeStart;
            singleFrameTF = true;       % 4.1
        end
        averageFolderName = [averageFolderStart  averageFolderMiddle averageFolderEnd]; % mod (4.0)
        disp(['Fetching data for ' num2str(timeWidthAll(t)) ' with ' num2str(timeOverlapAll(t)) ' overlap, from ' timeStart ' to ' timeStop ' APF.'])
        
        %%% Loading information for each animals
        tmpIndex = 1;
        for n = 1:nAllAnimals
            fprintf(['\tFetching information for animal ' allAnimals{n} ' ...'])
            
            if exist('cloneNameList','var') % 4.5
                cloneName =  [cloneNameList{n} 'Final'];
            end
            
            %%% calling SAP_info
            evalc(['SAP_info_' allAnimals{n}]);
            timeOverlapAll = roundn(timeOverlapAll,-2); % 4.3
            uTimeOverlap = roundn(uTimeOverlap,-2);     % 4.3
            
        %%% determines RESCALED deltaYmid IN MICRON for this animal with respect to origin (2.3)
        if ~isempty(yMid)
            deltaYmid(n) = (yMid - xyStart(2))* scale1D * yFactor; % now calculates it in MICRON (4.7), took opposite sign (4.11 consistently with macrocaetes)
%           deltaYmid(n) = (xyStart(2) - yMid)* scale1D * yFactor; % now calculates it in MICRON (4.7)
        end

            %%% loading GRID information
            AnimalGridList{n} = load(pathGridDefFile);
            
            if ismember( allAnimals{n}, avgAnimals )
                
                %%% loading AOT backup
                tmpAOTpath = [pathFolderAOT filesep gridSpecs filesep averageFolderName filesep 'mean_AOT_' allAnimals{n}];
                AOTbu = load(tmpAOTpath);
                
                %%% update AreaRatios (tobereplaced by arearatios from CPT)
                [AreaRatios, AOTbu] = AreaRatiosAssigner(AOTbu);
                save(tmpAOTpath, 'AreaRatios', '-append');   % appending "AreaRatios" to existing backup
                
                %%% store backup for averaging
                AnimalAOTList{tmpIndex} = AOTbu;
                
                %%% loading macrochaetes clicks IN MICRON AND RESCALING THEM (mod 4.7)
                if exist([pathFolderSR filesep 'Macro_XYs_' allAnimals{n} '.txt'],'file')
                    macro(:,:,tmpIndex) = load([pathFolderSR filesep 'Macro_XYs_' allAnimals{n} '.txt']);
                    % Stores in MICRON because images can be at different resolution between animals (4.7)
                    macro(:,1,tmpIndex) = (macro(:,1,tmpIndex) - xyStart(1)) * scale1D * xFactor; % 4.7
                    macro(:,2,tmpIndex) = (macro(:,2,tmpIndex) - xyStart(2)) * scale1D * yFactor; % 4.7
                else 
                    warning(strcat("No folder found at ", [pathFolderSR filesep 'Macro_XYs_' allAnimals{n} '.txt', ' this could cause AOA to fail']))
                end
                tmpIndex = tmpIndex + 1;
            end
            clear cloneMaskFrame cloneMaskTime
            fprintf(' Done\n')
        end
   
        %%% averaging landmarks
        if ~exist('macro','var')
            macro = nan(16,2,nAvgAnimals);
        end
        meanMacrocaetesRaw = zeros(2,size(macro,1)); % now ONLY contains macro XYs
        meanMacrocaetesRaw(1:2,:) = nanmean(macro,3)';
        if ~exist('deltaYmid','var')
            meanDeltaYmidRaw = nan;
        else
            meanDeltaYmidRaw = nanmean(deltaYmid); % 2.2
        end
        
        OutputPathName = [PathName filesep 'AOA_' mapAnimal '_' num2str(timeWidthAll(t)) 'h_' num2str(timeOverlapAll(t)) 'olap']; % 4.3
        
%         % REconverting back into PIXELS with refScale1D (4.7)
%         meanMacrocaetes = meanMacrocaetesRaw/PLOT.refScale1D;
%         meanDeltaYmid = meanDeltaYmidRaw/PLOT.refScale1D;
%         % NB: this step is not necessary, but it enables to keep using the
%         % same parameter values ("scaleRatios" in particular) that were used
%         % to draw maps during the SAP processing.

        %%% calling AOA
        fprintf('Averaging animals ...\n')
        AverageOverAnimals
        fprintf('Done\n\n')
    end
end


%% DBA - Advanced %%

DBAname = [deltaAnimals{1} '-' deltaAnimals{2}];

if DBA
    
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    disp('Starting DBA processing ...')
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    
    nTimeAvg = length(timeWidthAll);
    for t = 1:nTimeAvg
        
        disp('Loading backups...')
        
        PLOT.plot = makePlotsAllAOT(t);
        LoadedBackupsRaw = cell(1,2);
        
        % Average "animal" # 1:
        fileName1 = [PathName filesep 'AOA_' deltaAnimals{1} '_' num2str(timeWidthAll(t)) 'h_' num2str(timeOverlapAll(t)) 'olap' filesep 'AOA_backup'];
        disp(fileName1);
        LoadedBackupsRaw{1} = load(fileName1);
        
        % Average "animal" # 2
        fileName2 = [PathName filesep 'AOA_' deltaAnimals{2} '_' num2str(timeWidthAll(t)) 'h_' num2str(timeOverlapAll(t)) 'olap' filesep 'AOA_backup'];
        disp(fileName2);
        LoadedBackupsRaw{2} = load(fileName2);

        % output folder path
        OutputPathName = [PathName filesep 'DBA_' DBAname '_' num2str(timeWidthAll(t)) 'h_' num2str(timeOverlapAll(t)) 'olap'];
        
        %%% calling DBA
        fprintf('Running DBA ...\n')
        DifferenceBetweenArchetypes
        fprintf('Done\n\n') 
    end
end



%% POA - Advanced %%

if POA
    
    % overwritting plot value
    DISPLAY.plotType = 'circle';
    QKillTr = 0;
    
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    disp('Starting POA processing ...')
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    fprintf('\n')
    
    nTimeAvg = length(timeWidthAll);
    for t = 1:nTimeAvg
        
        %%% Defining quantities for THIS time averaging (2.5)%%
        TIME.animalTimeOverlap = timeOverlapAll(t);
        TIME.animalTimeWidth   = timeWidthAll(t);
        TIME.timeStart = timeStart;
        TIME.timeStop = timeStop;
        PLOT.plot = makePlotsAllAOT(t);
        
        uTIME = TIME;
        uTIME.animalTimeWidth = uTimeWidth;
        uTIME.animalTimeOverlap = uTimeOverlap;
        
        %%% folder path initialisation
        poaAnimal = mapAnimal;
        if strcmp(OnameProjection,'DBA')
            poaAnimal = DBAname;
        end
        animalProjectionFolder = [OnameProjection '_' poaAnimal '_' num2str(timeWidthAll(t)) 'h_' num2str(timeOverlapAll(t)) 'olap' ];  % 4.3
        animalProjectorFolder  = [uOname '_' uAnimal   '_' num2str(uTimeWidth)      'h_' num2str(uTimeOverlap)   'olap'   ]; % 4.3
        OutputPathName = [PathName filesep animalProjectionFolder];
        
        %%% Loading backup of quantity to be projected:
        fprintf('Fetching backup data A to be projected on backup data B ...\n');
        fileNameA = [PathName filesep animalProjectionFolder filesep OnameProjection '_backup'];
        disp(['Fetching ' fileNameA '...'])
        LoadedBackupsPOA{1} = load(fileNameA);
        
        %%% Loading backup of quantity to use as unitary tensor for projection:
        fileNameB = [PathName filesep animalProjectorFolder  filesep uOname '_backup'];
        disp(['Fetching ' fileNameB '...'])
        LoadedBackupsPOA{2} = load(fileNameB);

        
        %%% calling POA suite
        fprintf('Projecting animals ...')
        ProjectionOverAnimals
        fprintf('Done\n\n')
    end
end


%% PTE - Advanced %%

if PTE

    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    disp('Starting PTE processing ...')
    disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
    fprintf('\n')
    
    if ~exist('Qfactor','var') || isempty(Qfactor) || (length(Qfactor) ~= length(QnamePTE))
        Qfactor = ones(size(QnamePTE));
    end
    
    % Switch between AOA & DBA (4.9)
    if strcmp(QplotOrigin,'AOA')
        PTEname = mapAnimal;     
    elseif strcmp(QplotOrigin,'DBA')
        PTEname = DBAname;
    else
        fprintf('\nERROR: parameter "QplotOrigin" can only be "AOA" or "DBA"!!!\n')
    end
    
    nTimeAvg = length(timeWidthAll);
    for t = 1:nTimeAvg
        
        TIME.animalTimeWidth = timeWidthAll(t);
        TIME.animalTimeOverlap = timeOverlapAll(t);
        
        fprintf('Fetch all available backup ...')
        InputPathName = [PathName filesep QplotOrigin '_' PTEname '_' num2str(TIME.animalTimeWidth) 'h_' num2str(TIME.animalTimeOverlap) 'olap'];  % 4.9
%         InputPathName = [PathName filesep 'AOA_' mapAnimal '_' num2str(TIME.animalTimeWidth) 'h_' num2str(TIME.animalTimeOverlap) 'olap'];  % 4.3
        % loading AOA OR DBA backup
        backupPathName = [QplotOrigin '_backup.mat']; % 4.9
%         backupPathName = ['AOA_backup.mat'];
        backupPathPTE = [InputPathName filesep backupPathName];
        if exist(backupPathPTE, 'file')
            BACKUP = load( backupPathPTE );
        end
        
        %%% NOT loading POA backup anymore but defining "Qproj":
        if any(strcmp('uPar',Qtags)) || any(strcmp('uOrt',Qtags)) % ONLY if asking for projection onto 'uPar' or 'uOrt' (4.8)
            animalProjectorFolder  = [uOname '_' uAnimal   '_' num2str(uTimeWidth)      'h_' num2str(uTimeOverlap)   'olap'   ]; % 4.3
            fprintf('Loading animal backup to be used for projection ...\n');
            fprintf(['\tLoading ' uAnimal ' avg ' num2str(uTimeWidth) 'h with ' num2str(uTimeOverlap) ' overlap, from ' timeStart ' to ' timeStop ' APF ...\n'])
            bBackup = load([PathName filesep animalProjectorFolder  filesep uOname '_backup']);
            Qproj = eval(['bBackup.' uQname ';']);
            fprintf('Done\n')
        end
        
        % managing output path
        OutputPathName = InputPathName;
        
        colorsPlotSize = [ 1 0 0 ; 0 1 0];
        
        fprintf('Running PTE ... \n')
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        PlotTimeEvolution
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fprintf('Done\n')
    end
end


%% History %%

% 03/10/2024: 4.11 (Boris)
% - fixed yMid that was strangely always used with a minus sign, which was
% not consistent with treatment of macrocaetes coordinates.
% - added storage of gridColor, gridLineWidth and refScale1D in DISPLAY for
% convenience

% 29/09/2020: 4.10 (Boris)
% - defined "meanMacrocaetesRaw" and "meanDeltaYmidRaw" that are in MICRONS
% and have the macrocaetes barycenter as origin, so they could be
% transfered to AOA to be saved in backup.

% 23/06/2020: 4.9 (Boris)
% - support of DBA time evolution plots in PTE

% 28/05/2020: 4.8 (Boris)
% - reintroduction of DBA
% - introduction of "PlotAllTimeRanges" execution at the very beginning.

% 29/04/2020: 4.7 (Boris)
% - fixed and improved handling of macrocaetes and midline by directly BOTH
% rescaling them with factors along x and y and by storing them in MICRON,
% thereby making it possible to process animals having different scale1D.
% NB: now uses "PLOT.refBoxSizeMicron" and "PLOT.refScale1D" defined in
% MAP_parameters.

% 26/11/2019: 4.6 (Boris)
% - made PTE process ALL values in "timeWidthAll" (used to process just the
% second one).

% 20/09/2019: 4.5 (Boris)
% - added "cloneNameList" when need to define SAP_info variable "cloneName"
% PRIOR TO loading of SAP_info file.

% 02-15/07/2019: 4.4 (Boris)
% - LocalTimeAnalysis (LTA) became PlotTimeEvolution (PTE)
% - many PTE related improvements 

% 27/06/2019: 4.3 (Boris)
% - now rounding "timeOverlapAll" and "uTimeOverlap" right at the top
% - moved "olap" tag to the end of folder names

% 28/06/2018: 4.2 extracted from MAP_parameters (Boris)
% - now uses "fontSizeInfo" value from MAP_parameters (4.2)

% 27/06/2018: 4.1 (Boris)
% - fixing RA execution after Stephane update

% 24/05/2018: 4.0 (Stephane)
% - major update to make AOA, POA and LTA work again

% 24/04/2018: 3.0 became "MAP_parameters" (Boris)
% - included execution of "RescaleAnimals" v4.0 that now integrates
% "CreateArchetype".


