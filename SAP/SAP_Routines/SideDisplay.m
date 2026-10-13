function quantityMap = SideDisplay(imageSize, SIDES, VERTICES, quantity, caxisValues)

% Version 1.8
% Boris Guirao


%% Loads 'quantity' to plot from SIDES %%

CustomColors

%%% Defines "colormap_used":
if strcmp(quantity, 'ChordLengths')
    colormapUsed = [custom_white ; light_grey ; mid_grey ; crimson ; light_red;  mid_red ; red ; custom_green ; light_green ; green ; light_blue ; mid_blue ; blue];
    %                     1             2         3            4           5          6       7         8            9           10         11         12       13
elseif strncmp(quantity, 'Intensities', 11)  % 1.3
    colormapUsed = [custom_white ; light_grey ; mid_grey ; crimson ; light_orange;  mid_orange ; orange ; custom_green ; light_green ; green ; light_custom_magenta ; mid_custom_magenta ; custom_magenta];
end

%%% Loads side_types:
sideIndices = SIDES.Indices;
sideVertexIndices = SIDES.VertexIndices;
nSides = size(sideIndices,1);

%%% Extracts Core_sides, FL_sides and Border_sides:
if isfield(SIDES,'CATEGORIES')
    sideCATEGORIES = SIDES.CATEGORIES;
    coreSides = sideCATEGORIES.coreSides;
    coreFLSides = sideCATEGORIES.coreFLSides;
    FLSides = sideCATEGORIES.FLSides;
    borderFLSides = sideCATEGORIES.borderFLSides;
    borderSides = sideCATEGORIES.borderSides;
else
    coreSides = 1:numel(SIDES.Numbers);  % Quick and Dirty removal of Sides Categories usage in this Display (1.8)
    coreFLSides = [];
    FLSides = [];
    borderFLSides = [];
    borderSides = [];
end

selectedSides = sort([coreSides ; coreFLSides ; FLSides]);            % sides over which mean will be calculated and with color display

%%% Vertex quantities (mod 1.1):
% allVertexCATEGORIES = VERTICES.CATEGORIES;                               % 1.1
% bulkVertices = allVertexCATEGORIES.bulkVertices;                       % 1.1
bulkVertices = VERTICES.Numbers;                       % 1.1
%vertex_numbers = VERTICES.regular_numbers;
vertexIndices = VERTICES.Indices;
bulkVertexIndices = vertexIndices;                       % 1.1, 1.2
% regular_vertex_indices = vertex_indices(vertex_numbers);


%%% Extracts quantity to plot:
quantityPlot = SIDES.(quantity);
quantityPlotSelected = quantityPlot(selectedSides);

%%% Calculate mean and defines "caxis_values" if it was left empty:
if isempty(caxisValues)
    quantity_plot_selected_nonan = quantityPlotSelected(~isnan(quantityPlotSelected));  % removes NaNs
    quantity_mean = mean(quantity_plot_selected_nonan);
    caxisValues = [quantity_mean quantity_mean];
end

%%% Look for 0 length sides:
% Loading of Four vertices to display 0-length sides when computation of side lengths was not achieved:
fourVertices = VERTICES.nCells == 4;                       % 1.2
fourVerticesIndices = vertexIndices(fourVertices);                       % 1.2


%% Builds image %%

% SIDE MADE UP BY PIXELS:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if  ~strcmp(quantity, 'ChordLengths')
    
    %%% Assignment of "quantity" values to each side:
    quantityMap = NaN(imageSize);
    for i = 1:nSides
        
        side_i_indices = sideIndices{i};
        side_i_value = quantityPlot(i);
        
        % Filling up sides acording to quantity value AND category:
        if ismember(i, coreSides)
            upper_value = 13;
            inrange_value = 10;
            lower_value = 7;
            if side_i_value > caxisValues(1) && side_i_value < caxisValues(2)
                quantityMap(side_i_indices) = inrange_value;
            elseif side_i_value <= caxisValues(1)
                quantityMap(side_i_indices) = lower_value;
            elseif side_i_value >= caxisValues(2)
                quantityMap(side_i_indices) = upper_value;
            end
        elseif ismember(i, coreFLSides)
            upper_value = 12;
            inrange_value = 9;
            lower_value = 6;
            if side_i_value > caxisValues(1) && side_i_value < caxisValues(2)
                quantityMap(side_i_indices) = inrange_value;
            elseif side_i_value <= caxisValues(1)
                quantityMap(side_i_indices) = lower_value;
            elseif side_i_value >= caxisValues(2)
                quantityMap(side_i_indices) = upper_value;
            end
        elseif ismember(i, FLSides)
            upper_value = 11;
            inrange_value = 8;
            lower_value = 5;
            if side_i_value > caxisValues(1) && side_i_value < caxisValues(2)
                quantityMap(side_i_indices) = inrange_value;
            elseif side_i_value <= caxisValues(1)
                quantityMap(side_i_indices) = lower_value;
            elseif side_i_value >= caxisValues(2)
                quantityMap(side_i_indices) = upper_value;
            end
        elseif ismember(i, borderFLSides)
            quantityMap(side_i_indices) = 3;
        elseif ismember(i, borderSides)
            quantityMap(side_i_indices) = 2;
        end
    end
    
    %%% Vertex pixels:
    quantityMap(bulkVertexIndices) = 4;                                    % changed "regular" to "Bulk"
    
    %%% Background pixels (Replaces NaNs with lowest value):
    quantityMap(isnan(quantityMap)) = 1;
    

    %%%% Plot figure:
    fig = figure('PaperPositionMode','auto');                                  % new 1.1: required to save image without ANY border
    set(fig,'color', 'white');                                                 % sets border color to white
    imshow(quantityMap, 'Border', 'tight');
    
    caxis([1 13])
    
    set(gcf,'Colormap', colormapUsed);
    

% CHORDS:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
else
    %%% Blank background:
    quantityMap = ones(imageSize);        
    
    %%%% Plot figure:
    fig = figure('PaperPositionMode','auto');                                  % new 1.1: required to save image without ANY border
    set(fig,'color', 'white');                                                 % sets border color to white
    imshow(quantityMap, 'Border', 'tight');
    
    
    %%% conversion to XY coordinates:
    [chord_vertex_one_Ys, chord_vertex_one_Xs] = ind2sub(imageSize, sideVertexIndices(:,1));  % XYs coord of vertices in 1st column of side_vertex_indices
    [chord_vertex_two_Ys, chord_vertex_two_Xs] = ind2sub(imageSize, sideVertexIndices(:,2));  % XYs coord of vertices in 2nd column of side_vertex_indices
    
    for i = 1:nSides
        chord_i_vertex_Xs = [chord_vertex_one_Xs(i) ; chord_vertex_two_Xs(i)];
        chord_i_vertex_Ys = [chord_vertex_one_Ys(i) ; chord_vertex_two_Ys(i)];
        chord_i_value = quantityPlot(i);
        
        % Filling up sides acording to quantity value AND category:
        if ismember(i, coreSides)
            upper_value = 13;
            inrange_value = 10;
            lower_value = 7;
            if chord_i_value > caxisValues(1) && chord_i_value < caxisValues(2)
                 line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(inrange_value,:),'LineWidth',1)
            elseif chord_i_value <= caxisValues(1)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(lower_value,:),'LineWidth',1)
            elseif chord_i_value >= caxisValues(2)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(upper_value,:),'LineWidth',1)
            end
        elseif ismember(i, coreFLSides)
            upper_value = 12;
            inrange_value = 9;
            lower_value = 6;
            if chord_i_value > caxisValues(1) && chord_i_value < caxisValues(2)
                 line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(inrange_value,:),'LineWidth',1)
            elseif chord_i_value <= caxisValues(1)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(lower_value,:),'LineWidth',1)
            elseif chord_i_value >= caxisValues(2)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(upper_value,:),'LineWidth',1)
            end
        elseif ismember(i, FLSides)
            upper_value = 11;
            inrange_value = 8;
            lower_value = 5;
            if chord_i_value > caxisValues(1) && chord_i_value < caxisValues(2)
                 line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(inrange_value,:),'LineWidth',1)
            elseif chord_i_value <= caxisValues(1)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(lower_value,:),'LineWidth',1)
            elseif chord_i_value >= caxisValues(2)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(upper_value,:),'LineWidth',1)
            end
        elseif ismember(i, borderFLSides)
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(3,:),'LineWidth',1)
        elseif ismember(i, borderSides)
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormapUsed(2,:),'LineWidth',1)
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Points out zerolength sides with red circles:
hold all                                                                                                 % 1.2
[fourVertexYs, fourVertexXs] = ind2sub(imageSize, fourVerticesIndices);                        % 1.2
scatter(fourVertexXs, fourVertexYs, 10,'LineWidth', 0.9, 'MarkerEdgeColor', red);              % 1.2



%% History %%

% 10/04/2018: 1.8
% - quick and dirty removal of side categories in the display to fit C++ SIA

% 18/01/2018: 1.7
% - removed argument "border"
% - removed "chord_angles" related parts

% 05/07/2012: 1.6 (became SideDisplay)
% - removed all parts loading side lengths and checking that side lengths were calculated (to match SIA 2.15)

% 13/09/2011:
% - added "set(fig,'color', 'white');" (twice) to make white borders in figure

% 30/11/2010: 1.3
% - adaptation to >1 raw images and processing of several set of
% intensities: changed  strcmp(quantity, 'intensities')  to  strNcmp(quantity, 'intensities', 11) 
%

% 29/10/2010: 1.2
% - when side lengths are not calculated, loads and uses the four vertices to localize 0-length sides

% 27/10/2010: 1.1
% - adapted code to changes made in structure VERTICES in SIA (~2.0zc-e)

% 14/07/2010: creation





