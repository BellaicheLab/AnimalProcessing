function coupleRNs = coupleANs2coupleRNs(coupleANs, Correspondence)
%
% coupleRNs = coupleANs2coupleRNs(coupleANs, Correspondence)
%
% Will turn couples of ANs (1 couple per row) into couples of RNs using "Correspondence" of the current image.
% 
% Version 1.0
% Boris Guirao


%% Code %%

[coupleANs1, coupleANs2] = SplitCoupleANs(coupleANs);

% Getting corresponding RN couples
coupleRNs1 = uncoalescedANs2RNs(coupleANs1, Correspondence);
coupleRNs2 = uncoalescedANs2RNs(coupleANs2, Correspondence);

% Sorting RNs and removing rows with unfound RN couples:
coupleRNsRaw = SortNeighborCouples([coupleRNs1 coupleRNs2]);
rows2KeepTF = ~any(coupleRNsRaw == 0,2);

coupleRNs = coupleRNsRaw(rows2KeepTF,:);


%% History %%

% 07/12/2017: creation