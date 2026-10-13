function imageGray = BlendGray(imageGray, pixelList, greyLevel, ratio)
%
% imageGray = BlendGray(imageGray, pixelList, greyLevel, ratio)
%
% Blends list of linear pixel indices "pixelList" of a grey level image with "greyLevel" using ratio "r". Final
% greyLevel will be: greyLevelOUT = (1-r)*greyLevelIN + r*greyLevel
%
% Version 1.1
% Boris Guirao

%% Code %%

% Gets grey level at pixels
meanPixelGreyLevel = mean(imageGray(pixelList));

% blends each component with color at ratio r:
imageGray(pixelList) = (1-ratio)*meanPixelGreyLevel + ratio*greyLevel;



%% History %%

% 14/12/2017: 1.1
% - simplified code
% - now take average grey level value of pixels in imageGray

% 30/06/2017: created from Blend_RGB
