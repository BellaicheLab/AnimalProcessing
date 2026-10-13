function PlotInfo(Qtext, Qplot, killTrQ, Qcolor, Qunits, Animal, Time, Tcolor, scaleBarLength, scale, fontSize, xyOffset, scaleBarWidth)
%
% PlotInfo(Qtext, Qplot, killTrQ, Qcolor, Qunits, Animal, Time, Tcolor, scaleBarLength, scale, fontSize, xyOffset, scaleBarWidth)
%
% What it do:
% Qplot: type of representation of tensor Q: "merged" (ellipse), "split+"/"split-" (circle & dev+/- parts), "circle", "dev+" and "dev-"
% killTrQ: whether mean trace of Q has been reset to 0 in the plot (1.1)
% Tcolor: text color for text other than quantity plotted and scale bar
% scaleBarLength: length of scalebar in Q units
% scale: value of one pixel (for length, length of one pixel)
% NB: parameters "XYoffset" and "sbar_width" can be empty (default values [5 5] and 2, respectively)
%
% version 1.8
% Boris Guirao
% Stephane Rigaud


%% Code %%

% parameters:
ffactor = 0.7; % font factor (mod 1.5)

% text tag indicating whether trace has been set to 0 in the plot (1.1)
kTrQtext = '';
if killTrQ && ~strncmp(Qplot,'dev',3) && ~isempty(Qtext) % only relevant when plotting isotropic part (1.4)
    kTrQtext = ', <Tr> = 0';
end

% text tag indicating which eigenvalue of deviatoric has been plotted (1.1)
plotText = '';
if ~isempty(Qtext) %1.4
    if strcmp(Qplot,'split+') || strcmp(Qplot,'dev+')
        plotText = ' (+)';              % 1.6
    elseif strcmp(Qplot,'split-') || strcmp(Qplot,'dev-')
        plotText = ' (-)';              % 1.6
    end
end

% Completion of Qtext (1.1):
Qtext = [Qtext plotText kTrQtext];

if isempty(xyOffset)
    xyOffset = [5 5]; % default value
end

% Displays name of plotted quantity, time of average, frame number of segmented image:
xyOffsetOther = [5 5]; % different offset than for scalebar (1.5)
PlotText(Qtext, '', xyOffsetOther, fontSize, 'bold', Qcolor, 'TL');
PlotText(Animal, '', xyOffsetOther, -fontSize*ffactor, 'normal', Tcolor, 'BL'); % (1.8) opposite of font size => no interpreter

% Displaying nothing at time location if "Time" is empty (1.7)
if ~isempty(Time)
    PlotText(Time, 'APF', xyOffsetOther, fontSize, 'bold', Tcolor, 'TR'); % changed to APF from hAPF
end

% Scalebar display:
PlotScaleBar(scaleBarLength, scale, Qcolor, Qunits, fontSize*ffactor, xyOffset, scaleBarWidth, Qplot); %(v1.2), 1.3


%% History %%

% 26/04/2020: 1.8 (Boris)
% - using opposite of fontSize to plot animal name to use no interpreter in PlotText

% 25/03/2019: 1.7 (Boris)
% - now NOT diplaying anything in at time location if "Time" is empty.

% 06/07/2017: 1.6 (Boris)
% - simplified text specifying if + or - parts are plotted

% 29/05/2015: 1.5 (Boris)
% - added local parameter "xyOffsetOther"
% - increased "ffactor" to 0.7 from 0.6

% 30/04/2015: 1.4 (Boris)
% - support of empty "Qtext", then not plotting info in top left corner
% - only specifying "killTrQ" when plotting isotropic part

% 02/03/2015: 1.3 (Boris, changed name to InfoPlotter)
% - call to "ScaleBarPlotter"
% - call to "TimePlotter"

% 04/11/2014 : 1.2 (Stephane)
% - use the new Scalebar_Plotter call function

% 01/10/2014: 1.1
% - added argument "killTrQ" specifying whether TrQ has been set to 0 in the plot
% - changed text displayed accordingly

% 19/09/2014: changed to APF from hAPF

% 17/01/2014: creation