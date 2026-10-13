function poolSize = GetPoolSize()
%
% poolSize = GetPoolSize()
%
% Gets size of current pool.
%
% Version 1.0
% Boris Guirao


%% Code %%

poolObj = gcp('nocreate'); % If no pool, do not create new one.
if isempty(poolObj)
    poolSize = 0;
else
    poolSize = poolObj.NumWorkers;
end

%% History %%

% 09/01/2018: creation