function P = TensorScalarProduct5D(A,B)
%
% P = TensorScalarProduct5D(A,B)
%
% A and B must be 4D matrices of same size. Dim 1 & 2 correspond to grid,
% dim 3 to tensor values, dim 4 to time, and dim 5 (if any) to animals.
%
% Version 1.0
% Boris Guirao

%% Checking A & B have same size %%

sA = size(A);
sB = size(B);
ds = sA-sB;

if any(ds)
    disp('A and B must be square matrices of same size!')
    P = NaN;
    return
end

%% Calculating scalar product P %%

P = sum(A.*B,3);
% NB: calculates Trace(A*B') = (Axx*Bxx + Axy*Bxy + Ayx*Byx + Ayy*Byy for n = 2) at each location and timepoint

% renormalizing by tensor dimension "n"
n = sqrt(sA(3));
% NB: takes sqrt because if 4 components, was a 2x2 matrix => n = 2;
%                        if 9 components, 3x3 was a matrix => n = 3;...

P = P/n;

%% History %%

% 06/07/2018: creation