%% Segmentation script

% warning checking
if exist(pathFolderRES,'dir')
    % do warning because we are going to trash the segmentation
else
    mkdir(pathFolderRES);
end


%% loop for each images
parfor n = startFrame:finalFrame
    % manage path to images
    inputImagePath = [pathFolderRaw filesep rootFilename num2str(n,digitsFormat) '.' imageFormatRaw];
    outputImagePath = [pathFolderRES filesep filename num2str(n,digitsFormat) '.' imageFormat];
    maskImagePath = [pathFolderROI filesep roiname num2str(n,digitsFormat) '.' imageFormat];
    
    if ~exist(outputImagePath,'file')
    
    % build cmd line for executable
    cmd = [episegExe ' --input  '      inputImagePath  ...
                     ' --output '      outputImagePath ...
                     ' --tolerance '   num2str(noiseTolerance)];
%                    ' --iteration '   num2str(noiseIteration)];
%                    ' --step '        num2str(noiseStep)];
%                    ' --conductance ' num2str(noiseConductance)];
    if exist(maskImagePath,'file')
        cmd = [cmd ' --region ' maskImagePath ];
    end
    % execute segmentation
    system(cmd);
    
    end
end

% todo:
% save a text file for the sports