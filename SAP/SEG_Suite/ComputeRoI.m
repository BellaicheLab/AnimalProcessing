%%% ROI generator %%%

% warning checking
if exist(pathFolderROI,'dir')
    answer = questdlg('Do you want to remove already existing RoI files?', ...
        'Warning: RoI directory already existing!', ...
        'Yes','No','No');
    if strcmp(answer,'Yes')
        rmdir(pathFolderROI, 's');
        mkdir(pathFolderROI);
    end
else
    mkdir(pathFolderROI);
end


%% loop for each images

minHolePixel = round(minHoleSize / (scale1D^2));
parfor n = startFrame:finalFrame
    % manage path to images
    inputImagePath = [pathFolderRaw filesep rootFilename num2str(n,digitsFormat) '.' imageFormatRaw];
    outputImagePath = [pathFolderROI filesep roiname num2str(n,digitsFormat) '.' imageFormat];
    
    if ~exist(outputImagePath,'file')
        
        % load image
        I = imread(inputImagePath);
        
        % define RoI
        bw = GaborTextureBinarization(I, 0.15);
        
        % post-process cleaning of the RoI
        
        roi = ~bwareaopen(~bw, minHolePixel);       
        
        % save mask
        imwrite(roi,outputImagePath);
        
    end
    
end