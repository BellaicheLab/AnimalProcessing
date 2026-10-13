function WM = WeightedMean(X,W)
%
% Calculates scalar WM = mean of 2D matrix X values weighted by weights W.
% NB: X and W must have same dimensions, W shoud contain NO NaN
% 
% Version 1.0
% Boris Guirao

%% Code %%

nonanTF = ~isnan(X);
Xv = X(nonanTF); % making a vector with no NaN
Wv = W(nonanTF); % only keep weights corresponding to no NaN values in X
% NB: this last line is to give the same results as function "mean" when W = ones().

XMv = Xv.*Wv;
sumXMv = sum(XMv);  % weighted sum
sumW = sum(Wv);     % sum of weights on no NaN location of x

WM = sumXMv/sumW;

%% History %%

% 20/09/2014: creation
