function tf = isintegerBo(x)
%
% Returns 1 if x is an integer, 0 otherwise.
%
% version 1.0
% Boris Guirao


%% Code %%

tf = true;
if round(x) ~= x
    tf = false;
end


%% History %%

% 21/01/2015: creation