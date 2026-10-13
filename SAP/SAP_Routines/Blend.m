function imageRGB = Blend(imageRGB, pixelList, pixelColor, ratio)
%
% imageRGB = Blend(imageRGB, pixelList, pixelColor, ratio)
%
% Fills up list of linear pixel indices "pixelList" of "imageRGB" with "pixelColor". Returns a RGB image with values in [0 1].
%
% NB: also works if pixel is a logical image of same size as imageRGB (instead of a list of linear indices)
% NB: when "pixelList" is empty, the WHOLE image will be processed
% NB: if "imageRGB" is not RGB (single layer), it will be turned into a RGB image.
%
% Version 2.1
% Boris Guirao



%% Code %%

% checking if imageRGB actually consists of 3 RGB layers:
if length(size(imageRGB)) < 3
    imageRGB = cat(3,imageRGB,imageRGB,imageRGB); 
end

imageSize = size(imageRGB(:,:,1)); % gets 2D size of one image layer

% when empty, turns "pixelList" into a logical image of imageSize (2.1)
if isempty(pixelList)
    pixelList = true(imageSize);
end

% Case where "pixelList" is a logical image of same size as a layer of "imageRGB":
if size(pixelList) == imageSize
    pixelList = find(pixelList);  % turning the logical image into a series of pixel indices
end

% Adapting 2D pixel indicies to R,G,B layers
nPixels = imageSize(1)*imageSize(2);
Rpixels = pixelList; 
Gpixels = pixelList + nPixels;
Bpixels = pixelList + 2*nPixels;

% BLENDING color "pixelColor" WITH EXISTING COLOR:
imageRGB(Rpixels) = (1-ratio)*imageRGB(Rpixels) + ratio*pixelColor(1);
imageRGB(Gpixels) = (1-ratio)*imageRGB(Gpixels) + ratio*pixelColor(2);
imageRGB(Bpixels) = (1-ratio)*imageRGB(Bpixels) + ratio*pixelColor(3);



%% History %%

% 06/06/2018: 2.1
% - when empty, turns "pixelList" into a logical image of size "imageSize"

% 12/12/2017: 2.0 COMPLETE OVERHAUL
% - stopped extracting each color slice to RE-concatenate them later

% 19/05/2017: 1.2
% - now treats every color identically (again). Basically commented "Case 1" and uncommented "Case 2".

% 17/04/2012: 1.1
% - white pixels replaced by pure color

% 17/04/2012: creation
