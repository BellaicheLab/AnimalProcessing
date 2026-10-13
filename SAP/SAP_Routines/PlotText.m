function PlotText(text2Plot, units, xyOffset, fontSize, fontWeight, fontColor, location)
%
% PlotText(text2Plot, units, xyOffset, fontSize, fontWeight, fontColor, location)
%
% text2Plot = can be string OR decimal and will be displayed as such
% units = string ('hAPF' for instance)
% xyOffset = 2 elements vector specifying the offsets to apply along x and y
% fontSize = font size. NB: if >0 use 'tex' interpreter; if <0 use NONE!!
% fontWeight = 'normal', 'bold' (default), 'light', 'demi'
% fontColor = color of text to display (value RGB)
% location = string ('TR', 'TL', 'BR', 'BL' for Top Right,...)
%
% version 2.0 (from PlotTime 1.3)
% Boris Guirao


%% Code %%

% checks emptyness before continuing (1.2), COM 2.0
% if isempty(text2Plot)
%     disp('"PlotText" WARNING: no "text2Plot" string provided!')
%     return
% end

% Use "tex" interpreter if POSITIVE font size
textInterpreter = 'tex'; % default
if fontSize < 0
    fontSize = abs(fontSize);
    textInterpreter = 'none';
end

Xbounds = xlim;
Ybounds = ylim;

% defines default values:
if isempty(xyOffset)
    xyOffset = [5 5];
end
if isempty(fontWeight)
    fontWeight = 'bold';
end

% defines displayed time depending on
if ischar(text2Plot)
    timeDisplayed = [text2Plot ' ' units];
else
    timeDisplayed = [num2str(text2Plot) ' ' units];
end

% sets up text positio according to location:
if strcmp(location, 'TR')
    X = Xbounds(2) - xyOffset(1); % more left
    Y = Ybounds(1) + xyOffset(2); % more down
    HA = 'Right';
    VA = 'Top';
elseif strcmp(location, 'TL')
    X = Xbounds(1) + xyOffset(1); % more right
    Y = Ybounds(1) + xyOffset(2); % more down
    HA = 'Left';
    VA = 'Top';
elseif strcmp(location, 'BL')
    X = Xbounds(1) + xyOffset(1); % more right
    Y = Ybounds(2) - xyOffset(2); % more up
    HA = 'Left';
    VA = 'Bottom';
elseif strcmp(location, 'BR')
    X = Xbounds(2) - xyOffset(1); % more left
    Y = Ybounds(2) - xyOffset(2); % more up
    HA = 'Right';
    VA = 'Bottom';
else
    disp(['Error in "PlotText": incorrect "location" string (' location ')!!'])
return
end
        
text(X,Y,timeDisplayed, 'FontSize', fontSize,'FontWeight', fontWeight, 'Color', fontColor, 'HorizontalAlignment',HA, 'VerticalAlignment',VA,'Interpreter',textInterpreter); % mod 1.3
% text(X,Y,displayed_time, 'FontSize', size,'FontWeight', weight, 'Color', color, 'HorizontalAlignment',HA, 'VerticalAlignment',VA,'Interpreter',textInterpreter); % removed default Tex interpreter (1.1)


%% History %%

% 07/03/2018: 2.0 became "PlotText"
% - commented part displaying warning when empty "text2Plot" provided

% 25/01/2018: 1.3
% - now uses "tex" interpreter if POSITIVE "fontSize" value, "none" otherwise

% 12/01/2018:
% - removed ('Interpreter','none') option  (Matalb 2017)

% 25/02/2014: 1.2

% 21/01/2014: 1.1
% - added ('Interpreter','none') option for text display

% 25/07/2013: creation

