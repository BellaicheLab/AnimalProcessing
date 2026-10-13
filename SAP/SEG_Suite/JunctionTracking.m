%% JunctionTracking

% junction output directory
if ~exist(pathFolderJNK,'dir')
    mkdir(pathFolderJNK);
end

% % transpose raw image for data extraction
% parfor f = startFrame:finalFrame
%     I = imread([pathFolderRaw filesep filenameRaw{1} num2str(f, digitsFormat) '.' imageFormatRaw]);
%     I = I';
%     imwrite(I, [backupFolderPath filesep transposedTag filenameRaw{1} num2str(f, digitsFormat) '.' imageFormat], imageFormat);
% end

% parameters
skelDilation = 3;
backgroundArea = 50;
localestimator = [num2str(backgroundArea) 'x' num2str(skelDilation)];
nbFrames = finalFrame - startFrame + 1;
firstSegFramePath = [pathFolderRES filesep filename num2str(startFrame, digitsFormat) '.' imageFormat];
firstRawImagePath = [pathFolderRaw filesep filenameRaw{1} num2str(startFrame, digitsFormat) '.' imageFormatRaw]; 

% execute the quantification program
% cmd = [c18Exe ' ' firstTsegFramePath ' ' trackingMFolderPath ' ' num2str(nbFrames) ' ' pathFolderJNK ' ' firstTrawimagepath ' ' localestimator];

cmd = [junctExe ' ' firstSegFramePath ' ' trackingFolder ' ' num2str(nbFrames) ' ' pathFolderJNK ' ' firstRawImagePath ' ' localestimator ' -T'];
system(cmd);
