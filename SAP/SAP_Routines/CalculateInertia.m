function [I, Ianisotropy, Iorientation] = CalculateInertia(cellIndices, cellXYs, scale1D, imageSize)
%
% [I, Ianisotropy, Iorientation] = CalculateInertia(cellIndices, cellXYs, scale1D, imageSize)
%
% Allows to compute inertia matrix, inertia anistropy and inertia orientation on a cell from centroid coordinates.
% NB: "inertia_matrix" EXPRESSED IN ?m? AS OF VERSION 1.1 (the other outputs are dimensionless, in pixels? in 1.0)
% NB2: this update can leave "complete_SIA" and "SIA" unchanged.
%
% NB : Angles obey the following convention :
% - polarity and inertia are positive when pointing DOWNWARDS in the image
% - divisions are positive when pointing UPWARDS in the image
%
% Version 1.3
% Boris Guirao
% Mathieu Riviere


%% CODE %%

I = zeros(2);
cellXYsPixels = cellXYs/scale1D;                                        % Conversion of the centroids coordinates into px units
[Y,X] = ind2sub(imageSize,cellIndices);                                 % Conversion from linear indices to cartesian coordinates

% Fills inertia matrix
I(1,1) = mean((X-cellXYsPixels(1)).^2);
I(2,1) = mean((X-cellXYsPixels(1)).*(Y-cellXYsPixels(2)));
I(1,2) = I(2,1);
I(2,2) = mean((Y-cellXYsPixels(2)).^2);

I = reshape(I,1,[]);                                                    % turns 2x2 I into [Ixx Ixy Iyx Iyy]

% Determines eigen values & vectors and sort them
TD = TensorData(I);

% Computation of inertia anisotropy
Ianisotropy = 1 - sqrt(TD.Es(2)/TD.Es(1));                               % MATLAB's definition for anistropy uses a squareroot but we work on squared dimensions
% Ianisotropy2 = 1 - TD.Es(2)/TD.Es(1);

% Extraction of inertia orientation
Iorientation = TD.Angles(1);                                           % ANGLES ARE POSITIVE WHEN CELL ELONGATION IS POINTING DOWNWARDS

% conversion from pixels? to ?m? (1.1)
I = I*scale1D^2; % scale in ?m/pixel

end

%% HISTORY %%

% 19/01/2018: 1.3
% - removed output "Ianisotropy2" that is just Ianisotropy2 = 1 - (1-Ianisotropy)^2

% 03/03/2015:
% - calls "TensorData"
%
% 29/10/2013: 1.2
% - shortened names of output variables
% - included the reshaping of I into line vector
%
% 24/07/2013: 1.1
% - conversion of "interia_matrix" into ?m? using parametre "scale"
%
% 10/07/2013 : Corrected inertia anisotropy orientation convention
%
% 03/07/2013 : Name changed to Inertia_Computation from Cell_Inertia
%
% 06/06/2013 : Creation