% Stephane Rigaud
% 2016-03-15

% function that, for a given tensor map over time, return its corresponding
% isotropic part
% - input is a tensor map over time under the form of a 4D matrix (x,y,4,t)
%   where the 3rd dimension is the tensor dimension
% - output is a same dimension matrix, with only the isotropic part

function [ isoT ] = GetIsotropicPart( T )
isoT = T;
for t = 1:size(T,4)
    for x = 1:size(T,2)
        for y = 1:size(T,1)
            isoT(y,x,:,t) = Isotropic(T(y,x,:,t));
        end
    end
end
end

% function, for a given tensor, return its corresponding isotropic part
% - input is a size 4 vector
% - output is a size 4 vector

function [ D ] = Isotropic( T )
Tmat = Vec2Mat(T);
D = (trace(Tmat) ./2 * eye(2));
D = Mat2Vec(D);
end
