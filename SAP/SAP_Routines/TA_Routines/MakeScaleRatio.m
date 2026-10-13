function scaleRatio = MakeScaleRatio(allEVs, allAngles, spaceX, spaceY)
%
% scaleRatio = MakeScaleRatio(allEVs, allAngles, spaceX, spaceY)
%
% Calculate "scale_ratio" from eigenvalues and angles of ALL tensors (all_EVs, all_Angles) given the available space in
% both directions (space_x, space_y). Aim is to plot all tensors at same scale using all available space. The tensor
% with larger eigenvalue in the direction with smallest space therefore sets the scale.
% NB: when comparing two animals, for given grid and scale bar length, the larger the "scale_ratio", the longer the
% scale bar (large values must be decreased thanks to a smaller "scale_ratio" to fit in grid compartment, hence giving a
% shortest scale bar).
%
% version 1.0
% Boris Guirao


%% Code %%

leeway_factor = 0.85;

EVs_cosAngles = allEVs.*cos(deg2rad(allAngles));
EVs_sinAngles = allEVs.*sin(deg2rad(allAngles));
max_AEVscosAngles = max(unique(abs(EVs_cosAngles)));
max_AEVssinAngles = max(unique(abs(EVs_sinAngles)));
                                                                
width_ratio = spaceX/(max_AEVscosAngles/2);
height_ratio = spaceY/(max_AEVssinAngles/2);

scaleRatio = min(width_ratio, height_ratio)*leeway_factor;


%% History %%

% 27/11/2011: creation