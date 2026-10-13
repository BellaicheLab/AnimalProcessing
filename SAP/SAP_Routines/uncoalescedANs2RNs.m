function RNs = uncoalescedANs2RNs(ANs, Correspondence)
%
% RNs = uncoalescedANs2RNs(ANs, Correspondence)
%
% NB: VERY REDUNDANT WITH "ANs2RNs", SHOULD BE REMOVED IN FAVOR OF
% "ANs2RNs" (maybe after an update)
%
% Creates list of RNs that will match the list of ANs (same number of
% rows). Unlike "ANs2RNs" that will remove unfound ANs (in "cANs"), here
% "RNs" has 0s in rows where an ANs could not found in Correspondence.
%
% NB: IF some listed ANs are coalesced in a given region, the corresponding
% region RN will therefore be repeated several times in "Correspondence"
% and therefore in "RNs".
%
% NB: does NOT really work like "uncoalescedRNs2ANs"
%
% Version 1.0
% Boris Guirao


%% Code %%

[ANsTF, locANs] = ismember(ANs, Correspondence(:,2:end), 'rows');

foundLocANs = locANs(ANsTF);    % removes 0s

nRows = size(ANs,1);
RNs = zeros(nRows,1);

RNs(ANsTF) = Correspondence(foundLocANs,1);


%% History %%

% 07/12/2017: creation