function MakePointMap(allXYs, allValues, allColorIndices, PLOT)
%
% MakePointMap(allXYs, allValues, allColorIndices, PLOT)
%
% At "allXYs" locations, will plot disks whose sizes scale with "allValues"
% and whose colors follow "allColorIndices".
%
% In "PLOT", values "vMin" and "vMax" will be used to cap colors (values in
% "allColorIndices" (NOT "allValues"!) below vMin and beyond vMax, will
% appear saturated.
%
% If "allValues" contains only one value, all circles will be of same size. 
%
% In "PLOT", "scaleCircleValue" (must be same units as "allValues") and
% "scaleCircleText" will indicate the scale and the text to display next to
% it.
%
% Version 1.1
% Boris Guirao

%% Code %%

ExtractData(PLOT,'','caller');

%%% Defining "vMin" and "vMax" if not provided in "PLOT" (1.1)
if ~exist('vMin','var')
    vMin = min(allColorIndices);
end
if ~exist('vMax','var')
    vMax = max(allColorIndices);
end

allValues = abs(allValues); % unlike "allColorIndices", "allValues" used in scatter must be positive

%%% Case of only one value entered (1.1)
if length(allValues) == 1
    nPoints = length(allXYs);
    allValues = allValues*ones(nPoints,1);
    
else
    %%% Sort data values in ascending order (1.1)
    allTablesRaw = [allValues allXYs allColorIndices];
    allTables = sortrows(allTablesRaw,1);
    % Re-extracting sorted tables (to plot them on top of smaller ones): 
    allValues = allTables(:,1);
    allXYs = allTables(:,2:3);
    allColorIndices = allTables(:,4);
end


%%% Initiate figure (1.1)
image = ones(imageSize);                % makes image with minValEff as background value
image = repmat(image, [1 1 3]);         % making it RGB otherwise get B&W colormap with Matlab 2017! (1.2)

figure('PaperPositionMode','auto')
imshow(image,'Border', 'tight');
hold on

[hc, valVector]= PlotColorBar(colorBarUnits, colorBarXYWH, [vMin vMax], fontSizeInfo, colorInfo, cmap); % use of "colorBarUnits" (1.1)

caxis([vMin vMax]);             % colormap will cover this range of values
set(hc, 'XTick', valVector);    % specifies the values to display on colorbar

%%% Capping color index values (1.1)
allColorIndicesCapped = allColorIndices;
allColorIndicesCapped(allColorIndices < vMin) = vMin;
allColorIndicesCapped(allColorIndices > vMax) = vMax;
% NB: step required because otherwise values below vMin will end up in
% background colors and disappear in background

%%% Drawing circles of different sizes and colors
keepTF = ~(allValues == 0);
scatter(allXYs(keepTF,1), allXYs(keepTF,2), allValues(keepTF)*circleScaleFactor, allColorIndicesCapped(keepTF), 'filled')
% adding a black dot at removed locations
removedTF = ~keepTF;
scatter(allXYs(removedTF,1), allXYs(removedTF,2), 'k.')

%%% Plotting info (time hAPF, animal and scalebar):
if minimalInfoDisplay
    textAnimal = '';
    textQuantity = '';
end
timeRange = [frame2time(startFrame, timeRef, frameRef, dt,'str') '-' frame2time(finalFrame, timeRef, frameRef, dt,'str')];
PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, timeRange, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth)

%%% Adding circle corresponding to point scale
if exist('scaleCircleValue','var') && exist('scaleCircleText','var') 
    
    Xbounds = xlim;
    Ybounds = ylim;
    circleX = Xbounds(2) - 4*xyOffset(1);
    circleY = Ybounds(2) - 3*xyOffset(2);
    
    scatter(circleX, circleY, scaleCircleValue*circleScaleFactor, colorInfo, 'filled')
    text(circleX + xyOffset(1), circleY, scaleCircleText,'FontSize', fontSizeInfo*0.7,'Color', colorInfo, 'VerticalAlignment','Middle'); % 0.7 is ffactor used in "InfoPlotter"
end

%% History %%

% 15/01/2018: 1.1
% - sorting data values in ascending order
% - made it much more general, able to plot maps 
% - stopped using "InitiateColorMapImage"

% 12/01/2018: creation
