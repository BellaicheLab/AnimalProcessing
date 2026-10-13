function QnameFilt = QnameVMfilter(Qname)
% function QnameFilt = QnameVMfilter(Qname)
%
% Removes "PIV" or "CT" from "UPIV", "UCT", "OmegaPIV"...
%
% Version 1.0
% Boris Guirao

%% Code %%

QnameFilt = Qname; % default
if strcmp(Qname,'UPIV') || strcmp(Qname,'UCT')
    QnameFilt = 'U';
elseif strcmp(Qname,'EpsilonPIV') || strcmp(Qname,'EpsilonCT')
    QnameFilt = 'Epsilon';
elseif strcmp(Qname,'OmegaPIV') || strcmp(Qname,'OmegaCT')
    QnameFilt = 'Omega';
end

%% History %%

% 17/05/2020: creation
