%%% HolesCorrection.m
% This script takes the backups of SIA and CT and update them so that inner
% holes in the tissue are considered as border cells, and their neighbours
% are first layer cells. 
% It is based on the ROI images (Animal -> SEG_Animal -> roi_Animal) to
% determine which cells are holes or core. 

% If any error: check that SIA and CT backups are the good ones. 

version = '2.2';
% Victoire Cachoux

%% Display info %%

program = 'HC';
Today = datestr(now,29);
When = datestr(now,15);

disp(' '); disp(' ');
disp([program ' ' version  ': processing "' Animal '"): INITIALIZATION']);
disp('---------------------------------------------------------------------------------');


%% Check that ALL ROI Mask files and segmented image files exist; if one missing, stop script %%

oneSegimageMissingTF = false;
oneROIimageMissingTF = false;
fprintf('Checking availability of all ROI and segmented images...')

for n = startFrame:finalFrame
    nthROIFile = [pathFolderROI filesep roiname num2str(n,digitsFormat) '.' imageFormat];
    nthSegFile = [pathFolder filesep filename num2str(n,digitsFormat) '.' imageFormat];
    
    if ~exist(nthROIFile,'file')   %% Check existence of ROI Mask
        oneROIimageMissingTF = true;
        fprintf(['ROI image # ' num2str(n,digitsFormat) ' is missing!\n'])
        break
    end
    if ~exist(nthSegFile,'file')  %% Check existence of segmented image
        oneSegimageMissingTF = true;
        fprintf(['Segmented image # ' num2str(n,digitsFormat) ' is missing!\n'])
        break
    end
end

allROIimagePresentTF = ~oneROIimageMissingTF;
allSegimagePresentTF = ~oneSegimageMissingTF;

if allROIimagePresentTF && allSegimagePresentTF
    fprintf('Done.\n')  
else
    fprintf(['Some ROI or Segmented images are missing. ' program ' will not run.\n'])
    return
end


%% Check availability of SIA backups and CT bordercells backups %% (if not all available, will run on existing ones and just issue a warning)
%----------------------------------------------------------------------------------------------------------------------

%%% SIA %%%
oneSIAbackupMissingTF = false; % default
allSIAbackupMissingTF = true; % default
fprintf('Checking availability of all SIA backups...')
for n = startFrame:finalFrame
    nthSIAbackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(n,digitsFormat) '.mat'];
    if ~exist(nthSIAbackupFile,'file')
        oneSIAbackupMissingTF = true;
        fprintf(['SIA backup # ' num2str(n,digitsFormat) ' is missing!\n'])
    else
        allSIAbackupMissingTF = false;
    end
end
allSIAbackupAvailableTF = ~oneSIAbackupMissingTF;

if allSIAbackupAvailableTF
    fprintf('Done.\n')  
elseif allSIAbackupMissingTF
    fprintf('***WARNING: all SIA backups are missing. SIA BACKUPS WERE NOT UPDATED.***\n')
else
    fprintf(['***WARNING: some SIA backups are missing. Execution of ' program ' on existing backups.***\n'])
end

%%% CT %%%
oneCTbackupMissingTF = false; % default
allCTbackupMissingTF = true; % default
fprintf('Checking availability of all CT border cells backups...')
for n = startFrame:finalFrame
    nthCTbackupFile = [pathFolderCT filesep PIVgrid 'Grid' filesep 'border_cells_RN_' num2str(n) '.txt'];
    if ~exist(nthCTbackupFile,'file')
        oneCTbackupMissingTF = true;
        fprintf(['CT border cells backup # ' num2str(n) ' is missing!\n'])
    else
        allCTbackupMissingTF = false;
    end
end
allCTbackupAvailableTF = ~oneCTbackupMissingTF;

if allCTbackupAvailableTF
    fprintf('Done.\n')
elseif allCTbackupMissingTF
    fprintf('***WARNING: all CT backups are missing. CT BACKUPS WERE NOT UPDATED.***\n')
else
    fprintf(['***WARNING: some CT backups are missing. Execution of ' program ' on existing backups.***\n'])
end
%----------------------------------------------------------------------------------------------------------------------

if allCTbackupMissingTF && allSIAbackupMissingTF
    fprintf(['All CT and SIA backup missing; run SIA and/or CT before running ' program '!\n'])
    return
end


%% Change Backup folder names to "folderName_preHC" %%

SIAFolder = [pathFolderSIA filesep 'Backups'];
SIAFolderNew = [SIAFolder '_pre' program];

CTFolder = [pathFolderCT filesep PIVgrid 'Grid'];
CTFolderNew = [CTFolder '_pre' program];

% % % movefile(SIAFolder,SIAFolderNew);
% % % movefile(CTFolder,CTFolderNew);


%% Create new backup folders %%

% % % mkdir(SIAFolder);
% % % mkdir(CTFolder);
% % % 
% % % disp(['Copying old SIA Backups to new folder ' SIAFolder '...'])
% % % copyfile(SIAFolderNew,SIAFolder);
% % % fprintf('Done.\n')  
% % % 
% % % disp(['Copying old CT Backups to new folder ' CTFolder '...'])
% % % copyfile(CTFolderNew,CTFolder);
% % % fprintf('Done.\n')  


%% Update CT and SIA Backups: all cells with black pixels in ROI Mask become border cells %%
%%% Their neighbours become first layer cells %%%

parfor f = startFrame:finalFrame
    
    fprintf([program ' ' version  ': Updating backups, frame #' num2str(f) '/' num2str(finalFrame) '...\n'])
    
    
    %% Get New border RNs %% 
    
    %%% Load mask images %%%
    mask = imread([pathFolderROI filesep roiname num2str(f,digitsFormat) '.' imageFormat]);
    
    %%% Load segmented images %%%
    segImage = imread([pathFolder filesep filename num2str(f,digitsFormat) '.' imageFormat]);
    
    %%% Get RNs %%%
    imageLabels = bwlabel(segImage,4);    
    
    %%% Get Pixel list of indices %%%
    pixList = regionprops(imageLabels,'PixelIdxList');
    
    %%% Get list of new border cells %%%
    newBorderRNList = [];
    
    for i = 1:size(pixList,1)  %% Loop on all cells
        currIdxList = pixList(i).PixelIdxList;
        currIdxMaskValues = mask(currIdxList);
        if any(currIdxMaskValues == 0)  %% If any pixel of cell i has a value = 0 in mask,
            newBorderRNList = [newBorderRNList ; i];
        end
    end
    
    newBorderRNList = unique(newBorderRNList);
    
    
    %% Update CT bordercells %% 
    
    %%% Link to neighbouring RNs in CT backup %%%
    borderCellListFile = [CTFolder filesep 'border_cells_RN_' num2str(f) '.txt'];
    
    if exist(borderCellListFile,'file')
        
        %%% Update border RNs %%%
        borderCellList = dlmread(borderCellListFile);
        borderCellList = [borderCellList ; newBorderRNList];
        borderCellList = sort(unique(borderCellList));
        dlmwrite(borderCellListFile, borderCellList,'newline','pc');
        
    else
        
        fprintf(['CT border cells backup # ' num2str(f) ' missing and not updated \n'])
        
    end
    
    
    %% Update SIA backups %%
    
    SIABackupFile = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(f,digitsFormat) '.mat'];
    
    if exist(SIABackupFile,'file')
        
        %%% Load SIA Backup %%%
        SIABackup = load(SIABackupFile);
        updateCategoryTags = SIABackup.CELLS.CategoryTags;
        neighArray = SIABackup.CELLS.Neighbors;

        %%% Update CELLS.CategoryTags with new border cells %%%
        updateCategoryTags(newBorderRNList,1) = 2;
        
        %%% Find new first layers cells and update %%% 
        allBorderCells = find(updateCategoryTags == 2);
        borderNeighRNs = neighArray(allBorderCells,:);
        borderNeighRNs = cell2mat(borderNeighRNs.');
        borderNeighRNs = borderNeighRNs.';
        borderNeighRNs = borderNeighRNs(~ismember(borderNeighRNs,allBorderCells));
        updateCategoryTags(borderNeighRNs,1) = 1;
        
        %%% Save the updated category tags %%%
        CELLS = SIABackup.CELLS;
        CELLS.CategoryTags = updateCategoryTags;
        ParSaveAppend(SIABackupFile, CELLS, 'CELLS');
        
    else
        
         fprintf(['SIA backup # ' num2str(f) ' missing and not updated \n'])
         
    end
    
    
    
end

%% Create Text File to prove the run of HC

txtFilename = 'HolesCorrection_has_run.txt';
fopen([pathFolderSIA filesep txtFilename],'w');


%% History %%


% 21/11/2019: v2.2
% Correct mistake in SIA Backup saving; 

% 06/11/2019: v2.1
% Correct mistake in CT backup saving. 

% 06/11/2019: v2.0
% Now border cells are cells whose core pixels contain 0 Mask values.
% Previously: they needed to have one of their skeleton pixel at 0 Mask
% value. 

% - 25/10/2019: v1.0, creation


