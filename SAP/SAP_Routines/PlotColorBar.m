function [hc, valVector] = PlotColorBar(quantity, positionXYWH, limits, fontSize, fontColor, colorMap)
%
% [hc, valVector] = PlotColorBar(quantity, positionXYWH, limits, fontSize, fontColor, colorMap)
%
% Will plot color bar at bottom right corner, right before scale bar to scalebar. 
%
% NB: use fontSize < 0 to use "latex" as text interpreter (instead of "none")
%
% quantity = string specifying what the colorbar is quantifying
% positionXYWH = 4-element vector ("colorBarXYWH" in animal "AIA_info")
% limits = min and max values of quantity
% colorMap = colormap to be used (nTones x 3 matrix).
%
% NB1: if a **RGB** image is open, this will NOT apply the colorMap to the image but will JUST plot the colormap at "positionXYWH", thereby
% giving more flexibility to build the image (like displaying macrochaetes in yellow with a greyscale colormap)
%
% NB2: designed on **RGB** images made of "doubles". If using it on a 8bit **RGB** image, there will be an offset in the XTicks: 
% the first then tick corresponds to 0 and NOT 1 anymore => minVal ends up being plotted at the second tick instead of
% the first one!! => minTick should become 0 and maxTick = nTones-1;
%
% NB3: when image is **NOT RGB** (only n x m matrix), it will be colored according to colormap ( more convenient to use outputs
% "hc" and "valVector" and apply "caxis" outside of PlotColorBar (cf commented parts) (see also global delamination map from CppTDisplay")
%
% Version 2.3
% Boris Guirao

%% Code %%

fontFactor = 0.5;
fontFactorTitle = 0.6;  % 2.2
precision = 2;          % number to display

% Use "tex" interpreter if POSITIVE font size
textInterpreter = 'tex'; % default
if fontSize < 0
    fontSize = abs(fontSize);
    textInterpreter = 'none';
end

colormap(colorMap);         % applying colormap to already displayed image
nTones = size(colorMap,1);

hc = colorbar('FontSize', fontSize*fontFactor,'fontweight','bold','Color',fontColor,'Location','north','Position', positionXYWH,'Units','normalized');

%%% Determining the 3 colorbar ticks to be labelled (2.2):
minTick = 1;
maxTick = nTones;
midTick = (maxTick + minTick)/2; % nTones/2
% OLD
% minTick = 1;
% maxTick = nTones;
% midTick = (nTones+1)/2;

%%% Determining values to use as labels
minVal = limits(1);
maxVal = limits(2);
midVal = 0.5*(minVal+maxVal);

if minVal < 0 && maxVal > 0
    
    midVal = 0;             % will display 0 as mid value in the color bar in that case
    
    % finding corresponding tick:
    dVal = (maxVal - minVal)/(nTones-1); % if 3 tones, only 2 steps to go from 1 to 3
    sampledVal = minVal:dVal:maxVal;
    zeroTick = find(sampledVal == 0, 1); % found exact tick
    
    % look for nearest tick when couldn't find it
    if isempty(zeroTick)
        
        lastNegTick = find(sampledVal < 0, 1, 'last');
        firstPosTick = find(sampledVal > 0, 1 );
        
        nearZeroTicks = [lastNegTick firstPosTick];
        nearZeroVals = abs([sampledVal(lastNegTick) sampledVal(firstPosTick)]);
        [~, indClosest] = min(nearZeroVals);
        
        zeroTick = nearZeroTicks(indClosest);
    end
    
    midTick = zeroTick;
end

tickVector = [minTick midTick maxTick]/nTones; % 2.2
tickVector = tickVector - 0.5/nTones;           % set tick location at the center of each tone (2.2)
% tickVector = [minTick midTick maxTick];
valVector = [minVal midVal maxVal];
valArray = {num2str(minVal,precision) num2str(midVal,precision) num2str(maxVal,precision)};

%%% Values at the bottom, title on top
hc.Ticks = tickVector;
hc.TickLabels = valArray;
% OLD
set(hc,'xaxisloc','bottom');
% set(hc,'XTick', tickVector);
% set(hc,'XTickLabel', valArray);
% set(hc,'XColor',fontColor,'YColor',fontColor); % 2.1

title(hc,quantity,'VerticalAlignment','baseline','HorizontalAlignment','Center','Color',fontColor,...
    'FontSize',fontSize*fontFactorTitle, 'Interpreter', textInterpreter); % mod 2.2


%% History %%

% 25/06/2018: 2.3
% - now also using "fontColor" to diplay tick marks and box outline accordingly.

% 25/01/2018: 2.2
% - changes to make it work with Matlab 2017
% - now uses "tex" interpreter if POSITIVE "fontSize" value, "none" otherwise
% - improved location of ticks and tick labels

% 15/01/2018:
% removed "'Interpreter', 'none'" in title

% 08/11/2017: 2.1
% - added argument "fontColor" to control color of color bar axes and text

% 21/06/2017: 2.0

% 23/05/2017: created
