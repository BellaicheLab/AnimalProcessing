function [xImage, yImage, uImage, vImage] = InterpolatePIV(imageSize,x,y,u,v, interpType, PIVgrid)
%
% [xImage, yImage, uImage, vImage] = InterpolatePIV(imageSize,x,y,u,v, interpType, PIVgrid)
%
% INPUTS:
% - x,y,u,v = matpiv outputs (x,y gives location coordinates where displacement field u,v was caculated)
% - interp_type = type of interpolation. 'cubic' recommended (look up "interp2" function to see accepted types)
% - image_size = size of image (1x2 matrix)
% - PIV_Grid = 'XS'(1),'S'(2),'M'(4),'L'(8),'XL'(16),'XXL'(32)
%
% OUTPUTS:
% - x_image, y_image, u_image, v_image = x,y,u,v values interpolated (between points) and extrapolated (up to borders) to all image pixels
%
% Version 1.2
% Boris Guirao


%% Conversion of "PIV_Grid" into "grid_size" (1.1) %%

if strcmp(PIVgrid,'XS')
    gridSize = 1;
elseif strcmp(PIVgrid,'S')
    gridSize = 2;
elseif strcmp(PIVgrid,'M')
    gridSize = 4;
elseif strcmp(PIVgrid,'L')
    gridSize = 8;
elseif strcmp(PIVgrid,'XL')
    gridSize = 16;
elseif strcmp(PIVgrid,'XXL')
    gridSize = 32;
else
    disp('Error: Please choose a proper grid size: XS, S, M, L, XL, XXL')
    [xImage, yImage, uImage, vImage] = deal([]); % 1.2
    return
end


%% Creates x_image, y_image %%

%%% defining "size_grid_1" "size_grid_2":
if gridSize <= 16
    gridSize2 = 8*gridSize;
else                                                                       % for XXL grid_size
    gridSize2 = 8*gridSize;
end

%%% get x,y bounds:
xImageMax = imageSize(2);                                               % THE FIRST NUMBER CORRESPONDS TO THE NUMBER OF LINES AND THUS Y!!
yImageMax = imageSize(1);

%%% Create meshgrid for interpolation:
[xImage, yImage] = meshgrid(1:xImageMax,1:yImageMax);                % Creates a "x_image" matrix of 1s in column 1, 2s in column
                                                                           % 2...x_image_maxs in the last column WITH y_image_max NUMBER OF LINES AND
                                                                           % a "y_image" matrix with 1s in line 1,...y_image_maxs in last line WITH
                                                                           % x_image_max NUMBER OF COLUMNS.
%%% number of lines and columns of the native PIV matrices x,y,u,v:
nRowsPIV = size(x,1);                                                   
nColPIV = size(x,2);

%%  Extrapolation of x,y,u,v on image borders: x_extended,y_extended,u_extended,v_extended %%

% NB: values on borders are extrapolated from last known values using u and v gradients in x and y directions

%%% x,y:
xMax = max(max(x));
yMax = max(max(y));
[xExtendedTemp, yExtendedTemp] = meshgrid(0:gridSize2/2:xImageMax, 0:gridSize2/2:yImageMax);
nRows = size(xExtendedTemp,1);
nCols = size(xExtendedTemp,2);
xExtendedTemp(:,1) = ones(nRows,1);
xExtendedTemp(:,nCols) = xImageMax*ones(nRows,1);
xExtended = xExtendedTemp;
yExtendedTemp(1,:) = ones(1,nCols);
yExtendedTemp(nRows,:) = yImageMax*ones(1,nCols);
yExtended = yExtendedTemp;

%%% u:
[ux,uy] = gradient(u,gridSize2/2);                % calculates u gradients along x and y directions. The distance between 2 points (2 x values for example) is size_grid_2/2

uExtended = zeros(nRows,nCols);              % u, v have same size as x,y, so do u,v_extended
uExtended(2:nRows-1,2:nCols-1) = u;          % puts u right in the middle of u_extended, leaving one line and columns of 0s on the borders

% First: extending the u matrix in the x direction using (filling u_extended
% first and last columns) ux values at its first and last columns:
uExtended(:,1) = [0;u(:,1);0]-[0;ux(:,1);0].*(gridSize2/2-1);                                    % fills up the first column of u_extended using ux value in the first column
                                                                                                    % of ux multiplied by the difference of number of pixels
uExtended(:,nCols) = [0;u(:,nColPIV);0]+[0;ux(:,nColPIV);0].*(xImageMax-xMax);  % fills up the last column of u_extended

% Second: extending the u_EXTENDED matrix in y direction using uy on the first and last lines:
% NB: now that the first and last columns of u_extended are filled up, uy is also used to extrapolate these values. For this purpose, the first and last values
% of uy on each lines (uy(1,1), uy(1,n_columns_piv) and uy(n_lines_piv,1), uy(n_lines_piv,n_columns_piv)) are used.
uExtended(1,:) = uExtended(2,:)-[uy(1,1) uy(1,:) uy(1,nColPIV)].*(gridSize2/2-1);                                               % fills up the first line of u_extended
uExtended(nRows,:) = uExtended(nRows-1,:)+[uy(nRowsPIV,1) uy(nRowsPIV,:) uy(nRowsPIV,nColPIV)].*(yImageMax-yMax); % last line


%%% v:                 
[vx,vy] = gradient(v,gridSize2/2);

vExtended = zeros(nRows,nCols);              % u, v have same size as x,y, so do u,v_extended
vExtended(2:nRows-1,2:nCols-1) = v;          % puts u right in the middle of u_extended, leaving one line and columns of 0s on the borders

% First extending the v matrix in the x direction using vx:
vExtended(:,1) = [0;v(:,1);0]-[0;vx(:,1);0].*(gridSize2/2-1);                                    % fills up the first column of v_extended using vx value in the first column of vx multiplied by the difference of number of pixels
vExtended(:,nCols) = [0;v(:,nColPIV);0]+[0;vx(:,nColPIV);0].*(xImageMax-xMax);  % fills up the last column

% Second extending the v matrix in y direction using vy:
vExtended(1,:) = vExtended(2,:)-[vy(1,1) vy(1,:) vy(1,nColPIV)].*(gridSize2/2-1);
vExtended(nRows,:) = vExtended(nRows-1,:)+[vy(nRowsPIV,1) vy(nRowsPIV,:) vy(nRowsPIV,nColPIV)].*(yImageMax-yMax);


%% Interpolation of u,v_extended to each image pixel: u_image, v_image %%

uImage = interp2(xExtended,yExtended,uExtended,xImage,yImage, interpType);
vImage = interp2(xExtended,yExtended,vExtended,xImage,yImage, interpType);


%% History

% 26/02/2014: 1.2
% - added [x_image, y_image, u_image, v_image] = deal([]) in case PIV_Grid doesn't fit.

% 17/02/2011: 1.1
% - Replaced "grid_size" (number) by "PIV_Grid" (string)

% 21/06/2010: creation










