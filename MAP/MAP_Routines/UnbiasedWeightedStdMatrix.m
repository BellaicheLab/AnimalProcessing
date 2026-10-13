% Stephane Rigaud
% 2016-03-15

% Calculate the unbiased weighted std at each point X, Y at time T of a grid
% - A is a matrix of dimension X,Y,Z,T,A
% - meanA is a matrix of dimension X,Y,Z,T
% - Weight is a matrix of dimension X,Y,Z,T,A
% - the output STD is a matrix of dimension X,Y,Z,T

function [ STD ] = UnbiasedWeightedStdMatrix( A, meanA, Weight )

meanA = repmat( meanA, [1 1 1 1 size(A,5)] );
bias = sum( Weight , 5 ) ./ ( sum( Weight , 5 ) .^2 - sum( Weight .^2 , 5 ) );
WeightedSTD = nansum(  Weight .* (A - meanA).^2 , 5 );
STD = sqrt( bias .* WeightedSTD );

end
