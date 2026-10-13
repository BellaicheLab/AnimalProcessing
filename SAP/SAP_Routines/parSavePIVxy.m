function parSavePIVxy(path, filename, x, y)  %#ok<INUSD>
%
% parSavePIVxy(path, filename, x, y)
%
% Workaround to be able to save the 2 variables x and y containing the
% locations where displacement fields u v are calculated.
%
% NB: THIS FUNCTION IS VARIABLE SPECIFIC AND ONLY WORKS FOR "x" and "y"
%
% Version 1.0
% Boris Guirao

%% Code %%

fullPath = fullfile(path, [filename '.mat']);
save(fullPath, 'x', 'y')

%% History

% 17/06/2010: creation

