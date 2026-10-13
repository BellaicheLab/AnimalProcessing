function [EVsXs,EVsYs] = GetAxesEndpoints(EVs, Angles, CenterXY, scaleRatio)
%
% [EVsXs,EVsYs] = GetAxesEndpoints(EVs, Angles, CenterXY, scaleRatio)
%
% From eigenvalues "EVs", their angles "Angles" IN DEGREES, center coordinates "CenterXY"
% and factor "scale_ratio", determines the XY coordinates of endpoints of
% each eigenvalues so they can easily be plotted using Matlab function "line":
%
% line(EVsXs, EVsYs)
%
% version 1.0
% Boris Guirao


%% Code %%

EVsCosAngles = EVs.*cos(deg2rad(Angles))*scaleRatio;
EVsSinAngles = EVs.*sin(deg2rad(Angles))*scaleRatio;

EVsXs =  [CenterXY(1)+EVsCosAngles/2 ; CenterXY(1)-EVsCosAngles/2];
EVsYs =  [CenterXY(2)+EVsSinAngles/2 ; CenterXY(2)-EVsSinAngles/2];

end

%% History %%

% 18/11/2013: creation
% - moved formerly nested function "Axes_Endpoints" out of "Tensor_Plotter_BETA" (v 1.5)

