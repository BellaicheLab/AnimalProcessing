function [Qiso, QdevDiag, QdevOffDiag] = SplitIsoDev(Q)
%
% [Qiso, QdevDiag, QdevOffDiag] = SplitIsoDev(Q)
%
% ONLY WORKS for symmetric tensors only!!, otherwise QdevOffDiag has two values.
%
% Version 1.1
% Boris Guirao


%% Code %%

Qiso = 1/2*(Q(:,:,1,:) + Q(:,:,4,:)); % 1/2*(Qxx + Qyy)

QisoRep = repmat(Qiso,1,1,4,1); % repeats iso value 4 times along 3rd dim
QisoRep(:,:,2,:) = 0;           % puts Qiso_xy and yx to null
QisoRep(:,:,3,:) = 0;
Qdev = Q - QisoRep;             % removes trace from Q

% Qiso = Qiso(:);                 % makes it a column vector
QdevDiag = Qdev(:,:,1,:);       % taking Qdev_xx ( = -Qdev_yy as sum is null)
% QdevDiag = QdevDiag(:);         % makes it a column vector
QdevOffDiag = Qdev(:,:,2,:);    % ONLY takes Qdev_xy (or Qdev_yx)
% QdevOffDiag = QdevOffDiag(:);


%% History %%

% 30/01/2019: 1.1
% - stopped making column vectors as outputs

% 25/09/2018: creation