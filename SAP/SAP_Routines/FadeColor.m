function cmap = FadeColor(color, fadingValues)
%
% cmap = FadeColor(color, fadingValues)
%
% Creates colormap "cmap" (n(fadingValues)x3 matrix) by diluting color with white using values "fadingValues" (vector)
% NB: for fadingValues = 1/20*(0:20), one has: top color = pure color, bottom color = pure white 
%
% version 1.2
% Boris Guirao


%% Code

fadingValuesSize = size(fadingValues);
if fadingValuesSize(2) > fadingValuesSize(1)
    fadingValues = fadingValues';
end
ntones = length(fadingValues);

outtaBoundsTF = fadingValues > 1 | fadingValues < 0;
if any(outtaBoundsTF)
    disp('Error in "FadeColor": all values in "fadingValues" must be in [0 1]')
    return
else
    white = [1 1 1];
    repFadingValues = repmat(fadingValues,1,3);
    repWhite = repmat(white,ntones,1);
    repColor = repmat(color,ntones,1);
    cmap = repFadingValues.*repWhite + (1-repFadingValues).*repColor; 
end

%% History %%

% 17/01/2018: 1.2
% - cosmetics

% 10/02/2012: 1.1
% - now supports a vector of fading_values to generate a colormap