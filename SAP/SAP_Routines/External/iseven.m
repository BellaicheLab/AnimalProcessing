function tf = iseven(x)
%
% Returns 1 if x is an even integer, 0 otherwise.
%
% version 1.0
% Boris Guirao


%% Code %%

tf = true;
if round(x/2) ~= x/2
    tf = false;
end


%% History %%

% 16/09/2014: creation