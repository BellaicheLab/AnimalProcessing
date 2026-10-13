function [ANs, rsRNs] = RNs2ANs(RNs, Correspondence)
%
% [ANs, rsRNs] = RNs2ANs(RNs, Correspondence)
%
% Returns ANs that corresponds to RNs list, and "rsRNs" (reformatted RNs list) that matches ANs
% ordering and size. Indeed, if RNs was not listed in ascending order, or if contains coalesced cells,
% ANs ordering and size, respectively, will not match RNs.
%
% NB: IF A RN IS LISTED SEVERAL TIMES IN "RNs", THE CORRESPONDING AN(s) WILL NOT BE REPEATED
%
% version 1.0
% Boris Guirao

%% Code %%

RNsTF = ismember(Correspondence(:,1),RNs);       % finds EVERY LOCATION of numbers in sortRNs in Correspondence 1st column
rsRNs = Correspondence(RNsTF,1);                 % gets all the RNs REPEATED AND SORTED in ascending order, like in Correspondence.
ANs = Correspondence(RNsTF,2:end);               % gets corresponding Absolute Numbers (Vector Style)

% if length(rsRNs)>length(RNs)
%     disp('"RNs2ANs" WARNING: Some of the regions listed in RNs contains coalesced cells! Use "rsRNs" to match ANs size.');
% end
% 
% if any(sort(RNs)-RNs)
%     disp('"RNs2ANs" WARNING: RNs were not listed in ascending order! Use "rsRNs" to match ANs ordering.');
% end


%% History %%

% 01/08/2014: creation