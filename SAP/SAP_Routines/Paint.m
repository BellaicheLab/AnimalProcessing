function imageRGB = Paint(imageRGB, pixelList, pixelColor)
%
% imageRGB = Paint(imageRGB, pixelList, pixelColor)
%
% Fills up list of linear pixel indices "pixelList" of "imageRGB" with "pixelColor". Returns a RGB image with values in [0 1].
%
% NB: also works if pixel is a logical image of same size as imageRGB (instead of a list of linear indices)
%
% NB: if "imageRGB" is not RGB (single layer), it will be turned into a RGB image.
%
% NB: Paint(imageRGB, pixelList, pixelColor) = Blend(imageRGB, pixelList, pixelColor, 1) ;
%
% Version 2.0
% Boris Guirao


%% Code %%

% checking if imageRGB actually consists of 3 RGB layers:
if length(size(imageRGB)) < 3
    imageRGB = cat(3,imageRGB,imageRGB,imageRGB); 
end

% **2ND LONGEST STEP**
imageSize = size(imageRGB(:,:,1)); % gets 2D size of one image layer

% Case where "pixelList" is a logical image of same size as a layer of "imageRGB":
if size(pixelList) == imageSize
    pixelList = find(pixelList);  % turning the logical image into a series of pixel indices
end

% Adapting 2D pixel indicies to R,G,B layers
nPixels = imageSize(1)*imageSize(2);
Rpixels = pixelList; 
Gpixels = pixelList + nPixels;
Bpixels = pixelList + 2*nPixels;

% **LONGEST STEP**
% Applying color components to each layer
imageRGB(Rpixels) = pixelColor(1);
imageRGB(Gpixels) = pixelColor(2);
imageRGB(Bpixels) = pixelColor(3);


%% History %%

% 12/10/2017: 2.0 COMPLETE OVERHAUL
% - stopped extracting each color slice to RE-concatenate them later

% 16/04/2012: creation
