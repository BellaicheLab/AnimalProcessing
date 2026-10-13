function h = PlotMidline(image, Ymid, color)
%
% h = PlotMidline(image, Ymid, color)
%
% version 1.2
% Boris Guirao


%% Code %%

% color = 'c'; % commented 1.2
style = '--';
width = 1;
leeway = 0.05; % 1.2

h = [];
if ~isempty(Ymid)                           % No midline plot if Ymid is empty
    Xs = xlim;                      % finds image limits in X
    Xs = Xs(2)*[leeway 1-leeway];   % leaves "leeway" % of distance to border (1.2)
    Ys = repmat(Ymid,1,2);
    
    if ~isempty(image)
        
        %%% Creates new figure using "image":
        figure('PaperPositionMode','auto');
        h = imshow(image, 'Border','tight');
        hold on
        line(Xs,Ys,'Color',color,'LineStyle',style)
    else
        hold on
        line(Xs,Ys,'Color',color,'LineStyle',style, 'LineWidth', width)
    end
end


%% History %%

% 19/01/2014: 1.2 became "MidlinePlotter"

% 04/04/2014: 1.1
% - now arguments color, style, width are hard coded.

% 03/04/2014: creation

