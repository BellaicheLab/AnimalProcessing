function P = TensorScalarProduct(A,B)
%
% P = TensorScalarProduct(A,B)
%
% Calculates scalar (= contracted) product of 2 square matrices A,B.
%
% NB: with Pauli matrices, s1,s2,s3, one has:
%   TensorScalarProduct(si,si) = 1
%   TensorScalarProduct(si,sj) = 0 for i~=j
%   TensorScalarProduct(si,-si) = -1;
%
% Version 1.0
% Boris Guirao

%% Code %%

if (size(A,1) == size(A,2)) && (size(B,1) == size(B,2)) && size(A,1) == size(B,1)     % checks matrices are square and same size
        n = size(A,1);
        P = 1/n * trace(A*B');
else
    disp('A and B must be square matrices of same size!')
end


%% History %%

% 27/02/2015: creation
% - tested with Pauli matrices: s1,s2,s3:
% TensorScalarProduct(si,si) = 1;
% TensorScalarProduct(si,sj) = 0 for i~=j;
% TensorScalarProduct(si,-si) = -1;