function [RNs, cANs] = ANs2RNs(ANs, Correspondence)
%
% [RNs, cANs] = ANs2RNs(ANs, Correspondence)
%
% Returns RNs corresponding to ANs, listed in same order and repeated if some cells listed in ANs are coalesced. If some
% ANs are not listed in Correspondence, rather use "cANs" that matches "RNs" size (and ordering).
%
% version 1.0
% Boris Guirao

%% Code %%

[~,ANsLoc] = ismember(ANs, Correspondence(:,2:end),'rows');   % finds LOCATION INDICES of ANs in the 2:end "Correspondence" columns
ANsLoc = ANsLoc(ANsLoc > 0);                                 % crops to non-zero ind
RNs = Correspondence(ANsLoc,1);                              % gets corresponding RNs REPEATED if some cells listed in ANs are coalesced
cANs = Correspondence(ANsLoc,2:end);                         % list of ANs CROPPED to ANs found in Correspondence
  
% NB: cANs and RNs have always same dimensions!


%% History %%

% 01/08/2014: creation