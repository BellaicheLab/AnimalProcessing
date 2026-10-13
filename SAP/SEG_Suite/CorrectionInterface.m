function CorrectionInterface(startFrame_Correction, finalFrame_Correction, IMAGE)

%% SETTINGS %%
MAXDOTS = 100; % Max Number of Dots (2011-05-12)
screnSize = get(0, 'ScreenSize'); % screen size
modal = false; % modal window style (2011-06-24)
nzoom = 0; % zoom level
skelon = true; % display skeleton (2011-09-02)
equalized = false; % histogram equalization (2011-08-17)
bless = false; % background substraction (2011-10-17)
mad_on = false;
mde_on = false;
keyOn = false;
rgbMOn = false; % rgb mask (2012-01-03)
ctdMOn = false; % (2.0)
cptMOn = false; % (2.0)
ONEATaMOn = false; % (2.0)
ONEATdMOn = false; % (2.0)
greenDotSize = 2;
%Initialisation (in case of non-existance) (2.0)
maskRGB = 1;
ctdRGB = 1;
cptRGB = 1;
ONEATaRGB = 1;
ONEATdRGB = 1;
testCPTclone = 1; % Need double test for cptRGB
    

% figure positioning
Left = 1;
Bottom = 50;
Width = screnSize(3);
Height = screnSize(4) - 125;

%initialize the status of the 2 masks for the glasbey and the ctd
ctd = 0;
pngon = 0;
if IMAGE.ctdDisOn
    content = dir(IMAGE.pathFolderCTD); 
    % find the directory containing the ctd frames
    for i = 1:numel(content)
        % Check if the item is a directory
        if content(i).isdir
            direc_ctd = content(i);
        end
    end
    disp(direc_ctd.name);
end
   


greenDotSizeEff = greenDotSize + 0.5;
%% Dialog box to unselect some Help Displays

list = { 'Don''t use "s"','Don''t use "t"','Don''t use "c"','Don''t use "A"','Don''t use "D"'};             

[indx,tf] = listdlg('PromptString',{'Select commands you won''t use. ',...
    '',...
    'You can save time while changing frames',...    
    'by desactivating some commands before correction launch.',...
    '',...
    'Press Ctrl to make multiple selection.',''},'ListString',list, 'Name','Commands limitation to increase speed','ListSize',[350 110]);

%% INTERACTION LOOP %%
MAINbye = false;
i = startFrame_Correction;

while ~MAINbye

    %% SOME PARAMETERS INIT ... %%   

    % Load images
    rawimage = imread([IMAGE.pathFolderRaw filesep IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormatRaw]);
    segimage = ~imread([IMAGE.pathFolderSeg filesep IMAGE.segFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat], IMAGE.imageFormat);
    mask = rawimage * 0;   %initialize the mask for ctd and glasbey
    if IMAGE.glasOn
        pngMask = imread([IMAGE.pathSaveFolder filesep 'glasbey' filesep 'ct_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat]);
        pngMaskonoff = pngMask*pngon;
        
    end
    if IMAGE.ctdDisOn
        ctdMask = imread([IMAGE.pathFolderCTD filesep direc_ctd.name filesep 'CTD_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat]);
        ctdMask = imresize(ctdMask, IMAGE.imageSize);  % the ctd images often don't have the right size
        ctdMaskonoff = ctdMask*ctd;
        
    end
    % image size
    if ~exist('imageSize', 'var')
        imageSize = size(segimage); 
    end

    % masks display (2011-12-05)
    modif_mask_file = [IMAGE.pathFolderGUI filesep 'modif_mask_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
    % create the modification mask file if not found
    if ~exist(modif_mask_file, 'file')
        modif_mask = uint8(127 * ones(imageSize));
        imwrite(modif_mask, modif_mask_file, IMAGE.imageFormat); % convert to uint8 & save
    else
        modif_mask = imread(modif_mask_file);
    end
    
    % correction mask
    correction_file = [IMAGE.pathFolderGUI filesep 'correction_mask_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
    if ~exist(correction_file, 'file')
        blank = uint8( 127 * ones(imageSize) );
        imwrite(blank, correction_file);
    end
    correction_mask = imread(correction_file);

    
    % RGB mask
    if ismember(1,indx) == false 
        maskfile = [IMAGE.pathFolderGUI filesep 'maskRGB_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
        if exist(maskfile, 'file')
            maskRGB = imread(maskfile) * 0.5;
        end
    end
    
    % CTD mask (2.0)
    if ismember(2,indx) == false
        ctdFile = [IMAGE.pathFolderGUI filesep 'maskCTD_' filesep 'maskCTD_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
        if exist(ctdFile, 'file')
            ctdRGB = imread(ctdFile) * 0.6;
        end
    end
    
    % CPT mask (2.0)
    if ismember(3,indx) == false 
        cptFile = [IMAGE.pathFolderGUI filesep 'maskCPT_'  filesep 'maskCPT_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
        if exist(cptFile, 'file')
            cptRGB = imread(cptFile) * 0.5;
            testCPTclone = 0;
        end
    end
    
    % ONEATa mask (2.0)
    if ismember(4,indx) == false 
        oneatAFile = [IMAGE.pathFolderONEATa filesep 'maskONEATapoptosis_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
        if exist(oneatAFile, 'file')
            ONEATaRGB = imread(oneatAFile);
        end
    end

    % ONEATd mask (2.0)
    if ismember(5,indx) == false 
        oneatDFile = [IMAGE.pathFolderONEATd filesep 'maskONEATdivisions_' IMAGE.rootFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat];
        if exist(oneatDFile, 'file')
            ONEATdRGB = imread(oneatDFile);
        end
    end 
    
    
    % stay in the current frame
    stay = true;
    
    xyadd = zeros(2, MAXDOTS); % added dots array
    xydel = zeros(2, MAXDOTS); % deleted dots array
    nside_add = 0; % number of elements in xyadd
    nside_del = 0; % number of del dots
    nside_add_ONEAT = 0; %Special count for ONEAT PNG updates
    nside_del_ONEAT = 0;
    
    delmask = false(imageSize); % delete mask


    %% WINDOW SETUP %%
    
    interfaceHandle = figure(666);
    set(interfaceHandle, 'Units', 'pixels');
    set(interfaceHandle, 'Name', ['image ' num2str(i, IMAGE.digitsFormat) ' (overlay of image/segmentation)']);
    % always on top (2011-05-12, 2011-06-24: modal check added)
    if modal
        set(interfaceHandle, 'WindowStyle', 'modal');
    end
    updateDisplay(); % update display (2011-09-02)
    set(interfaceHandle, 'Position', [Left Bottom Width Height]); % Makes image fill the screen:


    %% INTERACTION LOOP %%
    while stay
        
        % try catch to quit properly if figure is closed by user using the close window button. (2011-06-29)
        
        try
            [xi, yi, buttemp] = ginputWhite(1);
        catch err
            if strcmp(err.identifier,'MATLAB:ginput:FigureDeletionPause')
                disp(err.identifier); % other error
            end
            return;
        end
        % no input detected
        if isempty(xi) || isempty(yi)
            disp('Problem : no mouse or keyboard input');
            return;
        end 
        
        % security for special keys (2011-12-02)
        if isempty(buttemp)
           disp('irregular key pressed!');
           buttemp = 0;
           xi = 0;
           yi = 0;
        end
        
        % 2011-06-30: caps lock warning
%         if buttemp > 64 && buttemp < 91
%             h = warndlg('BEWARE ! CAPS LOCK might be ON');
%             waitfor(h);
%         end
        
        % keep axis
        lim = axis;
        
        %% Input action definition
        switch buttemp
            %case 120
            %------------------------------------------------------
            % Remove points
            % Key: mouse wheel click
            %------------------------------------------------------
            
            case 2
                for pt = nside_add:-1:1
                    
                    if abs(xyadd(2,pt) - round(xi))<5 && abs(xyadd(1,pt) - round(yi)<5)
                        plot(xyadd(2,pt), xyadd(1,pt), 'o', 'MarkerEdgeColor', [1, 0.5, 0], 'MarkerFaceColor', [1, 0.5, 0], 'MarkerSize', 10);
                        xyadd(1,:) = [xyadd(1, 1:pt-1), xyadd(1, pt+1:end), 0];
                        xyadd(2,:) = [xyadd(2, 1:pt-1), xyadd(2, pt+1:end), 0];
                        nside_add = nside_add - 1;
                    end
                end
                for pt = nside_del:-1:1
                    if abs(xydel(2,pt) - round(xi))<5 && abs(xydel(1,pt) - round(yi)<5)
                        plot(xydel(2,pt), xydel(1,pt), 'o', 'MarkerEdgeColor', [1, 0.5, 0], 'MarkerFaceColor', [1, 0.5, 0], 'MarkerSize', 10);
                        inds = sub2ind(imageSize, xydel(1,pt), xydel(2,pt));
                        inds = SideDilator(imageSize, inds, greenDotSize);
                        delmask(inds) = false;
                        xydel(1,:) = [xydel(1, 1:pt-1), xydel(1, pt+1:end), 0];
                        xydel(2,:) = [xydel(2, 1:pt-1), xydel(2, pt+1:end), 0];
                        nside_del = nside_del - 1;
                        pt = pt - 1;
                        
                    end
                end
            
            %------------------------------------------------------
            % ADD SIDES
            % Key: Mouse-L-Click
            %------------------------------------------------------
            case 1
                if xi >= 1 && yi >= 0 && xi < imageSize(2) && yi < imageSize(1)
                    if nside_add < MAXDOTS
                        color = max(segimage(max(1, round(yi)-1):min(size(segimage, 1), round(yi)+1), max(1, round(xi)-1):min(size(segimage, 2), round(xi)+1)), [], 'all');
                        nside_add = nside_add + 1;
                        xyadd(1, nside_add) = round(yi); % y first!!!!
                        xyadd(2, nside_add) = round(xi);
                        %disp(xyadd);
                        %disp(nside_add);
                        %disp(xyadd(1, nside_add));
                        % Check the position in the other array
                        if color == 1                            
                            % Position is 1, display marker in a different color
                            plot(xi, yi, 'b+'); % blue color for position 1
                        else
                            % Position is 0, display marker in default color
                            plot(xi, yi, 'y+'); % Yellow color for position 0
                        end
                    else % number of dots limit reached!
                        wd = warndlg('You cannot add any more dots on this frame. Please SAVE the correction before adding any new dot.','WARNING : MAXIMUM DOTS NUMBER REACHED!','modal');
                        waitfor(wd);
                        
                    end
                end
            %----------------------------------------------------------
            % REMOVE SIDES
            % Key: Mouse-R-Click
            %----------------------------------------------------------
            case 3 
                if xi >= 1 && yi >= 0 && xi < imageSize(2) && yi < imageSize(1)
                    xi = round(xi);
                    yi = round(yi);
                    % lower limit case
                    if xi == 0, xi = 1; end
                    if yi == 0, yi = 1; end
                    % upper limit case
                    if xi > imageSize(2), xi = imageSize(2); end
                    if yi > imageSize(1), yi = imageSize(1); end
                    nside_del = nside_del + 1; % 0.8d
                    fprintf('delclick')
                    % convert to indice
                    inds = sub2ind(imageSize, yi, xi);
                    inds = SideDilator(imageSize, inds, greenDotSize);
                    delmask(inds) = true;
                    
                    % Display deletion patch:
%                     updateDisplay();
                    if nside_del < MAXDOTS
                        xydel(:,nside_del) = [yi ; xi];  % y first!!!!
                        Xs = [xi-greenDotSizeEff xi-greenDotSizeEff xi+greenDotSizeEff xi+greenDotSizeEff];
                        Ys = [yi-greenDotSizeEff yi+greenDotSizeEff yi+greenDotSizeEff yi-greenDotSizeEff];
                        patch(Xs,Ys,'cyan') 
                    else % number of dots limit reached !
                        wd = warndlg('You cannot add any more dots on this frame. Please SAVE the correction before adding any new dot.','WARNING : MAXIMUM DOTS NUMBER REACHED!','modal');
                        waitfor(wd);
                    end
                end
            %----------------------------------------------------------
            % ZOOM IN
            % Keys: '+' Up-Arrow '='
            %----------------------------------------------------------
            case {43 ; 30 ; 61}
                if xi >= 1 && yi >= 0 && xi < imageSize(2) && yi < imageSize(1)
                    nzoom = nzoom + 1;
                    zoom(2);
                    lim = axis;
                    % set new limits
                    lim = [xi+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]];
                    axis(lim);
                end
            %----------------------------------------------------------
            % HAND MODE
            % Keys: 'h' or 'p'
            %----------------------------------------------------------
            case {104}
                if modal
                    modal = false; % will permanantly switch the interface to normal
                    set(interfaceHandle, 'WindowStyle', 'normal');
                end
                pan on
                pause
                pan off    

            %----------------------------------------------------------
            % ZOOM OUT
            % Keys: '-' Down-Arrow
            %----------------------------------------------------------
            case {45 ; 31}
                nzoom = max(nzoom - 1, 0);
                zoom(0.5);
            %----------------------------------------------------------
            % Save and go next image
            % Keys: Right-Arrow
            %----------------------------------------------------------
            case 29
                % Checks some changes were actually made before exectuting changes, watershed and saving (0.8b):
                % save only if changes were made. (2011-09-05)
                if (nside_add > 0) || (nside_del > 0)
                    skip = false;
                    if mod(nside_add,2) ~= 0
                        button = questdlg('Odd number of dots detected.','WARNING! ODD NUMBER OF DOTS!','Return to the frame','Execute it anyway','Erase all','Execute it anyway');
                        switch button
                            case 'Return to the frame'
                                continue; %loop to next iteration
                            case 'Execute it anyway'
                                % ignore the last dot
                            case 'Erase all'
                                disp('Odd number of dots, dots erased');
                                skip = true;
                        end
                    end
                    if ~skip
                        updateSkeleton(); 
                    end
                end
                % leave current frame
                stay = false;
                % next !
                if i ~= finalFrame_Correction
                    i = i + 1;
                end
            %----------------------------------------------------------
            % Save and go previous image
            % Keys: Left-Arrow
            %----------------------------------------------------------
            case 28
                % Checks some changes were actually made before exectuting changes, watershed and saving (0.8b):
                % save only if changes were made. (2011-09-05)
                if (nside_add > 0) || (nside_del > 0)
                    skip = false;
                    if mod(nside_add, 2) ~= 0
                        button = questdlg('Odd number of dots detected.','WARNING! ODD NUMBER OF DOTS!','Return to the frame','Execute it anyway','Erase all','Execute it anyway');
                        switch button
                            case 'Return to the frame'
                                continue; % loop to next iteration
                            case 'Execute it anyway'
                                % ignore last dot
                            case 'Erase all'
                                disp('Odd number of dots, dots erased');
                                skip = true;
                        end
                    end
                    if ~skip
                        updateSkeleton();
                    end
                end
                stay = false;
                % update i
                if i ~= startFrame_Correction
                    i = i - 1; 
                end
            %----------------------------------------------------------
            % Eraser tool size interface
            % Keys: o
            %----------------------------------------------------------
            case 111
                prompt = {'Enter a value of Eraser tools (in pxl)'};
                title = 'Eraser tool size';
                definput = {num2str(greenDotSize)};
                answer = inputdlg(prompt,title,[1 40],definput);
                greenDotSize = str2double(answer{1});
                greenDotSizeEff = greenDotSize + 0.5;
            %----------------------------------------------------------
            % Contrast Limited Adaptative Histograme Equalisation (CLAHE)
            % Keys: e
            %----------------------------------------------------------            
            case 101
                equalized = ~equalized;
                updateDisplay();
            %----------------------------------------------------------
            % Background substraction
            % Keys: b
            %----------------------------------------------------------    
            case 98
                bless = ~bless;
                updateDisplay();
            
            %----------------------------------------------------------
            % Display/Hide glasbey mask
            % Keys: g
            %----------------------------------------------------------    
    
            case 103
                if IMAGE.glasOn
                    if pngon ~= 1
                        pngMaskonoff = pngMask*1;
                        pngon=1;
                    else
                        pngMaskonoff = pngMask * 0;
                        pngon=0;
                    end
                    updateDisplay();
                end
                
            %----------------------------------------------------------
            % Display/Hide CTD mask
            % Keys: r
            %----------------------------------------------------------    

            case 114
                if IMAGE.ctdDisOn
                    if ctd ~= 1
                        ctdMaskonoff = ctdMask*1;
                        ctd=1;
                    else
                        ctdMaskonoff = ctdMask * 0;
                        ctd=0;
                    end
                    updateDisplay();
                end
            %----------------------------------------------------------
            % Display suspicious borders (Updated in 2.0)
            % Keys: s
            %---------------------------------------------------------- 

       
            case 115
                if maskRGB ~= 1
                    rgbMOn = ~rgbMOn;
                    ctdMOn = false;
                    cptMOn = false; 
                    ONEATaMOn = false; 
                    ONEATdMOn = false;
                    updateDisplay();
                end
            %----------------------------------------------------------
            % Display CTD mask (2.0)
            % Keys: t
            %---------------------------------------------------------- 
            case 116
                if ctdRGB ~= 1
                    rgbMOn = false;
                    ctdMOn = ~ctdMOn;
                    cptMOn = false; 
                    ONEATaMOn = false; 
                    ONEATdMOn = false;
                    updateDisplay();
                end 
            %----------------------------------------------------------
            % Display CPT mask (2.0)
            % Keys: c
            %---------------------------------------------------------- 
            case 99
             if testCPTclone ~= 1
                    rgbMOn = false;
                    ctdMOn = false;
                    cptMOn = ~cptMOn; 
                    ONEATaMOn = false; 
                    ONEATdMOn = false;
                    updateDisplay()
              end
                
            %----------------------------------------------------------
            % Display ONEATa mask (2.0)
            % Keys: A
            %---------------------------------------------------------- 
            case 65
                if ONEATaRGB ~= 1
                    rgbMOn = false;
                    ctdMOn = false;
                    cptMOn = false; 
                    ONEATaMOn = ~ONEATaMOn; 
                    ONEATdMOn = false;
                    updateONEATa();
                    updateDisplay();
                end 
             
            %----------------------------------------------------------
            % Display ONEATd mask (2.0)
            % Keys: D 
            %---------------------------------------------------------- 
            case 68
                if ONEATdRGB ~= 1
                    rgbMOn = false;
                    ctdMOn = false;
                    cptMOn = false; 
                    ONEATaMOn = false;
                    ONEATdMOn = ~ONEATdMOn;
                    updateONEATd()
                    updateDisplay();
                end 
                
            %----------------------------------------------------------
            % Hide/Show segmentation skeleton
            % Keys: Tab or Suppr
            %----------------------------------------------------------
            case {9, 127}
                skelon = ~skelon;
                updateDisplay();
            %----------------------------------------------------------
            % Hide/Show modification mask (add)
            % Keys: a
            %---------------------------------------------------------- 
            case 97
                mad_on = ~mad_on;
                updateDisplay();
            %----------------------------------------------------------
            % Hide/Show modification mask (delete)
            % Keys: d
            %---------------------------------------------------------- 
            case 100
                mde_on = ~mde_on;
                updateDisplay();
            %----------------------------------------------------------
            % Window lock
            % Keys: l
            %----------------------------------------------------------  
            case 108
                modal = ~modal;
                if ~modal
                    set(interfaceHandle, 'WindowStyle', 'normal');
                else
                    set(interfaceHandle, 'WindowStyle', 'modal');
                end
            %----------------------------------------------------------
            % Display and Save modification on skeletonization
            % Keys: space, zero
            %----------------------------------------------------------      
            case {32 , 48}
                updateSkeleton();
                imwrite(~segimage,[IMAGE.pathFolderSeg filesep IMAGE.segFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat], IMAGE.imageFormat);
                % save the modification mask (2011-05-10)
                imwrite(modif_mask, modif_mask_file, 'png'); % save the modification mask
                nside_add_ONEAT = nside_add;
                nside_del_ONEAT = nside_del;
                nside_add = 0; % 0.8b
                nside_del = 0; % 0.8b
                delmask = false(imageSize); % reset delmask
                updateDisplay() % update display
            
            %----------------------------------------------------------
            % Return to previous segmentation
            % Keys: z
            %----------------------------------------------------------      
            case 122
                segimage = old_segimage;
                updateDisplay() % update display
            %----------------------------------------------------------
            % Display modification en skeletonization
            % Keys: space (or 0 numpad)
            %----------------------------------------------------------
            case 118
                % Checks if some changes were actually made before exectuting changes, watershed and saving (0.8b):
                % save only if changes were made. (2011-09-05)
                if (nside_add > 0) || (nside_del > 0)
                    skip = false;
                    if mod(nside_add, 2) ~= 0
                        button = questdlg('Odd number of dots detected.','WARNING! ODD NUMBER OF DOTS!','Return to the frame','Execute it anyway','Erase all','Execute it anyway');
                        switch button
                            case 'Return to the frame'
                                continue; % loop to next iteration
                            case 'Execute it anyway'
                                % the last dot will be ignored
                            otherwise % case 'Erase all' & case empty button
                                disp('Odd number of dots, dots erased');
                                skip = true;
                        end
                    end
                    if ~skip
                        updateSkeleton();
                    end
                end
                %nside_add_ONEAT = nside_add;
                %nside_del_ONEAT = nside_del;
                %nside_add = 0; % 0.8b
                %nside_del = 0; % 0.8b
                %delmask = false(imageSize); % reset delmask
                updateDisplay() % update display
            %----------------------------------------------------------
            % Jump to frame
            % Keys: j
            %----------------------------------------------------------  
            case 106
                if (nside_add > 0) || (nside_del > 0)
                    skip = false;
                    if mod(nside_add, 2) ~= 0
                        button = questdlg('Odd number of dots detected.','WARNING! ODD NUMBER OF DOTS!','Return to the frame','Execute it anyway','Erase all','Execute it anyway');
                        switch button
                            case 'Return to the frame'
                                continue; %loop to next iteration
                            case 'Execute it anyway'
                                % ignore the last dot
                            case 'Erase all'
                                disp('Odd number of dots, dots erased');
                                skip = true;
                        end
                    end
                    if ~skip
                        updateSkeleton(); 
                    end
                end
                % jumper
                if ~exist('newid', 'file')
                    rnframe = inputdlg(['Jump to frame # ? [' num2str(startFrame_Correction) '~' num2str(finalFrame_Correction) ']']);
                else
                    rnframe = newid(['Jump to frame # ? [' num2str(startFrame_Correction) '~' num2str(finalFrame_Correction) ']']);
                end
                if isempty(rnframe)
                    continue;
                elseif isempty(str2num(rnframe{1})) || mod(str2num(rnframe{1}), 1) || ~between(str2num(rnframe{1}), startFrame_Correction, finalFrame_Correction) %#ok<ST2NM>
                    wd = warndlg(['frame number must be an integer within [' num2str(startFrame_Correction) ','  num2str(finalFrame_Correction) '].']);
                    waitfor(wd);betw
                else
                    i = str2double(rnframe{1}); 
                    stay = false;
                end
            %----------------------------------------------------------
            % Quit interface
            % Keys: q esc
            %----------------------------------------------------------
            
            case {113 ; 27}
                % Checks some changes were actually made before exectuting changes, watershed and saving (0.8b):
                % save only if changes were made. (2011-09-05)
                if (nside_add > 0) || (nside_del > 0)
                    skip = false;
                    if mod(nside_add, 2) ~= 0
                        button = questdlg('Odd number of dots detected.','WARNING! ODD NUMBER OF DOTS!','Return to the frame','Execute it anyway','Erase all','Execute it anyway');
                        switch button
                            case 'Return to the frame'
                                continue; %loop to next iteration
                            case 'Execute it anyway'
                                % ignore last dot
                            case 'Erase all'
                                disp('Odd number of dots, dots erased');
                                skip = true;
                        end
                    end
                    if ~skip
                        updateSkeleton()
                    end
                end
                stay = false; % leave current frame
                MAINbye = true; % leave interface
        end % end switch case
    end % end while stay
end % end while MAINbye

% close last image 0.8b
close(interfaceHandle);

%% Nested Function %%

    %% nested function to modify the skeleton (2011-09-05) %%
    function updateSkeleton()
        old_segimage = segimage;
        if nside_add ~= 0
            for pt = 1:2:nside_add-1
                % skip if both dots are outside
                if (xyadd(2,pt)<1 || xyadd(2,pt)>imageSize(2) || xyadd(1,pt)<1 || xyadd(1,pt)>imageSize(1)) ...
                        && (xyadd(2,pt+1)<1 || xyadd(2,pt+1)>imageSize(2) || xyadd(1,pt+1)<1 || xyadd(1,pt+1)>imageSize(1))
                    continue;
                end
                lindex = drawline(xyadd(:,pt)', xyadd(:,pt+1)', imageSize);
                segimage(lindex) = 1;
            end
        end
        % delete borders
        if nside_del ~= 0
            segimage(delmask) = 0;
        end
        % Removes small cells: SmallCellRemover MUST HAVE white cells/black membranes as INPUT
        segimage = ~SmallCellRemover(~segimage, 5);
        % Removes incomplete sides
        segimage = ~watershed(segimage, 4);
        % save corrected skeleton in the results folder:
        %imwrite(~segimage,[IMAGE.pathFolderSeg filesep IMAGE.segFilename num2str(i, IMAGE.digitsFormat) '.' IMAGE.imageFormat], IMAGE.imageFormat);
        % mask update (2011-12-05)
        % update modification mask (2011-05-10)
        dif_mask = segimage - old_segimage; % after - before ;  <0: del ; >0:add
        modif_mask = modif_mask + uint8(dif_mask>0) - uint8(dif_mask<0); % update modif_mask
        % save the modification mask (2011-05-10)
        %imwrite(modif_mask, modif_mask_file, 'png'); % save the modification mask
    end % end updateSkeleton nested function

    %% nested function to update display %%
    %test
    % Display PNG mask
    
    function updateDisplay()
        mask = mask * 0;
        %rawimage = repmat(rawimage, [1, 1, 3]);
        
        imgdisp = rawimage;
        clear imageRGB; % clear to clean memory
        imageRGB = imgdisp * 0.9;
        
        % background substraction (2011-10-17)
        

        if bless
            background = imopen(imageRGB, strel('disk',5)); % estimate background
            imageRGB = imsubtract(imageRGB, background); % substract background
            imageRGB = imadjust(imageRGB); % adjust intensity
        end
        % CLAHE
        if equalized
            imageRGB = adapthisteq(imageRGB); % CLAHE
            imageRGB = imadjust(imageRGB); % adjust intensity
        end
        if skelon
            imageRGB = imoverlay(imageRGB, segimage, [1 0 1]); % skeleton
            % mad mask
            
            if mad_on
                imageRGB = imoverlay(imageRGB, modif_mask>127, [1 0.5 0]); % adding mad mask
                imageRGB = imoverlay(imageRGB, correction_mask>127, [1 0.5 0.5]); % adding correction mask (add)
            end
            % mde mask
            if mde_on
                imageRGB = imoverlay(imageRGB, modif_mask<127, [0 0.7 1]); % adding mde mask
                imageRGB = imoverlay(imageRGB, correction_mask<127, [0.2 0.8 0.2]); % adding correction mask (del)
            end
            % RGB mask (2012-01-03)
            if rgbMOn 
                imageRGB = imageRGB + maskRGB;
            end
            
            % CTD mask (2.0)
            if ctdMOn
                imageRGB = imageRGB + ctdRGB;
            end
            
            % CPT mask (2.0)
            if cptMOn
                 imageRGB = imageRGB + cptRGB;
            end
            
            % ONEATa mask (2.0)
            if ONEATaMOn
                 imageRGB = imageRGB * 0.85;
                 imageRGB = imageRGB + ONEATaRGB;
            end
            
            % ONEATd mask (2.0)
            if ONEATdMOn
                 imageRGB = imageRGB * 0.85;
                 imageRGB = imageRGB + ONEATdRGB;
            end
            
            
        end
        
%         if nside_del ~= 0
%             imageRGB = imoverlay(imageRGB, delmask, [0 1 0]);
%         end

        % deletes from the current axes all graphics objects
        cla reset;
        % Display:
        if IMAGE.glasOn 
            mask = mask + pngMaskonoff;
        end
        if IMAGE.ctdDisOn
            mask = mask + ctdMaskonoff;
        end
        
        imtop =  imageRGB + mask * 0.5;
        imshow(imtop, [], 'Border', 'tight');         
        hold on;
        % set zoom
        if nzoom ~= 0
%             zoom(2^nzoom); % was causing the anoying blinking
            axis(lim);
        end
        % Replots yellow crosses and green disks, if any (0.8b):
        if skelon && nside_add~=0
            plot(xyadd(2,1:nside_add), xyadd(1,1:nside_add), 'y+'); % Replots yellow crosses if any
        end
        
        if skelon && nside_del~=0
            % Repositioning deletion squares: WARNING y first in "xydel"!!!!
            Xs = [xydel(2,:)-greenDotSizeEff ; xydel(2,:)-greenDotSizeEff ; xydel(2,:)+greenDotSizeEff ; xydel(2,:)+greenDotSizeEff];
            Ys = [xydel(1,:)-greenDotSizeEff ; xydel(1,:)+greenDotSizeEff ; xydel(1,:)+greenDotSizeEff ; xydel(1,:)-greenDotSizeEff];
            patch(Xs,Ys,'cyan')
        end
        
        % To display rectangle of a ROI:
        if ~isempty(IMAGE.segZone)
            rectangle('Position',IMAGE.segZone,'EdgeColor','g');
        end
        
    end % end updateDisplay nested function

%% nested function to actualize ONEAT png (2020-09-30) %%
    function updateONEATa()

        if nside_add_ONEAT ~= 0 
            for k=1:nside_add_ONEAT
               ONEATaRGB(xyadd(1, k)-50:xyadd(1, k)+50 ,xyadd(2, k)-50:xyadd(2, k)+50,:) = zeros(101,101,3);
            end 
        end
        if nside_del_ONEAT ~= 0 
           for k=1:nside_del_ONEAT
               ONEATaRGB(xydel(1, k)-50:xydel(1, k)+50 ,xydel(2, k)-50:xydel(2, k)+50,:) = zeros(101,101,3);
           end
        end
        imwrite(ONEATaRGB, oneatAFile, 'png'); % save the modification mask
    end % end updateSkeleton nested function
  

    function updateONEATd()
        if nside_add_ONEAT ~= 0
            for k=1:nside_add_ONEAT
                ONEATdRGB(xyadd(1, k)-50:xyadd(1, k)+50 ,xyadd(2, k)-50:xyadd(2, k)+50,:) = zeros(101,101,3);
            end
        end
        if nside_del_ONEAT ~= 0 
            for k=1:nside_del_ONEAT
                ONEATdRGB(xydel(1, k)-50:xydel(1, k)+50 ,xydel(2, k)-50:xydel(2, k)+50,:) = zeros(101,101,3);
            end 
        end
        imwrite(ONEATdRGB, oneatDFile, 'png'); % save the modification mask
    end % end updateSkeleton nested function
 
end

%% History %%

% 06/10/2020: 2.0 (Lucas)
% - Adding CPT clone mask, ONEAT False Divisions mask, ONEAT False
% Apoptosis mask and change colouring of all layers (including previous
% one CTD mask and RGB mask). All these correction masks are stored in TMP_ folder and in ONEAT_ folder.
% - Update of ONEAT False Divisons mask by double typing D and
% ONEAT False Apoptosis mask by double typing A.
% - Avoid the interface to bug if some keys are typing by mistake
% - Possibility to unactivated some commands (keys) for the correction
% interface to increase the speed
% - Creation of short PDF file "Correction_Interface_Options" explaining all the
% keys in details for the user.

% 18/10/2019: (Boris)
% - loading a version of CTD images to help by hitting "t" key

% 20/03/19: (Boris)
% - added "Suppr" key (#127) to toggle skeleton display onto images (in
% addition to "Tab" #9)

% 19/02/19: (Boris)
% - added drawing of rectangle and loading of "segZone" defined in
% EpiSegLauncher and stored in "IMAGE".

% 21/12/18:
% - turns off display of added and deleted junctions by default (mad_on = false; & mde_on = false;)
% - fixed blinking when moving between frames in zoom mode
% - added "hand" (or "pan") mode to move image at a given zoom
% - accordingly initialize modal to "false" because hand mode need this to work.
% - now the green deletion squares are drawn with patches rather then using
% function "updateDisplay", thereby making this process must lighter.

