% Stephane Rigaud
% 2016-03-15
% version 2.0

% calculate the projection of the tensor map A on the unitary tensor map B
% input A and B should be a 5D matrix (x,y,4,t,a)
% output is a 5D matrix (x,y,1,t,a)

function [ SPM ] = ScalarProductFunction( A, B )

if size(A) == size(B)
    [h,w,~,t,a] = size(A);
    C = ones(h,w,1,t,a) .* 2;
    SPM = sum( A .* B, 3 ) ./ C ;
else
    disp('ERROR: data are not the right dimension');
    return
end

end

%% History

% 13/06/2018
% - add a fifth dimension for animals in case of usage by MAP



