function [AreaRatios, BACKUP] = AreaRatiosAssigner(BACKUP)
%
% [AreaRatios, BACKUP] = AreaRatiosAssigner(BACKUP)
%
% AreaRatios is assigned by prioritizing TA, SM, AOS, GEP.
%
% Version 1.1
% Boris Guirao

%% Code %%

if isfield(BACKUP,'AreaRatios_TA')
    AreaRatios = BACKUP.AreaRatios_TA;
    RcondsNoNaN = BACKUP.RConds;                % initializes RcondsNoNaN with RConds
    RcondsNoNaN(isnan(RcondsNoNaN)) = 0;        % Replacing NaNs by 0 because AreaRatios must have ONLY 0s and no NaNs (where no animal)
    AreaRatios = AreaRatios.*RcondsNoNaN;       % including RConds in TA AreaRatios
elseif isfield(BACKUP,'AreaRatios_SM')          % SM before AOS because SM directly eliminates border cells
    AreaRatios = BACKUP.AreaRatios_SM;
elseif isfield(BACKUP,'AreaRatios_AOS')
    AreaRatios = BACKUP.AreaRatios_AOS;
% Last because also exists when not segmented +> prefer weights coming from
% segmented images: in both GEP and VM, weights come from ROI masks
elseif isfield(BACKUP,'AreaRatios_GEP') 
    AreaRatios = BACKUP.AreaRatios_GEP;
elseif isfield(BACKUP,'AreaRatios_VM')         
    AreaRatios = BACKUP.AreaRatios_VM;
end

BACKUP.AreaRatios = AreaRatios; % storage in BACKUP


%% History %%

% 29/06/2018: 1.1
% - added loading of VM AreaRatios, required when VM is the only program
% running.

% 06/02/2017: creation