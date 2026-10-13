function macroRNs = FindMacroRNs(trackingFolder, nColTotal, macroANs, n)
%
% macroRNs = FindMacroRNs(trackingFolder, nColTotal, macroANs, n)
%
% Returns list of macrochaetae RNs in image n.
%
% version 1.0
% Boris Guirao
%

%% Code %%

% Loading Correspondence
CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(n) '.txt']);
Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal);
clear CorrespondenceRaw;
% Loading borderRNs:
borderRNs = dlmread([trackingFolder filesep 'border_cells_RN_' num2str(n) '.txt']);
borderRNs = borderRNs(borderRNs > 0);                                                % removes -1 stored when empty txt file

% now getting macroRNs from macroANs:
macroRNs = macroANs2macroRNs(macroANs, Correspondence, borderRNs);


%% History %%

% 12/10/2017: 1.0