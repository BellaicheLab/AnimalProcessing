% SpaceRegistration (formerly "ClickLandmarks")
%
% NB: must define and fill out the "AIA_info_animal.m" file
%
  version = '2.3';
% Isabelle Bonnet
% Anais Bailles
% Boris Guirao
% Stephane Rigaud

% clear all; close all; clc

%% PARAMETERS %%

% Colors for landmark categories
colorInstructions = 'yellow';
colorMacroClicksRight = 'green';                    % 2.1
colorMacroClicksLeft = 'magenta';                   % 2.1
colorMidlineClicks = 'cyan';
colorNeckClicks = 'blue';

fontScaling = 0.6;  % factor used to reduce "fontSizeInfo" (2.1)
nMidLineMAX = 2;    % 2 clicks
nNeckMAX = 2;       % 2 clicks
   

%% INITIALIZATION %%
    
mkdir(pathFolderSR);

%%% Displaying info (4.1):
disp(' '); disp(' ');
disp(['SpaceRegistration ' version  ': processing "' Animal '" on frame # ' num2str(clickFrame)]);
disp('---------------------------------------------------------------------------------');


%%% Writing txt file (4.0)
today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style. Look up date for details
txtFilename = [today '_SR_' version '.txt'];
% Writing main parameters in txt file:
parameterCell = {   'Parameters:',[];
                    [],[];
                    'halfNotum = ', halfNotum;
                    'timeRef = ', timeRef;
                    'frameRef = ', frameRef;
                    'clickTime = ', clickTime;
                    'clickFrame = ', clickFrame};

dlmcell([pathFolderSR filesep txtFilename], parameterCell,' '); % using "saveFolder" instead of "pathFolderCPT" (3.5)


%% Clicking MACROCHAETAE %%

%-- Graphical User Interface
disp('+ or up-arrow to zoom in');
disp('- or down-arrow to zoom out');
disp('"p" to go in pan mode and move image (press any key to get out)');                    % 2.0
disp('"f" or "F" (shift + f) to save and finish (1st switch to NEXT half in "both" mode)'); % mod 2.0

% loading image
frameText = [filenameRaw{1} num2str(clickFrame, digitsFormat) '.tif'];          % 1.3, 2.1
im2showR = imread([pathFolderRaw filesep frameText]);                                % 1.3
xyOffsetOther = [5 5];                                                              % different offset than for scalebar (1.5)
textAnimal = [Animal ' # ' num2str(clickFrame) ' (estimated ' clickTime ' APF)'];           % 1.3, 2.0
equalized = false; % 2.2

%-- Display image
h1 = figure;
im2show = im2showR; % 2.2
imshow(im2showR,[],'border','tight');
set(h1,'Position', positionFullScreen);
hold on

%--- The user must click the macrochaetae
text(30,50,[sideStr ' - Click up to ' num2str(nMacroMAXspace) ' MACROCHAETES'],'Color',colorInstructions,'FontSize',fontSizeInfo)
PlotText(textAnimal, '', xyOffsetOther, -fontSizeInfo*fontScaling, 'normal',colorInstructions, 'BL'); % 1.3

% displaying the order in which macrochetae must be clicked (1.1)
f = 0.5;                % scaling of Macro pattern
displayMacroPattern(halfNotum,f,colorInstructions); % 2.2

%--- Initializes variable "stopMacro" to loop until user has finished
stopMacro = 0;
nMacro=0;
xyMacro = NaN(nMacroMAXspace,2); % 2.0
while stopMacro == 0 
    
    lim = axis;
    %-- get input
    [xi,yi,button] = ginputWhite(1);
    
    % macro color according to side (2.1)
    colorMacroClicksUsed = colorMacroClicksRight; 
    if nMacro + 1 > 8 || halfNotum == 'l'               % +1 because macro number about to be used
        colorMacroClicksUsed = colorMacroClicksLeft;
    end
    
    %--- get macrochaetae coordinates
    if button == 1 || button == 49  % left mouse button 
        x = round(xi);
        y = round(yi);
        plot(x,y,'+','Color',colorMacroClicksUsed);
        nMacro = nMacro+1;
        text(x+10,y+10,num2str(nMacro),'Color',colorMacroClicksUsed,'FontSize',fontSizeInfo*fontScaling);
        %number of Macro added
        xyMacro(nMacro,1) = x;
        xyMacro(nMacro,2) = y;
        
        if nMacro==nMacroMAXspace
            stopMacro=1;
        end
        
    elseif button ==  3 || button == 51 % right mouse button 
        
        x=round(xi);
        y=round(yi);
        plot(x,y,'r+');
        nMacro = nMacro+1;
        text(x+10,y+10,[num2str(nMacro) 'NaN'],'Color','red','FontSize',fontSizeInfo*fontScaling);
        %number of Macro added
        xyMacro(nMacro,1)=NaN;
        xyMacro(nMacro,2)=NaN;
        
        if nMacro==nMacroMAXspace
            stopMacro=1;
        end
        
        %--- ZOOM IN
    elseif button == 43 || button==30 || button==61
        zoom(2)
        lim = axis;
        lim = [xi+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]];
        axis(lim)
        
        %-- ZOOM OUT
    elseif button == 45 || button ==31
        zoom out
        
        %-- PAN MODE
    elseif button == 112
        pan on
        pause
        pan off
        
        %-- CONTRAST ENHANCEMENT ("e" key)
    elseif button == 101
        equalized = ~equalized;
        cla
        if equalized   
            im2showE = adapthisteq(im2showR); % CLAHE
            im2showE = imadjust(im2showE); % adjust intensity
            im2show = im2showE;
        else
            clear im2showE
            im2show = im2showR;
        end
        imshow(im2show, [], 'Border', 'tight');
        text(30,50,[sideStr ' - Click up to ' num2str(nMacroMAXspace) ' MACROCHAETES'],'Color',colorInstructions,'FontSize',fontSizeInfo)
        PlotText(textAnimal, '', xyOffsetOther, -fontSizeInfo*fontScaling, 'normal',colorInstructions, 'BL');
        displayMacroPattern(halfNotum,f,colorInstructions); % 2.2
        
        %-- FINISH , EXIT
    elseif button==70 || button==102            % finish OR switch to next half = F or f (mod 2.0)
        if strcmp(halfNotum,'b') && nMacro < 8
            nMacro = 8;
        else
            stopMacro = 1;
        end
    end
end
zoom out
xM = xyMacro(:,1);
yM = xyMacro(:,2);
% close(h1)

%-- Save macrochaetaes coordinates
mkdir(pathFolderSR); % only creates destDir now (1.7)
dlmwrite([pathFolderSR filesep 'Macro_XYs_' Animal '.txt'],xyMacro, 'delimiter', '\t','newline', 'pc')
clear x y


%% Clicking MIDLINE %%

cla; % 2.0
imshow(im2show,[],'border','tight');

%--- The user must click the macrochaetae
text(30,50,[sideStr ' - Click MIDLINE endpoints'],'Color',colorInstructions,'FontSize',22)
PlotText(textAnimal, '', xyOffsetOther, -fontSizeInfo*fontScaling, 'normal',colorInstructions, 'BL');         % 2.1

%--- Initializes variable "stopMidline" to loop until user has finished
stopMidline = 0;
nMidLine=0;
xyMidLine = NaN(nMidLineMAX,2); % 2.0
while stopMidline == 0 
    
    lim = axis;
    %-- get input
    [xi,yi,button]=ginputWhite(1);
    %--- get macrochaetae coordinates
    if button == 1 || button == 49
        x=round(xi);
        y=round(yi);
        plot(x,y,'+','Color',colorMidlineClicks); % 2.0
        line(x,y)
        nMidLine=nMidLine+1;
        %number of Macro added
        xyMidLine(nMidLine,1)=x;
        xyMidLine(nMidLine,2)=y;
        
        if nMidLine==nMidLineMAX
            stopMidline=1;
        end
    elseif button ==  3 || button == 51 % right mouse button
        
        x=round(xi);
        y=round(yi);
        plot(x,y,'r+');
        nMidLine=nMidLine+1;
        text(x+10,y+10,[num2str(nMidLine) 'NaN'],'Color','red','FontSize',8);
        %number of Macro added
        xyMidLine(nMidLine,1)=NaN;
        xyMidLine(nMidLine,2)=NaN;
        
        if nMidLine==nMidLineMAX
            stopMidline = 1;
        end
        
        %--- ZOOM IN
    elseif button == 43 || button==30 || button==61
        zoom(2)
        lim = axis;
        lim = [xi+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]];
        axis(lim)
        
        %-- ZOOM OUT
    elseif button == 45 || button ==31
        zoom out
        
        %-- PAN MODE ("p" key)
    elseif button == 112
        pan on
        pause
        pan off
        
        %-- FINISH , EXIT
    elseif button==70 || button==102  % finish = F or f
        stopMidline = 1;
    end
end
zoom out
% close(h2)

%%% Saves midline coordinates
dlmwrite([pathFolderSR filesep 'MidLine_XYs_' Animal '.txt'],xyMidLine, 'delimiter', '\t','newline', 'pc'); % mod 2.0


%% Clicking NECK %%

cla; % 2.0
imshow(im2show,[],'border','tight');

%--- The user must click the macrochaetae
text(30,50,[sideStr ' - Click NECK location'],'Color',colorInstructions,'FontSize',22)
PlotText(textAnimal, '', xyOffsetOther, -fontSizeInfo*fontScaling, 'normal',colorInstructions, 'BL'); % 2.1

%--- Initializes variable "stopNeck" to loop until user has finished
stopNeck = 0;
nNeck=0;
xyNeck = NaN(nNeckMAX,2); % 2.0
while stopNeck == 0 
    
    lim = axis;
    %-- get input
    [xi,yi,button]=ginputWhite(1);
    %--- get macrochaetae coordinates
    if button == 1 || button == 49 
        x=round(xi);
        y=round(yi);
        plot(x,y,'+','Color', colorNeckClicks); % 2.0
        line(x,y)
        nNeck = nNeck+1;
        %number of Macro added
        xyNeck(nNeck,1)=x;
        xyNeck(nNeck,2)=y;
        
        if nNeck==nNeckMAX
            stopNeck = 1;
        end
    elseif button ==  3 || button == 51 % right mouse button
        
        x=round(xi);
        y=round(yi);
        plot(x,y,'r+');
        nNeck = nNeck+1;
        text(x+10,y+10,[num2str(nNeck) 'NaN'],'Color','red','FontSize',8);
        %number of Macro added
        xyNeck(nNeck,1)=NaN;
        xyNeck(nNeck,2)=NaN;
        
        if nNeck==nNeckMAX
            stopNeck = 1;
        end
        %--- ZOOM IN
    elseif button == 43 || button==30 || button==61
        
        zoom(2)
        lim = axis;
        lim = [xi+diff(lim(1:2))/2*[-1 1] yi+diff(lim(3:4))/2*[-1 1]];
        axis(lim)
        
        %-- ZOOM OUT
    elseif button == 45 || button ==31
        zoom out
        
        %-- PAN MODE
    elseif button == 112
        pan on
        pause
        pan off
        
        %-- FINISH , EXIT
    elseif button==70 || button==102  % finish = F or f
        stopNeck = 1;
    end
end
zoom out

xML=xyMidLine(:,1);
yML=xyMidLine(:,2);
xNK=xyNeck(:,1);
yNK=xyNeck(:,2);

%-- Save a graphical output 
line(xML,yML,'Color','r','LineWidth',2)
line(xNK,yNK,'Color','r','LineWidth',2)
% close(h3)

% Saves Neck coordinates
dlmwrite([pathFolderSR filesep 'Neck_XYs_' Animal '.txt'],xyNeck, 'delimiter', '\t','newline', 'pc');        % mod 2.0
clear x y 

close(h1)


%% Saving graphical output of all clicked landmarks %%

im2showR = imread([pathFolderRaw filesep filenameRaw{1} num2str(clickFrame, digitsFormat),'.tif']); % 2.1, replaced "Animal" (2.3)

% Cropping to cliced values (2.0):
xyMplotTF = ~isnan(xM);
xMplot = xM(xyMplotTF);
yMplot = yM(xyMplotTF);

nMacroPlot = (1:nMacroMAXspace)';
nMacroPlot = nMacroPlot(xyMplotTF);

% creating macroText and displaying macro number next to click (1.3):
macroVec = (1:nMacroMAXspace)';
macroVec = macroVec(xyMplotTF);
% macroVec = (1:nMacro)';
macroChar = char(num2str(macroVec));
macroText = cellstr(macroChar);             %  places each ROW of the character array macroChar into separate cells of c

h4 = figure;
imshow(im2showR,[],'border','tight');
set(h4,'Position', positionFullScreen);
hold all
% Right
LorRtf = nMacroPlot < 9;
plot(xMplot(LorRtf),yMplot(LorRtf),'+', 'Color', colorMacroClicksRight);
text(xMplot(LorRtf)+10,yMplot(LorRtf)+10, macroText(LorRtf),'Color',colorMacroClicksRight,'FontSize',fontSizeInfo*fontScaling);
% Left
LorRtf = nMacroPlot > 8;
plot(xMplot(LorRtf),yMplot(LorRtf),'+', 'Color', colorMacroClicksLeft);
text(xMplot(LorRtf)+10,yMplot(LorRtf)+10, macroText(LorRtf),'Color',colorMacroClicksLeft,'FontSize',fontSizeInfo*fontScaling);

% plot(xMplot,yMplot,'+', 'Color', colorMacroClicks);
% text(xMplot+10,yMplot+10, macroText,'Color',colorMacroClicks,'FontSize',8);
line(xML,yML,'LineWidth',2,'Color', colorMidlineClicks);
line(xNK,yNK,'LineWidth',2,'Color', colorNeckClicks);

PlotText(textAnimal, '', xyOffsetOther, -fontSizeInfo*fontScaling, 'normal','yellow', 'BL'); % 1.3

saveas(h4,[pathFolderSR filesep 'All_clicked_landmarks_frame#'  num2str(clickFrame) '.png']); % mod 2.0, 2.1
close(h4)
disp('---------------------------------------------------------------------------------');



%% History %%

% 29/06/2018: 2.3 (Boris)
% - stopped wrong use of "Animal" to load an image

% 15/05/2018: 2.2 (Boris)
% - possibility to increase image contrast (by pressing "e") to better
% click macrochaetaes.
% - use of function "displayMacroPattern"

% 03/04/2018: 2.1 (Boris) BECAME "SpaceRegistration"
% - removed parameter "singleImage" that was relevant for Maria's file, and
% all associated parts.
% - "frameFilename" became "Animal".
% - finalized changes so it can be run from AIA_parameters.
% - now uses different colors for LEFT and RIGHT macrochaetes
% - now uses negative values of font size to use "none" interpreter

% 30/03/2018: 2.0 (Boris)
% - now saves txt file of parameters
% - full screen display for better clicking accurracy (important to keep
% track of macrochaetes in the tracking)
% - introduced pan mode for convenience (press "p" key)
% - changed colors for macro, midline, neck
% - use of "ginputWhite" rather than "ginput"
% - changed name of folders (and files) for consistency
% - stopped loading same image again and again, stopped closing figure
% before the user is done clicking

% 23/11/2016: 1.6 (Boris)
% - moved "clickTime" in user parameter section
% - rounding up of "clickFrame" to ensure it is always an integer

% 17/10/2016: 1.5 (stephane)
% - add the neck landmark, same has midline pick but vertical at the delimitation with the neck

% 15/07/2016: 1.4 (Boris)
% - now 16 Macrochaetes should be clicked (instead of 14 before) when both sides of the animal are available
% - improved display of macrochaetes numbers to click to help user in that case

% 02/05/2016: 1.3 (Boris)
% - stopped applying the 29? correction since it is now carried out in AIA_parameters when calling AIA_info_"animal" by redefining "dt"
% - fixed bug displaying last macro numbers next to clicked positions
% - now displays and save frame number that is being clicked
% - stopped saving multiple useless images
% - renamed parameter "side" to "halfNotum" and moved it to AIA_info

% 11/04/2016: 1.2 renamed to "ClickLandmarks" from "Pick_Landmarks_v1" (Boris)
% - now uses AIA_info_"animal" to load path and basic info

% modified version 09/2014 by Anais

% May 2012: (I. Bonnet)
% User interface to pick landmarks within a BigFilm image
% Landmarks are:
% -  macrochaetae (7 maximum for each side of the thorax: 7 clicks
% -  the midline : 2 clicks
%


