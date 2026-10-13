function motherANs = MakeMothers(daughterANs)
%
% motherANs = MakeMothers(daughterANs)
%
% Only does: motherANs = MakeAncestors(daughterANs,'youngest');
%
% Boris Guirao


%% Code %%

motherANs = MakeAncestors(daughterANs,'youngest');

%% History %%

% 27/11/2017: creation