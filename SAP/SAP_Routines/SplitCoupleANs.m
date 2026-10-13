function [coupleANs1, coupleANs2] = SplitCoupleANs(coupleANs)
%
% [coupleANs1 coupleANs2] = SplitCoupleANs(coupleANs)
%
% Splits matrix of couples of ANs stacked into "coupleANs" into 2 matrices, one for each AN of the couples.
%
% Version 1.0
% Boris Guirao


%% Code %%

nCol = size(coupleANs,2)/2; % it is pair, so can be divided by 2

coupleANs1 = coupleANs(:,1:nCol);
coupleANs2 = coupleANs(:,nCol+1:2*nCol);


%% History %%

% 07/12/2017: 1.0
