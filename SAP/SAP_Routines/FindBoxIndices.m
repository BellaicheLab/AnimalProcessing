function boxIndices = FindBoxIndices(ky, kx, GRID, allIndices, imageSize)
%
% boxIndices = FindBoxIndices(ky, kx, GRID, allIndices, imageSize)
%
% For each grid compartment, will select the linear indices listed in "all_indices" that are located within box(ky,kx).
% NB: BEWARE OF ORDER IN WHICH ky, kx ARE ENTERED
%
% Version 1.0
% Boris Guirao


%% Extracting data from GRID & Getting this box limits %%

grid_ULCs = GRID.ULCs; % get pixel coordinates of grid top left corners
xywh = GRID.xywh;

this_box_ULCs = grid_ULCs{ky,kx};
this_x_min = this_box_ULCs(1); this_x_max = this_x_min + xywh(3) - 1; % -1 because pixel @ this_x_min + xywh(3) = ULCs{ky,kx+1} already belongs to next compartment!!
this_y_min = this_box_ULCs(2); this_y_max = this_y_min + xywh(4) - 1; % -1 because pixel @ this_y_min + xywh(4) = ULCs{ky+1,kx} already belongs to next compartment!!


%% Determining indices inside this grid compartment (box) %%

[all_indices_Ys, all_indices_Xs] = ind2sub(imageSize, allIndices);                                                    % turns linear indices into subscripts ijs

indices_in_Xrange_TF = all_indices_Xs >= this_x_min & all_indices_Xs <= this_x_max;
indices_in_Yrange_TF = all_indices_Ys >= this_y_min & all_indices_Ys <= this_y_max;
indices_in_box_TF = all([indices_in_Xrange_TF indices_in_Yrange_TF], 2);                                                % 1 on lines where both index X and Y are in

all_indices_IJs = [all_indices_Ys all_indices_Xs];
box_indices_IJs = all_indices_IJs(indices_in_box_TF,:);                                                                 % crops all_indices_IJs to the ones found inside box

boxIndices = sub2ind(imageSize, box_indices_IJs(:,1), box_indices_IJs(:,2));                                          % back to linear indices


% Display warning if box is empty:
if isempty(boxIndices)
    disp(['Warning: box (' num2str(ky) ',' num2str(kx) ') contains none of the indices listed!!'])
end


%% History %%

% 22/01/2014: creation



