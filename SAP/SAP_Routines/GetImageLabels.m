function [imageLabels, imageCC] = GetImageLabels(image)
%
% [imageLabels, imageCC] = GetImageLabels(image)
%
% From binary image "image", labels each region of 1 pixels with uint8 integer (or uint16 number if >255 regions).
%
% version 1.0
% Boris Guirao
%

%% Code %%

imageCC = bwconncomp(image,4);
imageLabels = labelmatrix(imageCC); % REcreates the image labelled uint8 or uint16 according to the number of regions

%% History %%

% 12/10/2017: 1.0