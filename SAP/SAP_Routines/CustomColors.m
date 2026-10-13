% Custom_Colors
%
% Version 1.1
% Boris Guirao
%
% NB: "PlotCustomColors" should be updated at the same time!

%% Color Definitions %%

%%% Fading Parameters:
mid_factor = 0.3;
light_factor = 0.6;

%%% Greys:
black=[0 0 0];
dark_grey=[0.25 0.25 0.25];
grey=[0.5 0.5 0.5];
mid_grey = [0.65 0.65 0.65];
light_grey=[0.75 0.75 0.75];
white_grey = [0.94 0.94 0.94];
custom_white = [0.99 0.99 0.99];                   % sometimes won't display if using [1 1 1]!!!

%%% Blues:
blue = [0 0 1];
mid_blue = FadeColor(blue, mid_factor); 
light_blue = FadeColor(blue, light_factor); 
custom_blue = 1/255*[113 177 255];
cyan=[0 1 1];
custom_cyan = 1/255*[0 200 255];

%%% Reds:
red = [1 0 0];
mid_red = FadeColor(red, mid_factor);
light_red = FadeColor(red, light_factor); 
crimson = 1/255*[150 0 50];
mid_crimson = FadeColor(crimson, mid_factor);
custom_red = 1/255*[235 67 79];

%%% Greens:
green=[0 1 0];
mid_green = FadeColor(green, mid_factor);
light_green = FadeColor(green, light_factor);
custom_green = 1/255*[140 248 168];
PLuc_green = 1/255*[0 136 0];
dark_green = 1/255*[0 150 0];
mid_dark_green = FadeColor(dark_green, mid_factor); 
light_dark_green = FadeColor(dark_green, light_factor); 
turquoise = MixColors(green,mid_blue);

%%% Oranges:
dark_orange = 1/255*[255 100 0];
orange = 1/255*[255 153 0];
mid_orange = FadeColor(orange, mid_factor); 
light_orange = FadeColor(orange, light_factor); 

%%% Purples:
dark_purple = 1/255*[153 51 255];
mid_purple = FadeColor(dark_purple, mid_factor); 
light_purple = FadeColor(dark_purple, light_factor); 
purple = 1/255*[188 152 224];
custom_purple = 1/255*[200 150 255];
% magentas:
magenta = [1 0 1];
mid_magenta = FadeColor(magenta, mid_factor);
light_magenta = FadeColor(magenta, light_factor);
% custom magentas:
crigenta = (0.3*magenta + 0.7*crimson);
custom_magenta = 0.5 * magenta + 0.5 * dark_purple; 
mid_custom_magenta = FadeColor(custom_magenta, mid_factor);
light_custom_magenta = FadeColor(custom_magenta, light_factor);

%%% Others:
salmon = 1/255*[250 182 126];
yellow = [1 1 0];
mid_yellow = FadeColor(yellow, mid_factor);
custom_yellow = [0.8 0.8 0];



%% History %%

% 23/11/2017:
% - added "white_grey"

% 23/04/2012:
% - changed white to 0.99 values

% 27/11/2011:
% - added color "crigenta"

% 02/11/2009: creation


