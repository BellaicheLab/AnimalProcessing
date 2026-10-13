% PlotAllTimeRanges
%
% Creates graphs enabling visualization of time ranges for all animals
% listed in "avgAnimals" cell array (defined at the top of MAP_parameters).
%
% Version 2.2 (replaces "PlotMovieTimeRange")
% Boris Guirao

%% Code %%

% Little fix to avoid First crash of AOA if the TimeRangePlot is not generated 
% eval(['SAP_info_' aName]); changes timeStop under certain conditions which crashses AOA afterwards

% Making backup of timeStart/Stop currently defined in SAP_parameters:
timeStartBackup = timeStart;
timeStopBackup = timeStop;

textFontSize = PLOT.fontSizeInfo/2;
nAnimals = length(avgAnimals);

animalTimeRanges = NaN(nAnimals+1,2);
animalTimeRangesText = cell(nAnimals+1,1); % will store a text version (1.1)

SAPcall = true;
% PMTRcall = true;
for a = 1:nAnimals
    
    aName = avgAnimals{a};
    eval(['SAP_info_' aName]);
    
    % Defining actual animal timeStart/Stop based on start/finalFrame (NOT
    % using SAP_parameters "timeStart/Stop") to assess actual movie duration (2.1):
    timeStartAnimal = frame2time(startFrame, timeRef, frameRef, dt,'str'); % mod 6.3
    timeStopAnimal = frame2time(finalFrame, timeRef, frameRef, dt,'str'); % mod 6.3

    animalTimeRanges(a+1,1) = TimeStr2Dec(timeStartAnimal);
    animalTimeRanges(a+1,2) = TimeStr2Dec(timeStopAnimal);
    
    % Storing a text version (1.1)
    animalTimeRangesText{a+1} = ['[' TimeDec2Str(animalTimeRanges(a+1,1)) ' - ' TimeDec2Str(animalTimeRanges(a+1,2))  ']'];
end

timeStartMin = min(animalTimeRanges(:,1));
timeStartMax = max(animalTimeRanges(:,1));
timeStopMin = min(animalTimeRanges(:,2));
timeStopMax = max(animalTimeRanges(:,2));

timeMinRange = [timeStartMax timeStopMin];
timeMaxRange = [timeStartMin timeStopMax];

animalTimeRanges(1,:) = timeMaxRange;
animalListExt = [['minRange:' '[' TimeDec2Str(timeStartMax) ' - ' TimeDec2Str(timeStopMin) ']']; avgAnimals];
animalTimeRangesText{1} = ['maxRange:' '[' TimeDec2Str(timeStartMin) ' - ' TimeDec2Str(timeStopMax)  ']']; % 1.1
% animalTimeRangesText = cell2mat(animalTimeRangesText); % 1.1

%% Plot %%

figure
box on
animalYs = (0:nAnimals)';
animalYs = repmat(animalYs,1,2);

line(animalTimeRanges', animalYs','LineWidth',3)

line([timeStartMin timeStopMax],[0 0],'LineWidth',3,'color',[0.7 0.7 0.7]); % replotting maxRange line in grey
line([timeStartMax timeStopMin],[0 0],'LineWidth',3,'color',[0 0 0]);       % adding minRange line in black on top of max range one

line([timeStartMax timeStopMin; timeStartMax timeStopMin],[0 0; nAnimals nAnimals],'LineStyle','--','color','black')
line([timeStartMin timeStopMax; timeStartMin timeStopMax],[0 0; nAnimals nAnimals],'LineStyle','--','color','black')

axis([10 45 -1 nAnimals+1])

text(mean(animalTimeRanges,2),animalYs(:,1),animalListExt,'VerticalAlignment','Bottom','HorizontalAlignment','Center','FontSize',textFontSize, 'Interpreter','none');
text(mean(animalTimeRanges,2),animalYs(:,1),animalTimeRangesText,'VerticalAlignment','Top','HorizontalAlignment','Center','FontSize',textFontSize);

xlabel('hAPF')
ylabel('animals')
title(['Time ranges of "' mapAnimal '" animals (n = ' num2str(nAnimals) ')'])

if ~exist(PathName,'dir')
    mkdir(PathName)
end

print('-dpng','-r200',PATRfile)
disp(['Saved animal time range graph at "' PATRfile '".'])
close % leaves images on screen for user

timeStop = timeStopBackup;
timeStart = timeStartBackup;


%% History %%

% 11/10/2024: 2.2
% - added number of animals in title

% 19/09/2020: 2.1
% - now locally defining actual animal timeStart/Stop based on start/finalFrame (NOT
% using SAP_parameters "timeStart/Stop") to assess actual movie duration.
% - Accordingly stopped overwritting timeStart/Stop by empty '' in SAP.
% - Accordingly stopped overwritting boolean "PMTRcall" that only used once in SAP.

% 01/06/2020: 2.0 ("PlotMovieTimeRange" became "PlotAllTimeRanges")
% - integration into MAP Suite
% - added maxTimeRange in addition to minTimeRange

% 21/01/2019: 1.1
% - now must specify "printFolder"
% - now displays animal name above time range segment
% - now displays corresponding time range name below time range segment
