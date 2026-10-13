function positionVector = FullScreenDisplay(imageSize)
%
% positionVector = FullScreenDisplay(imageSize)
%
% Determines positionVector = [plotLeft plotBottom plotWidth plotHeight]
% to either fill screen height or screen width according to image aspect
% ratio. Then use it as follows: "set(gcf,'Position',positionVector);"
%
% NB: originally used in "TimeRegistration" and "SpaceRegistration" so that
% images displayed in user interface either fill the (available) full
% height or width of screen.
%
% Version 1.0
% Boris Guirao

%% Code %%

% Getting screen size:
screenSize= get(0,'ScreenSize');
screenWidth = screenSize(3);

leewayBottom = 45;                                          % leeway to avoid windows taskbar at bottom
leewayTop = 100;                                            % leeway to avoid Mac top bar at top 
screenHeight = screenSize(4) - leewayBottom - leewayTop;    % effective available screen Height

% Image Size
imHeight = imageSize(1);
imWidth = imageSize(2);

% Determining image and screen aspect ratios:
imAspectRatio = imWidth/imHeight;
screenAspectRatio = screenWidth/screenHeight;

% Determining "plotHeight" and "plotWidth" accordingly:
if imAspectRatio <= screenAspectRatio       % image is more slender than screen
    plotHeight = screenHeight;
    plotWidth = round(screenHeight/imHeight * imWidth);
else
    plotWidth = screenWidth;
    plotHeight = round(screenWidth/imWidth * imHeight);
end
plotBottom = leewayBottom;
plotLeft = round((screenWidth - plotWidth)/2); % display in the middle

% Building "positionVector"
positionVector = [plotLeft plotBottom plotWidth plotHeight];


%% History %%

% 30/03/2018: creation