function QuantitativeInterface(DATA, KYMO)
% DATA.startFrame
% DATA.finalFrame
% DATA.backupFolderPath
% DATA.segmentationPath
% DATA.rawFolderPath
% DATA.junctionTrackPath
% DATA.rootFilename
% DATA.segmFilename
% DATA.digitsFormat
% DATA.rawImageFormat
% DATA.imageFormat

showLocal = true;
backgroundArea = 50;
btrack = 0;                 % border tracking
boxedbordercolor = [1 1 0]; % border color
modal = true;               % figure mode
bless = false;              % background subtration
equalized = false;          % histogram equalization
skelon = true;              % skeleton display
skeleton_color = [1 0 0];   % skeleton color
nzoom = 0;                  % zoom
nbFrames = DATA.finalFrame - DATA.startFrame +1;

% figure settings
fig = figure(25);
set(fig, 'Units', 'pixels');
scrsz = get(0, 'ScreenSize');
pos = [1 50 scrsz(3) scrsz(4)-125];

% storage variables
backgrounds = cell(1, nbFrames); % background estimation storage (for display use)
NEIGHBOURS  = cell(1, nbFrames); % neighbours list storage
BORDERSI    = cell(1, nbFrames); % Border Storage Info


% load tracking info
PatchedBorderTracking_file = [DATA.junctionTrackPath filesep 'patchedBorderTracking.txt'];
try
    borderTracking = dlmread(PatchedBorderTracking_file, ' ');
catch err
    if strcmp('MATLAB:dlmread:FileNotOpened', err.identifier) % open failed
        wd = warndlg(['Unable to open tracking file ' PatchedBorderTracking_file '.' 10 'Please be sure to run border tracking program before this.'], 'File Not Found', 'modal');
    else
        wd = warndlg(['ERROR: ' 10 err.identifier], 'Error', 'modal');
    end
    waitfor(wd);
    close(fig);
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



% 12 neighbours (central pixels dilate by a 4-connexity disk of radius 2)
offsetset = [-1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1; -2,0; 0,-2; 0,2; 2,0];





%% Figure loop %%
bye = false; % loop flag
currentFrame = DATA.startFrame;
while ~bye
    
    % load image and segmentation
    rawImage = imread([DATA.rawFolderPath filesep DATA.rootFilename{1} num2str(currentFrame, DATA.digitsFormat) '.' DATA.rawImageFormat]);
    segImage = imread([DATA.segmentationPath filesep DATA.segmFilename num2str(currentFrame, DATA.digitsFormat) '.' DATA.imageFormat]);
    segImage = imcomplement(logical(segImage));
    imgSize = size(segImage);
    
    % load border and neighbours info from cell and junction tracking, with exception security
    indexFrame = currentFrame - DATA.startFrame + 1;
    if isempty(BORDERSI{indexFrame})
        try
            BORDERSI{indexFrame} = dlmread([DATA.junctionTrackPath filesep 'bordersInfo2_' num2str(currentFrame) '.txt'],' ');
        catch exception
            if strcmp(exception.identifier,'MATLAB:textscan:BadFormatString')
                disp(['frame ' num2str(currentFrame) ': empty border data ...']);
                BORDERSI{indexFrame} = -1;
                NEIGHBOURS{indexFrame} = -1;
            else
                disp(exception);
                return;
            end
        end
    end
    if isempty(NEIGHBOURS{indexFrame})
        NEIGHBOURS{indexFrame} = ReadBordersNei([DATA.junctionTrackPath filesep 'BordersNeighbours_' num2str(currentFrame) '.txt']);
    end
    
    
    
    % set figure
    set(fig,'Name',['image ' num2str(currentFrame, DATA.digitsFormat) ' (overlay of image/segmentation)']);
    if modal
        set(fig,'WindowStyle','modal');
    end
    upDisplay(); % update display function
    set(fig, 'Position', pos);
    if nzoom ~= 0
        for k = 1:nzoom
            zoom(2);
        end
        axis(lim);
    end
    hold on;
    
    
    %% Interaction loop %%
    byebye = false;
    while ~byebye
        
        % Get input
        try
            [xi,yi,buttemp] = ginputWhite(1);
        catch err
            if (strcmp(err.identifier,'MATLAB:ginput:FigureDeletionPause')) % figure closed by user
                disp('Leaving interface ...');
            else
                disp(err.identifier); % other error
            end
            return;
        end
        
        % specific verifications
        if isempty(buttemp) %2011-12-02
            disp('ERROR: irregular key pressed!');
            buttemp = 0;
        end
        if buttemp>64 && buttemp<91
            h = warndlg('BEWARE ! CAPS LOCK might be ON');
            waitfor(h);
        end
        if isempty(xi) || isempty(yi)
            disp('ERROR: no mouse or keyboard input');
            buttemp = 0;
            xi = 0;
            yi = 0; % prevent crash when wrong button pushed
        end
        
        % zoom
        xizoom = xi;
        lim = axis;
        outside = xi<lim(1) || xi>lim(2) || yi<lim(3) || yi>lim(4);
        
        % interaction managment
        switch buttemp
            %--------------------------------------------------------------
            case {27,113} % 'esc' - we quit the interface
                byebye=true;
                bye=~bye;
                %--------------------------------------------------------------
            case 101 % 'e' - equalise image histogram
                equalized=~equalized;
                upDisplay();
                %--------------------------------------------------------------
            case 9 % 'tab' - hide/show segmentation
                skelon = ~skelon;
                upDisplay();
                %--------------------------------------------------------------
            case 108 % 'l' - lock/unlock figure
                modal = ~modal;
                if ~modal
                    set(fig,'WindowStyle','normal');
                else
                    set(fig,'WindowStyle','modal');
                end
                %--------------------------------------------------------------
            case 98 % 'b' - background substraction
                bless = ~bless;
                upDisplay();
                %--------------------------------------------------------------
            case {29,117} % 'rigth' - next image
                hold off
                currentFrame = min(currentFrame+1,DATA.finalFrame);
                byebye = true;
                %--------------------------------------------------------------
            case {28,121} % 'left' - previous image
                hold off
                currentFrame = max(currentFrame-1,DATA.startFrame);
                byebye = true;
                %--------------------------------------------------------------
            case {43,30,61} % 'up','+' - zoom in
                nzoom = nzoom+1;
                zoom(2);
                if ~outside
                    lim = axis;
                    lim = [xizoom+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]]; % adjust image limits
                    axis(lim);
                end
                %--------------------------------------------------------------
            case {45,31} % 'down','-' - zoom out
                nzoom = max(nzoom-1, 0);
                zoom(0.5);
                %--------------------------------------------------------------
            case 1 % 'left click' - select junction
                if BORDERSI{indexFrame} == -1
                    wd = warndlg('no border infos available in this frame ...','Warning','modal');
                    waitfor(wd);
                    continue;
                end
                % get click coordinate
                x_coord = round(xi);
                y_coord = round(yi);
                Mcenter = (y_coord-1) * imgSize(2) + x_coord;
                % look for it in the border pixels list
                [lig,~] = find(getPixels(BORDERSI{indexFrame}) == Mcenter);
                n = 1;
                % if we dont find it directly (because unprecise click)
                while (isempty(lig) && n < length(offsetset) +1)
                    y_coord = y_coord + offsetset(n,1); % dilate x
                    x_coord = x_coord + offsetset(n,2); % dilate y
                    if (y_coord>0 && y_coord<imgSize(1) && x_coord>0 && x_coord<imgSize(2))
                        % adjust y
                        Mindex = Mcenter + offsetset(n,1);
                        % adjust x
                        if offsetset(n,2) == -1
                            Mindex = Mindex - imgSize(2);
                        elseif offsetset(n,2) == 1
                            Mindex = Mindex + imgSize(2);
                        end
                        [lig,~] = find(getPixels(BORDERSI{indexFrame}) == Mindex);
                    end
                    n = n + 1;
                end
                if ~isempty(lig)
                    % vertex case
                    if size(lig,1) > 1
                        lig = lig(1,:); %keep the first found
                    end
                    fprintf('border id: %d\n',BORDERSI{indexFrame}(lig,1));
                    % tracking
                    [btrack,~] = find(borderTracking(:,indexFrame) == BORDERSI{indexFrame}(lig,1));
                    upDisplay(); % update display
                end
                %--------------------------------------------------------------
            case 107 % 'k' - kymograph
                kymographFolderPath = [DATA.rawFolderPath filesep 'Output_kymograph'];
                cropsFolderPath = [DATA.rawFolderPath filesep 'Output_kymograph' filesep 'crops'];
                
                if ~exist(kymographFolderPath,'dir'),mkdir(kymographFolderPath); end
                if ~exist(cropsFolderPath,'dir'),mkdir(cropsFolderPath); end

                secondChannel = false;
                if length(DATA.rootFilename) == 2
                    secondChannel = true;
                end
                
                if btrack ~= 0 % only process if a track has been selected
                    if btrack < 0
                        borderIDs = -btrack; % I dont know why
                    else
                        borderIDs = borderTracking(btrack, :); % get the border ids
                    end
                    centroids = zeros(length(borderIDs),2); % centroids
                    
                    % kymograph variables setup
                    pixelList    = cell(nbFrames, 1); % pixel storage
                    cropChannel1 = cell(nbFrames, 1);
                    kymoDistance = zeros(length(borderIDs), 500 );
                    kymoChannel1 = zeros(length(borderIDs), 500 );
                    if secondChannel
                        cropChannel2 = cell(nbFrames, 1);
                        kymoChannel2 = zeros(length(borderIDs), 500);
                    end
                    
                    % get initial direction of the junction
                    [lig,~] = find(BORDERSI{1}(:,1) == borderIDs(1));
                    pixelList{1} = getPixels(BORDERSI{1}, lig);
                    % convert to x,y
                    [~, x_t] = ind2sub(imgSize, pixelList{1});
                    initialDirection = sign(x_t(end) - x_t(1));
                    
                    % accumulate kymographe
                    progressbar('Processing');
                    for k = 1:length(borderIDs) % for each time point of the border
                        tmpIndex = k + DATA.startFrame - 1;
                        if borderIDs(k)~=0 % if we did not loose the border
                            % load image time point
                            channel1RawImage = imread([DATA.rawFolderPath filesep DATA.rootFilename{1} num2str(k, DATA.digitsFormat) '.' DATA.rawImageFormat]);
                            if secondChannel
                                channel2RawImage = imread([DATA.rawFolderPath filesep DATA.rootFilename{2} num2str(k, DATA.digitsFormat) '.' DATA.rawImageFormat]);
                            end
                            % load border info at timepoint k
                            if isempty(BORDERSI{k})
                                BORDERSI{k} = dlmread([DATA.junctionTrackPath filesep 'bordersInfo2_' num2str(tmpIndex) '.txt'],' ');
                            end
                            % get pixels list
                            [lig,~] = find( BORDERSI{k}(:,1) == borderIDs(k) );
                            pixelList{k} = getPixels( BORDERSI{k}, lig );
                            % convert to x,y
                            [yp_t xp_t] = ind2sub( imgSize, pixelList{k} );
                            % vertecis of the junction
                            P1 = [xp_t(1)   yp_t(1)];
                            P2 = [xp_t(end) yp_t(end)];
                            normLine = sqrt( (yp_t(end)-yp_t(1)).^2 + (xp_t(end)-xp_t(1)).^2 );
                            % if asked, crop and save junction for validation
                            if KYMO.crops
                                cropChannel1{k} = channel1RawImage;
                                if secondChannel
                                    cropChannel2{k} = channel2RawImage;
                                end
                                for i = 1:length(yp_t)
                                    cropChannel1{k}(yp_t(i),xp_t(i)) = 255;
                                    if secondChannel
                                        cropChannel2{k}(yp_t(i),xp_t(i)) = 255;
                                    end
                                end
                                
                                cropFolderId = [cropsFolderPath filesep num2str(borderIDs(1))];
                                if ~exist(cropFolderId,'dir'),mkdir(cropFolderId); end
                                imwrite(cropChannel1{k},[cropFolderId filesep 'crop_' DATA.rootFilename{1} 'j=' num2str(borderIDs(1)) '.tif'],'WriteMode','append');
                                if secondChannel
                                    imwrite(cropChannel2{k},[cropFolderId filesep 'crop_' DATA.rootFilename{2} 'j=' num2str(borderIDs(1)) '.tif'],'WriteMode','append');
                                end
                            end
                            % check junction direction, and define pixel list reading direction
                            if initialDirection ~= sign( xp_t(end) - xp_t(1) )
                                yp_t = fliplr(yp_t);
                                xp_t = fliplr(xp_t);
                            end
                            % first pixel entry
                            kymoDistance(k,1) = 1;
                            kymoChannel1(k,1) = getKymoValue_b(channel1RawImage, yp_t, xp_t, 1, KYMO.filter, KYMO.ponderation);
                            if secondChannel
                                kymoChannel2(k,1) = getKymoValue_b(channel2RawImage, yp_t, xp_t, 1, KYMO.filter, KYMO.ponderation);
                            end
                            % loop reading on the rest of the junction pixel
                            for p = 2:length(yp_t)
                                % distance computation
                                distance = sqrt( (yp_t(p)-yp_t(p-1))^2 + (xp_t(p)-xp_t(p-1))^2 );
                                kymoDistance(k,p) = kymoDistance(k,p-1) + distance;
                                % kymograph computation
                                kymoChannel1(k,p) = getKymoValue_b(channel1RawImage, yp_t, xp_t, p, KYMO.filter, KYMO.ponderation);
                                if secondChannel
                                    kymoChannel2(k,p) = getKymoValue_b(channel2RawImage, yp_t, xp_t, p, KYMO.filter, KYMO.ponderation);
                                end
                            end % end loop on pixel junction
                        end
                        progressbar(k/(length(borderIDs)));
                    end % end loop on frame junction
                    
                    % max distance, used for data interpolation
                    maxDist = -1;
                    for i = 1:length(borderIDs)
                        indexs = find( kymoChannel1(i,:) );
                        dist{i} = kymoDistance(i, indexs );
                        channel1{i} = kymoChannel1(i, indexs );
                        if secondChannel
                            channel2{i} = kymoChannel2(i, indexs );
                        end
                        if ~isempty(dist{i})
                            maxDist = max(maxDist, max(dist{i}));
                        end
                    end
                    if mod(ceil(maxDist),2) == 0
                        maxDist = ceil(maxDist);
                    else
                        maxDist = floor(maxDist);
                    end
                    di = 1:1:maxDist;
                    iChannel1 = zeros(length(borderIDs), length(di));
                    iChannel2 = zeros(length(borderIDs), length(di));
                    %  interpolation of the kymograph
                    for i = 1:length(borderIDs)
                        if isempty(channel1{i})
                            iChannel1(i,:) = zeros(1,length(di));
                            if secondChannel
                                iChannel2(i,:) = zeros(1,length(di));
                            end
                        else
                            iChannel1(i,:) = interp1(dist{i}, channel1{i}, di);
                            if secondChannel
                                iChannel2(i,:) = interp1(dist{i}, channel2{i}, di);
                            end
                        end
                    end
                    % justify the kymograph
                    cChannel1 = zeros(length(borderIDs), length(di));
                    cChannel2 = zeros(length(borderIDs), length(di));
                    for i = 1:length(borderIDs)
                        maxIndexValue = sum( iChannel1(i,:) > 0 );
                        shift = floor((maxDist - maxIndexValue) ./ 2);
                        if shift > 0
                            cChannel1(i,(1+shift):(maxIndexValue+shift)) = iChannel1(i,1:maxIndexValue);
                            if secondChannel
                                cChannel2(i,(1+shift):(maxIndexValue+shift)) = iChannel2(i,1:maxIndexValue);
                            end
                        else
                            cChannel1(i,:) = iChannel1(i,:);
                            if secondChannel
                                cChannel2(i,:) = iChannel2(i,:);
                            end
                        end
                    end
                    % saving kymograph
                    dataType = class(channel1RawImage);
                    nameChannel1 = [kymographFolderPath filesep 'kymograph_' DATA.rootFilename{1} 'j=' num2str(borderIDs(1)) '.png'];
                    imwrite(cast(cChannel1,dataType), nameChannel1);
                    if secondChannel
                        nameChannel2 = [kymographFolderPath filesep 'kymograph_' DATA.rootFilename{2} 'j=' num2str(borderIDs(1)) '.png'];
                        imwrite(cast(cChannel2,dataType), nameChannel2);
                    end
                end
                %--------------------------------------------------------------
            otherwise
                disp('toto');
                %--------------------------------------------------------------
        end % end switch
        
        
    end % interaction loop
    
    
end % figure loop

% close figure
close(fig);


%% nested function to filter pixels list
    function pixs = getPixels(binfo, rown)
        if nargin == 1
            pixs = binfo(:,12:end); % 2012-08-02
        else
            pixs = binfo(rown, 12:end); % 2012-08-02
            pixs = pixs(pixs > 0); % remove trailing zeros
        end
        % transpose if MTracking
        if nargin==2
            [yt,xt] = ind2sub([imgSize(2) imgSize(1)], pixs);
            pixs = sub2ind(imgSize, xt, yt);
        end
    end % end function getPixels()



%% 2012-03-27: read BORDERSI content % 2012-06-15: mad removed % 2012-08-02: short mint & mint removed
    function [bid,ban,bsh,bmi,ble,bco,bra,bcu,bis,bnp,bak,sli,npl,ocha] = readBORDERSI(frame, line)
        bid=BORDERSI{frame}(line,1);        % border id
        ban=BORDERSI{frame}(line,2);        % border angle
        bsh=-1;                             % border short mint
        bmi=-1;                             % border mint
        ble=BORDERSI{frame}(line,3);        % border length
        bco=BORDERSI{frame}(line,4);        % border cord length
        bcu=BORDERSI{frame}(line,5);        % border curvature (radius)
        bis=BORDERSI{frame}(line,6);        % border intensity sum
        bnp=BORDERSI{frame}(line,7);        % border number of pixel after dilation
        bra=BORDERSI{frame}(line,8);        % border intensity ratio
        bak=BORDERSI{frame}(line,9);        % local background estimation % 2012-04-04
        sli=BORDERSI{frame}(line,10);       % local integrated intensity % 2012-04-04
        npl=BORDERSI{frame}(line,11);       % local number of pixel
        ocha=[];                            % other chanel
        % pxlList=BORDERSI{frame}(line,(12:(12+ble)-1)); % pixel id list
    end % end function readBORDERSI()



%% nested function to update display %%
    function upDisplay()
        clear imageRGB; % clean memory
        imageRGB = rawImage;
        bID = 0;
        % background substraction
        if bless
            % 2011-12-12: estimate background if necessary
            if isempty(backgrounds{indexFrame})
                backgrounds{indexFrame} = imopen(imageRGB, strel('disk', 30));
            end
            % substract background
            imageRGB = imsubtract(imageRGB, backgrounds{indexFrame});
            % adjust intensity
            imageRGB = imadjust(imageRGB);
        end
        % CLAHE
        if equalized
            imageRGB = adapthisteq(imageRGB);
        end
        % skeleton
        if skelon
            imageRGB = imoverlay(imageRGB, segImage, skeleton_color);
        end
        % tmode
        if btrack ~= 0
            if btrack < 0 % 2012-05-11
                bID = -btrack;
            else
                % get border tracking
                bID = borderTracking(btrack, indexFrame);
            end
            % exist !
            if(bID ~= 0)
                [line3,~] = find(BORDERSI{indexFrame}(:,1)==bID);
                % get pixels
                borderToDraw = getPixels(BORDERSI{indexFrame},line3); %2011-12-12
                % 2012-02-07
                if ~showLocal
                    track_mask = false(imgSize);
                    track_mask(borderToDraw) = true;
                    imageRGB = imoverlay(imageRGB, track_mask, boxedbordercolor); % adding track mask
                end
            end
        end
        % Display
        if bID==0 || ~showLocal
            imshow(imageRGB, 'Border', 'tight');
        end
        if bID ~= 0
            % lifetag
            lifetag = 'xx[ ]xxx';
            %        12345678
            padme = 0;
            scut = indexFrame; % cut start
            if scut < 1
                padme = padme + 1 - scut;
                scut = 1;
            end
            ecut = min(indexFrame+3, nbFrames); % cut end
            % tracking cut
            if btrack<0 % 2012-05-11
                lifetag(4)='1';
            else
                mlife=borderTracking(btrack, scut:ecut);
                for temp_i = 1:length(mlife)
                    if padme + temp_i == 3
                        padme = padme + 1;
                    end
                    if mlife(temp_i) ~= 0
                        lifetag(padme+temp_i) = '1';
                    else
                        lifetag(padme+temp_i) = '0';
                    end
                    if padme + temp_i == 4
                        padme = padme + 1;
                    end
                end
            end
            % 2012-01-30: local mean intensity estimation
            [yb,xb] = ind2sub(imgSize, borderToDraw);
            % border centroid
            Bcentroid = round([mean(yb) mean(xb)]);
            
            % 2012-01-31: replaced by a function
            %             [~,mask,~]=localMeanBorderIntensity(i,Bcentroid);
            % 2012-08-02: mask now reflects c++ processing
            mask = localMask(Bcentroid);
            
            % 2012-02-07: display area of computation
            if showLocal
                imageRGB = imoverlay(imageRGB, mask, [1 1 0]);
                % display
                imshow(imageRGB, 'Border', 'tight');
                hold on
                % display centroid
                plot(Bcentroid(2), Bcentroid(1), 'c*');
            end
            % 2012-03-28 % 2012-06-15
            [~,angleR,~,~,len,cor,rat,curv,isum,ndpix,bkg,lsi,lnp] = readBORDERSI(indexFrame, line3);
            lmbi = lsi / lnp;
            mint = isum / ndpix;
            % display border's infos
            texthandle=text(10,130,...
                ['ID: ' num2str(bID) 10 ...
                'Mean Border Intensity: ' num2str(mint) 10 ...
                'Intensity Ratio: ' num2str(rat) 10 ...
                'Local Background Int.: ' num2str(bkg) 10 ...
                'Local Mean Border Int.: ' num2str(lmbi) 10 ...
                'Angle: ' num2str(180*angleR/pi) '°' 10 ...
                'Length: ' num2str(len) 10 ...
                'Cord Length: ' num2str(cor) 10 ...
                'Tortuosity: ' num2str(len/(cor+1)) 10 ...
                'Curvature: ' num2str(curv) 10 ... %2012-01-20: curvature
                '# of pixels: ' num2str(numel(borderToDraw)) 10 ...
                'Neighbours (Relative): ' num2str(NEIGHBOURS{indexFrame}{2}(line3)) ' | ' num2str(NEIGHBOURS{indexFrame}{3}(line3)) 10 ...
                'Neighbours (Absolute): ' NEIGHBOURS{indexFrame}{4}{line3} ' | ' NEIGHBOURS{indexFrame}{5}{line3} 10 ...
                'Life: ' lifetag],...
                'BackgroundColor',boxedbordercolor,'Units','pixels');
        end
    end % end function upDisplay()



%% local mask function
    function MASK = localMask(BCentroidYX)
        MASK = false(imgSize);
        % top left corner
        topleftcorner.x = max(1, BCentroidYX(2) - backgroundArea);
        topleftcorner.y = max(1, BCentroidYX(1) - backgroundArea);
        % bottom right corner
        bottomrightcorner.x = min(BCentroidYX(2) + backgroundArea, imgSize(2));
        bottomrightcorner.y = min(BCentroidYX(1) + backgroundArea, imgSize(1));
        % mask
        MASK(topleftcorner.y:bottomrightcorner.y,topleftcorner.x:bottomrightcorner.x) = segImage(topleftcorner.y:bottomrightcorner.y,topleftcorner.x:bottomrightcorner.x);
    end % end function localMask()



% 2012-01-31: estimate local mean border intensity : LEGACY !
    function [mi,locmask,mb] = localMeanBorderIntensity(framei, BCentroid, filteredIDs)
        % top left corner
        topleftcorner.x = BCentroid(2) - backgroundArea;
        topleftcorner.y = BCentroid(1) - backgroundArea;
        % bottom right corner
        bottomrightcorner.x = BCentroid(2) + backgroundArea;
        bottomrightcorner.y = BCentroid(1) + backgroundArea;
        mbi = 0;
        nb = 0;
        locmask = false(imgSize); % debug use
        % get all the borders to keep in all frames
        % 2012-02-07: background estimation
        bkgnpix = 0;
        bkg = 0;
        % for each border in the list
        for j = 1:size(BORDERSI{framei-DATA.startFrame+1}, 1)
            % 2012-02-17: if border not in the list, skip
            if nargin == 3 && ~any(ismember(filteredIDs,BORDERSI{framei-DATA.startFrame+1}(j,1)))
                continue;
            end
            % get pixels
            pixs = getPixels(BORDERSI{framei-DATA.startFrame+1}, j);
            % convert to x,y
            [yp,xp] = ind2sub(imgSize,pixs);
            % within the box ?
            iny = (yp>=topleftcorner.y) & (yp<=bottomrightcorner.y);
            inx = (xp>=topleftcorner.x) & (xp<=bottomrightcorner.x);
            % keep if at least one pixel within the box
            if sum(iny & inx) > 1
                locmask(pixs) = true; % debug use
            end
        end
        % security
        if nb == 0 % this should never be reached !
            mi = -1;
            mb = -1; % 2012-02-07
        else
            mi = mbi / nb;
            mb = bkg / bkgnpix; % 2012-02-07
        end
    end % end function localMeanBorderIntensity()






%% 2014-06-05: neighbour kymo get value
% filter choice : line square and cross
% proc choice : sum mean
    function value = getKymoValue_b( image, yp_t, xp_t, p, filter, pond )
        pond = reshape(pond,[1 numel(pond) 1]);
        shift_h = filter(1);
        shift_w = filter(2);
        yp = repmat( [yp_t(p)-shift_h:yp_t(p)+shift_h],[1,3,1]);
        xp = reshape(repmat( [xp_t(p)-shift_w:xp_t(p)+shift_w],[3,1,1]),[1 length(yp)]);
        subImageInd = sub2ind(size(image),yp,xp);
        value_t = [];
        for i = 1:length(subImageInd)
            [yp,xp] = ind2sub(size(image),subImageInd(i));
            value_t = [ value_t image(yp,xp) ];
        end
        value = sum( double(value_t) .* pond ) ./ sum( pond );
    end % end function getKymoValue_b()

%% 2014-06-05: neighbour kymo get value
% filter choice : line square and cross
% proc choice : sum mean
    function [value,pixelList] = getKymoValue_b2( image, yp_t, xp_t, p, filter, cellPixelList )
        shift_h = filter(1);
        shift_w = filter(2);
        yp = repmat( [yp_t(p)-shift_h:yp_t(p)+shift_h],[1,filter(1).*2,1]);
        xp = reshape(repmat( [xp_t(p)-shift_w:xp_t(p)+shift_w],[filter(1).*2,1,1]),[1 length(yp)]);
        subImageInd = sub2ind(size(image),yp,xp);
        indBord = sub2ind(size(image),yp_t(p),xp_t(p));
        value_t = [];
        pixelList = [];
        for i = 1:length(subImageInd)
            if ismember(subImageInd(i),cellPixelList) %|| (subImageInd(i) == indBord)
                [yp,xp] = ind2sub(size(image),subImageInd(i));
                distPonderation = sqrt( (xp_t(p) - xp).^2 + (yp_t(p) - yp).^2);
                value_t = [ value_t image(yp,xp)./distPonderation ];
                pixelList = [pixelList subImageInd(i)];
            end
        end
        value = mean(value_t);
    end % end function getKymoValue_b2()






end





