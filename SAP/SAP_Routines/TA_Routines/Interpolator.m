function [XI,YI,ZI] = Interpolator(X, Y, Z,image_size, interp_type)
%
% Version 1.0 (adapted from PIV_Interpolate)
% Boris Guirao
%
% [XI,YI,ZI] = Interpolator(X, Y, Z,image_size, interp_type)
%
% INPUTS:
% - X,Y,u,v = matpiv outputs (X,Y gives location coordinates where displacement field u,v was caculated)
% - interp_type = type of interpolation. 'cubic' recommended (look up "interp2" function to see accepted types)
% - image_size = size of image (1X2 matriX)
% - PIV_Grid = 'XS'(1),'S'(2),'M'(4),'L'(8),'XL'(16),'XXL'(32)

% OUTPUTS:
% - XI, YI, u_image, v_image = X,Y,u,v values interpolated (between points) and eXtrapolated (up to borders) to all image piXels




%% Creates XI, YI %%

%%% Original grid
grid_size = size(X);                                                                                                    % = size(Y)
ny = grid_size(1);
nx = grid_size(2);
grid_step = X(1,2)-X(1,1);
Xmax = X(1,nx);
Ymax = Y(ny,1);

%%% get X,Y bounds:
XImax = image_size(2);                                               % THE FIRST NUMBER CORRESPONDS TO THE NUMBER OF LINES AND THUS Y!!
YImax = image_size(1);

%%% Create meshgrid for interpolation:
[XI, YI] = meshgrid(1:XImax,1:YImax);                                 % Creates a "XI" matriX of 1s in column 1, 2s in column
% 2...XImaxs in the last column WITH YImax NUMBER OF LINES AND
% a "YI" matriX with 1s in line 1,...YImaxs in last line WITH
% XImax NUMBER OF COLUMNS.



%%  EXtrapolation of X,Y,u,v on image borders: X_extended,Y_extended,u_extended,v_extended %%


if ~strcmp(interp_type,'nearest')
    
    % NB: EXTRApolating border values to end up with a grid having same size as when using 'nearest' interpolation
    
    %%% X,Y:
    Xstart = X(1,1) - grid_step;
    Xend = Xmax + grid_step;
    Ystart = Y(1,1) - grid_step;
    Yend = Ymax + grid_step;
    [X_extended Y_extended] = meshgrid(Xstart:grid_step:Xend, Ystart:grid_step:Yend);
    nyI = size(X_extended,1);
    nxI = size(X_extended,2);
    
    %%% Z:
    [ZX,ZY] = gradient(Z,grid_step);                % calculates Z gradients along X and Y directions. The distance between 2 points (2 X values for eXample) is grid_step
    
    %%% Z_extended:
    % core values:
    Z_extended = zeros(nyI,nxI);              % u, v have same size as X,Y, so do u,v_extended
    Z_extended(2:nyI-1,2:nxI-1) = Z;          % puts u right in the middle of u_extended, leaving one line and columns of 0s on the borders
    % adding values on extra lines using gradients:
    Z_extended(:,1) = [0 ; Z(:,1) ; 0] - [0 ; ZX(:,1) ; 0]*grid_step;
    Z_extended(:,nxI) = [0 ; Z(:,nx) ; 0] + [0 ; ZX(:,nx) ; 0]*grid_step;
    Z_extended(1,:) = [0  Z(1,:)  0] - [0  ZY(1,:)  0]*grid_step ;
    Z_extended(nyI,:) = [0  Z(ny,:)  0] + [0  ZY(ny,:)  0]*grid_step;
    % Fixing 4 image corners:
    Z_extended(1,1) = 1/2*(Z_extended(1,2) + Z_extended(2,1));
    Z_extended(1,nxI) = 1/2*(Z_extended(1,nxI-1) + Z_extended(2,nxI));
    Z_extended(nyI,1) = 1/2*(Z_extended(nyI-1,1) + Z_extended(nyI,2));
    Z_extended(nyI,nxI) = 1/2*(Z_extended(nyI-1,nxI) + Z_extended(nyI,nxI-1));
    
else
    X_extended = X;
    Y_extended = Y;
    Z_extended = Z;
end

%% Interpolation of Z,v_extended to each image piXel: u_image, v_image %%

ZI = interp2(X_extended, Y_extended, Z_extended, XI, YI, interp_type);

%% History %%

% 09/02/2012: becomes "Interpolator"

% 17/02/2011: 1.1
% - Replaced "grid_size" (number) bY "PIV_Grid" (string)

% 21/06/2010: creation










