function N = TensorNorm(A)
%
% N = TensorNorm(A)
%
% Using "TensorScalarProduct", calculates 2-Norm of nxn square matrix A: N = sqrt(1/n*A:A) = sqrt(TensorScalarProduct(A,A))
%
% NB: with Pauli matrices, s1,s2,s3, one has: TensorNorm(si) = 1
%
% Version 1.0
% Boris Guirao

%% Code %%

N = sqrt(TensorScalarProduct(A,A));

%% History %%

% 04/03/2015: creation