function displayMacroPattern(halfNotum,mF,colorInstructions)
%
% displayMacroPattern(halfNotum,mF,colorInstructions)
%
% Displays macrochaetes pattern with their number to help user click them.
% Solely used in "SpaceRegistration".
%
% Version 1.0
% Boris Guirao

%% Code %%

if ~strcmp(halfNotum,'b')                               % NOT the "both" case (1.4)
    xM = 600; yM = 40;  % will be coordinates of Macro 1
    text(xM,yM, '1','Color','yellow')
    text(xM+40*mF,yM+50*mF, '2','Color',colorInstructions)
    text(xM+150*mF,yM+55*mF, '3','Color',colorInstructions)
    text(xM+280*mF,yM+55*mF, '4','Color',colorInstructions)
    text(xM+100*mF,yM+150*mF, '5','Color',colorInstructions)
    text(xM+160*mF,yM+200*mF, '6','Color',colorInstructions)
    text(xM+300*mF,yM+210*mF, '7','Color',colorInstructions)
    text(xM+220*mF,yM+250*mF, '8','Color',colorInstructions)
else                                                       % "both" sides case (1.4)
    xM = 100; yM = 300;  % will be coordinates of Macro 1
    % right part
    text(xM,yM, '1','Color','yellow')
    text(xM+40*mF,yM+50*mF, '2','Color',colorInstructions)
    text(xM+150*mF,yM+55*mF, '3','Color',colorInstructions)
    text(xM+280*mF,yM+55*mF, '4','Color',colorInstructions)
    text(xM+100*mF,yM+150*mF, '5','Color',colorInstructions)
    text(xM+160*mF,yM+200*mF, '6','Color',colorInstructions)
    text(xM+300*mF,yM+210*mF, '7','Color',colorInstructions)
    text(xM+220*mF,yM+250*mF, '8','Color',colorInstructions)
    % left part
    yM = yM-50;  % will be coordinates of Macro 9 (symmetric of #1 % miline)
    text(xM,yM, '9','Color','yellow')
    text(xM+40*mF,yM-50*mF, '10','Color',colorInstructions)
    text(xM+150*mF,yM-55*mF, '11','Color',colorInstructions)
    text(xM+280*mF,yM-55*mF, '12','Color',colorInstructions)
    text(xM+100*mF,yM-140*mF, '13','Color',colorInstructions)
    text(xM+160*mF,yM-200*mF, '14','Color',colorInstructions)
    text(xM+300*mF,yM-210*mF, '15','Color',colorInstructions)
    text(xM+220*mF,yM-250*mF, '16','Color',colorInstructions)
end

%% History %%

% 15/05/2018: creation