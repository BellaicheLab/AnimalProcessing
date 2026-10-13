function TrQ = TraceMatrix(Q)
%
% Q is a ny*nx cell array either containing in each compartment 1x2 vectors of eigenvalues ("Es" array),
% or 1x4 vectors of cartesian coordinates ("XYs" array) (or empty compartments.
% TrQ is ny*nx matrix of the trace of each compartment, namely Es(1)+Es(2) or Qxx+Qyy.
% NB: uses fuction cell2mat3D.
%
% Version 1.0
% Boris Guirao

%% Code %%

[Q3D,s] = cell2mat3D(Q); % turns cell array Q into 3D matrix

% Calculating trace according depth of matrix Q3D 3rd dimension:
if s == 2
    TrQ = sum(Q3D,3);                   % Q was a cell array of eigenvalues "Es": TrQ = Es(1) + Es(2)
elseif s == 4
    TrQ = Q3D(:,:,1) + Q3D(:,:,4);      % Q was a cell array of cartesia coordinates "XYs": TrQ = Qxx + Qyy
else
    disp('TraceMatrix ERROR: cell array 3rd dimension must either be 2 or 4!')
    return;
end


%% History %%

% 20/09/2014: creation