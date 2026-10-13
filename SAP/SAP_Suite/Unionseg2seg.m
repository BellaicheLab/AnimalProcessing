% Unionseg2seg
%
% Will detect existence of old "Output_results" folder and non-existence of
% new "SEG_(Animal)\results_(Animal)" folder to copy & rename the
% "Unionseg" images into "Seg" images.
%
% NB: by precaution, NO images will be erased
%
 version = '1.1';
% Boris Guirao

%% Code %%

program = 'Unionseg2Seg';
pathFolderOutputResults  = [pathFolderRaw filesep 'Output_results'];

if exist(pathFolderOutputResults,'dir') && ~exist(pathFolderRES,'dir') % mod 1.1
      
    % getting "Unionseg" animal name (can be different than Animal)
    fileList = dir([pathFolderOutputResults filesep 'Unionseg_*.' imageFormat]); 
    firstFilenameOLD = fileList(1).name;
    
    % Getting everything before "_XXX.png":
    filenameLength = length(firstFilenameOLD);      % length of generic name
    filenameEnd = filenameLength - (nDigits + 4);   % "XXXX.png"
    filenameOLD = firstFilenameOLD(1:filenameEnd);
    
    disp(' ');
    disp([program ' ' version  ': processing "' Animal '" frame # ' num2str(startFrame) ' to ' num2str(finalFrame)]);
    disp('---------------------------------------------------------------------------------');
    disp(['Copying & renaming "' filenameOLD '..." files'])
    disp(['from ' pathFolderOutputResults]);
    disp(['to ' pathFolderRES '...'])
    disp(' ');
    
    % creating "SEG_(Animal)\results_(Animal)" folders
    mkdir(pathFolderRES);  % mod 1.1

      
    for n = startFrame:finalFrame
        
        % OLD
        filenameOLDfull = [filenameOLD  num2str(n, digitsFormat) '.' imageFormat];
        fullPathIn = [pathFolderOutputResults filesep filenameOLDfull];
        % NEW
        filenameFull = [filename  num2str(n, digitsFormat) '.' imageFormat];
        fullPathOut = [pathFolderRES filesep filenameFull];
        
        % Copying & renaming file when found:
        if exist(fullPathIn,'file')
            fprintf(['File "' filenameOLDfull '" -> "' filenameFull '"\n']);
            copyfile(fullPathIn, fullPathOut);
        else
            disp(['WARNING: file "' filenameOLDfull ' could not be found and was skipped!']);
        end
    end
    disp(' ');
    disp('Done!')
    disp('---------------------------------------------------------------------------------');
end



%% History %%

% 11/06/2018: 1.1
% - checking existence of "pathFolderRES" rather than "pathFolderSEG"

% 11/05/2018: creation
