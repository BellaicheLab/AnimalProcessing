function [GRID, backupPathList, RAW] = SingleAnimalLoader(AIAFolderName, Animal, TIME, tobeprocessed )
%
%
% version 1.5

%% Code
AIA_call = 1; %#ok<NASGU>

% return
backupPathList = [];

% run AIA_info to retrive ... info
gridTime = TIME.gridTime;                           %#ok<NASGU> % loads it so that AIA_info finds it (1.3)
run([ AIAFolderName filesep 'AIA_info_' Animal ]);
% Overwritting values to keep those from AIA_MultiOperation (1.3)
gridTime = TIME.gridTime;
gridType = TIME.gridType;
gridOverlap = TIME.gridOverlap;

% rebuild the GRID
GRID = GridMaker(imageSize, boxSize, xyStart, gridSize, gridColor, gridLineWidth, gridOverlap); % added "gridOverlap"
xywh = GRID.xywh;
nx   = GRID.size(2);
ny   = GRID.size(1);
% gridOverlap = GRID.overlap; % has been set to 0 by "GridMaker" if was empty in AIA_info (commented 1.3)

% defining "olapTag"
olapTag = ''; % default value: not displaying overlap in folder name when empty or 0 (for compatibility)
if gridOverlap > 0
    olapTag =  ['_olap_' num2str(gridOverlap)];
end
% defining "gridTag" (1.1,1.2)
delta_t = TIME.delta_t;
gridFrame = gridFrameTimeAssigner(gridTime,timeRef,frameRef,delta_t, startFrame,finalFrame); % 1.3
gridTag = '';
if gridFrame ~= startFrame && strcmp(gridType,'L')
    gridTag = ['_' gridTime];
end

RAW.nDigits = nDigits;
RAW.filename = filename;
RAW.rawPathFolder = pathFolderRaw;
RAW.gridAnimalFolder = '';
RAW.imageFormat = imageFormat;
RAW.halfNotum = halfNotum;
RAW.boxSize = boxSize;
RAW.xyStart = xyStart;
RAW.yMid = yMid;                % 1.3
RAW.yFactor = yFactor;          % 1.3
RAW.imageSize = imageSize;      % 1.4
RAW.startFrame = startFrame;    % 1.4
RAW.finalFrame = finalFrame;    % 1.4
RAW.digitsFormat = digitsFormat; % 1.4
RAW.xywh = xywh;                % 1.5
RAW.centroids = GRID.centroids; % 1.5

if tobeprocessed
    
    % Defines grid specific subfolder name
    gridSpecsName = ['Grid_xy_' num2str(xywh(1)) '_' num2str(xywh(2)) '_wh_' num2str(xywh(3)) 'x' num2str(xywh(4)) '_nynx_' num2str(ny) 'x' num2str(nx) gridTag olapTag]; % added gridTag (1.1)
    
    %%% Defines the "Process_Folder", "Grid_folder", "Average folder"
    %--------------------------------------------------------------
    % redefines path to TA backups (that contain info on Lagrangian patch) according to gridType defined in AOA_MultiOperation (1.4)
    gridAddon = [gridType 'Grid_'];
    pathFolder_TA = [pathSaveFolder filesep 'TA_MT_' CT_PIVgrid '_' gridAddon Animal CoreFLHLsTag renormTag];
    gridLBackupFolder = [ pathFolder_TA filesep gridSpecsName ];  % path to the grid backups containing the Lgrid information
    RAW.gridAnimalFolder = gridLBackupFolder;
    %--------------------------------------------------------------
    
    %--------------------------------------------------------------
    % Average
    % if AOA_time start and stop are define use them, else use time defined in AOT of AIA_parameters
    pathFolder_AOT = [pathSaveFolder filesep 'AOT_' gridType 'Grid_' Animal]; % redefines path according to gridType defined in AOA_MultiOperation (1.3)
    averageFolderName = ['Average_' num2str(TIME.animalTimeWidth) 'h_' TIME.multiTimeStart '_to_' TIME.multiTimeStop '_olap_' num2str(TIME.animalTimeOverlap)]; % moved down here (1.9)
    backupPath = [pathFolder_AOT filesep gridSpecsName filesep averageFolderName];  % 1.2, 1.4
    %--------------------------------------------------------------
    
    %%% Loads "mean" backup (mod 1.2)
    fullpath = [backupPath filesep 'mean_AOT_' Animal '.mat'];
    if exist(fullpath,'file')
%         load(fullpath); % commented 1.4
        backupPathList = fullpath;
        % updating AreaRatios in AOT backups (1.4)
        fprintf('Updating AreaRatios in AOT backup...')
        AOTbu = load(fullpath);
        AreaRatios = AreaRatiosAssigner(AOTbu);     %#ok<NASGU>
        save(fullpath, 'AreaRatios', '-append');   % appending "AreaRatios" to existing backup
        fprintf('Done\n');
        return;
    else
        disp(['Error: backup "' fullpath '" was not found and was skipped.'])
        return;
    end 
end

end

%% History 

% 08/02/2017: 1.5 (Boris)
% - included "xywh" and "centroids" in RAW structure

% 06/02/2017: 1.4 (Boris)
% - determines common "AreaRatios" and UPDATES AOT backup by appending AR into it.

% 18/01/2017: 1.3 (Boris)
% - removed most of the many old commented parts
% - removed "AOSvariable" from function outputs
% - added midline position "yMid" and "yFactor" in RAW
% - overwrites gridType that is specified in AIA_parameters by the one in AOA_MultiOperation
% - redefines "pathFolder_AOT" locally accordingly 
% - use of "gridFrameTimeAssigner"

% 12/01/2017: 1.2 (Boris)
% - ONLY using AOT backups now!!

% 07/12/2016: 1.1 (Boris)
% - added "gridTag" that is now specified in the grid folder name
