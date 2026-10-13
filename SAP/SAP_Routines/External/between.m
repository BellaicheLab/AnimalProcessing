function B=between(a,lowerBound,upperBound,strict)
%% B=BETWEEN(A,L,U,S)
% true if A is between L and U.
% the bounds are included by default.
% A : the element to check
% L : the lower bound
% U : the upper bound
% S : (optional) the limit behaviour. if provided and set to 'true', the bounds are excluded.
%
% GOYA Yûki
% v0.1 (last update: 2012-08-27)
    if nargin==3, strict=false; end
    % swap bounds if not in the right order
    if lowerBound>upperBound
        tmp=lowerBound;
        lowerBound=upperBound;
        upperBound=tmp;
    end
    if strict
        B=lowerBound<a && a<upperBound;
    else
        B=lowerBound<=a && a<=upperBound;
    end
end