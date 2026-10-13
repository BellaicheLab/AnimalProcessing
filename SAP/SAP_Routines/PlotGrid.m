function [himage, fh] = PlotGrid(image, GRID)
%
% himage = PlotGrid(image, GRID)
%
% Plots regular grid, the characteristics of which are specified in GRID)
% over image "image". Returns image handle "himage" (see "imshow" help). If
% "image" is empty, will overlay the grid on existing figure.
%
% Version 1.6
% Boris Guirao

%% Loads Grid characteristics %%

if ~isempty(GRID)
    gridULCs = GRID.ULCs;
    xywh = GRID.xywh;
    gridColor = GRID.Color;             % 1.4
    gridLineWidth = GRID.LineWidth;     % 1.4
    nx = GRID.Size(2);                  % 1.4
    ny = GRID.Size(1);                  % 1.4
    nBoxes = nx*ny;                     % 1.3
    xyBox = xywh(1:2);                  % 1.6
    whBox = xywh(3:4);
end


%% Display Grid over image %%


if ~isempty(image)
    %%% Creates new figure using "image":
    fh = figure(666);
    set(fh, 'PaperPositionMode','auto');
    set(fh, 'color', 'white');
    himage = imshow(image,[], 'Border','tight');
end

%%% Draw grid over existing figure:
hold on
for b = 1:nBoxes
    [ky,kx] = ind2sub([ny nx],b);                           % turns linear index b into (i,j) grid coordinate (1.3)
    bULC = gridULCs{ky,kx};
    rectangle('Position',[bULC whBox],'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor',gridColor);
    scatter(xyBox(1), xyBox(2), 5, [1 0 0], 'LineWidth', 2);
end


%% History %%

% 06/06/2024: 1.6
% - simplified code

% 21/05/2020: 1.5
% - now giving number 666 to figure

% 14/06/2016: 1.4
% - using capitals when loading GRID quantities

% 15/09/2016: 1.3
% - linear iteration on grid compartments using nBoxes

% 02/06/2015: 1.2

% 20/01/2012: 1.1
% - adjustments to match Grid_Maker version 1.5 (checking GRID is not empty)

% 13/01/2012: creation



