function [VnoNaN] = RemoveNaNs(V)
%
% [VnoNaN] = removeNaNs(V)
%
% Removes NaN values from vector V
%
% Version 1.1
% Boris Guirao


%% Code

VnoNaN = V(~isnan(V));

%% History

% 02/06/2016: 1.1: renamed to "nanRemover" from "NaN_Remover"

% 04/08/2010: creation