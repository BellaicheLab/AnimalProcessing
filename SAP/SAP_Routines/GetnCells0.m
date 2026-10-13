function nCells0 = GetnCells0(trackingFolder, startFrame)
%
% nCells0 = GetnCells0(trackingFolder, startFrame)
%
% Version 1.0
% Boris Guirao

%% Code %%

CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(startFrame) '.txt']);
startFrameRootANs = unique(CorrespondenceRaw(:,1)); % for startFrame, ANs = RNs
nCells0 = max(startFrameRootANs);

%% History %%

% 13/03/2018: creation