% FinalProcessingAnalysis

% clear previous tracking
if exist(trackingFolder, 'dir'), delete(trackingFolder); end
mkdir(trackingFolder);

% transpose (even if already done, we dont know from when)
% TransposeSEG
% TransposePIV

% perform tracking on segmented images
option = '1111 -T';
% firstFramePath = [pathFolderTRES filesep 'T_' filename num2str(startFrame,digitsFormat) '.' imageFormat];
% firstPIVPath_u = [pathFolderTPIV filesep 'T_' filenamePIV '_u_' num2str(startFrame,digitsFormat) '.' imageFormat];
firstFramePath = [pathFolderRES filesep filename num2str(startFrame,digitsFormat) '.' imageFormat];
firstPIVPath_u = [pathFolderPIV filesep 'Results' filesep filenamePIV '_u_' num2str(startFrame,digitsFormat) '.' imageFormat];
cmd = [trackingExe ' ' firstFramePath ' ' trackingFolder ' ' num2str(startFrame) ' ' num2str(finalFrame) ' ' firstPIVPath_u ' ' option];
%15/06/23 system(cmd) caused Arguments must contain a character vector. I
%think it solves the issue to convert cmd to single string using
%strjoin(cmd, '')
cmd = strjoin(cmd, '');

system(cmd);

