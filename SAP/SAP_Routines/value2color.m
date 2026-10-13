function valueColor = value2color(value, valueMin, valueMax, cmap)
%
% Will turn "value" into "valueColor" according to color map "cmap" and
% "valueMin" and "valueMax".
%
% Version 1.0
% Boris Guirao

%% Code %%

nTones = size(cmap,1);

vTone = 1 + round((nTones - 1)*(value - valueMin)/(valueMax - valueMin));

valueColor = cmap(vTone,:); 


%% History %%

% 17/07/2018: creation