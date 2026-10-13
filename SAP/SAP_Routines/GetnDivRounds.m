function nDivRounds = GetnDivRounds(ANs)
%
% nDivRounds = GetnDivRounds(ANs)
%
% For a list of ANs, returns the number of divisions each AN has ALREADY undergone (based on their division tags).
%
% Version 1.0
% Boris Guirao

%% Code %%

ANsTags = ANs(:,2:end);
ANsTagsTF = logical(ANsTags);
nDivRounds = sum(ANsTagsTF,2);


%% History %%

% 22/11/2017: creation