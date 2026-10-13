% PlotCustomColors
%
% Version 1.1
% Boris Guirao
%
% Plots colormap corresponding to "CustomColors".
% NB: MUST BE UPDATED ANYTIME "CustomColors" GETS UPDATED (Version numbers should match)
%

%% Loads Custom Colors and define ncolor x 3 color matrix %%

CustomColors

CB = [
    black;
    dark_grey;
    grey;
    mid_grey;
    light_grey;
    white_grey;
    custom_white;
    
    blue;
    mid_blue;
    light_blue;
    custom_blue;
    cyan;
    custom_cyan;
    
    red;
    mid_red;
    light_red;
    crimson ;
    mid_crimson;
    custom_red ;
    
    green;
    mid_green ;
    light_green ;
    custom_green;
    PLuc_green;
    dark_green;
    mid_dark_green;
    light_dark_green ;
    turquoise;
    
    dark_orange;
    orange;
    mid_orange;
    light_orange;
    
    dark_purple;
    mid_purple;
    light_purple;
    purple ;
    custom_purple;
    
    magenta ;
    mid_magenta ;
    light_magenta ;
    
    crigenta ;
    custom_magenta ;
    mid_custom_magenta
    light_custom_magenta
    
    salmon ;
    yellow ;
    mid_yellow ;
    custom_yellow
    ];

 %% Defining corresponding name cell array %%
 
CBnames = {
    'black';
    'dark grey';
    'grey';
    'mid grey';
    'light grey';
    'white grey';
    'custom white';
    
    'blue';
    'mid blue';
    'light blue';
    'custom blue';
    'cyan';
    'custom cyan';
    
    'red';
    'mid red';
    'light red';
    'crimson' ;
    'mid crimson';
    'custom red' ;
    
    'green';
    'mid green' ;
    'light green' ;
    'custom green';
    'PLuc green';
    'dark green';
    'mid dark green';
    'light dark green' ;
    'turquoise';
    
    'dark orange';
    'orange';
    'mid orange';
    'light orange';
    
    'dark purple';
    'mid purple';
    'light purple';
    'purple' ;
    'custom purple';
    
    'magenta' ;
    'mid magenta' ;
    'light magenta' ;
    
    'crigenta';
    'custom magenta' ;
    'mid custom magenta'
    'light custom magenta';
    
    'salmon' ;
    'yellow' ;
    'mid yellow' ;
    'custom yellow' ;
    };

%% Plotting colormap %%

I = zeros(90,30);
val = (1:900)';
M = repmat(val/900,1,600);

ncolors = size(CBnames, 1);

figure('PaperPositionMode','auto')
imshow(M,'Border','loose');
hold on
for n = 1:ncolors
    Ystep = n*900/ncolors;
    if n>3
        text(10,Ystep,CBnames{n},'VerticalAlignment','bottom')
    else
        text(10,Ystep,CBnames{n},'VerticalAlignment','bottom','Color',custom_white)
    end
end
colormap(CB)
title('Done with "PlotCustomColors"','Interpreter','none');
print('-dpng','-r200','CustomColors.png');
close
%saveas(gcf,'test.png')


%% History %%

% 23/11/2017: name became "PlotCustomColors"
% - added "white_grey"

% 12/01/2012: creation


