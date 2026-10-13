% SingleAnimalProcessing (SAP)
%
% Script running PIV, SIA, CT,... successively or separately. 
% Animal specific parameters, paths and frame to process are specified in
% "SAP_info_(animal)" while program to run and other parameters are
% specified in "SAP_parameters".This enables to easily process several
% movies of different animals using the exact same parameters.
%
% Version 8.21 (created from SAP_parameters 8.3)
% Boris Guirao


%% Updates/overrides of parameters %%

% opengl hardware % to fix poor rendering of saved images! (8.7)

%%% Defines today's string to save txt files (7.1)
today = datestr(now,29);                      % format # 29 displays date yyyy-mm-dd style. Look up "date" for details (7.1)

%%% Turning off warnings and clearing workspace:
%-----------------------------------------------------------------------------------------------------------------------
warning off Images:initSize:adjustingMag
warning off MATLAB:MKDIR:DirectoryExists
warning off MATLAB:xlswrite:AddSheet    
warning off MATLAB:Figure:RecursionOnClose  % 5.0
warning off MATLAB:singularMatrix           % 6.3
warning off MATLAB:nearlySingularMatrix     % 6.3
%-----------------------------------------------------------------------------------------------------------------------

%%% Time Rescaling: correcting "dt" according to temperature (6.3),
%-----------------------------------------------------------------------------------------------------------------------
fprintf('\n')
if temperature == 29
    dt = dt / 0.9;          % to compare velocities, constriction rates... between 25 and 29 movies, dt must be corrected
    disp(['WARNING "SAP": "SAP_info" parameter "dt" has been updated to ' num2str(dt) ' since temperature = 29!'])
elseif temperature ~= 25
    disp(['ERROR "SAP": "SAP_info" parameter "temperature" (here ' num2str(temperature) ') can only be 25 or 29!'])
    return
end
dtH = dt/60;                % defines time interval in HOURS (7.8)
% NB: as of SAP_parameters 6.3 (and TA 3.2), "dt" HAS ALREADY BEEN CORRECTED ACCORDING TO TEMPERATURE
%-----------------------------------------------------------------------------------------------------------------------

% Checking "halfNotum" (7.12)
%-----------------------------------------------------------------------------------------------------------------------
nMacroMAXtime = 2;      % Default number of macrochaeteae to click for TIME registration
nMacroMAXspace = 8;     % Default number of macrochaeteae to click for SPACE registration
if halfNotum == 'l'
    sideStr = 'left';   
elseif halfNotum == 'r'
    sideStr = 'right';
elseif halfNotum == 'b'
    sideStr = 'both';
    nMacroMAXtime = 4;
    nMacroMAXspace = 16;
else
    disp('SAP ERROR: parameter "halfNotum" can only be "l", "r" or "b"!')
    return
end
%-----------------------------------------------------------------------------------------------------------------------

% Turning "clickTime" into "clickFrame" (7.12)
if strcmp(clickTime, 'start')
    clickFrame = startFrame;
    clickTime = frame2time(startFrame, timeRef, frameRef, dt,'str');
elseif strcmp(clickTime, 'final')
    clickFrame = finlaFrame;
    clickTime = frame2time(finalFrame, timeRef, frameRef, dt,'str');
else
    clickFrame = time2frame(clickTime, timeRef, frameRef, dt);
    clickFrame = round(clickFrame);
end


% checking "renormM" (7.5, 7.8)
if ~ismember(renormM, {'nLinks' ; 'nCells'})
    disp('SAP ERROR: parameter "renormM" must either be "nLinks" or "nCells"!')
    return
end


%%% Gets number of frames to process
%-----------------------------------------------------------------------------------------------------------------------
CustomColors; % loads CustomColors once and for all!! (5.0)
nRawImages = length(filenameRaw);                       % number of raw images defined here (6.5)
digitsFormat =['%0' num2str(nDigits) 'd'];              % digitsFormat now defined in SAP, % 5.2                                  
printFormat = ['-d' imageFormatOutput];                 % 6.0
printResolution = ['-r' num2str(imageResolution)];      % 6.0
rootFilename = filenameRaw{1};                          % 5.0
frames2process = startFrame:finalFrame;                                          % 5.0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% frames2process = fliplr(frames2process); % WARNING
% h = warndlg('"frames2process" HAS BEEN REVERSED!', 'WARNING!');
% uiwait(h);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nFrames = length(frames2process);           % 7.4
% nFrames = finalFrame - startFrame + 1;
nInterFrames = nFrames - 1;
%-----------------------------------------------------------------------------------------------------------------------

%%% Manage path and filename of segementation and ROI images (7.11)
%-----------------------------------------------------------------------------------------------------------------------
pathFolderSEG = [pathFolderRaw filesep 'SEG_' Animal];              % SEG folder containing both segmentation and roi files
pathFolderRES = [pathFolderSEG filesep 'results_' Animal];          % 7.11
pathFolderROI = [pathFolderSEG filesep 'roi_' Animal];
pathFolderMRK = [pathFolderRES filesep 'markers_' Animal];
pathFolder = pathFolderRES;

% Filenames for segmented images and region of interest 
filename = ['seg_' filenameRaw{1}];  
roiname = ['roi_' filenameRaw{1}];
imageFormat = 'png'; 
%-----------------------------------------------------------------------------------------------------------------------


%%% Determines "gridFrame", "imageSize" and loads segmented image to be used for grid plot ("refImage") (7.1, 7.7, 7.8)
%-----------------------------------------------------------------------------------------------------------------------
[gridFrame, gridTime] = gridFrameTimeAssigner(gridTime,timeRef,frameRef,dt,startFrame,finalFrame); % Determines "gridFrame" (6.7)

gridImagePath = [pathFolder filesep filename num2str(gridFrame, digitsFormat) '.' imageFormat];
startImagePath = [pathFolder filesep filename num2str(startFrame, digitsFormat) '.' imageFormat];
rawImagePath = [pathFolderRaw filesep rootFilename num2str(startFrame, digitsFormat) '.' imageFormatRaw];

% Checking that raw images are 8bit (8.9)
refImage = imread(rawImagePath); % ALWAYS loads raw image to check it is 8bits and NOT 16 (8.9)
if ~isa(refImage,'uint8')
    warndlg(['"' Animal '" raw images are NOT 8bit!! Please convert your images to 8bit with ImageJ. Stopped Execution.'],'WRONG IMAGE CLASS!')
    return
else
    disp(['Checked that "' Animal '" raw images are 8bit.'])
end

% Overwritting "refImage" if segmentation done:
if exist(gridImagePath,'file')
    refImage = imread(gridImagePath);
elseif exist(startImagePath,'file')      % uses first image to get "imageSize" if "gridImage" unfound (7.7)   
    refImage = imread(startImagePath);  
end
imageSize = size(refImage);
positionFullScreen = FullScreenDisplay(imageSize);  % 'Position' vector to display image in full screen (native ratio, no grey borders) (7.12)
%-----------------------------------------------------------------------------------------------------------------------


%%% Starting to fill "PLOT" structure (7.7)
%-----------------------------------------------------------------------------------------------------------------------
PLOT.startFrame = startFrame;
PLOT.finalFrame = finalFrame;
PLOT.dt = dt;
PLOT.scale1D = scale1D;
PLOT.frameRef = frameRef;
PLOT.timeRef = timeRef;
PLOT.Animal = Animal;
PLOT.fontSizeInfo = fontSizeInfo;
PLOT.xyOffset = xyOffset;
PLOT.scaleBarWidth = scaleBarWidth;
PLOT.scaleBarLength = scaleBarLength;
PLOT.colorInfo = colorInfo;
PLOT.minimalInfoDisplay = minimalInfoDisplay;
PLOT.colorBarXYWH = colorBarXYWH;
PLOT.imageSize = imageSize;
PLOT.circleScaleFactor = circleScaleFactor;
PLOT.colorBorderCells = colorBorderCells;
PLOT.colorFLCells = colorFLCells;           % 8.6
PLOT.colorMacrochaetes = colorMacrochaetes; % 8.6

PLOT.colorJunctions = colorJunctions; % 8.20
PLOT.gridBulkThreshold = gridBulkThreshold;
PLOT.displayImages = displayImages;

%-----------------------------------------------------------------------------------------------------------------------


%%% Assigning default values when timeStart, timeStop and timeWidth are empty (6.2, 7.7):
%%% Defining frameStart, frameStop, interframeWidth
%-----------------------------------------------------------------------------------------------------------------------
if ~exist('MAA','var') % don't go through this if MAA
    % NB: MAA stands for MultipleAnimalAnalysis (a program loading multiple
    % animal backups to figure out some statistics such as division
    % angles), which is different than MAP.
    if isempty(timeStart)
        timeStart = frame2time(startFrame, timeRef, frameRef, dt,'str'); % mod 6.3
        disp(['WARNING  "SAP": empty parameter "timeStart" was assigned to ' timeStart ' corresponding to frame #' num2str(startFrame) '!'])
    end
    if isempty(timeStop)
        timeStop = frame2time(finalFrame, timeRef, frameRef, dt,'str'); % mod 6.3
        disp(['WARNING "SAP": empty parameter "timeStop" was assigned to ' timeStop ' corresponding to frame #' num2str(finalFrame) '!'])
    end
    
    %%% Converting "timeStart", "timeStop" into frame numbers:
    frameStart = time2frame(timeStart, timeRef, frameRef, dt);   % frame start CAN BE NON INTEGER mod 6.3
    frameStop = time2frame(timeStop, timeRef, frameRef, dt);     % frame start CAN BE NON INTEGER mod 6.3
    
    timeWidthMax = (frameStop-frameStart)*dt/60;    % only one width in that case (moved 8.5)
    
    if isempty(timeWidthAll)
        timeWidthAll = timeWidthMax;    % only one width in that case (mod 7.8, 8.5)
        timeOverlapAll = 0;                             % 7.8
        disp(['WARNING "SAP": empty parameter "timeWidthAll" will be assigned to ' num2str(timeWidthAll)...
            'h corresponding to frame interval # ' num2str(frameStart) '-' num2str(frameStop) ...
            ', and "timeOverlapAll" set to 0'])
    end
    
    % Replacing values larger than "timeWidthMax" in "timeWidthAll" by "Inf" (8.5)
    locTooLargeTF = timeWidthAll > timeWidthMax;
    if any(locTooLargeTF)
        timeWidthAll(locTooLargeTF) = Inf;
        disp(['WARNING "SAP": some values in "timeWidthAll" are larger than max value ' num2str(timeWidthMax)...
            'h corresponding to frame interval # ' num2str(frameStart) '-' num2str(frameStop) ' and have been set to "Inf"!'])
    end
    
    % Replacing "Inf" values in "timeWidthAll" by max possible values (8.2)
    locInfTF = timeWidthAll == Inf;
    if any(locInfTF)
        timeWidthAll(locInfTF) = timeWidthMax;            % replace Inf values by timeWidthMax 
        timeOverlapAll(locInfTF) = 0;                     % updating "timeOverlapAll" accordingly
        disp(['WARNING "SAP": "Inf" values in "timeWidthAll" will be assigned to ' num2str(timeWidthMax)...
            'h corresponding to frame interval # ' num2str(frameStart) '-' num2str(frameStop) ...
            ', and corresponding "timeOverlapAll" set to 0'])
    end
end
%-----------------------------------------------------------------------------------------------------------------------


%%% Setting "newJuncDisplayFrames/Times" and "junctionTag" (7.5) (relevant for CTD & CPT)
%-----------------------------------------------------------------------------------------------------------------------
junctionTag = [];
earliestTime = frame2time(startFrame,timeRef, frameRef, dt, 'dec');
earliestTime = roundn(earliestTime, -2);

if displayNewT1Junctions || displayNewDivJunctions 
    
    % Default
    newJuncDisplayFrames = time2frame(newJuncDisplayTimes,timeRef,frameRef,dt); 
    newJuncDisplayFrames = round(newJuncDisplayFrames);                           % Has to be an actual frame number
    
    if isempty(newJuncDisplayTimes) || newJuncDisplayTimes(1) < earliestTime 
        
%         warndlg(['"newJunctionStartTime" (' num2str(newJuncDisplayTimes(1)) ') was empty or too low and has been set to minimal '...
%             num2str(earliestTime) ' hAPF!!'],'WARNING "SAP"!');
        newJuncDisplayTimes(1) = earliestTime;
        newJuncDisplayFrames(1) = startFrame;
    end
    % setting "junctionTag"
    preTagDiv = [];
    if displayNewDivJunctions
        preTagDiv = 'Div';
    end
    preTagT1 = []; %#ok<*NASGU>
    if displayNewT1Junctions
        preTagT1 = 'T1';
    end
        junctionTag = ['_newJ' preTagDiv preTagT1 '=' num2str(newJuncDisplayTimes) 'h']; % 7.7
%         junctionTag = ['_newJDT=' num2str(newJuncDisplayTimes) 'h'];
end
%-----------------------------------------------------------------------------------------------------------------------


%% DEFINING PATHS TO BACKUP FOLDERS (mod 5.0, 7.3)%% 

pathSaveFolder = [pathFolderRaw filesep 'SAP_' Animal ];            % Path to Parent SAP_Animal folder
if ~exist(pathSaveFolder,'dir') % 7.8
    mkdir(pathSaveFolder)
end

%%% Defins path to "SAPparameterFile" (7.8)
SAPparameterFile = [pathSaveFolder filesep 'SAPparameters.mat'];

% Defining "VMtag" (6.2, 8.2)
%---------------------------------------------------------------------------------------------------------
if strcmp(modeVM,'CT')
    VMtag = 'CT';               % 8.2
elseif strcmp(modeVM,'PIV')
    VMtag = ['PIV.' PIVgridVM]; % 8.2, use of "PIVgridVM" 8.8
else
    disp('VM ERROR: parameter "modeVM" can onlby be "PIV" or "CT"!. Stopped execution.')
    return
end
% NB: Velocity and derived deformation maps will be nearly independant of
% PIVgrid when using Cell Tracking as the latter is midly impacted by a
% change of grid. However, results directly based on PIV will be strongly
% impacted => hence the specification in "VMtag" for PIV, NOT for CT.
%---------------------------------------------------------------------------------------------------------


% PATHS TO PROGRAM FOLDERS:
%---------------------------------------------------------------------------------------
% pathFolderSTR = [pathFolderRaw filesep 'STR_' Animal];             }                     % "STR" for SpaceTimeRegistration  (7.12)
pathFolderTR =  [pathSaveFolder filesep 'timeReg_' Animal];                              % "TR" for "TimeRegistration" (7.12), mod 8.0
pathFolderSR =  [pathSaveFolder filesep 'spaceReg_'  Animal '_' num2str(clickFrame)];    % "SR" for "SpaceRegistration" (7.12), mod 8.0

pathFolderPIV =    [pathSaveFolder filesep 'PIV_' Animal filesep PIVgrid 'Grid'];       % Path to PIV Backups (7.8), mod 8.0
pathFolderVM =     [pathSaveFolder filesep 'VM_' Animal filesep VMtag];                 % NOT used since VM NO longer creating folder, BUT called by AOT
pathFolderPIV4VM = [pathSaveFolder filesep 'PIV_' Animal filesep PIVgridVM 'Grid'];     % Path to PIV Backups TO BE USED BY VM (8.8)

pathFolderCT =     [pathSaveFolder filesep 'CT_' Animal];           % 7.8
pathFolderJNK =    [pathSaveFolder filesep 'JNK_' Animal];
pathFolderKYM =    [pathSaveFolder filesep 'KYM_' Animal]; 
pathFolderSIA =    [pathSaveFolder filesep 'SIA_' Animal];          % not directly pointing to backup folder (7.3)
pathFolderCTD =    [pathSaveFolder filesep 'CTD_' Animal];        	% removed info on tracking type (always MT) and PIV grid (7.3)
pathFolderCPT =    [pathSaveFolder filesep 'CPT_' Animal];          % 7.1
pathFolderGEP =    [pathSaveFolder filesep 'GEP_' Animal];          % (stephane)
pathFolderCTA =    [pathSaveFolder filesep 'CTA_' Animal];         	% 7.5
pathFolderAOS =    [pathSaveFolder filesep 'AOS_' Animal];      	% NB: backups saved in GridSpecs dependant SUBfolder (5.0) 
pathFolderAOT =    [pathSaveFolder filesep 'AOT_' Animal];          % 6.2
pathFolderTA =     [pathSaveFolder filesep 'TA_'  Animal];         	% much shortened (7.5)

pathFolderGV =     [pathSaveFolder filesep 'GV_' Animal];           % folder where GetVertex output will be stored (former "folder_path_in") (7.8)
pathFolderSTPE =   [pathSaveFolder filesep 'STPE_' Animal];         % folder where STPE output will be stored "save_path_STPE" became "Path_folder_STPE"
pathFolderMSM =    [pathSaveFolder filesep 'MSM_' Animal];          % folder where MSM output will be stored 
pathFolderSM =     [pathSaveFolder filesep 'SM_'  Animal];       	% NB: backups saved in GridSpecs dependant SUBfolder (5.0)

pathFolderTMP = [pathFolderRaw filesep 'TMP_' Animal];              % TMP folder containing temporary data for computing the segmentation
pathFolderCORR = [pathFolderTMP filesep 'autocorrection'];
pathFolderCLR = [pathFolderTMP filesep 'cleaningFilter'];
parhFolderWPRS = [pathFolderTMP filesep 'WatershedPostRunSegmentation'];
pathFolderGUI  = [pathFolderTMP filesep 'interface'];
pathFolderCEL  = [pathFolderTMP filesep 'cellout'];
pathFolderTCT  = [pathFolderTMP filesep 'temporaryCT'];
pathFolderTCTD  = [pathFolderTMP filesep 'temporaryCTD'];
pathFolderONEAT = [pathFolderRaw filesep 'ONEAT_' Animal];
pathFolderONEATa = [pathFolderONEAT filesep 'False_Apoptosis'];
pathFolderONEATd = [pathFolderONEAT filesep 'False_Divisions'];
%---------------------------------------------------------------------------------------

% FILENAMES of BACKUP FILES:
%---------------------------------------------------------------------------------------
% Backup filenames (7.2)
filenamePIV =  ['PIV' '_' Animal];                  % 7.8
filenameGEP =  ['GEP' '_' Animal];                  % (Stephane)
filenameVM  =  ['VM.' VMtag '_' Animal];            % 8.2
% filenameVM  =  ['VM'  '_' Animal];                % also removed "modeTag" and "PIVgrid" (7.2)

% filenameCT =    ['CT' '_' Animal];                % 7.8
filenameSIA =  ['SIA' '_' Animal]; 
filenameCTA =  ['CTA' '_' Animal];                  % 7.5
filenameCPT =  ['CPT' '_' Animal];                  % removed origin of tracking ("MT", always used, "OMT", no longer used) (7.0) AND "CT_PIVgrid" (7.1)
filenameAOS =  ['AOS' '_' Animal];                  % removed '_Backup' so that TA,SM and AOS are formatted the same 6.2
filenameAOT =  ['AOT' '_' Animal];                  % 6.2
filenameCTD =  ['CTD' '_' Animal];                  % removed info on tracking type (always MT) and PIV grid (7.3)
filenameTA =   ['TA'  '_' Animal];                  % shortened (7.5)

filenameGV =   ['GV' '_' Animal];                  % 7.8
filenameSTPE = ['STPE' '_' Animal];                % 5.0
filenameMSM =  ['MSM'  '_' Animal];                % 5.0
filenameSM =   ['SM'   '_' Animal];                % 5.0
%---------------------------------------------------------------------------------------

% Path to Executable 7.11, 8.0, 
% 08/06/23 => Added start of cross-platform support
% 19/07/23 => Added a mean of finding the correct path in all cases using regex 
% 10/10/23 => Completely refractored the function to handle more OS more
% robustly and clean the code a bit

pathstr = path;
%---------------------------------------------------------------------------------------
%{
if ispc
    pathsep =";";
elseif isunix
    pathsep =":";
else
    disp('Platform not supported yet, need to compile the exectubles for your architecture, subsequent code will most likely fail')
end

paths = strsplit(pathstr, pathsep);
selectedPaths = paths(endsWith(paths, 'AnimalProcessing'));
selectedPath = selectedPaths(1);

if ispc
    pathFolderEXE = [selectedPath filesep 'SAP' filesep 'SAP_Routines' filesep 'Executable' filesep 'windows_x86'];
elseif isunix
    % Here we correct all the junk in the path in the case where it is in
    % dropbox
    selectedPath = correctPath(selectedPath);
    pathFolderEXE = [selectedPath filesep 'SAP' filesep 'SAP_Routines' filesep 'Executable' filesep 'linux_x86'];  % NB: the "" prevente space character to interfere; mod 8.3
end

    % 
episegExe = [pathFolderEXE filesep 'EpitheliumSegmentation']; 
markerWatershedExe = [pathFolderEXE filesep 'MarkerControledWatershed'];
trackingExe = [pathFolderEXE filesep 'CellTracking'];
junctExe = [pathFolderEXE filesep 'c18'];
cellExe = [pathFolderEXE filesep 'cell'];
SIAexe = [pathFolderEXE filesep 'SegmentedImageAnalysis'];
GVexe = [pathFolderEXE filesep 'GetVertex' filesep 'GetVertex']; % 8.0
if ispc() % manage exe extention if windows os
    trackingExe = [trackingExe '.exe'];
    cellExe = [cellExe '.exe'];
    episegExe = [episegExe '.exe'];
    SIAexe = [SIAexe '.exe'];
    GVexe = [GVexe '.exe'];    % 8.0
    junctExe = [junctExe '.exe'];
    markerWatershedExe = [markerWatershedExe '.exe'];
end 
%}




% Get the system's PATH
pathstr = path;

% Determine the path separator based on the OS
if ispc
    pathsep = ";";
elseif isunix
    pathsep = ":";
else
    disp('Platform not supported yet. Subsequent code will most likely fail.')
end

% Split the PATH string into an array
paths = strsplit(pathstr, pathsep);

% Filter paths that end with 'AnimalProcessing'
selectedPaths = paths(endsWith(paths, 'AnimalProcessing'));
selectedPath = selectedPaths{1};  % Assuming that selectedPaths is non-empty

% Determine the architecture for macOS
if ismac()
    [~,result] = system('uname -m');
    is_m1_mac = strcmp(strtrim(result),'arm64');
else
    is_m1_mac = false;
end

% Construct the folder path for executables
if ispc
    pathFolderEXE = fullfile(selectedPath, 'SAP', 'SAP_Routines', 'Executable', 'windows_x86');
elseif isunix
    pathFolderEXE = fullfile(selectedPath, 'src', 'cpp_executables', 'ubuntu_20.04_x86');
elseif ismac
    if is_m1_mac
        pathFolderEXE = fullfile(selectedPath, 'AnimalProcessing', 'src', 'cpp_executables', 'macOs_arm');
    else
        pathFolderEXE = fullfile(selectedPath, 'AnimalProcessing', 'src', 'cpp_executables', 'macOs_x86');
    end
end

% List of executables
exeNames = {'EpitheliumSegmentation', 'MarkerControledWatershed', 'CellTracking', 'c18', 'cell', 'SegmentedImageAnalysis', 'GetVertex'};

% Construct full paths for each executable and append '.exe' extension if the platform is Windows
for i = 1:numel(exeNames)
    fullPath = fullfile(pathFolderEXE, exeNames{i});
    
    % Escape special characters in the path
    fullPath = escape_cmd(fullPath);
    
    if ispc
        fullPath = [fullPath '.exe'];
    end
    
    % Check if the executable file exists (note: check before escaping)
    %{
    if ~isfile(fullPath)
        warning(['Executable ' exeNames{i} ' does not exist at ' fullPath]);
    end
    %}
    
    % Assign the executable path to a variable
    eval([exeNames{i} 'Exe = fullPath;']);
end




%---------------------------------------------------------------------------------------

trackingFolder = [pathFolderCT filesep PIVgrid 'Grid']; % 7.8, removed '_Backups' (8.3)


%% Checks existence and value of 'SAPcall': just loads SAP parameters (3.3, 5.0, 7.0, 7.7, 8.2)
%-----------------------------------------------------------------------------------------------------------------------
% HC = 0; % HC won't run if "'HolesCorrection_has_run.txt" already exists
if  exist([pathFolderSIA filesep 'HolesCorrection_has_run.txt'],'file')
    HC = 0; % does not run if txt file was found
end 
if exist('SAPcall','var') || exist('MAPcall','var') % mod 8.2
% if exist('SAPcall','var') && SAPcall
    
    TR =    0;                                  % "TimeRegistration" (NO PARAMETERS) (7.12)
    SR =    0;                                  % "SpaceRegistration" (NO PARAMETERS) (7.12)
    PIV =   0;                              	% "ParticleImageVelocimetry"
    GEP =   0;                                  % "GeneExpressionPattern"
    VM =    0;                                  % "VelocityMaps" (with PIVmode = 1; can also be run after cell tracking with PIVmode = 0)
    FFPB =  0;                                  % "FilterFourPixelBlocks" (NO PARAMETERS)
    SIA =   0;                                  % "SegmentedImageAnalysis"
    CT =    0;                                  % "CellTracking" (NO PARAMETERS)(7.8)
    HC =    0;                                  % "HolesCorrection" (NO PARAMETERS) (8.18) 
    CTD =   0;                                  % "CellTrackingDisplay"
    CPT =   0;                                  % "CellPatchTracking"
    CTA =   0;                                  % "CellTrackingAnalysis" (can also run before CPT in full image mode)
    AOS =   0;                                  % "AverageOverSpace"
    TA =    0;                                  % "TensorAnalysis"
    GV =    0;                                  % "GetVertex" (NO PARAMETERS)
    STPE =  0;                                  % "STPEstimate"
    MSM =   0;                                  % "MatlabShujiMatcher"
    SM =    0;                                  % "StressMap"
    AOT =   0;                                  % AverageOverTime    
end

allProgramsTF = [SR;TR;PIV;GEP;VM;FFPB;SIA;CT;CTD;CPT;CTA;AOS;TA;GV;STPE;MSM;SM;AOT]; % 7.3
%-----------------------------------------------------------------------------------------------------------------------


%% GRID VALIDATION by user, definition of "GRID_DEF" and "gridSpecs": clone Trackng vs Regular Grid (7.1,7.7) %%


if ~isempty(gridType) && (GEP || VM || CPT || AOS || TA || SM || AOT || POT || CTA...
        || (exist('MAA','var') && (strcmp(sthSetMode,'clone') || strcmp(sthSetMode,'roi')))...
        || exist('ROIcall','var') || exist('MAPcall','var')) % added MAPcall
    % NB: not going in if full image mode OR no program requiring grid plot), mod 7.10
    
    % Checking "gridType" here (7.5)
    if ~ismember(gridType,['E' ; 'L'])
        warndlg(['Parameter "gridType" (currently: "' gridType '") must be empty, "E" or "L".'],'Wrong "gridType" value!!')
        return
    end
    
    % overriding "cloneTracking" when "ROIcall" (from "MakeROImask" in "MakeAllMasks") (8.2)
    if exist('ROIcall','var')
        cloneTracking = false;
    end
    
    % "excludeLostCells" tag (8.7)
    elcTag = ['_elc_' num2str(excludeLostCells)];
%     elcTag = ''; % for MultiAnimalAnalysis

    if (~cloneTracking && ~exist('MAA','var')) || (exist('MAA','var') && strcmp(sthSetMode,'roi')) % CASE of ROI TRACKING (7.10)    
        
        % defining gridTag (after "if" 8.1)
        gridTag = '';
        if strcmp(gridType,'L') % mod 8.1
            gridTag = ['_' gridTime];
        else                            % E grid case: excludeLostCells then NOT relevant in CPT => NOT adding it to folder name (8.7)
            elcTag = '';
        end
        
        % ALWAYS creates grid:
        GRID_DEF = MakeGrid(imageSize, boxSize, xyStart, gridSize, gridColor, gridLineWidth, gridOverlap);
        % NB: NOW ALWAYS taking regular "boxSize", "xyStart" and "gridSize" values, AND "gridOverlap" now
        
        xywh = GRID_DEF.xywh;
        nx = GRID_DEF.Size(2); % 8.3
        ny = GRID_DEF.Size(1); % 8.3
        nBoxes = nx*ny;
        gridSize = GRID_DEF.Size; % 8.8
        
        % Defining "olapTag" (moved after grid creation in 8.8)
        olapTag = ''; % default value: not displaying overlap in folder name when empty or 0 (for simplicity AND compatibility)
        if gridOverlap > 0 && max(gridSize) > 1 % now checking that at least ONE dimension of grid is greater than one (8.6)
            olapTag =  ['_olap_' num2str(gridOverlap)];
        else
            gridOverlap = 0; % overriding overlap value when single compartment grid (8.6)
            fprintf('\nWARNING: parameter "gridOverlap" was set to 0 because grid only has 1 compartment!\n'); % 8.6
        end
        
        % Defines grid specific subfolder name:
        gridSpecs = [gridType 'Grid_xy_' num2str(xywh(1)) '_' num2str(xywh(2)) '_wh_' num2str(xywh(3)) 'x' num2str(xywh(4))...
            '_nynx_' num2str(ny) 'x' num2str(nx) gridTag olapTag elcTag]; % added ny*nx, gridTag (2.13), olapTag (3.1), elcTag (8.7)
                
        % Grid validation by user:
        gridTypeFull = 'LAGRANGIAN';     % default
        if strcmp(gridType,'E')
            gridTypeFull = 'EULERIAN'; % capitals
        end
        
        % Extra warning when plotting
        extraWarning = '';
        if CPT && strcmp(gridType,'E') && makeCPTimages
            extraWarning = 'NB: are you sure you want to plot CPT images with and EULERIAN grid?! If not, please set "makeCPTimages" to "false".';
        end
        

        if gridValidation && ~exist('MAA','var')  && ~exist('gridValidatedOnce','var')              % mod 7.10, mod 8.2
            
            [~, hGridFig] = PlotGrid(refImage, GRID_DEF);                                               % uses gridImage for grid plot; inside "if" (8.5)
            PlotMidline([], yMid, 'c');                                                                 % plots midline if y_mid not empty; inside "if" (8.5)
            
%             % displaying grid and saving grid image:
%             print(hGridFig, printFormat, printResolution, 'C:\DATA\Scaling\maxGrid.png'); 
            
            button = questdlg({['Use this ' gridTypeFull ' grid with the following parameters?'];'';...
                               ['gridOverlap = ' num2str(gridOverlap)] ;'';...                              % 7.6
                               ['gridTime = ' gridTime ' (time at which grid is applied)'] ;'';...          % 7.6
                               ['excludeLostCells = ' num2str(excludeLostCells)]; '';...                    % 7.4
                               ['nLayers = ' num2str(nLayers)] ;'';...                                      % 7.6
                               ['clickTime = ' clickTime '  (time of macro clicks, if any)'] ;'';...        % 7.6
                               ['resultsFolder = ' resultsFolder '  (folder to duplicate AOT maps)'] ;'';...% 8.7
                                extraWarning},...
                ['"' Animal '" ' gridTypeFull ' Grid Validation'],'Yes','No','Yes'); % added Animal in title (7.4)
            if ~strcmp(button,'Yes')
                disp('Grid not saved. Program stopped.');
                close;
                return
            end
        end
         
    elseif (cloneTracking && ~exist('MAA','var')) || (exist('MAA','var') && strcmp(sthSetMode,'clone')) % CASE of CLONE TRACKING (7.7)
        
        % defining cloneTag (8.1)
        cloneTag = '';
        if strcmp(gridType,'L') % mod 8.1
            
            if ~exist('cloneMaskFrame','var') || isempty(cloneMaskFrame) % 8.17
                % Determining "cloneMaskFrame" from "path2cloneMask" (8.3)
                cloneMaskFrameStr = path2cloneMask(end-4-nDigits+1:end-4); % removes .png or .tif at the end to only get frame number
                cloneMaskFrame = str2double(cloneMaskFrameStr);
            end
            
            cloneMaskTime = frame2time(cloneMaskFrame, timeRef, frameRef, dt, 'str');
            gridTime = cloneMaskTime;       % overriding "gridTime" with "cloneMaskTime" (8.3)
            gridFrame = cloneMaskFrame;     % 8.3
            cloneTag = ['_greyLevel_' num2str(greyLevelClone) '_' gridTime];
        end
        
        % Override gridType = 'E' if cloneTracking
        if cloneTracking && strcmp(gridType,'E')
            gridType = 'L';
            disp('WARNING "SAP": overridden gridType "E" into "L" to perform clone tracking!!');
        end
        
        % "yMid" CANNOT be empty if "matchingWTclone" is true (because used to flip actual clone) (7.3)
        if matchingWTclone == 1 && isempty(yMid)
            disp('SAP ERROR: one cannot have simultaneously "yMid" empty AND "matchingWTclone" set to "true"!!')
            disp('Stopped execution.')
            return
        end
        
        % defining cloneTag to differentiate the simple tracking of clones VS WT mirror parts
        if matchingWTclone
            cloneTag = [cloneTag '_WTclone']; % 8.1
        end
        
        % Loading clone AND filtering according to "greyLevelClone" (8.2)
        cloneImage = imread(path2cloneMask);            % loading clone binary mask  
        cloneImage = mat2gray(cloneImage);              % put [0,255] values back into [0,1] (8.2)
        cloneImage(cloneImage >= greyLevelClone) = 1;   % 8.2
        cloneImage(cloneImage < greyLevelClone) = 0;    % 8.2
        cloneImage = logical(cloneImage);               % making it binary
        
        cloneImageCC = bwconncomp(cloneImage,4);
        cloneImageLabels = labelmatrix(cloneImageCC); % REcreates the image labelled uint8 or uint16 according to the number of regions (2.15)
         
        nx = 2;                                 % *1st* COLUMN: FILTERED CLONE; *2nd* COLUMN WILL contain WT parts mirroring clone parts (% midline)
        ny = double(max(cloneImageLabels(:)));  % number of clones in image BEFORE filtering (8.10)
        % Cases according to "matchingWTclone" value (8.14)
        if matchingWTclone == 0
            nx = 1;                                 % NO WT part matching clone in that case (7.2)
        elseif matchingWTclone == 1
            if isempty(yMid)
                disp('CPT ERROR: "yMid" must be specified if "matchingWTclone" is set to 1!')
                return
            end          
        elseif matchingWTclone == 2
            ny = 1;                                             % all clone parts will be gathered together
            cloneImageLabels(cloneImageLabels > 0) = uint8(1);  % sets all 
        end
        nBoxes = nx*ny;
        
        GRID_DEF.Size = [ny nx];        % 8.3
        GRID_DEF.Color = gridColor;     % 8.3
        GRID_DEF.fullImage = false;     % required for TA (7.6)
        
        gridSpecs = ['Clone_' cloneName '_nynx_' num2str(ny) 'x' num2str(nx) cloneTag elcTag]; % only cloneTag (8.1), elcTag (8.7)
        

        if gridValidation && ~exist('MAA','var') && ~exist('gridValidatedOnce','var')    % Never validates grid when running MAA, mod 7.10, mod 8.2  
            
            hGridFig = figure('PaperPositionMode','auto');  % inside "if" (8.5)
            imshow(cloneImage,'Border','tight');            % inside "if" (8.5)      
            
            button = questdlg({ 'Use this CLONE with the following parameters?';'';...
                                ['matchingWTclone = ' num2str(matchingWTclone)];'';...                      % 7.2
                                ['gridTime = ' gridTime ' (time of clone mask)'];'';...                     % 8.1, mod 8.3
                                ['excludeLostCells = ' num2str(excludeLostCells)];'';...                    % 7.4
                                ['invertCloneMask = ' num2str(invertCloneMask)];'';...                      % 7.6
                                ['clickTime = ' clickTime ' (time of macro clicks, if any)'];'';...         % removed comment on "ny" not being accurate at this step (8.4)
                                ['resultsFolder = ' resultsFolder '  (folder to duplicate AOT maps)']},...  % 8.7
                        ['"' Animal '" Clone Validation'],'Yes','No','Yes'); % added Animal in title (7.4)
            
            if ~strcmp(button,'Yes')
                disp('Grid not saved. Program stopped.');
                close;
                return
            end
        end  
    end
    
    % Adding "excludeLostCells" value in "GRID_DEF" (7.6)
    if strcmp(gridType,'L')
        GRID_DEF.excludeLostCells = excludeLostCells;
    end
    
    % creating CPT grid folder (7.4)
    gridFolderCPT = [pathFolderCPT filesep gridSpecs];
    
    % defines "pathGridDefFile" storing grid definition info:
    pathGridDefFile = [gridFolderCPT filesep filenameCPT '_GridDef.mat'];
    
    % defines "pathCPTbackupFiles" full path to CPT backup files with ONLY "'_' num2str(fplot, digitsFormat) '.mat'" missing
    pathCPTbackupFiles = [gridFolderCPT filesep 'Backups' filesep filenameCPT];
    
    % creates CPT grid Folder if doesn't already exist (moved up 8.2)
    if ~exist(gridFolderCPT,'dir')
        mkdir(gridFolderCPT);
    end
    
    % If grid/clone already exists, checks "excludeLostCells" value (7.6)
    %---------------------------------------------------------------------------------------------------------
    if exist(pathGridDefFile,'file')

        if strcmp(gridType,'L') % 8.2
            
            existingGRID_DEF = load(pathGridDefFile);
            existingExcludeLostCells = existingGRID_DEF.excludeLostCells;
            
            % If different value, warns user and stops execution
            if existingExcludeLostCells ~= excludeLostCells
                warndlg({['This grid/clone backup already exists, but with a different value of "excludeLostCells" (' num2str(existingExcludeLostCells) ')!!'];'';...
                    'Please change value of "excludeLostCells" to match the one of found grid/clone, OR erase all related CPT backups and rerun it with new value.'},...
                    'WARNING "SAP": inconsistent "excludeLostCells" values!')
                disp('Program stopped.');
                close
                return
            end
        end
            
    else
        %%% Saving "GRID_DEF" backup file right away for non-segmented movies:
        save(pathGridDefFile,'-struct','GRID_DEF'); % 8.2
    end
    %---------------------------------------------------------------------------------------------------------
    
    
    % Adding grid/clone compartment numbers (8.11, 8.15)
    %---------------------------------------------------------------------------------------------------------
    if exist('hGridFig','var') % only does it when there is a figure opened (8.15)
        
        nBoxesPlot = nBoxes;
        
        if cloneTracking
            boxCentroidsPlot = regionprops(cloneImageCC,'Centroid');
            boxCentroidsPlot = struct2cell(boxCentroidsPlot); % makes it a cell array
            boxCentroidsPlot = cell2mat(boxCentroidsPlot');   % makes it a matrix
            
            if matchingWTclone
                nBoxesPlot = nBoxes/2;
            end
        else
            boxCentroidsPlot = GRID_DEF.Centroids;
            boxCentroidsPlot = boxCentroidsPlot(:);
            boxCentroidsPlot = cell2mat(boxCentroidsPlot);   % makes it a matrix
        end
        
        [I,J] = ind2sub(GRID_DEF.Size, (1:nBoxesPlot)');
        IJtext = [repmat('[',nBoxesPlot,1) num2str(I) repmat(',',nBoxesPlot,1) num2str(J) repmat(']',nBoxesPlot,1)];
        %text(boxCentroidsPlot(:,1), boxCentroidsPlot(:,2), IJtext,
        %'HorizontalAlignment','center','VerticalAlignment','middle',
        %'Color', magenta,'FontWeight','bold') % je commente que je l'ai
        %comment�
        
        % adding grid COORDINATES (8.18)
        if ~cloneTracking
            gridXYs = GRID_DEF.Coordinates;
            gridXYs = gridXYs(:); % puts everything in a column (=> matching linear indices)
            gridXYsMat = cell2mat(gridXYs);
            XYtext = [repmat('[',nBoxes,1) num2str(gridXYsMat(:,1)) repmat(',',nBoxes,1) num2str(gridXYsMat(:,2)) repmat(']',nBoxes,1)];
            
            %text(boxCentroidsPlot(:,1), boxCentroidsPlot(:,2), IJtext, 'HorizontalAlignment','center','VerticalAlignment','top', 'Color', magenta,'FontWeight','bold');
            %text(boxCentroidsPlot(:,1), boxCentroidsPlot(:,2), XYtext, 'HorizontalAlignment','center','VerticalAlignment','bottom', 'Color', cyan,'FontWeight','bold'); % 8.18
        end
     end
%     %---------------------------------------------------------------------------------------------------------
    
    
    % Saving image of grid or clone so we can close the image (7.4)
    %---------------------------------------------------------------------------------------------------------
    if gridValidation && ~exist('MAA','var')  && ~exist('gridValidatedOnce','var') % ONLY if grid was displayed (8.5)
        % saves grid or clone image
        if ~cloneTracking              % mod 7.10
            % displaying grid and saving grid image:
            thisFilename = ['this_Grid_' num2str(gridFrame, digitsFormat) '.' imageFormatOutput];   % gridFrame
            print(hGridFig, printFormat, printResolution, [gridFolderCPT filesep thisFilename]);    % specifying figure handle
        else
            thisFilename = ['this_Clone_' num2str(gridFrame, digitsFormat) '.' imageFormatOutput];
            print(hGridFig, printFormat, printResolution, [gridFolderCPT filesep thisFilename]);    % specifying figure handle
%             imwrite(cloneImage,[gridFolderCPT filesep thisFilename]);
        end
        close(hGridFig); % specifying figure handle (3.3)
        pause(0.5)
    end
    % NB: CPT parameter txt file and CPT grid backup will be saved during CPT execution
    %---------------------------------------------------------------------------------------------------------
    
    % MAP processing (8.2; moved 8.5)
    if exist('MAPcall','var')
        gridValidatedOnce = true;
        % NB: will NOT ask for grid validation if this variable exists, namely after having the user validate first animal's grid (8.2)
    end
    
    gridSize = GRID_DEF.Size; % 7.8, 8.3
    gridFolderAOT = [pathFolderAOT filesep gridSpecs]; % moved here 8.5
end
%-----------------------------------------------------------------------------------------------------------------------


%% AOT frame range check before building alltime backups (7.8) %%

if AOT == 1 && ~isempty(gridType) % now checking a grid is being processed (8.0)
    
    %%% Checking if other segmented images exist outside of range [startFrame finalFrame]
    existOtherSegImages = false;    % initialization
    nProbe = 5;                     % extent of probe
    prevNumberFound = [];
    nextNumberFound = [];
    for p = 1:nProbe

        prevNumber = startFrame - p;
        prevSegImageFile = [pathFolder filesep filename num2str(prevNumber, digitsFormat) '.' imageFormat];
        nextNumber = finalFrame + p;
        nextSegImageFile = [pathFolder filesep filename num2str(nextNumber, digitsFormat) '.' imageFormat];
        
        if exist(prevSegImageFile,'file')
            existOtherSegImages = true;
            prevNumberFound = prevNumber;
            existOtherSegImages = true;
        end
        
         if exist(nextSegImageFile,'file')
             existOtherSegImages = true;
             nextNumberFound = nextNumber;
             existOtherSegImages = true;
         end
         
         if existOtherSegImages
             break
         end   
    end
    
    %%% Checking existence of alltime backups
    for a = 1:length(averageOverAll)
        
        averageOver = averageOverAll{a};
        gridBackupRootFilename = eval(['filename' averageOver]); 
%         gridFolderAOT = [pathFolderAOT filesep gridSpecs];
        alltimeBackupFile = [gridFolderAOT filesep 'alltime_' gridBackupRootFilename '.mat'];  % using "gridFolder_AOT" instead of "gridFolder" (3.0)
        
        % Checks existence of "alltime" backup and defines "makeAlltimeBackup" accordingly (1.19):
        makeAlltimeBackup = ~exist(alltimeBackupFile,'file');                                   % 1 if does NOT exist => will be generated
                 
        if makeAlltimeBackup && existOtherSegImages
            
            %%% Warning message
            % button = questdlg({['AOT is about to build "alltime" backup, stacking "' averageOver '" quantities at ALL times into 4D matrices.'];...
             %    ['However segmented frames BEFORE "startFrame" (' num2str(prevNumberFound) ' < ' num2str(startFrame) ') AND/OR AFTER "finalFrame" (' ...
             %   num2str(finalFrame) ' < ' num2str(nextNumberFound) ') were found!!']},...
             %   ['WARNING "SAP": "alltime" backup for "' Animal '"'],'Continue','Abort','Continue for all','Continue for all');
            %if strcmp(button,'Abort')
            %    return
            %elseif strcmp(button,'Continue for all')
            %    break
            %end
            break
        end
    end
end


%% Determining "maxDivisionRound" and "nColTotal" for (7.1) %%

maxDivisionRoundFilePath = [trackingFolder filesep 'max_n_divisions_' num2str(startFrame) '-' num2str(finalFrame) '.txt'];

maxDivisionRound = [];  % 7.5
nColTotal = 2;          % Default value to process single images for which no tracking is available (7.8)
if exist(maxDivisionRoundFilePath,'file')
    
    maxDivisionRound = dlmread(maxDivisionRoundFilePath);           % Loading max n div found in tracking "max_n_divisions_nStart-nEnd.txt"
    nColTotal = 2 + maxDivisionRound;                              % corresponds to actual nb of Correspondence columns for ANVS used.
                                                                    % Ex: [RN AN 1 2 0 0] ie 6 for maxDivisionRound = 4
end


%% PIV pre-execution and definition of "refFigPosition" (7.9) %%

if PIV == 1
%     "PIV";
    
    lastPIVbackup =  [pathFolderPIV filesep 'Backups' filesep  filenamePIV '_' num2str(finalFrame-1, digitsFormat) '.mat']; % stops 1 frame before, mod 8.0
    PIVframeFolder = [pathFolderPIV filesep 'Frames'];                                              % 7.8, mod 8.0
    lastPIVimageVelocity = [PIVframeFolder filesep  filenamePIV '_Velocity_'  num2str(finalFrame-1,digitsFormat) '.' imageFormatOutput];
    lastPIVimageSpeed = [PIVframeFolder filesep filenamePIV '_Speed_'  num2str(finalFrame-1,digitsFormat) '.' imageFormatOutput];
    lastPIVimageDivergence = [PIVframeFolder filesep filenamePIV '_Divergence_'  num2str(finalFrame-1,digitsFormat) '.' imageFormatOutput];
    
    % determines if any PIV image will be created and saved
    anyPIVdisplayTF = (velocityDisplay && ~exist(lastPIVimageVelocity,'file')) || (speedDisplay && ~exist(lastPIVimageSpeed,'file'))...
                                    ||  (divergenceDisplay && ~exist(lastPIVimageDivergence,'file'));

    % Uses "imshow" to get corresponding figure size and aspect-ratio (7.8)
    if anyPIVdisplayTF
        
        figure('PaperPositionMode','auto')
        imshow(refImage,'Border', 'tight');
        refFig = gcf;
        refFigPosition = refFig.Position; % will be saved in "SAPparameters.mat"
        close
    end
    % NB: "refFigPosition" is to be used when using "imagesc" for instance to
    % save images at exact same resolution AND WITHOUT BORDERS!
end


%% creating "SAP_Animal" directory (7.3) and saving "SAPparameterFile" (7.8) mod 8.2 %%

if ~(exist('SAPcall','var') || exist('MAPcall','var')) % 8.2
% if ~(exist('SAPcall','var') && SAPcall) % 8.2
    
    if any(allProgramsTF)
        mkdir(pathSaveFolder);   % only creates parent SAP directory if at least one program will be run
    end
    
    fprintf('\nSaving "SAPparameters.mat" file...')
    save(SAPparameterFile); % 7.9
    fprintf('Done.\n')
end


%% TR execution (7.12, 8.0) %%

if TR == 1
    
    rotationImageFile = [pathFolderTR filesep 'Rotation_vs_frame#_' sideStr '_' Animal '.png'];
    
    if ~exist(rotationImageFile,'file')
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        TimeRegistration                                                  %#ok<*UNRCH>
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        warndlg(['Please update parameter "frameRef" in "' Animal '_info" according to "TimeRegistration" results!'],...
            'WARNING "SAP"!')
        return
    else
        fprintf('\nWARNING "SAP": "TimeRegistration" has already run and was skipped!\n')
    end
end


%% SR execution (7.12) %%

if SR == 1
    
    allClickedLandmarksImageFile = [pathFolderSR filesep 'All_clicked_landmarks_frame#' num2str(clickFrame) '.png'];
    
    if ~exist(allClickedLandmarksImageFile,'file')
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        SpaceRegistration                                                  %#ok<*UNRCH>
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    else
        fprintf(['\nWARNING "SAP": "SpaceRegistration" has already run on this frame (' num2str(clickFrame) ')and was skipped!\n'])
    end
end


%% PIV execution  %%

if PIV == 1

    if ~exist(lastPIVbackup,'file') || anyPIVdisplayTF % 7.9
                                                  
        % IF not just replot, opens matlabpool if not already done (6.2,7.7)
        poolObj = gcp('nocreate');          % If no pool, do not create new one.
        if isempty(poolObj)
            poolObj = parpool;
        end
        nLabs = GetPoolSize();

        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                                          
        ParticleImageVelocimetry
        pause(1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    else
        fprintf('\nWARNING "SAP": LAST PIV backups already exists: skipped PIV execution!\n')
    end
    
elseif PIV~=0
    disp('Error: "PIV" should be either 0 or 1.')
    return
end


%% GEP execution %% % (stephane)
if GEP
    GeneExpressionPattern
end


%% "Unionseg2Seg" & "Roi2roi" execution (8.0, 8.2) %%

Unionseg2seg;
% NB: Unionseg2Seg will detect existence of old "Output_results" folder and non-existence of
% new "SEG_(Animal)\results_(Animal)" folder to copy & rename the "Unionseg" images into "Seg" images.

Roi2roi;        % 8.2
% Will detect existence of old "Output_ROI" folder and non-existence of new
%"SEG_(Animal)\roi_(Animal)" folder to copy & rename the "Roi" images into "roi" images.


%% FPBF execution (6.0, 8.0, 8.2) %%

if FFPB
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    FilterFourPixelBlocks 
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end

    
%% SIA execution %%

if SIA == 1
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  (mod 6.5,7.8) %%%%%%%%%%%%%%%%%%%%%%%%%
    nFrameMin2CreateFolders = 2;        % min number of frames to create subfolders for Areas, R&Vs...
    
    % Defining "SIAmode", "SIAboxTag" (moved out of SIA in 7.8)
    %------------------------------------------------------------------------------
    % Default values:
    SIAmode ='SIA';
    pathFolderSIAfull = pathFolderSIA;
    filenameSIAfull = filenameSIA;
    % Box case:
    if SIAboxMode
        SIAmode ='SIA.Box';
        pathFolderSIAfull = [pathSaveFolder filesep SIAmode '_' Animal];
        filenameSIAfull = [SIAmode '_' Animal];
    elseif SIAboxMode ~= 0
        warndlg('"SIAboxMode" value must either be 0 or 1.','SIAboxMode Error!')
        return
    end
    %------------------------------------------------------------------------------
    
    % Checking existence of all backups from startFrame to finalFrame
    missingFrames = [];
    for frame = startFrame:finalFrame
        backupFile = [pathFolderSIAfull filesep 'Backups' filesep filenameSIAfull '_' num2str(frame, digitsFormat)  '.mat'];
        if ~exist(backupFile, 'file')
            missingFrames = [missingFrames, frame];
        end
    end
    
    if isempty(missingFrames) && noDisplay % All backups exist and no display is requested
        fprintf('\nAll SIA backups from frame %d to %d exist. Skipping SIA execution.\n', startFrame, finalFrame);
    else
        if ~isempty(missingFrames)
            fprintf('\nThe following frames are missing backups: %s\n', mat2str(missingFrames));
            fprintf('Running SIA to complete missing frames.\n');
        end
        
        % IF not just replot, opens matlabpool if not already done (6.2,7.7)
        poolObj = gcp('nocreate');          % If no pool, do not create new one.
        if isempty(poolObj)
            poolObj = parpool;
        end
        nLabs = GetPoolSize();
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % BETA: saving parameters into "SAPparameters.mat" & running exe
        %------------------------------------------------------------------------------
%         SAPparameterFile = [pathSaveFolder filesep 'SAPparameters.mat'];
%         save(SAPparameterFile);
%         SegmentedImageAnalysisFUN(SAPparameterFile)
%         system(['path\to\SIA.exe "' SAPparameterFile '"'])
        %------------------------------------------------------------------------------
%         SegmentedImageAnalysisPSI
        SegmentedImageAnalysis
        pause(1);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end 
elseif SIA~=0
    disp('Error: "SIA" should be either 0 or 1.')
    return
end


%% CT execution (7.8,8.0) %%

if CT == 1
    
    lastCorrespondenceTxt = [trackingFolder filesep 'correspondence_' num2str(finalFrame) '.txt']; % last Correspondence backup:
    
    if ~exist(lastCorrespondenceTxt,'file')
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        CellTracking                                                  %#ok<*UNRCH>
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    else
        fprintf('\nWARNING "SAP": last "correspondence" txt file was found => skipped CT execution!\n');
    end
end


%% HC execution (8.18) %%

if HC == 1
    HolesCorrection;
end


%% Determining "maxDivisionRound" and "nColTotal" for (7.1, moved 7.9) %%

maxDivisionRoundFilePath = [trackingFolder filesep 'max_n_divisions_' num2str(startFrame) '-' num2str(finalFrame) '.txt'];

maxDivisionRound = [];  % 7.5
nColTotal = 2;          % Default value to process single images for which no tracking is available (7.8)
if exist(maxDivisionRoundFilePath,'file')
    
    maxDivisionRound = dlmread(maxDivisionRoundFilePath);           % Loading max n div found in tracking "max_n_divisions_nStart-nEnd.txt"
    nColTotal = 2 + maxDivisionRound;                              % corresponds to actual nb of Correspondence columns for ANVS used.
                                                                    % Ex: [RN AN 1 2 0 0] ie 6 for maxDivisionRound = 4
end


%% CTD execution (6.0, moved 7.5) %%

if CTD
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    CellTrackingDisplay
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end


%% CPT execution (mod 7.0) %%

if CPT == 1 && ~isempty(gridType) % now checking a grid is being processed (8.0)
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    CellPatchTracking
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif CPT == 1 && isempty(gridType)
    fprintf('\nWARNING "SAP": CPT can only proceeed on grids or clones! => Skipped execution.\n'); % 8.0
    fprintf('Please set parameter "gridType" to "L" (or "E") and rerun CPT.\n'); % 8.0
elseif CPT ~= 0
    disp('ERROR: "CPT" should be either 0 or 1.')
    return
end


%% CTA execution (7.5,7.9,8.6) %%

if CTA
       
    CTAbackupFile = [pathFolderCTA filesep filenameCTA '.mat'];
    
    if ~isempty(gridType) && ~exist(CTAbackupFile,'file') % Will run in full image mode if "CTAbackupFile" doesn't exist
        
        if cloneTracking || max(gridSize) == 1 % only process clone OR 1 compartment grids
            
            fprintf('\nWARNING "SAP": "full image" CTA backup was NOT found: FIRST running CTA on full image...\n')
            
            % Temporarly overrides for full image analysis
            userGrid = gridType;
            userNoDisplayCTA = noDisplayCTA;
            gridType = '';
            noDisplayCTA = true; % not making full image plots
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            CellTrackingAnalysis    % FIRST need to run in FULL image mode
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            gridType = userGrid;
            noDisplayCTA = userNoDisplayCTA;
        end      
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    CellTrackingAnalysis
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % COMMENTED IN 8.6
%     if isempty(gridType) || (~isempty(gridType) && (cloneTracking || max(gridSize) == 1))
%         %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%         CellTrackingAnalysis
%         %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     else
%         fprintf('\nWARNING "SAP": CTA can only work on full image (ie. empty "gridType") OR clone OR 1-compartment grid. Skipped CTA execution.\n')
%     end
end


%% VM execution (6.0, 8.2) %%

if VM == 1
    for t = 1:length(timeWidthAll)
        
        makePlotsAOT = makePlotsAllAOT(t); % 6.9
        timeWidth = timeWidthAll(t);
        timeOverlap = timeOverlapAll(t);
        interframeWidth = time2frame(timeWidth, 0, 0, dt); % number of INTERFRAMES over which averaging will be done (mod 6.3, moved here 6.8)
        % NB: resetting timeRef and frameRef to 0 and 0 to get a duration: 1h at dt = 5min => 12 INTERframes, involving 13 frames
        
        % Setting "noAverage" parameter (7.8)
        noAverage = false;  % default
        if timeWidth == 0
            noAverage = true;
            if timeOverlap > 0
                disp('WARNING "SAP": "timeWidth" = 0 => AOT parameter "timeOverlap" has been set to 0!')
                timeOverlap = 0;    % time overlap cannot be different than 0 when no averaging
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        VelocityMaps
        %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
elseif VM ~= 0
    disp('Error: "VM" should be either 0 or 1.')
    return
end


%% AOS execution (mod 8.0)%%

if AOS == 1 && ~isempty(gridType) % now checking a grid is being processed (8.0)
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    AverageOverSpace
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
elseif AOS == 1 && isempty(gridType)
    fprintf('\nWARNING "SAP": AOS can only proceeed on grids or clones! => Skipped execution.\n'); % 8.0
    
elseif AOS ~= 0
    disp('Error: "AOS" should be either 0 or 1.')
    return
end


%% TA execution (5.3,7.5,7.8)


if TA == 1
    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % When grid mode, FIRST checks that "full image" backups exists, if not WILL RUN "full image" MODE BEFORE:
    % defining root names to TA backups (7.6)
    rootFulImageTAbackup = [pathFolderTA filesep 'Backups' filesep filenameTA]; % moved here (8.13)
    
    if ~isempty(gridType)
        
       rootGridTAbackup =      [pathFolderTA filesep gridSpecs filesep 'Backups' filesep filenameTA]; % 7.8
        
        % Paths to LAST full image backup (finalFrame):
        commonLastPart = ['_' num2str(finalFrame, digitsFormat) '.mat'];
        
        lastFulImageTAfileTF = exist([rootFulImageTAbackup  commonLastPart],'file');
        
        lastGridTAfileTF = exist([rootGridTAbackup        commonLastPart],'file'); % 7.8
        
        % if LAST full image backups NOT found (even from older TA version), FIRST run TA in "full image" mode:
        if ~lastFulImageTAfileTF
            
            if ~displayHLC % added "~diplayHLC " (7.6)
                
                fprintf('\nWARNING "SAP": "full image" TA LAST backup was NOT found: FIRST running TA on full image...\n')
                % saving values to restore:
                userGridTA = gridType;
                
                % Temporarly overrides for full image analysis
                gridType = '';
                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                TensorAnalysis              % running in "full image" mode
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                % Restoring initial values for Grid iteration:
                gridType = userGridTA;
            else
                fprintf('\nWARNING "SAP": "full image" TA LAST backup was NOT found (in any version)!\n')
                fprintf('Link display ("displayHLC") can only be run AFTER all TA backup have been generated!\n')
                fprintf('Stopped Execution.\n')
                return
            end
        elseif displayHLC && ~lastGridTAfileTF % checking that last grid backup exists before running in HLC display mode (7.8)
            
            fprintf('\nWARNING "SAP": "grid" TA LAST backup was NOT found!\n')
            fprintf('Link display ("displayHLC") can only be run AFTER all TA backup have been generated!\n')
            fprintf('Stopped Execution.\n')
            return
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    TensorAnalysis
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif TA ~= 0
    disp('Error: "TA" should be either 0 or 1.')
    return
end


%% GV execution (5.0) %%

if GV
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    GetVertex;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end


%% STPE execution (5.0, 7.4) %%

if STPE 
    
    % Display of apoptotic cells on junction tension map: must load "allDelaminatingCells.mat" first (6.6)
    %---------------------------------------------------------------------------------
    if displayApoptoticCells
        
        allDelaminatingANsFile = [pathFolderCTD filesep 'allDelaminatingCells.mat']; 
        
        if exist(allDelaminatingANsFile,'file')
            load(allDelaminatingANsFile,'allDelaminatingANs','allLastFrames')
        else
            disp('WARNING "SAP": file "allDelaminatingCells.mat" was not found: please run CTD.')
        end
    end
    %---------------------------------------------------------------------------------
    
    allVertexFixLog = [];                                                           % will store changes made by Vertex_Fixer il all frames
    allPextrema = []; 
    allTextrema = []; 
    init = true;                                                                    % STPE initialization is yet to be done
    progressbar(['STPE iteration over ' Animal ' frames...']);                      % 7.4
    separator = {'-----------------------------------------------------------'};

    for fn = frames2process
        
        filename_fn = [rootFilename num2str(fn,digitsFormat)];                      % added "_fn" suffix (6.9)
        disp(' '); disp(' ');
        disp(['Running "STPEstimate" on "' filename_fn '"...']);
        disp('---------------------------------------------------------------------------------');
        
        fullFilenameIn = [pathFolderGV filesep 'Backups' filesep filenameGV '_' num2str(fn,digitsFormat)];      % adjustments for GV 2.0 (7.8)
        fullFilenameData_fn = [fullFilenameIn '.txt'];                                                          % adjustments for GV 2.0 (7.8)
        
        if exist(fullFilenameData_fn,'file')
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            STPEstimate
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Saving txt file execution log (2.3,2.4):
            if ~replotSTPE && ~skippedSTPE
%             if ~replotSTPE % removed "&& ~skippedSTPE" (7.8)
                
                % if not empty the
                if exist('vertexFixLog','var') && ~isempty(vertexFixLog)
                    text_frame = {{} ; ['frame # ' num2str(fn)]};
                    vertexFixLog = [text_frame ; separator ; vertexFixLog ];        % % adding frame # on top of "vertex_fix_log"
                    allVertexFixLog = [allVertexFixLog ; vertexFixLog];             % % adds this frame vertex_fix_log 
                end
                % Updates of TP extrema values (2.5):
                allPextrema = [allPextrema ; [minP maxP]];                      
                allTextrema = [allTextrema ; [minT maxT]];                      
                P_min_data = [min(allPextrema(:,1)) mean(allPextrema(:,1)) std(allPextrema(:,1))];
                P_max_data = [max(allPextrema(:,2)) mean(allPextrema(:,2)) std(allPextrema(:,2))];
                T_min_data = [min(allTextrema(:,1)) mean(allTextrema(:,1)) std(allTextrema(:,1))];
                T_max_data = [max(allTextrema(:,2)) mean(allTextrema(:,2)) std(allTextrema(:,2))];
                
                % Updates (overwrites) text file at EACH iteration (2.4);
                textShuji = {'Cells and vertices are numbered according to Shuji numbering.' ; {}} ;
                textProgress = {['Frames processed so far: ' num2str(frames2process(1)) '-' num2str(fn)] ; {}};
                textPmin = {['P_min :  ' num2str(P_min_data)]};
                textPmax = {['P_max :  ' num2str(P_max_data)]};
                textTmin = {['T_min :  ' num2str(T_min_data)]};
                textTmax = {['T_max :  ' num2str(T_max_data)]};
                textTPextrema = ['P,T extreme values (min, avg, std):' ; textPmin ; textPmax ; textTmin ; textTmax];
                fullText =  [textShuji ; textProgress ; textTPextrema ; {{} ; 'Vertex fix log:'} ; allVertexFixLog];                % add precision on top
                filename_fn = [pathFolderSTPE filesep 'Execution_log_frames_#' num2str(frames2process(1)) '_' num2str(frames2process(end)) '.txt']; %3.4
                disp('Updating Execution log file...')
                dlmcell(filename_fn, fullText);         
            end
        else
            disp(['file ' fullFilenameData_fn ' was not found and was skipped'])          
        end
        nFramesDone = sum(frames2process <= fn); % gets number of processed frames to update progress bar (7.4)
        progressbar(nFramesDone/nFrames);
        disp('---------------------------------------------------------------------------------');
    end
end


%% MSM execution (5.0)%%

if MSM
    progressbar(['MSM iteration over ' Animal ' frames...']);                                               % 7.4
%     warndlg('Stop removing 1 from "VXYs_M" once the problem has been fixed in C++SIA!!', 'MSM WARNING!'); % 8.0
    
    for fn = frames2process
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
        MatlabShujiMatcher
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        nFramesDone = sum(frames2process <= fn);    % gets number of processed frames to update progress bar (7.4)
        progressbar(nFramesDone/nFrames);
    end
end


%% SM execution (5.0)%%

if SM && ~isempty(gridType) % now checking a grid is being processed (8.0)
    
    lastSMfile = [pathFolderSM filesep gridSpecs filesep 'Backups' filesep filenameSM '_' num2str(finalFrame, digitsFormat) '.mat'];
    
    if ~exist(lastSMfile,'file') || makePlotsSM % 7.8
        
        init = true;                                                % SM initialization is yet to be done
        for fn = frames2process
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            StressMap
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            nFramesDone = sum(frames2process <= fn);                % gets number of processed frames to update progress bar (6.0)
            progressbar(nFramesDone/nFrames);
        end
    else
        fprintf('\nWARNING "SAP": LAST SM backup already exists and no SM plot requested. Skipping SM execution...\n');
    end
    
elseif SM == 1 && isempty(gridType) % 8.0
    fprintf('\nWARNING "SAP": SM can only proceeed on grids or clones! => Skipped execution.\n'); % 8.0
end


%% AOT execution (mod 6.8)%%

if AOT == 1
    
    for a = 1:length(averageOverAll)
        
        averageOver = averageOverAll{a};
        
        for t = 1:length(timeWidthAll)
            
            makePlotsAOT = makePlotsAllAOT(t); % 6.9
            timeWidth = timeWidthAll(t);
            timeOverlap = timeOverlapAll(t);
            interframeWidth = time2frame(timeWidth, 0, 0, dt); % number of INTERFRAMES over which averaging will be done (mod 6.3, moved here 6.8)
            % NB: resetting timeRef and frameRef to 0 and 0 to get a duration: 1h at dt = 5min => 12 INTERframes, involving 13 frames
            
            % Setting "noAverage" parameter (7.8)
            noAverage = false;  % default
            if timeWidth == 0
                noAverage = true;
                if timeOverlap > 0
                    disp('WARNING "SAP": "timeWidth" = 0 => AOT parameter "timeOverlap" has been set to 0!')
                    timeOverlap = 0;    % time overlap cannot be different than 0 when no averaging
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            AverageOverTime
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    end
elseif AOT ~= 0
    disp('Error: "AOT" should be either 0 or 1.')
    return
end

%% POT execution (8.12)%%

if POT == 1
    
    for t = 1:length(timeWidthAll)
        
        makePlotsPOT = makePlotsAllPOT(t);
        
        if makePlotsPOT

            timeWidth = timeWidthAll(t);
            timeOverlap = timeOverlapAll(t);
            interframeWidth = time2frame(timeWidth, 0, 0, dt); % number of INTERFRAMES over which averaging will be done (mod 6.3, moved here 6.8)
            % NB: resetting timeRef and frameRef to 0 and 0 to get a duration: 1h at dt = 5min => 12 INTERframes, involving 13 frames
            
            % Setting "noAverage" parameter (7.8)
            noAverage = false;  % default
            if timeWidth == 0
                noAverage = true;
                if timeOverlap > 0
                    disp('WARNING "SAP": "timeWidth" = 0 => AOT parameter "timeOverlap" has been set to 0!')
                    timeOverlap = 0;    % time overlap cannot be different than 0 when no averaging
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            PlotOverTime
            %%%%%%%%%%%%%%%%%%%%%%%%%%% PROGRAM RUN  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
    end
    
elseif POT ~= 0
    disp('Error: "POT" should be either 0 or 1.')
    return
end


function escaped_str = escape_cmd(str)
    escape_chars = {' ', '(', ')', '{', '}', '[', ']', '&', ';', '|', '<', '>', '$', '?', '*', '#', '@'};
    escaped_str = '';
    for i = 1:length(str)
        if ismember(str(i), escape_chars)
            escaped_str = [escaped_str, '\'];
        end
        escaped_str = [escaped_str, str(i)];
    end
end

%% Python compatibility layer
% Here, I add 

%% History %%

% 19/09/2020: 8.21
% - fixed initial MAP run due to PMTR execution by stopping the
% overwritting of timeStart/Stop by empty '' prior to PMTR execution.
% - defined what "MAA" means in comment

% 19/05/2023:
% - HC will run if HC = 1 in SAP_parameters AND
% "'HolesCorrection_has_run.txt'" file does NOT exist

% 31/01/2023: 8.20
% - added "colorJunctions" in PLOT structure so it can be used from SIA to
% color cell junctions.

% 31/01/2023:
% "clickTime" can now be 'start' or 'final'

% 01/09/2021:
% HC won't run if "'HolesCorrection_has_run.txt" already exists

% 15/10/2020: 8.19
% - removed all calls to "PIVtype"

% 31/01/2020: 8.18
% - on the "this_Grid_" image, added display of grid COORDINATES on top of grid IJs.
% - added execution of "HolesCorrection" (always running, except in SAPcall
% or MAPcall modes)

% 18/10/2019:
% - definition of "pathFolderTCTD" folder path to save a version of CTD
% images with "imwrite" for the segmentation interface

% 15-18/07/2019:
% - DAA became MAA
% - now setting back "timeStart" and "timeStop" to empty when called by
% PlotMovieTimeRange (PMTRcall = true)

% 24/06/2019: 8.17
% - now only determines "cloneMaskFrame" from "path2cloneMask" if the
% former was not specified in animal SAP_info

% 21/05/2019: 8.16
% - restored use of "skippedSTPE" to fix bug

% 06/05/2019: 8.15
% - fixed the recurrent blank figure pop up
% - removed comments older than version 8.0

% 03-05/04/2019: 8.14
% - removed warning when newJuncDisplayTimes(1) < earliestTime
% - changes to support the 3 possible values of "matchingWTclone" (used to
% be boolean).
% - now specifies animal name in warning message before running AOT when
% noticing there are extra frames in folder

% 14/02/2019: 8.13
% - fixed bug where "rootFulImageTAbackup" was not defined in non grid mode

% 28/01/2019: 8.12
% - added POT execution (almost exactly similar to AOT execution)

% 25/01/2019: 8.11
% - now adding grid/clone compartment numbers on grid/clone image to
% better know which one to select in following analysis.

% 02/11/2018: 8.10
% - reverted change made in 8.4 where clone cells were all put in a single
% compartment instead of keeping them in separated regions.

% 25/09/2018: 8.9
% - Now checking that raw images are 8bit before processing. Stopping
% execution otherwise.

% 06/09/2018: 8.8
% - use of "pathFolderPIV4VM" and "PIVgridVM"
% - crash fix: definition of "olapTag" after use of "MakeGrid" to be able
% to determine and test "gridSize" when the latter has been left empty in
% SAP_info.

% 19/07/2018: 8.7
% - added "excludeLostCells" tag, "elcTag", in grid folder name specified
% by "gridSpecs".
% - added "opengl hardware" to fix poor rendering of saved images!
% - now specifies "resultsFolder" (where duplicates of AOT maps are saved)
% when validating grid.

% 13/07/2018: 8.6
% - now checking that at least ONE dimension of grid is greater than one
% when "gridOverlap" > 0, otherwise setting it to 0.
% - added "colorMacrochaetes" and "colorFLCells" in PLOT
% - now CTA can also run in non-(ROI or clone) mode to make "grid maps"

% 28/06/2018: 8.5
% - fixed bug when a timeWidthAll had a larger value than timeWidthMax. Now
% issues a warning and set this time width to max value.
% - now defines "gridFolderAOT" earlier 
% - STOPPED OVERWRITING "Animal" THAT IS DEFINED BY THE END OF "SAP_info_"
% FILES WITH FIRST ELEMENT OF "filenameRaw"!!!!
% - stopped displaying grid when "gridValidation" is false (or
% "gridValidatedOnce" is true) => this substantially speeds up MAP execution.

% 26/06/2018: 8.4
% - now clone grids always have ny = 1 since all cells will be gathered
% into one single box => simplified related part and remove comments.

% 26/06/2018: 8.3 (part extracted from SAP_parameters 8.3)

% 14/06/2018: 8.3
% - determines "cloneMaskFrame" straight from "path2cloneMask"
% - when doing clone processing, overrides "gridTime" (and "gridFrame") by
% "cloneMaskTime" (and "cloneMaskFrame")
% - put capitals to every quantity "Q" that was called "gridQ" when stored
% in GRID. This to avoid having variable "size" that is also a function.

% 25/05/2018: 8.2
% - many changes: look for "8.2" tags for all changes
% - erased old backup filenames
% - changes related to VM execution that is now supported
% - removed parameter "replotVM"

% 18/05/2018: 8.1
% - now using "cloneMaskFrame" defined in animal's "SAP_info" for better
% separation with "gridFrame/Time": it was confusing to use ROI tracked
% using a given gridTime (24h00 for instance) AND a clone drawn at a
% different time
% - removed CPT parameter "invertCloneMask"
% - now ALWAYS specify "gridTag" in folder name when L grid, (EVEN when
% gridFrame == startFrame)
% - removed CPT parameter "ROIcrop": now modifying clone before loading it

% 27/04-15/05/2018: 8.0 BECAME "SAP_parameters"
% - merge with "AIA_parameters" modified by Stephane 
% - parameter "PIVgrid" moved back here
% - "AIAcall" became "SAPcall"
% - removed execution of "SIAextractor"
% - now skipping execution of "FFPB" if txt log file already exists
% - fixed wrong "lastPIVbackup" path that used to start parpool even when
% it existed
% - now "pathFolderPIV" leads to grid subfolder
% - now checking existence of last "correspondence" txt file before running CT.
% - included "Unionseg2Seg" to transform "Unionseg" images into "Seg"
% images with right folder structure (only runs when "Output_results"
% folder is found AND "SEG_(Animal)\results_(Animal)" folder is NOT.
% - "pathFolderTR" and "pathFolderSR" are now inside "SAP" folder
% - removed definition of "pathFolderTRES" related to transpose of PIV images
% - now enters part making grid when "ROIcall" exists


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% REMOVED EARLIER COMMENTS IN VERSION 8.15
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


