% TimeRegistration (formerly "FindRotationPeak")
%
% Asks user to click macrochaetes in a specific order, then runs PIV to
% determine the rotation peak in a subregion of the scutellum in order to
% achieve TIME registration.
%
version = '4.3';
% Isabelle Bonnet
% Stephane Rigaud
% Boris Guirao


%% INITIALIZATION %%

%%% Definition of additional parameters:
frame18h00 = time2frame('18h00',timeRef,frameRef,dt);   % now uses values defined in SAP_info_Animal (4.0)
frame18h00 = round(frame18h00); % 4.1 % approximate frame corresponding to P1 cell 1st division
meanFrameWidth = round(120/dt);                         % width of time-averaging: 2h of development = 120 min, in frames
overlapSync = 0;                                        % no overlap for synchronization
gridSizeSync = 8;                                       % PIV parameter
graphicalOutput = false;                                % to display and save frames with piv vectors (3.3)

% PIV parameters
gridSize1 = 16*gridSizeSync;
gridSize2 = 8*gridSizeSync;
boxSize = gridSize2;                            % the size of PIV box
gridStep =(1-overlapSync)*boxSize;              % The distance between 2 PIV-points
gridSizeLetter = 'L';
% overlap corresponds to neighboring sub-windows in the same image

mkdir(pathFolderTR);

%%% Displaying info (4.1):
disp(' '); disp(' ');
disp(['TimeRegistration ' version  ': processing "' Animal '" on frame # ' num2str(frame18h00)]);
disp('---------------------------------------------------------------------------------');


%%% Writing txt file (4.0)
today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style. Look up date for details
txtFilename = [today '_TR_' version '.txt'];
% Writing main parameters in txt file:
parameterCell = {   'Parameters:',[];
                    [],[];
                    'halfNotum = ', halfNotum;
                    'timeRef = ', timeRef;
                    'frameRef = ', frameRef;
                    'gridSizeSync = ', gridSizeSync;
                    'gridSizeLetter = ', gridSizeLetter;
                    'overlapSync = ', overlapSync};

dlmcell([pathFolderTR filesep txtFilename], parameterCell,' '); % using "saveFolder" instead of "pathFolderCPT" (3.5)


%% User Interface to click Macros at 18h00 APF %%

% Graphical User Interface
disp('+ or up-arrow to zoom in');
disp('- or down-arrow to zoom out');
disp('"f" or "F" (shift + f) to save and finish');

% 1st step: determine X/Y axes relative to macrocahetaes position
im2show = imread([pathFolderRaw filesep filenameRaw{1} num2str(frame18h00,digitsFormat),'.tif']);
[ny0, nx0] = size(im2show);

% Checking that images have been converted to 8-bit (3.4):
isUint8  = isa(im2show, 'uint8');
if ~isUint8
    disp('"FindRotationPeak" : images used for PIV must be OPTIMALLY converted into 8-bit images!')
end

% Display image
h1 = figure;
imshow(im2show,[],'border','tight');
set(h1,'Position', positionFullScreen);
% imshow(im2show,[],'border','tight','InitialMagnification',100)
hold on

% The user must click the macrochaetae
text(30,50,[sideStr '' ': click macrochaete from left to right (of animal)'],'Color','yellow','FontSize',fontSizeInfo) % mod 3.3
textAnimal = [Animal ' # ' num2str(frame18h00) ' (estimated 18h00 APF)'];                                               % 3.3, 4.0
xyOffsetOther = [5 5];                                      % different offset than for scalebar (3.3)
PlotText(textAnimal, '', xyOffsetOther, - fontSizeInfo*0.6, 'normal','yellow', 'BL'); % 3.3, 4.0, use negative fontSize to avoid tex interpreter (4.1)

% Initializes variable "but" to loop until user has finished
stop = 0;
nMacro = 0;
xyMacro = NaN(nMacroMAXtime,2); % 4.0
while stop == 0 % loop to stay in the interface till user press F
    
    lim = axis;
    % get input from user
    [xi,yi,button] = ginputWhite(1); % using "ginputWhite" (4.0)
    
    % get macrochaetae coordinates
    if button == 1 || button == 49 % left mouse button = add segment
        x = round(xi);
        y = round(yi);
        plot(x,y,'y+');
        nMacro = nMacro+1;
        %number of Macro added
        xyMacro(nMacro,1) = x;
        xyMacro(nMacro,2) = y;
        
        if nMacro == nMacroMAXtime
            stop=1;
        end
        
        % ZOOM IN
    elseif button == 43 || button==30 || button==61
        zoom(2)
        lim = axis;
        lim = [xi+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]];
        axis(lim)
        
        % ZOOM OUT
    elseif button == 45 || button ==31
        zoom(0.5)
        % FINISH , EXIT
    elseif button==70 || button==102  % finish = F or f
        stop =1;
    end
end


% Take back coordinates of the macrochaetae
zoom out
xM = xyMacro(:,1);
yM = xyMacro(:,2);
% Display the X / Y axes
if halfNotum =='l'
    
    Xref=floor(xM(1)); % If Xref/Yref is not rounded, resizing fails sometimes
    Yref=floor(yM(2));
    hline = refline([0 Yref]); % Xaxis
    set(hline,'Color','g')
    vline=line([Xref Xref],[0 ny0]); % Yaxis
    set(vline,'Color','g')
    
elseif halfNotum=='r'
    
    Xref=floor(xM(2));
    Yref=floor(yM(1));
    hline = refline([0 Yref]); % Xaxis
    set(hline,'Color','r')
    vline=line([Xref Xref],[0 ny0]); % Yaxis
    set(vline,'Color','r')
    
elseif halfNotum=='b'
    
    XrefL=floor(xM(1));
    YrefL=floor(yM(2));
    XrefR=floor(xM(4));
    YrefR=floor(yM(3));
    hlineL = refline([0 YrefL]); % Xaxis
    set(hlineL,'Color','g')
    hlineR = refline([0 YrefR]); % Xaxis
    set(hlineR,'Color','r')
    vlineL=line([XrefL XrefL],[0 ny0/2]); % Yaxis
    set(vlineL,'Color','g')
    vlineR=line([XrefR XrefR],[ny0/2 ny0]); % Yaxis
    set(vlineR,'Color','r')
end


% Save a graphical output of the clicking
saveas(h1,[pathFolderTR filesep 'Macro_clicked_frame_#'  num2str(frame18h00) '.tif'],'tif')
close(h1)
% Save macrochaetaes coordinates
dlmwrite([pathFolderTR filesep 'Macro_XYs.txt'],xyMacro, 'delimiter', '\t','newline', 'pc')


% 2d step : crop the image around the ROI
refWindowWidth = 5*boxSize; %in pixels
refWindowHeight = 3*boxSize;
if halfNotum=='l' || halfNotum=='r'
    
    Xcrop = Xref-2.5*boxSize;
    Ycrop = Yref-2.5*boxSize;
    
elseif halfNotum=='b'
    
    XcropL = XrefL-2.5*boxSize;
    YcropL = YrefL-2.5*boxSize;
    XcropR = XrefR-2.5*boxSize;
    YcropR = YrefR-2.5*boxSize;
end
widthCrop= 7*boxSize;
heightCrop= 5*boxSize;
%--------------------------------------------------------------------------


%% PIV computations %%

% Initialization
if halfNotum=='l' || halfNotum=='r'
    
    gridXYs = cell(2,1);
    gridUVs = cell(finalFrame,2);
    scaleVector = 0;
    
elseif halfNotum=='b'
    
    gridXYs = cell(4,1);
    gridUVs = cell(finalFrame,4);
    scaleVectorL = 0;
    scaleVectorR = 0;
end

% 1st loop, without averaging
for n = startFrame:finalFrame-1 % Loop over frames; starts at "startFrame" (4.0)
    
    % Load first and last frame of the interval
    im1 = imread([pathFolderRaw,filesep,filenameRaw{1} num2str(n,'%04d'),'.tif']);
    im2 = imread([pathFolderRaw,filesep,filenameRaw{1} num2str(n+1,'%04d'),'.tif']);
    
    % Resizing
    if halfNotum == 'l' || halfNotum == 'r'
        im1Crop = im1(Ycrop:Ycrop+heightCrop-1,Xcrop:Xcrop+widthCrop-1);
        im2Crop = im2(Ycrop:Ycrop+heightCrop-1,Xcrop:Xcrop+widthCrop-1);
    elseif halfNotum == 'b'
        % left
        im1CropL = im1(YcropL:YcropL+heightCrop-1,XcropL:XcropL+widthCrop-1);
        im2CropL = im2(YcropL:YcropL+heightCrop-1,XcropL:XcropL+widthCrop-1);
        % right
        im1CropR = im1(YcropR:YcropR+heightCrop-1,XcropR:XcropR+widthCrop-1);
        im2CropR = im2(YcropR:YcropR+heightCrop-1,XcropR:XcropR+widthCrop-1);
    end
    
    clear im1 im2
    
    % PIV
    if halfNotum=='l' || halfNotum=='r'
        [x,y,u0,v0] = matpiv(im1Crop,im2Crop,[gridSize1 gridSize1; gridSize2 gridSize2],1,overlapSync,'multin');
        % Right units for velocities
        u = u0*scale1D/dt; v=v0*scale1D/dt; % ?m/min
        
        % Remove the NAN (useful for interpolation) from u and v
        u(isnan(u))=0; v(isnan(v))=0;
        
        % Only for 1st frame
        if n == startFrame                % use of startFrame (4.0)
            %--- Saving grid position only for 1st frame
            gridXYs{1}=x;
            gridXYs{2}=y;
            save([pathFolderTR filesep 'gridXYs' '.mat'],'gridXYs','-mat')
        end
        
        % Saving cropped image
        if n==frame18h00
            
            h2=figure;
            imshow(im1Crop,[],'InitialMagnification',75)
            hold all
            text(widthCrop/10, heightCrop/10,sideStr,'Color','y','FontSize',22)
            scatter(xM-Xcrop,yM-Ycrop,'+y');
            hline = refline([0 Yref-Ycrop]); % Xaxis
            set(hline,'Color','y')
            vline=line([Xref-Xcrop Xref-Xcrop],[0 heightCrop]); % Yaxis
            set(vline,'Color','y')
            rectangle('Position',[boxSize,boxSize,refWindowWidth,refWindowHeight],'EdgeColor','Yellow','LineWidth',3)
            % Saving image of ref windows
            saveas(h2,[pathFolderTR filesep 'Ref_windows_' sideStr '_18h00.tif'],'tif'); % mod 4.0
            close(h2)
        end
        
        % Keeping velocity fields
        scaleVector=max([scaleVector, max(abs(u(:))), max(abs(u(:)))]);
        gridUVs{n,1} = u;
        gridUVs{n,2} = v;
        clear u0 v0 u v
        
        
    elseif halfNotum=='b'
        
        [xL,yL,u0L,v0L] = matpiv(im1CropL,im2CropL,[gridSize1 gridSize1; gridSize2 gridSize2],1,overlapSync,'multin');
        [xR,yR,u0R,v0R] = matpiv(im1CropR,im2CropR,[gridSize1 gridSize1; gridSize2 gridSize2],1,overlapSync,'multin');
        
        % Right units for velocities
        uL = u0L*scale1D/dt;
        vL = v0L*scale1D/dt; % um/min
        uR = u0R*scale1D/dt;
        vR = v0R*scale1D/dt;
        
        % Remove the NAN (useful for interpolation) from u and v
        uL(isnan(uL))=0;
        vL(isnan(vL))=0;
        uR(isnan(uR))=0;
        vR(isnan(vR))=0;       
        
        % Only for 1st frame
        if n == startFrame                % use of startFrame (4.0)
            % Saving grid position only for 1st frame
            gridXYs{1}=xL;
            gridXYs{2}=yL;
            gridXYs{3}=xR;
            gridXYs{4}=yR;
            save([pathFolderTR filesep 'gridXYs' '.mat'],'gridXYs','-mat')
        end
        
        % Saving cropped image
        if n==frame18h00
            
            h3=figure;
            
            % LEFT side
            subplot(2,1,1)
            imshow(im1CropL,[])
            text(widthCrop/10, heightCrop/10,'LEFT','Color','y','FontSize',22)
            hold all
            scatter(xM(1:2)-XcropL,yM(1:2)-YcropL,'+g');
            hline = refline([0 YrefL-YcropL]); % Xaxis
            set(hline,'Color','g')
            vline=line([XrefL-XcropL XrefL-XcropL],[0 heightCrop]); % Yaxis
            set(vline,'Color','g')
            rectangle('Position',[boxSize,boxSize,refWindowWidth,refWindowHeight],'EdgeColor','Yellow','LineWidth',3)
        
            
            % RIGHT side
            subplot(2,1,2)
            imshow(im1CropR,[])
            text(widthCrop/10, heightCrop/10,'RIGHT','Color','y','FontSize',22)
            hold all
            scatter(xM(3:4)-XcropR,yM(3:4)-YcropR,'+r');
            hline = refline([0 YrefR-YcropR]); % Xaxis
            set(hline,'Color','r')
            vline=line([XrefR-XcropR XrefR-XcropR],[0 heightCrop]); % Yaxis
            set(vline,'Color','r')
            rectangle('Position',[boxSize,boxSize,refWindowWidth,refWindowHeight],'EdgeColor','Yellow','LineWidth',3)
            
            % Saving image of ref windows:
            saveas(h3,[pathFolderTR filesep 'Ref_windows_' sideStr '_18h00.tif'],'tif'); % mod 4.0
            close(h3)
        end
        
        if halfNotum=='l' || halfNotum=='r'
            scaleVector=max([scaleVector, max(abs(u(:))), max(abs(u(:)))]);
            
            gridUVs{n,1}=u;
            gridUVs{n,2}=v;
            clear u0 v0 u v
            
        elseif halfNotum=='b'
            
            scaleVectorL=max([scaleVectorL, max(abs(uL(:))), max(abs(uL(:)))]);
            scaleVectorR=max([scaleVectorR, max(abs(uR(:))), max(abs(uR(:)))]);
            
            gridUVs{n,1}=uL;
            gridUVs{n,2}=vL;
            gridUVs{n,3}=uR;
            gridUVs{n,4}=vR;
            clear u0_l v0_l u_l v_l u0_r v0_r u_r v_r
        end   
    end
end

% Saving velocity fields
save([pathFolderTR filesep 'gridUVs.mat'],'gridUVs','-mat')

if halfNotum=='l' || halfNotum=='r'
    
    scaleVector=0.5*scaleVector;
    
elseif halfNotum=='b'
    
    scaleVectorL=0.5*scaleVectorL;
    scaleVectorR=0.5*scaleVectorR;
end


% 2d loop, temporal aeraging
Rot = NaN(finalFrame - meanFrameWidth,1); % 4.0
RotL = NaN(finalFrame - meanFrameWidth,1); % 4.0
RotR = NaN(finalFrame - meanFrameWidth,1); % 4.0

for n = startFrame:(finalFrame - meanFrameWidth)             % Loop over frames; % use of "startFrame" (4.0)
    
    % Averaging
    if halfNotum=='l' || halfNotum=='r'
        
        for i = 1:meanFrameWidth
            uTemp(:,:,i) = gridUVs{n+i-1,1};
            vTemp(:,:,i) = gridUVs{n+i-1,2};
        end
        uMean = mean(uTemp,3);
        vMean = mean(vTemp,3);
        
        clear uTemp vTemp
        
    elseif halfNotum=='b'
        
        for i = 1:meanFrameWidth
            % LEFT
            uTempL(:,:,i) = gridUVs{n+i-1,1};
            vTempL(:,:,i) = gridUVs{n+i-1,2};
            % RIGHT
            uTempR(:,:,i) = gridUVs{n+i-1,3};
            vTempR(:,:,i) = gridUVs{n+i-1,4};
        end
        
        % LEFT
        uMeanL = mean(uTempL,3);
        vMeanL = mean(vTempL,3);
        % RIGHT
        uMeanR = mean(uTempR,3);
        vMeanR = mean(vTempR,3);
        
        clear uTempL vTempL uTempR vTempR
    end
    
    
    % display velocity field for isual checking
    % Load first and last frame of the interval
    fr2show = n+round(meanFrameWidth/2);
    im2show = double(im2uint8(imread([pathFolderRaw,filesep,filenameRaw{1} num2str(fr2show,'%04d'),'.tif'])));
    
    % Resizing & Graphical output
    if graphicalOutput % Generate grpahical output
        
        velDir = [pathFolderTR '\PIV-Check'];
        mkdir(velDir);
        h3=figure;
        if halfNotum=='l' || halfNotum=='r'
            
            im2showCrop = im2show(Ycrop:Ycrop+heightCrop-1,Xcrop:Xcrop+widthCrop-1);
            imshow(im2showCrop,[],'Border','tight');
            hold on
            ncquiverref2(x,y,uMean,vMean,'?m/min',scaleVector,'true','y')
            
        elseif halfNotum=='b'
            
            im2showCropL = im2show(YcropL:YcropL+heightCrop-1,XcropL:XcropL+widthCrop-1);
            im2showCropR = im2show(YcropR:YcropR+heightCrop-1,XcropR:XcropR+widthCrop-1);
            
            % LEFT
            subplot(2,1,1)
            imshow(im2showCropL,[],'Border','tight');
            hold on
            ncquiverref2(xL,yL,uMeanL,vMeanL,'?m/min',scaleVectorL,'true','y')
            % RIGHT
            subplot(2,1,2)
            imshow(im2showCropR,[],'Border','tight');
            hold on
            ncquiverref2(xR,yR,uMeanR,vMeanR,'?m/min',scaleVectorR,'true','y')
            
        end
        print(h3,'-dpng','-r150',[velDir filesep 'Velocity_' sideStr '_fr_' num2str(n,'%04d') '_' num2str(n+meanFrameWidth,'%04d') '.png']);
        close(h3)
    end
        
    % Gradient computation
    if halfNotum=='l' || halfNotum=='r'
        
        [ux,uy] = gradient(uMean,gridStep);
        [vx,vy] = gradient(vMean,gridStep);
        % Put right units for derivatives : min^{-1}
        % u and v are already in um/min
        % ux, uy, vx and vy are du/d(step_grid)
        % since I divided gradient by step_grid
        ux = ux/scale1D;
        vx = vx/scale1D;
        uy = uy/scale1D;
        vy = vy/scale1D;
    
        % Rotation
        w = -uy+vx;
        
    elseif halfNotum=='b'
        
        % LEFT
        [uxL,uyL]=gradient(uMeanL,gridStep);
        [vxL,vyL]=gradient(vMeanL,gridStep);
        uxL=uxL/scale1D;
        vxL=vxL/scale1D;
        uyL=uyL/scale1D;
        vyL=vyL/scale1D;
        
        % RIGHT
        [uxR,uyR] = gradient(uMeanR,gridStep);
        [vxR,vyR] = gradient(vMeanR,gridStep);
        uxR = uxR/scale1D;
        vxR = vxR/scale1D;
        uyR = uyR/scale1D;
        vyR = vyR/scale1D;
        
        % Rotation
        wL= -uyL + vxL;
        wR= -uyR + vxR;
    end
     
    
    % Reference Window
    begX=2;
    endX=6;
    intX=begX:endX;
    begY=2;
    endY=4;
    intY=begY:endY;
    
    
    % Rotation summed in the reference window
    if halfNotum=='l' || halfNotum=='r'
        
        Rot(n) = sum(sum(w(intY,intX)));
        
    elseif halfNotum=='b'
        
        %-- LEFT
        RotL(n) = sum(sum(wL(intY,intX)));
        %-- RIGHT
        RotR(n) = sum(sum(wR(intY,intX)));
    end
end


%% Determination of Frame corresponding to 20h15 + time of 1st frame (mod 4.3) %%

if halfNotum == 'r'
    
    % Looking for max value of POSITIVE rotation
    modRot = Rot; % take rotation unchanged (4.3)
%     absRot = abs(Rot);
    [maxRot,frMaxRot] = max(modRot);
    [~,frame20h15] = min(abs(0.75*maxRot-modRot(1:frMaxRot))); % ONLY WORKS WHEN MOVIE STARTS AT FRAME ONE!!
    
    timeFrameOne = frame2time(1,'20h15',frame20h15,dt,'str'); % 3.3
    frame18h00new = time2frame('18h00','20h15',frame20h15,dt); % 3.3
    
    % comparing newly found 18h00 frame with user provided one (3.3)
    delta18h00 = abs(frame18h00new - frame18h00);
    deltaTag = '(matches input)';                          % when user has entered the actual 18h00 frame number
    if delta18h00 >= 0.5                                % tolerance for non-integer frame numbers
        deltaTag = ['(input was ' num2str(frame18h00) ')'];
    end
    
elseif halfNotum == 'l'
    
    % Looking for MIN value of NEGATIVE rotation
    modRot = -Rot;  % taking negative value and still looking for the MAX (4.3)
%     absRot = abs(Rot);
    [maxRot,frMaxRot] = max(modRot);
    [~,frame20h15] = min(abs(0.75*maxRot-modRot(1:frMaxRot))); % ONLY WORKS WHEN MOVIE STARTS AT FRAME ONE!!
    
    timeFrameOne = frame2time(1,'20h15',frame20h15,dt,'str'); % 3.3
    frame18h00new = time2frame('18h00','20h15',frame20h15,dt); % 3.3
    
    % comparing newly found 18h00 frame with user provided one (3.3)
    delta18h00 = abs(frame18h00new - frame18h00);
    deltaTag = '(matches input)';                          % when user has entered the actual 18h00 frame number
    if delta18h00 >= 0.5                                % tolerance for non-integer frame numbers
        deltaTag = ['(input was ' num2str(frame18h00) ')'];
    end
    
elseif halfNotum == 'b'
    
    % LEFT
    modRotL = -RotL;    % taking negative value and still looking for the MAX (4.3)
%     absRotL = abs(RotL);
    [maxRotL,frMaxRotL] = max(modRotL);
    [~,frame20h15L] = min(abs(0.75*maxRotL-modRotL(1:frMaxRotL))); % ONLY WORKS WHEN MOVIE STARTS AT FRAME ONE!!
    
    timeFrameOneL = frame2time(1,'20h15',frame20h15L,dt,'str'); % 3.3
    frame18h00newL = time2frame('18h00','20h15',frame20h15L,dt); % 3.3
    
    % comparing newly found 18h00 frame with user provided one (3.3)
    delta18h00L = abs(frame18h00newL - frame18h00);
    deltaTagL = '(matches input)';                          % when user has entered the actual 18h00 frame number
    if delta18h00L >= 0.5
        deltaTagL = ['(input was ' num2str(frame18h00) ')'];
    end
    
    % RIGHT
    modRotR = RotR; % unchanged (4.3)
%     absRotR = abs(RotR);
    [maxRotR,frMaxRotR] = max(modRotR);
    [~,frame20h15R] = min(abs(0.75*maxRotR-modRotR(1:frMaxRotR)));
    
    timeFrameOneR = frame2time(1,'20h15',frame20h15R,dt,'str'); % 3.3
    frame18h00newR = time2frame('18h00','20h15',frame20h15R,dt); % 3.3
    
    % comparing newly found 18h00 frame with user provided one (3.3)
    delta18h00R = abs(frame18h00newR - frame18h00);
    deltaTagR = '(matches input)';                          % when user has entered the actual 18h00 frame number
    if delta18h00R >= 0.5
        deltaTagR = ['(input was ' num2str(frame18h00) ')'];
    end
end


%% Rotation Plot %%

fr = 1:(finalFrame - meanFrameWidth); % Loop over frames; % use of "startFrame" (4.0)
figure(6)
if halfNotum=='l' || halfNotum=='r'
    hold all
    grid on
    plot(fr,Rot,'-xb','Linewidth',2)
    xlabel('frames before synchronization')
    ylabel([sideStr ':Sum Rotation in Reference Window'])
    title({['Frame   ' num2str(frame20h15) '   corresponds to 20h15APF'];...
        ['Frame   ' num2str(frame18h00new) '  ' deltaTag '   corresponds to 18h00APF'];... % 3.3
        ['Frame   ' num2str(1) '   corresponds to' '  ' timeFrameOne];
        ['Temperature is' '   '      num2str(temperature) 'C']})
    
elseif halfNotum=='b'
    % LEFT
    subplot(2,1,1)
    hold all
    grid on
    plot(fr,RotL,'-xg','Linewidth',2)
    xlabel('frames before synchronization')
    ylabel('LEFT: Sum Rotation in Reference Window')
    title({['Frame   ' num2str(frame20h15L) '   corresponds to 20h15APF'];...
        ['Frame   ' num2str(frame18h00newL) '  ' deltaTagL '   corresponds to 18h00APF'];... % 3.3
        ['Frame   ' num2str(1) '   corresponds to' '  ' timeFrameOneL];
        ['Temperature is' '   '      num2str(temperature) 'C']})
    
    % RIGHT
    subplot(2,1,2)
    hold all
    grid on
    plot(fr,RotR,'-xr','Linewidth',2)
    xlabel('frames before synchronization')
    ylabel('RIGHT: Sum Rotation in Reference Window')
    title({['Frame   ' num2str(frame20h15R) '   corresponds to 20h15APF'];...
        ['Frame   ' num2str(frame18h00newR) '  ' deltaTagR '   corresponds to 18h00APF'];... % 3.3
        ['Frame   ' num2str(1) '   corresponds to' '  ' timeFrameOneR];
        ['Temperature is' '   '      num2str(temperature) 'C']})
    
     set(6,'Position',[100 100 500 800])
end
print(6,'-dpng', '-r300', [pathFolderTR '\Rotation_vs_frame#_' sideStr '_' Animal '.png']); % 4.0, added Animal (4.3)
close(6)
disp('---------------------------------------------------------------------------------');

%% History %%

% 10/04/2019: 4.3 (Boris)
% - stopped taking absolute value because we want to detect the actual
% POSITIVE MAXIMUM of rotation on the RIGHT part of animal and the actual
% NEGATIVE MINIMUM of rotation on the LEFT part of animal. Before the
% program would take the absolute values, thereby sometimes finding a
% negative minimum on the right part instead of a positive maximum, smaller
% in absolute value.
% - added animal name in the rotation graph filename

% 28/09/2018: 4.2 (Boris): update of rotation peak time thanks to Aude's work
% - ALL "16h30" became "18h00"
% - ALL "18h40" became "20h15"

% 03/04/2018: 4.1 (Boris) BECAME "TimeRegistration"
% - finalized changes to be run from AIA_parameters
% - now uses negative values of font size to use "none" interpreter

% 29/03/2016: 4.0 (Boris)
% - initiated changes to be run from AIA_parameters
% - now uses frameRef and timeRef to determine frame16h30
% - now supports movies NOT starting at frame 1
% - changed folder names for consistency with other programs
% - changed many filenames and now saving a txt files of parameters
% - "Res_vel_piv" became "gridUVs"
% - "Res_grid_pos" became "gridXYs"
% - use of "ginputWhite" rather than "ginput"
% - now displays image in full screen to make the clicking easier

% 23/06/2016: 3.4 (Boris)
% - now checks that images have been converted to 8-bit before running

% 27/05/2016: 3.3 (Boris)
% NB: NOTICED THAT BEFORE v3.1, DIFFERENT DEV FRAME&TIME WIDTH (meanFrameWidth) WERE USED FOR TIME AVERAGE (since dt was only corrected
% later for 29C movies) => RETIMED ALL TRBL MOVIES
% - use of "time2frame" and "frame2time"
% - added display of newly found frame16h30 on rotation peak plot for the user to start over if very different
% - stopped asking question for graphical output (now boolean in parameters)
% - now displaying animal name and frame number being clicked on image
% - added "(of animal)" when asking the user to click from "left to right" when processing both notum halves
% - renamed pretty much all variables

% 02/05/2016: 3.2 (Boris)
% - stopped applying the 29� correction since it is now carried out in AIA_parameters when calling AIA_info_"animal" by redefining "dt"
% - renamed parameter "side" to "halfNotum" and moved it to AIA_info
% - cleaned up

% 20/04/2016: v3.1
% - cleaned up
% - use AIA_info parameters

% 21/05/2015: changed name to "FindRotationPeak" from "Find_peak_rotation_v3" (Boris)
% - cleaned up

% April 2012: this program directly comes from PIV scripts. It computes PI in the
% reference window taht so it determines rotation peak timing.
