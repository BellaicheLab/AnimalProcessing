function V = Mat2Vec(M)
%
% M = Mat2Vec(M)
%
% Turns 2x2 matrix M = [Mxx Mxy ; Myx Myy] into vector V = [Mxx Mxy Myx Myy].
% NB: PAY ATTENTION TO INDICES!
%
% Ex:
% B = [0.7547    0.2760;
%      0.6797    0.6551]
% A = Mat2Vec(B) = [0.7547    0.2760    0.6797    0.6551];
%
% A = Mat2Vec(Vec2Mat(A));
% B = Vec2Mat(Mat2Vec(B));
%
% Version 1.0
% Boris Guirao

%% Code %%

V = reshape(M',1,4);


%% History %%

% 22/02/2015: creation