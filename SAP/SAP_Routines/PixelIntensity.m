function Ipixel = PixelIntensity(rawImage, pixelIndex, dilation)
%
% Ipixel = PixelIntensity(rawImage, pixelIndex, dilation)
%
% Inputs:
% - raw_image: fluorescence image in grey levels
% - pixel_index: LINEAR index of pixel in image
%
% NB: pixel_index must have been determined on an image having SAME SIZE as "rawImage"
%
% Outputs:
% - Ipixel = mean intensity over pixel and its vicinity defined by "dilatation" which is the number of pixels
%
% Version 1.0
% Boris Guirao

%% Code %%

imageSize = size(rawImage);
dilatedPixelIndices = SideDilator(imageSize, pixelIndex, dilation);
Ipixel = mean(rawImage(dilatedPixelIndices));


%% History %%

% 23/03/2011: creation