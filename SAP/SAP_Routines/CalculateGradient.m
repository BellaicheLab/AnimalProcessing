function [EpsilonStack, OmegaStack, AreaRatiosStack] = CalculateGradient(UStack, AreaRatiosStack, GRID, scale1D)
%
% [EpsilonStack, OmegaStack, AreaRatiosStack] = CalculateGradient(UStack, AreaRatiosStack, GRID)
%
% Version 1.0
% Boris Guirao

%% Code %%

ny = size(UStack, 1);
nx = size(UStack, 2);
nTimePoints = size(UStack, 4);

% Determining spacing between grid compartments (taking overlap into account)
dXY = GRID.ULCs{2,2} - GRID.ULCs{1,1};
dX = round(dXY(1))*scale1D;             % IN MICRON
dY = round(dXY(2))*scale1D;             % IN MICRON;

EpsilonStack = NaN(ny,nx,4,nTimePoints);
OmegaStack = NaN(ny,nx,1,nTimePoints);

for t = 1:nTimePoints
    
    Ux = UStack(:,:,1,t);
    Uy = UStack(:,:,2,t);
    
    % gradient of velocity
    [dxUx, dyUx] = gradient(Ux, dY, dX);
    [dxUy, dyUy] = gradient(Uy, dY, dX);
    
    EpsilonStack(:,:,:,t) = 1/2*cat(3, 2*dxUx, dxUy+dyUx, dxUy+dyUx, 2*dyUy);
    OmegaStack(:,:,1,t) = 1/2*(dxUy - dyUx);
    
    AR = AreaRatiosStack(:,:,1,t);
    AreaRatiosStack(:,:,1,t) = GetMatrixLocalMin(AR); % selecting lowest weight value among neighbors to be conservative
end



%% History %%

% 01/06/2018: creation