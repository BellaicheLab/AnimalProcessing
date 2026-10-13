function imageOut = PlotLGrid(imageIn, gridContourIndices, gridColor, imageFading, thickness)
%
% imageOut = PlotLGrid(imageIn, gridContourIndices, gridColor, imageFading, thickness)
%
% Will plot Lagrangian domain bounds on faded unionseg image.
%
% INPUTS:
% - imageIn:            input BINARY image to draw domain boundaries on
% - gridContourIndices: (ny x nx) cell array containing linear indices of pixels making up the domain boundary for each compartment
% - gridColor:          rgb color of grid
% - imageFading:        in [0,1], 0 won't fade image, 1 will fade it entirely
% - thickness:          dilatation in pixels on both sides of skeleton. 0 yields a 1-pixel thick boundary, 1 -> 3-pixels thick....
%
% OUTPUT:
% - imageOut: RGB image with values in [0 1]
%
% version 1.2
% Boris Guirao

%% Code %%

imageOut = imageIn;
fadeColor = [0.99 0.99 0.99];                                        % correspods to custom_white

% Gets global list of pixels to color
imageSize = size(imageOut);
allContourIndices = unique(cell2mat(reshape(gridContourIndices,[],1)));      % gathers all indices making up LGrid contour in a vector
allContourIndices = SideDilator(imageSize, allContourIndices, thickness);    % dilates of 
allPixels2Color = unique([find(~imageOut) ; allContourIndices]);             % gathers skeleton AND grid contour pixel for color fading

% creates RGB image:
imageR = imageOut;
imageG = imageOut;
imageB = imageOut;
imageRGB = cat(3,imageR,imageG,imageB);

% colors patch boundaries with grid_color:
imageRGB = Paint(imageRGB, allContourIndices, gridColor); % NB: will be blended by next operation => girdColor won't appear as such
imageOut = Blend(imageRGB, allPixels2Color, fadeColor, imageFading); % proper way to fade imageRGB to white:
% imageOut = im2uint8(imageOut); % COMMENTED in 1.1


%% History %%

% 2DO:
% - make program save a grayscale image instead of 8bit grayscale RGB image 

% 28/02/2018: 1.2 (became "PlotLGrid")

% 13/10/2017: 1.1
% - stopped converting output image in 8 bit image => values are now in [0 1]

% 03/04/2015: creation