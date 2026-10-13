function [ancestorCoreDelRNs, ancestorNonCoreDelRNs] = DisplayAncestorDelRNs(ancestorAllDelANs,coreDelLastRNsTF,allLastFramesDel,timeB4Del,Correspondence,nColTotal,n,dt)
%
% Function used in CTD to display delaminating cells "timeB4Del" hours
% before their actual delamination.
% 
% Version 1.0
% Boris Guirao
%
%% Code %%

nFramesB4Del = round(timeB4Del*60/dt); % conversion in number of frames
allFramesB4Del = allLastFramesDel - n;
allSelectedFramesB4DelTF = allFramesB4Del >= 0 & allFramesB4Del < nFramesB4Del;
% NB: strict < ensures A/D cells are only displayed in their last frame when timeB4Del is 5 min

% Splitting delaminating RNs to display according to their final RNs status (CORE vs NON-CORE)
coreDelaminatingANsTF = all([allSelectedFramesB4DelTF coreDelLastRNsTF],2);
nonCoreDelaminatingANsTF = all([allSelectedFramesB4DelTF ~coreDelLastRNsTF],2);

% Now gathering all ancestors ANs of delaminating cells that should be displayed:
% RELIABLE delaminations ending with CORE RNs
ancestorCoreDelANs = ancestorAllDelANs(:,coreDelaminatingANsTF,:);
ancestorCoreDelANs = reshape(ancestorCoreDelANs,nColTotal-1,[]);  % stacking all ANs along dimension 2
ancestorCoreDelANs = ancestorCoreDelANs';                         % reshape to normal ANs list
ancestorCoreDelANs = unique(ancestorCoreDelANs,'rows');
ancestorCoreDelRNs = ANs2RNs(ancestorCoreDelANs, Correspondence); % will only find existing ones

% UNRELIABLE delaminations ending with NON-CORE RNs
ancestorNonCoreDelgANs = ancestorAllDelANs(:,nonCoreDelaminatingANsTF,:);
ancestorNonCoreDelgANs = reshape(ancestorNonCoreDelgANs,nColTotal-1,[]);  % stacking all ANs along dimension 2
ancestorNonCoreDelgANs = ancestorNonCoreDelgANs';                         % reshape to normal ANs list
ancestorNonCoreDelgANs = unique(ancestorNonCoreDelgANs,'rows');
ancestorNonCoreDelRNs = ANs2RNs(ancestorNonCoreDelgANs, Correspondence); % will only find existing ones


%% History %%

% 05/04/2019: creation