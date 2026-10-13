function quantity_map = SideDisplayPten(image_size, CELLS, SIDES, VERTICES, quantity, caxis_values, border, patch_cells)

% Version 1.6
% Boris Guirao


%% Loads 'quantity' to plot from SIDES %%

CustomColors

%%% Defines "colormap_used":
if strcmp(quantity, 'lengths') || strcmp(quantity, 'chord_lengths')
    colormap_used = [custom_white ; light_grey ; dark_grey ; crimson ; light_red;  mid_red ; magenta ; custom_green ; light_green ; PLuc_green ; light_blue ; mid_blue ; blue];
%   colormap_used = [custom_white ; light_grey ; mid_grey ; crimson ; light_red;  mid_red ; red ; custom_green ; light_green ; green ; light_blue ; mid_blue ; blue];
    %                     1             2         3            4           5          6       7         8            9           10         11         12       13
elseif strncmp(quantity, 'intensities', 11)  % 1.3
    colormap_used = [custom_white ; light_grey ; mid_grey ; crimson ; light_orange;  mid_orange ; orange ; custom_green ; light_green ; green ; light_custom_magenta ; mid_custom_magenta ; custom_magenta];
elseif strcmp(quantity, 'chord_angles')
    colormap_used = [custom_white ; light_grey ; mid_grey ; crimson ; light_magenta ; mid_magenta ; magenta ; custom_green ; light_green ; green ; light_magenta ; mid_magenta ; magenta];    
    % NB: For angles, same color used before and after (blue) the inrange segment (green) because -80 similar to +80 for example
end

%%% Loads side_types:
side_CATEGORIES = SIDES.CATEGORIES;
side_indices = SIDES.indices;
side_vertex_indices = SIDES.vertex_indices;
N_sides = size(side_indices,1);

%%% Extracts Core_sides, FL_sides and Border_sides:
Core_sides = side_CATEGORIES.Core_sides;
Core_FL_sides = side_CATEGORIES.Core_FL_sides;
FL_sides = side_CATEGORIES.FL_sides;
Border_FL_sides = side_CATEGORIES.Border_FL_sides;
Border_sides = side_CATEGORIES.Border_sides;

Selected_sides = sort([Core_sides ; Core_FL_sides ; FL_sides; Border_FL_sides]); % kepping Border_FL_sides for pten
%Selected_sides = sort([Core_sides ; Core_FL_sides ; FL_sides]);            % sides over which mean will be calculated and with color display


%%% Vertex quantities (mod 1.1):
all_vertex_CATEGORIES = VERTICES.CATEGORIES;                               % 1.1
Bulk_vertices = all_vertex_CATEGORIES.Bulk_vertices;                       % 1.1
%vertex_numbers = VERTICES.regular_numbers;
vertex_indices = VERTICES.indices;
Bulk_vertex_indices = vertex_indices(Bulk_vertices);                       % 1.1, 1.2
% regular_vertex_indices = vertex_indices(vertex_numbers);


%%% Extracts quantity to plot:
quantity_plot = SIDES.(quantity);
quantity_plot_selected = quantity_plot(Selected_sides);

%%% Calculate mean and defines "caxis_values" if it was left empty:
if isempty(caxis_values) && strcmp(quantity, 'chord_angles')
    quantity_plot_selected_nonan = quantity_plot_selected(~isnan(quantity_plot_selected));  % removes NaNs
    quantity_mean = circ_mean(quantity_plot_selected_nonan * pi/180) * pi/180;              % circular mean if dealing with angles
    caxis_values = [quantity_mean quantity_mean];
elseif isempty(caxis_values)
    quantity_plot_selected_nonan = quantity_plot_selected(~isnan(quantity_plot_selected));  % removes NaNs
    quantity_mean = mean(quantity_plot_selected_nonan);
    caxis_values = [quantity_mean quantity_mean];
end

%%% Look for 0 length sides:
% Loading of Four vertices to display 0-length sides when computation of side lengths was not achieved:
Four_vertices = all_vertex_CATEGORIES.Four_vertices;                       % 1.2
Four_vertex_indices = vertex_indices(Four_vertices);                       % 1.2


%% Builds image %%

% SIDE MADE UP BY PIXELS:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~strcmp(quantity, 'chord_angles') && ~strcmp(quantity, 'chord_lengths')
    
    %%% Assignment of "quantity" values to each side:
    quantity_map = NaN(image_size);
    for i = 1:N_sides
        
        side_i_indices = side_indices{i};
        side_i_value = quantity_plot(i);
        
        % Filling up sides acording to quantity value AND category:
        if ismember(i, Core_sides)
            upper_value = 13;
            inrange_value = 10;
            lower_value = 7;
            if side_i_value > caxis_values(1) && side_i_value < caxis_values(2)
                quantity_map(side_i_indices) = inrange_value;
            elseif side_i_value <= caxis_values(1)
                quantity_map(side_i_indices) = lower_value;
            elseif side_i_value >= caxis_values(2)
                quantity_map(side_i_indices) = upper_value;
            end
        elseif ismember(i, Core_FL_sides)
            upper_value = 12;
            inrange_value = 9;
            lower_value = 6;
            if side_i_value > caxis_values(1) && side_i_value < caxis_values(2)
                quantity_map(side_i_indices) = inrange_value;
            elseif side_i_value <= caxis_values(1)
                quantity_map(side_i_indices) = lower_value;
            elseif side_i_value >= caxis_values(2)
                quantity_map(side_i_indices) = upper_value;
            end
        elseif ismember(i, FL_sides)
            upper_value = 11;
            inrange_value = 8;
            lower_value = 5;
            if side_i_value > caxis_values(1) && side_i_value < caxis_values(2)
                quantity_map(side_i_indices) = inrange_value;
            elseif side_i_value <= caxis_values(1)
                quantity_map(side_i_indices) = lower_value;
            elseif side_i_value >= caxis_values(2)
                quantity_map(side_i_indices) = upper_value;
            end
        elseif ismember(i, Border_FL_sides)
            quantity_map(side_i_indices) = 3;
        elseif ismember(i, Border_sides)
            quantity_map(side_i_indices) = 2;
        end
    end
    
    %%% Vertex pixels:
    quantity_map(Bulk_vertex_indices) = 4;                                    % changed "regular" to "Bulk"
    
    %%% Background pixels (Replaces NaNs with lowest value):
    quantity_map(isnan(quantity_map)) = 1;
    

    %%%% Plot figure:
    fig = figure('PaperPositionMode','auto');                                  % new 1.1: required to save image without ANY border
    set(fig,'color', 'white');                                                 % sets border color to white
    imshow(quantity_map, 'Border', border);
    
    caxis([1 13])
    
    set(gcf,'Colormap', colormap_used);
    

% CHORDS (changed for pten study):
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
else
    %%% Black background (1.4):
    quantity_map = zeros(image_size);                                           % 1.4
    
    %%%% Plot figure:
    fig = figure('PaperPositionMode','auto');                                  % new 1.1: required to save image without ANY border
    set(fig,'color', 'white');                                                 % sets border color to white
    imshow(quantity_map, 'Border', border);
    
    
    %%% conversion to XY coordinates:
    [chord_vertex_one_Ys chord_vertex_one_Xs] = ind2sub(image_size, side_vertex_indices(:,1));  % XYs coord of vertices in 1st column of side_vertex_indices
    [chord_vertex_two_Ys chord_vertex_two_Xs] = ind2sub(image_size, side_vertex_indices(:,2));  % XYs coord of vertices in 2nd column of side_vertex_indices
    
    %%% calculate mean chord length (pten) OVER SELECTED SIDES:
    mean_chord = mean(quantity_plot_selected);
    
    %%% extracting cell RNs making up sides:
    side_cells = SIDES.cells;
    
    %%% displaying ratio nsmall/n for Non Border_sides:
%     Nsmall = sum(quantity_plot_selected/mean_chord <= caxis_values(1)); % caxis_values(1) is lower range value
%     Nselected = length(quantity_plot_selected);
%     ratio = Nsmall/Nselected;
    
    %%% iterating over ALL sides:
    for i = 1:N_sides
        chord_i_vertex_Xs = [chord_vertex_one_Xs(i) ; chord_vertex_two_Xs(i)];
        chord_i_vertex_Ys = [chord_vertex_one_Ys(i) ; chord_vertex_two_Ys(i)];
        chord_i_value = quantity_plot(i)/mean_chord;
        
        % checking belonging to patch boundary:
        this_pair = side_cells(i,:);
        this_pair_TF = ismember(this_pair,patch_cells);
        boundary_side = 0;
        if sum(this_pair_TF)==1
            boundary_side = 1;
        end
        
        if ~ismember(i, Border_sides) && ~boundary_side
            upper_value = 10;                                                                                           % 13-> 10 in pten
            inrange_value = 10;
            lower_value = 7;
            if chord_i_value > caxis_values(1) && chord_i_value < caxis_values(2)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(inrange_value,:),'LineWidth',1)
            elseif chord_i_value <= caxis_values(1)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(lower_value,:),'LineWidth',2)    % increased thickness (pten)
            elseif chord_i_value >= caxis_values(2)
                line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(upper_value,:),'LineWidth',1)
            end
        elseif boundary_side
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(1,:),'LineWidth',2)
        else
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(3,:),'LineWidth',1)
        end 
    end
    
    %%% REdrawing short sides on top to better see them (pten):
    ind_all_small = find(quantity_plot/mean_chord <= caxis_values(1));
    Nallsmall = length(ind_all_small);
    for s = 1:Nallsmall
        i = ind_all_small(s);
        chord_i_vertex_Xs = [chord_vertex_one_Xs(i) ; chord_vertex_two_Xs(i)];
        chord_i_vertex_Ys = [chord_vertex_one_Ys(i) ; chord_vertex_two_Ys(i)];
        
        % checking belonging to patch boundary:
        this_pair = side_cells(i,:);
        this_pair_TF = ismember(this_pair,patch_cells);
        boundary_side = 0;
        if sum(this_pair_TF)==1
            boundary_side = 1;
        end
        
        if ~ismember(i, Border_sides) && ~boundary_side
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(lower_value,:),'LineWidth',2)    % increased thickness (pten)
        elseif boundary_side
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(1,:),'LineWidth',2)
        else
            line(chord_i_vertex_Xs , chord_i_vertex_Ys ,'Color', colormap_used(3,:),'LineWidth',1)
        end 
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Points out zerolength sides with magenta circles:
hold all                                                                                                        % 1.2
[Four_vertex_Ys Four_vertex_Xs] = ind2sub(image_size, Four_vertex_indices);                                         % 1.2
scatter(Four_vertex_Xs, Four_vertex_Ys, 10,'LineWidth', 1.5, 'MarkerEdgeColor', magenta);                           % pten

% %%% Displaying ratio nsmall/nselected (pten):
% text(5,image_size(1),['r = ' num2str(ratio,'%0.2f')],'Color',custom_white,'FontSize',8,'HorizontalAlignment','left','VerticalAlignment', 'bottom');
% 
% %%% Adding cell quantities (pten)
% cell_CATEGORIES = CELLS.CATEGORIES;
% NB_cells = cell_CATEGORIES.Non_Border_cells;
% cell_chord_disorders = CELLS.chord_disorders;
% cell_n_neighbors = CELLS.n_neighbors;
% NB_chord_disorders = cell_chord_disorders(NB_cells);
% NB_n_neighbors = cell_n_neighbors(NB_cells);
% n_NB_6_neighbors = sum(NB_n_neighbors==6);
% n_NB_n_neighbors = length(NB_n_neighbors);
% 
% mean_NB_chord_disorders = mean(NB_chord_disorders);
% ratio_NB_6_neighbors = n_NB_6_neighbors/n_NB_n_neighbors;
% % display:
% offset = 70;
% text(5+offset,image_size(1),['p^6 = ' num2str(ratio_NB_6_neighbors,'%0.2f')],'Color',custom_white,'FontSize',8,'HorizontalAlignment','left','VerticalAlignment', 'bottom');
% text(5+2*offset,image_size(1),['\sigma = ' num2str(mean_NB_chord_disorders,'%0.2f')],'Color',custom_white,'FontSize',8,'HorizontalAlignment','left','VerticalAlignment', 'bottom');

%% History %%

% 05/07/2012: 1.6 (became SideDisplayPten)
% - removed all parts loading side lengths and checking that side lengths were calculated (to match SIA 2.15)

% 12/07/2012: 1.5
% - added display of ratio nsmall_sides/n_sides, p_6, and sigma (side disorder) on image.
% - redraws short sides on top of all sides to make them more visible

% 10/07/2012: 1.4 became "Side_Display_pten"
% - modify display of chord lengths to match Fig. 1 of pten paper (black bg, green long chords, magenta short chords...)

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





