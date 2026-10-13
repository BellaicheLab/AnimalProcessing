function ANs = uncoalescedRNs2ANs(RNs, Correspondence)
%
% ANs = uncoalescedRNs2ANs(RNs, Correspondence)
%
% Made to work with UNcoalesced RNs!!
% Creates list of ANs that will match the list of RNs (same number of rows).
%
% NB: IF a listed RN is coalesced, and is therefore repeated several times in "Correspondence", ONLY
% ITS LAST OCCURRENCE in "Correspondence" and therefore LAST matching AN will be listed in "ANs".
%
% Version 1.0
% Boris Guirao


%% Code %%

[~, locRNs] = ismember(RNs,Correspondence(:,1));
% NB: these RNs are NOT repeated in Correspondence since they are NOT coalesced => for each RN, one single index will be
% found in Coalescence

ANs = Correspondence(locRNs,2:end);
% NB: gets corresponding Absolute Numbers (Vector Style) POSSIBLY REPEATED if corresponding RN was repeated in RNs


%% History %%

% 24/02/2017: creation