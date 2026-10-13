function PlotScaleBar(scalebarLength, pixScale, color, units, fontSize, xyOffset, lineWidth, plotType)
%
% PlotScaleBar(scalebarLength, pixScale, color, units, fontSize, XYoffset, lineWidth, plotType)
%
% will plot a scale bar of magnitude "scalebarLength" (in real units) at bottom right corner of image using "XYoffset",
% "pixScale" (value of 1 pixel, NOT THE "scale_ratio"!!), "lineWidth", and will display scale and "units" at "fontSize".
% If "XYoffset" is empty, default value [5 5] is assigned. If "lineWidth" is empty, default value 2 is assigned.
% If fontSize = 0, no text will be displayed above scale bar.
%
% Version 2.4
% Boris Guirao
% Stephane Rigaud
% 

%% Initialization %%

% Use "tex" interpreter if POSITIVE font size
textInterpreter = 'tex'; % default
if fontSize < 0
    fontSize = abs(fontSize);
    textInterpreter = 'none';
end

% Gets min and max values for x and y in image (1.3)
Xbounds = xlim;
Ybounds = ylim;

% assigns default values when arguments left empty (1.1):
if isempty(xyOffset)
    xyOffset = [5 5];
end
if isempty(lineWidth)
    lineWidth = 2;
end

% Turns "pix_scale" into vector if scalar by duplicating it OR overrides 2nd value if "merged" plot (1.5):
if length(pixScale) == 1 || strcmp(plotType,'merged')
    pixScale = [pixScale(1) pixScale(1)];
end

% Renames each listed values according to meaning:
circ_ps = pixScale(1);
bar_ps = pixScale(2);


%% Defining scale bar default coordinates using pix_scale(2) %%

% NB: may be overidden later if plotting circle as well

L = scalebarLength/bar_ps;                     % scalebar length in pixels
SBx1 = Xbounds(2) - xyOffset(1);
SBx2 = SBx1 - L;
SBx = (SBx1 + SBx2)/2;                        % center
SBy = Ybounds(2)- xyOffset(2);


%% Circle plot: uses pix_scale(1) (2.0)%%

circle_plot = false; % default (2.1)
% always plots it unless "dev" or "merge" plot, or "" (empty, 2.1):
if ~isempty(plotType) && ~(strcmp(plotType,'dev+') || strcmp(plotType,'dev-') || strcmp(plotType,'merged'))   % mod 2.1
    
    r = scalebarLength/2*1/circ_ps ;   % this naturally rescales circle to its right size which is defined by "sbar_length"
    
    % make circle tangent to frame + leeway defined by XY_offset:
    Cx = Xbounds(2) - xyOffset(1) - r;
    Cy = Ybounds(2) - xyOffset(2) - r;
    
    % Overrides coordinates of circle center ONLY IF NOT using "circle" plot
    if ~strcmp(plotType,'circle')
        Cx = min(SBx,Cx);
        Cy = min(SBy,Cy);
    end
    
    % Plot with Ellipse (2.2)
    EDISPLAY.EdgeColor = color;
    EDISPLAY.EdgeWidth = lineWidth/2; % will plot circle with half width of bar
    EDISPLAY.FaceColor = [1 1 1];
    EDISPLAY.FaceOpacity = 0.5;
    Ellipse(r,r,Cx,Cy,0,EDISPLAY); % plots cricle
%     Ellipse(r,r,Cx,Cy, 0, color, line_width/2, '-', color, 0); % draws circle
    
    % Will plot bar at circle center:
    SBx1 = Cx + L/2;
    SBx2 = Cx - L/2;
    SBy = Cy;
    
    circle_plot = true; % circle was indeed plot (2.1)
end


%% Bar plot: uses pix_scale(2) (2.0) %%

% Vectors to be used with "line":
SBXs = [SBx1 ; SBx2];
SBYs = [SBy ; SBy];

% Always plots it unless "circle" plot:
if ~strcmp(plotType,'circle')
    
    line(SBXs, SBYs,'Color',color,'LineWidth',lineWidth,'LineStyle','-'); % draws line
end


%% Writing text (2.0, 2.3) %%

% defining text coordinates: will be written on the left of circle+bar, right justified
Tx = SBx1;              % default: write text right above scalebar (2.1)
Ty = SBy;
Valign = 'bottom';      % default (2.1)
if circle_plot
    Tx = min(SBx2,Cx-r);    % ends writing text either NEXT TO bar OR circle (2.1)
    Valign = 'Baseline';      % baseline because with "middle" it won't show up if the bar is too low (2.3)
%     Valign = 'middle';      % centers writing at bar height when plotting circle (2.1), commented 2.3
end
% TxMin = Xbounds(2)- 30;
% Tx = min(Tx, TxMin);
% TyMin = Ybounds(2)- 30;
% Ty = min(Ty, TyMin);

% COMMENTED FOR VICTOIRE'S ARTICLE
text(Tx,Ty, [num2str(scalebarLength,2) ' ' units],'HorizontalAlignment','right','VerticalAlignment', Valign,'FontSize',fontSize,...
    'Color',color,'FontWeight','bold','Interpreter', textInterpreter); % mod 2.4


%% History %%

% 25/01/2018: 2.4 (Boris)
% - now uses "tex" interpreter if POSITIVE "fontSize" value, "none" otherwise

% 29/06/2017: (Boris)

% 09/03/2015: 2.3 (Boris)
% - fixed display of scalebar text (when plotting bar+circle) that used to not show up. Now using "baseline" instead of "middle"

% 02/03/2015: 2.2 (Boris, changed name to "ScaleBarPlotter")
% - adjustments to use latest version of Ellipse (1.3)

% 24/02/2015: 2.1
% - not drawing circle when "plot_type" is empty
% - now displays text right above scalebar when circle not plotted, right next to scalebar or circle when plotted

% 18/02/2015: 2.0: major overhaul and simplification of the code (Boris)
% - now writes scale on left of bar/circle
% - now plots circle centered on scale bar like tensors
% - the circle radius is now properly rescaled according to value of pix_scale(1) => display of bar scale is sufficient (used to be wrong)
% - when plotting both circle and bar, location determined to fit in image
% - changed argument name to "sbar_length" from "length" because of conflict with Matlab function "length"
% - now turns "pix_scale" into vector if entered as scalar

% 04/11/2014: 1.4 (Stephane)
% - add plot_type parameter to the function
% - add scale circle magnitude for the isotropic values (split+/- and circle)
% - scale circle and scale bar can have different values

% 17/01/2014: 1.3
% - removed "image_size" from arguments to use xlim, ylim instead.
% - moved "XY_offset" argument to 2nd to last position.

% 17/07/2012: 1.2
% - now possible to remove text above scale bar by setting font_size = 0

% 03/05/2012: 1.1
% - added default value "XY_offset" and "line_width" when they are left empty

% 23/04/2012: creation