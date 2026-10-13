function p = CurveFill(Xs,Y1s,Y2s,Color,fading)
%
% p = CurveFill(Xs,Y1s,Y2s,Color,fading)
%
% Plots the two curves defined by coordinates (Xs,Y1s) and (Xs,Y2s) with line color "Color", filling the space between
% the two curves with faded color ("fading" in [0,1], 1 = all white.
%
% Xs = x coordinates of data points (COLUMN VECTOR)
% Yis = y coordinates of ith curve to plot (COLUMN VECTOR)
% Color = edge curve color
%
% NB2: all data must be COLUMN VECTORS OR MATRICES
%
% Version 1.2
% Boris Guirao


%% Code %%

% Colors:
colorCurves = Color;
white = [1 1 1];
colorFill = fading*white + (1-fading)*colorCurves; % color_curves diluted with white

% Defines patches:
fv.Vertices = [ Xs(1) Y1s(1)
                Xs(:) Y2s(:)
                Xs(end:-1:1) Y1s(end:-1:1)];

fv.Faces = 1:size(fv.Vertices,1);
fv.FaceColor = colorFill;
fv.EdgeColor = colorFill;

% Plot:
p = patch(fv);
hold on
% h = plot(x,y1,x,y2,'Color',colorCurves);
box on

end

%% History

% 08/10/2018: 1.2
% - added "fading" in arguments
% - simplified code: now requires exact number of arguments

% 21/03/2014: 1.1
% - cleaned up

% 12/10/2009: Creation
