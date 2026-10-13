function Ellipse(a,b,cx,cy,angle,DISPLAY)
%
% Ellipse(a,b,cx,cy,angle,DISPLAY)
%
% Inputs:
% - a: semimajor axis (width) in pixels
% - b: semiminor axis (height) in pixels
% - cx: horizontal center
% - cy: vertical center
% - angle: orientation ellipse in degrees
% - DISPLAY: structure that can contain OPTIONAL display parameters
%   - EdgeColor
%   - EdgeWidth 
%   - EdgeStyle         '-',':'...
%   - EdgeOpacity       value in [0 1]
%   - FaceColor
%   - FaceOpacity       value in [0 1]
%
% Version 2.0
% Boris Guirao
% Adapted from "plot_ellipse" downloaded from MatlabCentral


%% Plot test %%

% NB: important to check sign of plotted angles.

% imshow(image_raw)
% hold on
% 
% angle = -90;
% a = 15;
% b = 5;
% cx = 100;
% cy = 100;
% color = 'r';


%% Assigning default values (2.0) %%

if isfield(DISPLAY,'EdgeColor')
    EdgeColor = DISPLAY.EdgeColor;
else
    EdgeColor = [0 0 0]; % black
end

if isfield(DISPLAY,'EdgeWidth')
    EdgeWidth = DISPLAY.EdgeWidth;
else
    EdgeWidth = 2;
end

if isfield(DISPLAY,'EdgeStyle')
    EdgeStyle = DISPLAY.EdgeStyle;
else
    EdgeStyle = '-'; % full line
end
    
if isfield(DISPLAY,'EdgeOpacity')
    EdgeOpacity = DISPLAY.EdgeOpacity;
else
    EdgeOpacity = 1; % full opacity
end

if isfield(DISPLAY,'FaceColor')
    FaceColor = DISPLAY.FaceColor;
else
    FaceColor = 'none';
end

if isfield(DISPLAY,'FaceOpacity')
    FaceOpacity = DISPLAY.FaceOpacity;
else
    FaceOpacity = 1; % full opacity when plotted (FaceColor ~= none)
end


%% Plotting ellipse %%
    
angle = angle/180*pi;

r = 0:0.1:2*pi+0.1;
p = [a*cos(r) ; b*sin(r)];                                                  % [x1 x2 x3...
                                                                            %  y1 y2 y3...]     series of [x;y] column-vectors

alpha = [cos(angle) -sin(angle)
         sin(angle) cos(angle)];

p1 = alpha*p;                                                               % X' = R*X          applies rotation matrix PROPERLY
p1 = p1';

h = patch(cx+p1(:,1),cy+p1(:,2),EdgeColor,'EdgeColor',EdgeColor,'EdgeAlpha',EdgeOpacity);             % 2.0
set(h,'LineWidth',EdgeWidth,'LineStyle',EdgeStyle,'FaceColor',FaceColor,'FaceAlpha', FaceOpacity);  % 1.2



%% History 

% 02/03/2015: 2.0 Major overhaul
% - drastically reduced number of arguments by using structure DISPLAY
% - defined default values for all display parameters so an ellipse can be plotted by only specifying its geometry

% 03/04/2014: 1.2
% - included Anais' modifications: optional addition of parameters "face_color" and "face_opactiy" as arguments
% - fixed bug with "face_opacity" set to '0' instead of 0

% 23/07/2013: 1.1
% - addition of optional parameter 'line_style' to edit ellipse linestyle

% 02/02/2011: 
% - fixed the wrong angle display (-angle) due to sloppy handling of transposed vectors
% - removed the inside of ellipse and added line_width as paramter


 
   
   