function MakeGridMap(segImage, gridRNs, gridValues, PLOT)
%
% MakeGridMap(segImage, gridRNs, gridValues, PLOT)
%
% Program to plot map representing "gridValues" (one value per grid
% compartment) using image "segImage", grid defined by "gridRNs" using
% "cmap" stored in PLOT.
%
% - segImage: image used to display regions
% - gridRNs: cell array listing RNs (IN "segImage"!) making up each grid compartment
% - gridValues: matrix of values to display in each compartment
% - PLOT: structure required for plot. Must contain "cmap", "borderRNs"
% (corresponding to "segImage"!).
%
% Version 1.0
% Boris Guirao

%% Building "gridMap" image %%

ExtractData(PLOT,'','caller');
CustomColors;

%%% Defining "vMin" and "vMax" if not provided in "PLOT"
if ~exist('vMin','var')
    vMin = min(gridValues);
end
if ~exist('vMax','var')
    vMax = max(gridValues);
end

%%% Capping color index values
gridValuesCapped = gridValues;
gridValuesCapped(gridValues < vMin) = vMin;
gridValuesCapped(gridValues > vMax) = vMax;
% NB: step required because otherwise values below vMin will end up in
% background colors and disappear in background

%%% Creates empty image:
gridMapR = zeros(imageSize);
gridMapG = zeros(imageSize);
gridMapB = zeros(imageSize);

%%% Assiging value to all pixels in patch
segImageLabels = GetImageLabels(segImage);    % REcreates the image labelled uint8 or uint16 according to the number of regions
nBoxes = numel(gridValues);
for b = 1:nBoxes
    
    bRNs = gridRNs{b};
    bValue = gridValuesCapped(b);
    bPixelsTF = ismember(segImageLabels, bRNs);    % finds pixels corresponding
    
    if ~isnan(bValue)
        bColor = value2color(bValue,vMin, vMax, cmap);
    else
        bColor = custom_white;
    end
    gridMapR(bPixelsTF) = bColor(1);
    gridMapG(bPixelsTF) = bColor(2);
    gridMapB(bPixelsTF) = bColor(3);
end

% Determining "gridFLRNs"
allRNs = unique(segImageLabels);
gridCoreRNs = cell2mat(gridRNs(:));
gridFLRNs = setdiff(allRNs,[0; gridCoreRNs ; borderRNs]); % 0 are membrane pixels

%%% Coloring FL and border pixels:
FLCpixelsTF = ismember(segImageLabels, gridFLRNs);
blendRatio = 0.8; % diluting with existing color
gridMapR = BlendGray(gridMapR, FLCpixelsTF, colorFLCells(1), blendRatio);
gridMapG = BlendGray(gridMapG, FLCpixelsTF, colorFLCells(2), blendRatio);
gridMapB = BlendGray(gridMapB, FLCpixelsTF, colorFLCells(3), blendRatio);

BCpixelsTF = ismember(segImageLabels, borderRNs);
gridMapR(BCpixelsTF) = colorBorderCells(1);
gridMapG(BCpixelsTF) = colorBorderCells(2);
gridMapB(BCpixelsTF) = colorBorderCells(3);

%%% Coloring junctions with "colorJunctions"
junctionPixelsTF = ismember(segImageLabels, 0);
gridMapR(junctionPixelsTF) = colorJunctions(1);
gridMapG(junctionPixelsTF) = colorJunctions(2);
gridMapB(junctionPixelsTF) = colorJunctions(3);

%%% Overriding colors for macrochaetes with "colorMacrochaetes"
macrochaetesPixelsTF = ismember(segImageLabels, macroRNs);                        % directly using imageLabels to find regions
gridMapR(macrochaetesPixelsTF) = colorMacrochaetes(1);
gridMapG(macrochaetesPixelsTF) = colorMacrochaetes(2);
gridMapB(macrochaetesPixelsTF) = colorMacrochaetes(3);

%%% Overriding patch contour pixels with ContourIndices
allGridContourIndices = unique(cell2mat(ContourIndices(:)));
allDilatedGridContourIndices = SideDilator(imageSize,allGridContourIndices, 1);
gridMapR(allDilatedGridContourIndices) = gridColor(1);
gridMapG(allDilatedGridContourIndices) = gridColor(2);
gridMapB(allDilatedGridContourIndices) = gridColor(3);

% making RGB image
gridMap = cat(3,gridMapR,gridMapG,gridMapB);

%% Plotting "gridMap" image %%

figure('PaperPositionMode','auto')
imshow(gridMap,'Border', 'tight');
hold on

[hc, valVector]= PlotColorBar(colorBarUnits, colorBarXYWH, [vMin vMax], fontSizeInfo, colorInfo, cmap); % use of "colorBarUnits"

caxis([vMin vMax]);             % colormap will cover this range of values
set(hc, 'XTick', valVector);    % specifies the values to display on colorbar



%%% Plotting info (time hAPF, animal and scalebar):
if minimalInfoDisplay
    textAnimal = '';
    textQuantity = '';
end
timeRange = [frame2time(startFrame, timeRef, frameRef, dt,'str') '-' frame2time(finalFrame, timeRef, frameRef, dt,'str')];
PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, timeRange, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth)



%% History %%

% 13/07/2018: creation
