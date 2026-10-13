function valueListFilt = RemoveZeros(valueList)
%
% valueListFilt = RemoveZeros(valueList)
%
% Removes 0s from vector (keeping initial ordering).
%
% Version 1.0
% Boris Guirao

%% Code %%

indexListTF = valueList > 0;
valueListFilt = valueList(indexListTF);

%% History %%

% 21/11/2017: creation