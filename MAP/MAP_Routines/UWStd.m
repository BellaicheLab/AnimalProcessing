% Stephane Rigaud
% 2016-03-15

% Unbiased weighted standard deviation (on the 4th dimension of a matrix)
% - input X a 4 dimension matrix (x,y,:,t), W the weights
% - output the corresponding std

function [ STD ] = UWStd( X, W )

Xmean = mean(X);
bias = nansum(W) ./ ( nansum(W).^2 - nansum(W.^2) );
STD = sqrt( bias .* nansum(W .* (X - Xmean).^2) );

end