function M = Vec2Mat(V)
%
% M = Vec2Mat(V)
%
% Turns vector V = [Mxx Mxy Myx Myy] into 2x2 matrix M = [Mxx Mxy ; Myx Myy].
% NB: PAY ATTENTION TO INDICES!
%
% Ex:
% A = [0.7547    0.2760    0.6797    0.6551];
% B = Vec2Mat(A) = [0.7547    0.2760;
%                   0.6797    0.6551]
%
% A = Mat2Vec(Vec2Mat(A));
% B = Vec2Mat(Mat2Vec(B));
%
% Version 1.0
% Boris Guirao

%% Code %%

M = reshape(V,2,2)';


%% History %%

% 22/02/2015: creation