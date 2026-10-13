% AutoCorrection filter

%% Initialisation
% preallocate an empty array of u,v vectors
pivData(finalFrame).uVect = [];
pivData(finalFrame).vVect = [];

option = '0000';
historySize = 6;

tmpPathFolderPIV = [pathFolderPIV filesep 'Results'];

if exist(pathFolderTCT, 'dir')
    delete(pathFolderTCT);
end
if exist(pathFolderCEL, 'dir')
    delete(pathFolderCEL);
end
if exist(pathFolderGUI, 'dir')
    delete(pathFolderGUI);
end
mkdir(pathFolderTCT);
mkdir(pathFolderCEL);
mkdir(pathFolderGUI);

%% PROCESSING %%

% Initialize/reset and label the progress bar
progressbar('Auto-correction in progress ... Please wait...','Processing ...');
nFrames = historySize;
for f = startFrame:finalFrame-nFrames+1
    
    index = f;
    fr = 1;
    
    % prepraring for the tracking
    firstImagePath = [pathFolderRES filesep filename num2str(f, digitsFormat) '.' imageFormat];
    firstPIVFile_u = [tmpPathFolderPIV filesep filenamePIV '_u_' num2str(f, digitsFormat) '.' imageFormat];
    firstRawImagePath = [pathFolderRaw filesep rootFilename num2str(f, digitsFormat) '.' imageFormatRaw];
    
    % execute the cell tracking
    % disp('*********** CELL TRACKING ***********');
    cmd = [trackingExe ' ' firstImagePath ' ' pathFolderTCT ' ' num2str(f) ' ' num2str(f+nFrames-1) ' ' firstPIVFile_u ' ' option];
    %15/06/23 system(cmd) caused Arguments must contain a character vector. I
    %think it solves the issue to convert cmd to single string using
    %strjoin(cmd, '')
    cmd = strjoin(cmd, '');
    system(cmd);
    
    % execute the border tracking
    % disp('********** BORDER TRACKING **********');
    cmd = [cellExe ' ' firstImagePath ' ' pathFolderTCT ' ' num2str(nFrames) ' ' pathFolderCEL ' ' firstRawImagePath  ' -1 -W'];
    %15/06/23 system(cmd) caused Arguments must contain a character vector. I
    %think it solves the issue to convert cmd to single string using
    %strjoin(cmd, '')
    cmd = strjoin(cmd, '');

    system(cmd);
    
    % segmentation correction
    % disp('****** SEGMENTATION CORRECTION ******');
    progressbar([],0); % reset second progressbar
    for i = f:(f+nFrames-1)
        progressbar([],fr/nFrames);
        fr = fr + 1;
        % fprintf('* frame %d\n',i);
        
        % path to the del/add lists
        dListFile = [pathFolderCEL filesep 'del-' num2str(i) '.txt'];
        aListFile = [pathFolderCEL filesep 'add-' num2str(i) '.txt'];
        % load the del/add file if exists
        if ~exist(dListFile,'file'), DV = [];
        else DV = dlmread(dListFile,' '); end
        if ~exist(aListFile,'file'), AV = [];
        else AV = dlmread(aListFile,' '); end
        % next if nothing to do
        if isempty(AV) && isempty(DV), continue; end
        
        
        % segmentation skeleton
        segmentedImage = ~imread([pathFolderRES filesep filename num2str(i, digitsFormat) '.' imageFormat]);
        imageSize = size(segmentedImage);
        correctionFile = [pathFolderGUI filesep 'correction_mask_' rootFilename num2str(i, digitsFormat) '.' imageFormat];
        if exist(correctionFile, 'file')
            corrections = imread(correctionFile);
        else
            corrections = ones(imageSize) * 127;
            % convert to uint8
            corrections = uint8(corrections);
            % save in disk
            imwrite(corrections ,correctionFile, imageFormat);
        end
        
        % keep segmentedImage
        oldSegmentedImage = segmentedImage;
        
        % delete borders
        if ~isempty(DV)
            % disp('... Deleting borders ...');
            segmentedImage(DV) = 0;
        end % end delete
        
        % add borders
        if ~isempty(AV)
            % disp('... Adding borders ...');
            for k = 1:size(AV,1)
                dBorder = AV(k,:);
                dBorder = dBorder(dBorder>0); % only keep non-zeros
                [y_coord x_coord] = ind2sub(imageSize, dBorder);
                
                t = i - 1;
                % load PIV data if empty
                if isempty(pivData(t).vVect)
                    pivfile = [tmpPathFolderPIV filesep filenamePIV '_u_' num2str(t, digitsFormat) '.' imageFormat];
                    pivData(t).uVect = double(imread(pivfile)) - 128;
                    pivfile = [tmpPathFolderPIV filesep filenamePIV '_v_' num2str(t, digitsFormat) '.' imageFormat];
                    pivData(t).vVect = double(imread(pivfile)) - 128;
                end
                % move the border using the PIV
                y_coord = y_coord + pivData(t).vVect(dBorder);
                x_coord = x_coord + pivData(t).uVect(dBorder);
                % ceil to convert to int coordinates
                y_coord = ceil(y_coord);
                x_coord = ceil(x_coord);
                % remove outOfBound elements
                keeper_y = (y_coord<imageSize(1)+1) & (y_coord>0) ;
                keeper_x = (x_coord<imageSize(2)+1) & (x_coord>0) ;
                % keep only if both coordinates not outOfBound
                keeper = keeper_x & keeper_y;
                y_coord = y_coord(keeper);
                x_coord = x_coord(keeper);
                % dilate border to add
                dBorder = sub2ind(imageSize,y_coord,x_coord);
                dBorder = SideDilator(imageSize,dBorder',1)';
                % add the border
                segmentedImage(dBorder)=1;
            end
        end % end add
        
        
        % skeletonization
        segmentedImage = bwmorph(segmentedImage, 'skel', Inf);
        % small cells removal
        segmentedImage = ~SmallCellRemover(~segmentedImage, 5);
        % watersheding
        segmentedImage = ~watershed(segmentedImage, 4);
        % segmentedDifferenceference after-before
        segmentedDifference = segmentedImage - oldSegmentedImage;
        % keep corrections
        corrections = corrections + uint8(segmentedDifference>0) - uint8(segmentedDifference<0);
        % save corrections
        imwrite(uint8(corrections), correctionFile, imageFormat);
        % saving the corrected segmentation
        imwrite(~segmentedImage,[pathFolderRES filesep filename num2str(i, digitsFormat) '.' imageFormat],imageFormat);
    end % end temporal window loop
    
    % clear the output directory
    delete([pathFolderCEL filesep 'add-*']);
    delete([pathFolderCEL filesep 'del-*']);
    
    % update 1st progress bar
    progressbar(f/(finalFrame-nFrames+1),[]);
    
    % unload PIV
    % disp(['unloading PIV #' num2str(frame)]);
    pivData(f).uVect = [];
    pivData(f).vVect = [];
    
end % end global frame loop

