function [minValEff, dVal] = InitiateColorMapImage(imageSize, minVal, maxVal, colorMap)
%
% [minValEff, dVal] = InitiateColorMapImage(imageSize, minVal, maxVal, colorMap)
%
% NB: became obsolete with Matlab 2017 as background image seemingly became
% totally independant of color map.
%
% Version 1.2
% Boris Guirao

%% Code %%

nTones = size(colorMap,1);

dVal = (maxVal - minVal)/(nTones-1-1);  % distance between 2 tones; extra -1 to remove the extra tone of white (important for Tension plot)
minValEff = minVal - dVal;              % decrease minVal of one notch

image = minValEff*ones(imageSize);      % makes image with minValEff as background value

image = repmat(image, [1 1 3]);         % making it RGB otherwise get B&W colormap with Matlab 2017! (1.2)

figure('PaperPositionMode','auto')
imshow(image,'Border', 'tight');
hold on



%% History %%

% 12/01/2018: 1.2
% - adjustments for Matlab 2017b compatibility

% 21/06/2017: 1.1
% - simplified code: does not generate the colormap here anymore
% - added extra -1 for dVal calculation because of the white extra tone

% 23/05/2017: created