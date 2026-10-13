function colorOut = MixColors(color1,color2,x)
%
% colorOut = MixColors(color1,color2,x)
%
% Mixes 2 colors ([r g b], with 0< r,g,b <1) with weight x as follows: color = x*color1 + (1-x)*color2;
%
% 1.1
% Boris Guirao

%% code %%

if nargin == 2
    x = 1/2;
end

colorOut = x*color1 + (1-x)*color2;
%mixed_color = 1/2*(color1 + color2);


%% History %%

% 19/09/2014: 1.1
% - introduced weight x

% 16/01/2012: creation