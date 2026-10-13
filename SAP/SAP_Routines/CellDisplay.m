function quantityMap = CellDisplay(imageLabels, CELLS, quantity, caxisValues, PLOT)
%
% quantityMap = CellDisplay(image_size, CELLS, quantity, caxis_values, border, PLOT)
%
% Plots a map of cells with colorcode based on the chosen 'quantity'
% (scalar) value. When threshold values have not been specified
% ("caxis_values" empty), colorcode spans values taken in cell
% category of interest (areas=Core/FL_cells, n_neighbors = Core_cells...)
%
% INPUTS:
% - imageSize = size of image (1x2 matrix))
% - CELLS = structure containing all info regarding every single cells
% - quantity = quantity to plot (string): 'n_neighbors', 'areas'...
% - caxisValues = 1x2 matrix. Threshold values
%
% Version 2.4
% Boris Guirao


%% Loads 'quantity' to plot from CELLS %%

CustomColors

%%% Defines number of tones variations and loads custom colors:
nTones = 32;            % looping on nTones => keep it as low as possible (not applicable for "n_neighbors")

%%% Extracts "PLOT" (1.5)
ExtractData(PLOT,'','caller');

imageSize = size(imageLabels); % overwrites value just loaded (moved in 2.4)

%%% Loads cell_types and cell_indices:
allRNs = CELLS.Numbers;
cellCategoryTags = CELLS.CategoryTags; % 2.3
[coreRNs, FLRNs] = GetCellCategories(cellCategoryTags); % Extracting cell categories from "CategoryTags" (2.3)

% cellCATEGORIES = CELLS.CATEGORIES;                                        % 1.2
% cell_indices = CELLS.indices;
% nCells = length(cell_numbers);

%%% Rebuilds Core_cells, FL_cells and Border_cells (changed 1.2):
% coreRNs = cellCATEGORIES.coreRNs;
% FLRNs = cellCATEGORIES.FLRNs;
% borderCells = cell_CATEGORIES.Border_cells;

%%% Extracts quantity to plot (1.2):
quantityPlot = CELLS.(quantity);

units = ''; % default (2.1)
%%% Compare string entered in quantity with existing fields in "CELLS":
if strcmp(quantity, 'Areas')
    
    selectedCells = sort([coreRNs ; FLRNs]);
    colorLow = blue ;
    colorMid = custom_white ;
    colorHigh = red ;
    colorMap = [];
    units = ' ({\mu}m^2)'; % 2.1

elseif strcmp(quantity, 'ChordDisorders')
    
    %Selected_cells = Core_cells;
    selectedCells = sort([coreRNs ; FLRNs]);
    colorLow = dark_purple;
    colorMid = custom_white;
    colorHigh = dark_orange;
    colorMap = [];
    
elseif strcmp(quantity, 'nNeighbors') 
    
    selectedCells = sort([coreRNs ; FLRNs]);
%     selectedCells = coreCells;
    colorMap = [cyan ; turquoise ; custom_white ; dark_purple ; magenta];
    nTones = length(colorMap);
    caxisValues = [4 8];

elseif strncmp(quantity, 'SideIntensityDisorders', 22)                   % COMPARES ONLY 22 FIRST CHARACTERS
    
    selectedCells = sort([coreRNs ; FLRNs]);
    colorLow = turquoise;
    colorMid = custom_white;
    colorHigh = dark_orange;
    colorMap = [];   
    
else
    disp(' '); disp('Please enter a quantity name among these ones:')
    disp(fieldnames(CELLS));
    return
end

nonSelectedCells = setdiff(allRNs,selectedCells);

% NB: "side_disorders","orientations", "rsp_sides","contour_lengths","contour_lengths","contour_chord_lengths" no longer plotted
% NB: "anisotropies" NOT plotted with CellDisplay anymore


%% Builds image %%

%%% Get all values in "quantity_map":
selectedValues = unique(quantityPlot(selectedCells));

if ~isempty(caxisValues)
    minValue = max(min(selectedValues), caxisValues(1));                % add threshold values to extend the range over which available colors will be assigned (avoid col saturation)
    maxValue = min(max(selectedValues), caxisValues(2));
else
    minValue = min(selectedValues);
    maxValue = max(selectedValues);
end

qStep = (maxValue - minValue)/(nTones-1);

% 2 extra tones for saturated values:
satMinValue = minValue - qStep;
satMaxValue = maxValue + qStep;

%%% Capping values OF BORDER CELL VALUES (2.1) OR if limits were specified by user:
quantityPlotCapped = quantityPlot;
quantityPlotCapped(quantityPlot < minValue) = satMinValue; % those values will be saturated
quantityPlotCapped(quantityPlot > maxValue) = satMaxValue;
% NB: minValue & maxValue were determined on "selectedCells" => capping always required to cap borderCells values (2.1)


%%% Assignment of "quantity" values to each cell:
quantityMap_R = NaN(imageSize);
quantityMap_G = NaN(imageSize);
quantityMap_B = NaN(imageSize);

%%% Creates colormap:
if isempty(colorMap)
    darkening = 0.7;
    colorMap = makeColorMap(colorLow, colorMid, colorHigh, nTones);                   % n_tones-2 available to color values between "min_value" and "max_value"
    colorMap = [darkening * colorLow ; colorMap ; darkening * colorHigh];            % adds a dark version of end each color (n_tones)
else
    colorMap = [blue ; colorMap ; crimson];            % adds a dark version of end each color (n_tones)
end

toneIndicesFound = round((quantityPlotCapped-minValue)/qStep) + 2; % gives nTones+2 (resp. 1) when values in "quantityPlotCapped" reach "satMaxValue" (resp. "satMinValue")
minToneIndex = min(toneIndicesFound);
maxToneIndex = max(toneIndicesFound);

for t = minToneIndex:maxToneIndex
    
    tCells = find(toneIndicesFound == t);
    tRegionsTF = ismember(imageLabels, tCells); 
    tTone = colorMap(t,:);
    quantityMap_R(tRegionsTF) = tTone(1);
    quantityMap_G(tRegionsTF) = tTone(2);
    quantityMap_B(tRegionsTF) = tTone(3);
end

nonSelectedCellsTF = ismember(imageLabels, nonSelectedCells);
quantityMap_R(nonSelectedCellsTF) = colorBorderCells(1);
quantityMap_G(nonSelectedCellsTF) = colorBorderCells(2);
quantityMap_B(nonSelectedCellsTF) = colorBorderCells(3);


%%%%%%%%%%%%%%%%% VICTOIRE'S PAPER %%%%%%%%%%%%%% 
% Assigning color to cell contours;
cellContours = find(imageLabels==0);
quantityMap_R(cellContours) = colorJunctions(1);
quantityMap_G(cellContours) = colorJunctions(2);
quantityMap_B(cellContours) = colorJunctions(3);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

quantityMap = cat(3,quantityMap_R,quantityMap_G,quantityMap_B);


%% Plots figure %%

figure('PaperPositionMode','auto');                                  % new 1.1: required to save image without ANY border
imshow(quantityMap, 'Border', 'tight'); % 1.5
% set(gcf, 'Position', get(0, 'Screensize'));


% Plotting colorbar (2.0))
quantityPlot = [quantity units]; % 2.1
if ~strcmp(quantity, 'nNeighbors') 
    PlotColorBar(quantityPlot, colorBarXYWH, [minValue maxValue], fontSizeInfo, colorInfo, colorMap);
else
    PlotColorBar(quantityPlot, colorBarXYWH, [satMinValue satMaxValue], fontSizeInfo, colorInfo, colorMap);
end

% Plotting info (quantity plotted, time hAPF, animal and scalebar) (1.5):
%-------------------------------------------------------------------------------
textAnimal = '';
textQuantity = '';
textTime = ''; % 2.5
if ~minimalInfoDisplay
    textTime = time;        % 2.5
    textAnimal = [Animal ' # ' num2str(n)];
    textQuantity = quantity;
end
PlotInfo(textQuantity, '',0, colorInfo, '{\mu}m', textAnimal, textTime, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5, 2.5
%-------------------------------------------------------------------------------


%% History

% 19/05/2023: 2.6
% - now assigning color "colorJunctions" to cell contours;

% 26/03/2019: 2.5
% - now defining variable "textTime" that can now be empty if running in
% "minimalInfoDisplay" mode.

% 12/03/2019: 2.4
% - moved definition of imageSize after loading of PLOT for cases where
% images in movies have different sizes (Denis & Martial)

% 04/05/2018: 2.3
% - use of "GetCellCategories" to extract "coreRNs", "FLRNs", "borderRNs"

% 08/02/2018: 
% - added "quantityMap" as output so it can be used with "imwrite" to save
% image at native resolution

% 18/01/2018: 2.2
% - calling coreRNs, FLRNs...
% - removed "rsp_chords"

% 27/06/2017: 2.1
% - fixed bug when not specifying data range: now always applying data capping according to data values in selectedCells

% 23/06/2017: 2.0
% - complete overhaul to conveniently plot colorbars with "PlotColorBar"
% - lowered number of tones as now looping on it

% 22/05/2015: 1.5

% 13/09/2011:
% - added "set(fig,'color', 'white');" to make white borders in figure

% 26/01/2011: 1.4
% - included display of "cell_side_intenisty_disorders" for each raw image

% 17/07/2010: 1.3
% - removed outputs [min_value, max_value] that are just useful for
% colormap but not reliable as statistical quantities

% 13/07/2010: 1.2
% - uses "cell_CATEGORIES" now instead of checking cell_types values
% - now defines quantity to plot as such: quantity_plot = CELLS.(quantity);

% 12/07/2010: 1.1
% - added "figure('PaperPositionMode','auto')" alowing to save image
% without border at all

% 05-06/07/2010: creation