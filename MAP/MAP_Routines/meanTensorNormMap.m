% Stephane Rigaud
% 2016-03-15

% Calculate the weighted mean norm value (<||x||>) of a tensor map
% input B is a matrix of tensors of dimension (y,x,4,t)
% input W is a matrix of weights dimenaion    (y,x,1,t)
% output is a scalar value

function [ meanNorm ] = meanTensorNormMap( B, W )

Nmap = TensorNormMap(B) .^ 2;                           % get the norm map of B
weightedNmap = Nmap .* W;                               % apply weight to the norm map
meanNorm = nansum( weightedNmap(:) ) ./ nansum( W(:) ); % calculate the mean norm value

end