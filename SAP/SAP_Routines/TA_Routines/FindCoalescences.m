function [iCs, ioCs] = FindCoalescences(iiosMatch, coalescedRNs, coalescedRNsOLD)
%
% [iCs, ioCs] = FindCoalescences(iiosMatch, coalescedRNs, coalescedRNsOLD)
%
% Returns the list of cell RNs "is" that are found coalesced in CURRENT OR PREVIOUS frame
% WARNING: "iiosMatch" MUST LIST CURRENT RNs IN FIRST COLUMN AND OLD RNs IN SECOND COLUMN
%
% Version 1.0
% Boris Guirao


%% Code %%

isCTF = ismember(iiosMatch(:,1),coalescedRNs);                                                                     % 1s where RN found to be coalesced in CURRENT frame, 0s elswhere
iosCTF = ismember(iiosMatch(:,2),coalescedRNsOLD);                                                                % 1s where RN found to be coalesced in OLD frame, 0s elswhere

iiosCTF = any([isCTF iosCTF],2);                                                                                    % 1s where 1+ 1s found on line
iCs = unique(iiosMatch(iiosCTF,1));
ioCs = unique(iiosMatch(iiosCTF,2));


%% History %%

% 16/11/2011: creation