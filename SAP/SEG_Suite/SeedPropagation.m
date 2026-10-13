%% Seed initialisation and propagation for simple segmentation
% This methods take user seed intialisation for input and then propagate the
% markers for a frame by frame segmentation. The approach is VERY naive and
% do not manage division, apopthosis, nor cell going in or out the field of
% view. In counter part, it is fast and easy to use, and provide good results
% for close up movie at cellular scale.
%
% 31/01/2018 by Stephane Rigaud - v1
%

%% First image initialisation
% folder initialisation
if ~exist(pathFolderMRK,'dir')
    mkdir(pathFolderMRK);
end

if ~exist(pathFolderRES,'dir')
    mkdir(pathFolderRES);
end

%% interface seed initiallisation
if ~exist([pathFolderMRK filesep filenameRaw{1} num2str(startFrame, digitsFormat) '.' imageFormat],'file')
    rawImage = imread([pathFolderRaw filesep rootFilename num2str(startFrame,digitsFormat) '.' imageFormatRaw]);
    markerImage = zeros(size(rawImage));
    bye = false;
    nbCell = 0;
    interfaceHandle = figure(666);
    imshow(rawImage, [], 'Border', 'tight');
    hold on;
    while ~bye
        try
            [x, y, buttemp] = ginputWhite(1);
        catch err
            if strcmp(err.identifier,'MATLAB:ginput:FigureDeletionPause')
                disp(err.identifier); % other error
            end
            return;
        end
        %% Input action definition
        switch buttemp
            case 1
                nbCell = nbCell + 1;
                xyadd(1, nbCell) = round(y); % y first
                xyadd(2, nbCell) = round(x);
                plot(x, y, 'y+');
            case {113 ; 27}
                % Construct a questdlg with three options
                choice = questdlg('Do you want to continue with the segmentation', ...
                    'Initial Marker Validation', ...
                    'Yes','No','Yes');
                bye = ~bye; % leave interface
            otherwise
                disp('irregular key pressed!');
        end
    end
    close(interfaceHandle);
    switch choice
        case 'Yes'
            markerIndex = sub2ind(size(markerImage), xyadd(1,:), xyadd(2,:) );
            markerImage(markerIndex) = 255;
            imwrite(markerImage, [pathFolderMRK filesep filenameRaw{1} num2str(startFrame, digitsFormat) '.' imageFormat]);
        case 'No'
            return;
    end
end

% first frame segmentation using user provided seeds
inputPath = [pathFolderRaw filesep rootFilename num2str(startFrame, digitsFormat) '.' imageFormatRaw];
outputPath = [pathFolderRES filesep filename num2str(startFrame, digitsFormat) '.' imageFormat];
seedPath = [pathFolderMRK filesep rootFilename num2str(startFrame, digitsFormat) '.' imageFormat];
cmd = [markerWatershedExe ' --input ' inputPath ' --seed ' seedPath ' --output ' outputPath];
system(cmd);

%% Propagate seeds
progressbar('Frame iteration ...');
for f = startFrame+1:finalFrame
    %disp(['Segmentation of frame #' num2str(f, digitsFormat) ' ...']);
    
    % use output image for current image seeds
    previousSegPath = outputPath;
    I = imread(previousSegPath);
    seeds = SegmentationToSeeds(I, 3);
    imwrite(seeds, [pathFolderMRK filesep rootFilename num2str(f, digitsFormat) '.' imageFormat], imageFormat);
    
    % current frame segmentation using computed seeds
    inputPath = [pathFolderRaw filesep rootFilename num2str(f, digitsFormat) '.' imageFormatRaw];
    outputPath = [pathFolderRES filesep filename num2str(f, digitsFormat) '.' imageFormat];
    seedPath = [pathFolderMRK filesep rootFilename num2str(f, digitsFormat) '.' imageFormat];
    cmd = [markerWatershedExe ' --input ' inputPath ' --seed ' seedPath ' --output ' outputPath];
    system(cmd);
    
    progressbar(f/(finalFrame-startFrame+1))
end

