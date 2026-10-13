

if exist(pathFolderKYM,'dir')
    answer = questdlg('Do you want to remove already existing kymographs files?', ...
        'Warning: Kymographs directory already existing!', ...
        'Yes','No','No');
    if strcmp(answer,'Yes')
        rmdir(pathFolderKYM, 's');
        mkdir(pathFolderKYM);
    end
else
    mkdir(pathFolderKYM);
end

nbFrames = finalFrame - startFrame +1;
BORDERSI = cell(1, nbFrames); % Border Storage Info
junctionMap = zeros(imageSize);


%% load border tracking info
PatchedBorderTracking_file = [pathFolderJNK filesep 'patchedBorderTracking.txt'];
try
    borderTracking = dlmread(PatchedBorderTracking_file, ' ');
catch err
    if strcmp('MATLAB:dlmread:FileNotOpened', err.identifier) % open failed
        wd = warndlg(['Unable to open tracking file ' PatchedBorderTracking_file '.' 10 'Please be sure to run border tracking program before this.'], 'File Not Found', 'modal');
    else
        disp(exception);
    end
    return;
end
% security check
if size(borderTracking, 2) ~= nbFrames + 1 %+1 for trailing zero
    wd = warndlg('Tracking file outdated ! Please re-run border tracking before start this interface !','TRACKING OUTDATED!');
    waitfor(wd);
    close(fig);
    return
end
% remove trailing zero
borderTracking = borderTracking(:, 1:nbFrames);
toKeepTracks = find(borderTracking(:,1));
borderTracking = borderTracking(toKeepTracks,:);

%% load border pixel list
for currentFrame = startFrame:finalFrame
    indexFrame = currentFrame - startFrame + 1;
    try
        BORDERSI{indexFrame} = dlmread([pathFolderJNK filesep 'bordersInfo2_' num2str(currentFrame) '.txt'],' ');
    catch exception
        if strcmp(exception.identifier,'MATLAB:textscan:BadFormatString')
            disp(['frame ' num2str(currentFrame) ': empty border data ...']);
            BORDERSI{indexFrame} = -1;
        else
            disp(exception);
            return;
        end
    end
end

%% loop on borders
for borderId = 1:size(borderTracking,1)
    
    borderRNs = borderTracking(borderId,:);
    
    kymoDistance = zeros(length(borderRNs), 500 );
    for c = 1:numel(rootFilename)
        kymographes{c} = zeros(length(borderRNs), 500 );
    end
    kymoMaximumLength = -1;
    
    % define border initial direction
    [lig,~] = find(BORDERSI{1}(:,1) == borderRNs(1));
    pixelList = GetPixelsFromBorderTracking(BORDERSI{1}, lig, imageSize);
    [y_t, x_t] = ind2sub(imageSize, pixelList); 
    initialDirection = sign(x_t(end) - x_t(1));
    
    % update junction map
    junctionMap(pixelList) = borderId;
    cXY(borderId,:) = [mean(x_t) mean(y_t) borderId];
    
    % accumulate kymographe
    for frame = startFrame:finalFrame
        frameIdx = frame + startFrame - 1;
        if borderRNs(frame) ~= 0
            
            % load all channels
            for c = 1:numel(filenameRaw)
                IMAGE{c} = imread([pathFolderRaw filesep filenameRaw{c} num2str(frame, digitsFormat) '.' imageFormatRaw]);
            end
            
            % get pixels list
            [lig,~] = find( BORDERSI{frameIdx}(:,1) == borderRNs(frameIdx) );
            pixelList = GetPixelsFromBorderTracking(BORDERSI{frameIdx}, lig, imageSize);
            
            % get (x,y) coordinate of pixels
            [yp_t,xp_t] = ind2sub( imageSize, pixelList );
            
            % get junction verticise
            P1 = [xp_t(1)   yp_t(1)];
            P2 = [xp_t(end) yp_t(end)];
            normLine = sqrt( (yp_t(end)-yp_t(1)).^2 + (xp_t(end)-xp_t(1)).^2 );
            
            % check junction direction, and define pixel list reading direction
            if initialDirection ~= sign( xp_t(end) - xp_t(1) )
                yp_t = fliplr(yp_t);
                xp_t = fliplr(xp_t);
            end
            
            % kymo accumulation
            kymoDistance(frameIdx,1) = 1;
            for c = 1:numel(filenameRaw)
                kymographes{c}(frameIdx,1) = GetLocalIntensityValue(IMAGE{c}, yp_t(1), yp_t(1), kymoKernel);
            end
            for pxl = 2:length(yp_t)
                distance = sqrt( (yp_t(pxl)-yp_t(pxl-1))^2 + (xp_t(pxl)-xp_t(pxl-1))^2 );
                kymoDistance(frameIdx, pxl) = kymoDistance(frameIdx, pxl-1) + distance;
                for c = 1:numel(filenameRaw)
                    kymographes{c}(frameIdx,pxl) = GetLocalIntensityValue(IMAGE{c}, yp_t(pxl), yp_t(pxl), kymoKernel);
                end
            end % end loop on pixel junction
            
        end % end border id check
    end % end for each frame
    clear distance
    
    % max distance, used for data interpolation (ToBeImproved)
    kymoMaximumLength = -1;
    for idx = 1:length(borderRNs)
        indexs = find( kymographes{1}(idx,:) );
        distance{idx} = kymoDistance(idx, indexs );
        for c = 1:numel(filenameRaw)
            rawKymographe{c}{idx} = kymographes{c}(idx, indexs );
        end
        if ~isempty(distance{idx})
            kymoMaximumLength = max(kymoMaximumLength, max(distance{idx}));
        end
    end
    if mod(ceil(kymoMaximumLength),2) == 0
        kymoMaximumLength = ceil(kymoMaximumLength);
    else
        kymoMaximumLength = floor(kymoMaximumLength);
    end
    
    % kymographe interpolation to respect real distances
    interpDistance = 1:1:kymoMaximumLength;
    for c = 1:numel(filenameRaw)
        interpKymographe{c} = zeros(length(borderRNs), length(interpDistance));
        for idx = 1:length(borderRNs)
            if isempty(rawKymographe{c}{idx})
                interpKymographe{c}(idx,:) = zeros(1, length(interpDistance));
            else
                interpKymographe{c}(idx,:) = interp1(distance{idx}, rawKymographe{c}{idx}, interpDistance);
            end
        end
    end
    
    % justify kymographe
    for c = 1:numel(filenameRaw)
        justKymographe{c} = zeros(length(borderRNs), length(interpDistance));
        for idx = 1:length(borderRNs)
            maxIndexValue = sum( interpKymographe{c}(idx,:) > 0 );
            shift = floor((kymoMaximumLength - maxIndexValue) ./ 2);
            if shift > 0
                justKymographe{c}(idx,(1+shift):(maxIndexValue+shift)) = interpKymographe{c}(idx,1:maxIndexValue);
            else
                justKymographe{c}(idx,:) = interpKymographe{c}(idx,:);
            end
        end
    end
    
    for c = 1:numel(filenameRaw)
        dataType = class(IMAGE{c});
        outputName = [pathFolderKYM filesep 'kymographe_j=' num2str(borderId) '_' filenameRaw{c}(1:end-1) '.png'];
        imwrite( cast(justKymographe{c},dataType), outputName);
    end
    
end % end loop over junctions

rgbJunctionMap = label2rgb(junctionMap);
figure('PaperPositionMode','auto');
imshow(rgbJunctionMap);
hold on
text(cXY(:,1), cXY(:,2), num2str(cXY(:,3)),'FontSize',9);
hold off
print([pathFolderKYM filesep 'JunctionMap.png'],'-dpng');
close;
