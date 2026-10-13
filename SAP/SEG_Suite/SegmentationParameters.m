% Segmentation Parameters

% pathSaveFolder = AIA_Animal = pathFolderAIA

pathFolderSEG = [pathFolderRaw filesep 'SEG_' Animal];

pathFolderRES = [pathFolderSEG filesep 'results_' Animal];
pathFolderROI = [pathFolderSEG filesep 'roi_' Animal];



pathFolderAIA = [pathFolderRaw filesep 'AIA_' Animal];

pathFolderPIV = [pathFolderAIA filesep 'PIV_' Animal];



pathFolderTMP = [pathFolderRaw filesep 'TMP_' Animal];
pathFolderTRES = [pathFolderTMP filesep 'tResults'];
pathFolderTPIV = [pathFolderTMP filesep 'tPIV'];
pathFolderTCT  = [pathFolderTMP filesep 'CT'];
pathFolderCORR = [pathFolderTMP filesep 'autocorrection'];
pathFolderCLR1 = [pathFolderTMP filesep 'cleanning1'];
pathFolderCLR2 = [pathFolderTMP filesep 'cleanning2'];
pathFolderGUI  = [pathFolderTMP filesep 'interface'];
pathFolderCEL  = [pathFolderTMP filesep 'cellout'];





filename = ['Seg_' filenameRaw{1}];  
roiname = ['Roi_' filenameRaw{1}];
imageFormat = 'png';  









episegExe = ['episeg']; 
trackingExe = ['tracking'];
cellExe = ['cell'];






% executablePath = ['.' filesep 'segmentation_v1' filesep 'segmentationRoutines' filesep 'executable'];
 
% cellExe = [executablePath filesep 'cell'];
% episegExe = [executablePath filesep 'episeg']; 
% c18Exe = [executablePath filesep 'c18'];
% markerWatershedExe = [executablePath filesep 'MarkerControledWatershed'];

if ispc()
     trackingExe = [trackingExe '.exe'];
     cellExe = [cellExe '.exe'];
    episegExe = [episegExe '.exe']; 
%     c18Exe = [c18Exe '.exe'];
%     markerWatershedExe = [markerWatershedExe '.exe'];
end 

% other stuff
