% Roi2roi
%
% Will detect existence of old "Output_ROI" folder and non-existence of
% new "SEG_(Animal)\roi_(Animal)" folder to copy & rename the
% "Roi" images into "roi" images.
%
% NB: by precaution, NO images will be erased
%
 version = '1.0';
% Boris Guirao

%% Code %%

program = 'Roi2roi';
pathFolderOutputROI  = [pathFolderRaw filesep 'Output_ROI'];

if exist(pathFolderOutputROI,'dir') && ~exist(pathFolderROI,'dir')
      
    % getting "Unionseg" animal name (can be different than Animal)
    fileList = dir([pathFolderOutputROI filesep 'Roi_*.' imageFormat]);
    firstFilenameOLD = fileList(1).name;
    
    % Getting everything before "_XXX.png":
    roinameLength = length(firstFilenameOLD);      % length of generic name
    roinameEnd = roinameLength - (nDigits + 4);   % "XXXX.png"
    roinameOLD = firstFilenameOLD(1:roinameEnd);
    
    disp(' ');
    disp([program ' ' version  ': processing "' Animal '" frame # ' num2str(startFrame) ' to ' num2str(finalFrame)]);
    disp('---------------------------------------------------------------------------------');
    disp(['Copying & renaming "' roinameOLD '..." files'])
    disp(['from ' pathFolderOutputROI]);
    disp(['to ' pathFolderRES '...'])
    disp(' ');
    
    % creating "SEG_(Animal)\results_(Animal)" folders
    mkdir(pathFolderROI)
   
    for n = startFrame:finalFrame
        
        % OLD
        roinameOLDfull = [roinameOLD  num2str(n, digitsFormat) '.' imageFormat];
        fullPathIn = [pathFolderOutputROI filesep roinameOLDfull];
        % NEW
        roinameFull = [roiname  num2str(n, digitsFormat) '.' imageFormat];
        fullPathOut = [pathFolderROI filesep roinameFull];
        
        % Copying & renaming file when found:
        if exist(fullPathIn,'file')
            fprintf(['File "' roinameOLDfull '" -> "' roinameFull '"\n']);
            copyfile(fullPathIn, fullPathOut);
        else
            disp(['WARNING: file "' roinameOLDfull ' could not be found and was skipped!']);
        end
    end
    disp(' ');
    disp('Done!')
    disp('---------------------------------------------------------------------------------');
end



%% History %%

% 11/06/2018: creation from "Unionseg2seg"
