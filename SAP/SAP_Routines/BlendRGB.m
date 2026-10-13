function [imageR, imageG, imageB] = BlendRGB(imageR,imageG,imageB, pixels, color, r)
%
% image_RGB = BlendRGB(imageR,imageG,imageB, pixels, color, r)
%
% Blends list of linear pixel indices "pixels" of 3 RGB layer of an image with "color" using ratio "r". Final color will be:
% color_final = (1-r)*color_o + r*color, except for white pixels where color will be pure "color".
%
% Version 1.0
% Boris Guirao (adapted from Blend 1.1)


%% gets current RGB values at each pixels %%

pixels_R = imageR(pixels);
pixels_G = imageG(pixels);
pixels_B = imageB(pixels);


%% Case 1: replacing white pixel with pure color (1.1) %%

% sorting out white vs non-white pixels:
white_pixels_TF = ismember([pixels_R pixels_G pixels_B], [1 1 1], 'rows');
white_pixels = pixels(white_pixels_TF);
non_white_pixels_TF = ~white_pixels_TF;
non_white_pixels = pixels(non_white_pixels_TF);

% blends each non-white pixel with color at ratio r:
imageR(non_white_pixels) = (1-r)*pixels_R(non_white_pixels_TF) + r*color(1);
imageG(non_white_pixels) = (1-r)*pixels_G(non_white_pixels_TF) + r*color(2);
imageB(non_white_pixels) = (1-r)*pixels_B(non_white_pixels_TF) + r*color(3);

% white pixels are replaced with pure color:
imageR(white_pixels) = color(1);
imageG(white_pixels) = color(2);
imageB(white_pixels) = color(3);


%% Case 2: treating all pixels the same %%

% % blends each component with color at ratio r:
% image_R(pixels) = (1-r)*pixels_R + r*color(1);
% image_G(pixels) = (1-r)*pixels_G + r*color(2);
% image_B(pixels) = (1-r)*pixels_B + r*color(3);




%% History %%

% 31/01/2014: creation from Blend 1.1
