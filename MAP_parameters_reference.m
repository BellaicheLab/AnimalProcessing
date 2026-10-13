% MAP_parameters
%
% Defines the set of animals to analyze as well as parameters specific to
% this multi-animal analysis to run "MAP".
% Parameters specific to single animals must be set in "parametersSAP".
%

% Version = 4.3;
% Stephane Rigaud
% Boris Guirao

clear all; close all; %clc;  % Cleaning of workspace (DO NOT MODIFY)
addpath(genpath("/path/to/AnimalProcessing"));


%% ANIMALS TO INCLUDE %%

% Definition of animal lists often use for analysis:
%--------------------------------------------------------------------------
% Animal lists: 
avgAnimalsWT = {  'WT_1'; 'WT_2'; 'WT_3'; 'WT_4'; 'WT_5'; 'WT_6'; 'WT_7'; 'WT_8'; 'WT_9'; 'WT_10';...
                'WT_11'; 'WT_12'; 'WT_13'; 'WT_14'; 'WT_15'; 'WT_16'; 'WT_17'; 'WT_18'; 'WT_19'; 'WT_20';...
                'WT_21'; 'WT_22'; 'WT_23'; 'WT_24'; 'WT_25'; 'WT_26'; 'WT_27'; 'WT_28'; 'WT_29'; 'WT_30';...
                'WT_31'; 'WT_32'; 'WT_33'; 'WT_34'; 'WT_35'; 'WT_36'; 'WT_37'; 'WT_38'; 'WT_39'};
excludeAnimalsWT ={'WT_6'; 'WT_15'; 'WT_22'; 'WT_33'; 'WT_34'; 'WT_35'};
avgAnimalsWT = setdiff(avgAnimalsWT, excludeAnimalsWT);

avgAnimalsKO = {  'KO_1'; 'KO_2'; 'KO_3'; 'KO_4'; 'KO_5'; 'KO_6'; 'KO_7'; 'KO_8'; 'KO_9'; 'KO_10';...
                'KO_11'; 'KO_12'; 'KO_13'; 'KO_14'; 'KO_15'; 'KO_16'; 'KO_17'; 'KO_18'; 'KO_19'; 'KO_20';...
                'KO_21'; 'KO_22'; 'KO_23'; 'KO_24'; 'KO_25'; 'KO_26'; 'KO_27'; 'KO_28'; 'KO_29'; 'KO_30';...
                'KO_31'; 'KO_32'; 'KO_33'; 'KO_34'; 'KO_35'; 'KO_36'; 'KO_37'; 'KO_38'; 'KO_39'; 'KO_40';...
                'KO_41'; 'KO_42'; 'KO_43'; 'KO_44'; 'KO_45'};
excludeAnimalsKO ={'KO_1'; 'KO_3'; 'KO_4'; 'KO_5'; 'KO_6'; 'KO_7'; 'KO_8'; 'KO_13'; 'KO_23'};
avgAnimalsKO = setdiff(avgAnimalsKO, excludeAnimalsKO);

% 11 ANIMALS
% avgAnimals = {'WT_1'; 'WT_10'; 'WT_11'; 'WT_12'; 'WT_13'; 'WT_14'; 'WT_16'; 'WT_17'; 'WT_18'; 'WT_19'; 'WT_2'};
% avgAnimals = {'KO_10'; 'KO_11'; 'KO_12'; 'KO_14'; 'KO_15'; 'KO_16'; 'KO_17'; 'KO_18'; 'KO_19'; 'KO_2'; 'KO_20'};
% excludeAnimals ={};
%--------------------------------------------------------------------------
% Animals to take into account in the average (selection of one of the above list)
%--------------------------------------------------------------------------
avgAnimals = avgAnimalsWT;
mapAnimal = 'WT';                                               % name of average animal OR actual animal name (BIG1, TRBL4...) when processing single animal
% avgAnimals = avgAnimalsKO;
% mapAnimal = 'KO';                                               % name of average animal OR actual animal name (BIG1, TRBL4...) when processing single animal
PathName = 'C:\DATA\TissueAnalysis\AOA.outputs.all.animals';                 % Global output path: all outputs will be saved there in a structure file.
% PathName = 'C:\DATA\TissueAnalysis\AOA.outputs.11.animals';                 % Global output path: all outputs will be saved there in a structure file.
% PathName = 'path\to\SegmentationTest\AOA.outputs';                             % Global output path: all outputs will be saved there in a structure file.
% PathName = '/path/to/data/SegmentationTest/AOA.outputs';                             % Global output path: all outputs will be saved there in a structure file.

%--------------------------------------------------------------------------

% ALL animals to consider to build commong grid:
%--------------------------------------------------------------------------
% allAnimals = [avgAnimalsWhite ; avgAnimalsActn];
allAnimals = [avgAnimalsWT; avgAnimalsKO];
%--------------------------------------------------------------------------


%% Operation Name (Oname) Selection / PROGRAMS TO RUN %%

% PRE-segmentation
RA = 0;                % "RescaleAnimals"

% POST-segmentation
AOA = 0;               % "AverageOverAnimals"
DBA = 0;               % "DifferenceBetwenArchetypes"
POA = 0;               % "ProjectionOverAnimals"
PTE = 0;               % "PlotTimeEvolution"

% NOT updated
% COQ = 0;               % "CalculOverQuantities"
% CCF = 1;              % Cross-Correlation Function
% TC  = 0;               % Tensor Corelator (in progress)

%% RA - RescaleAnimals (3.0)%%

% Enter "Archetype" to CREATE archetype OR "Rescale" to use existing archetype for RESCALING
rescaleMode = 'Rescale';       

% Time at which landmarks were clicked IN ALL MOVIES
clickTimeAll = '22h00'; 

% Minimum number of macrochaetes AVAILABLE (ON EACH SIDE OF ANIMAL if halfNotum = 'b') in all animals to process (USED TO CALCULATE BARYCENTERS)
nMacroMin = 4;   

%%% Archetype related
% Parent folder that will contain archetypes made at different clicking times
parentArchetypeFolder = 'path\to\Archetype'; 
% parentArchetypeFolder = '/path/to/data/Archetype'; 

% Prefix that will appear before "archetype_..." in folder name
archetypeName = '';                                          

%%% Rescaled animal related:
% Parent folder that will contain rescaled animals made at different clicking times
parentRescaledAnimalsFolder = 'path\to\SegmentationTest';
% parentRescaledAnimalsFolder = '/path/to/data/SegmentationTest';     

% Prefix that will appear before "rescaled_..." in folder name
rescaleName = 'ALL';                                            




makeSVG = false;

%% Quantities to be PLOTTED and PROJECTED %%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Qname = {'EG'};
Qname = {'I'; 'dnD';'Epsilon';'Omega';'ER';'ES';'EG';'EA';'ED';'EF';'EN';'EJ'};
% Qname = {'ER';'ES';'EG';'EA';'ED';'Epsilon';'S';'I';'U'};
%  Qname = {'dnD';'dnA';'nCoreRNs'};
%Qname = {'dnD'};
% Qname = {'U'};
% % Qname = {'OmegaPIV'};
% Qname = {'UPIV' ; 'EpsilonPIV'};
% Qname = {'U' ; 'Epsilon' ; 'Omega'};
% Qname = {'ER';'ES';'EG';'EA';'ED';'dnD';'dnA';'AvgCellArea';'AvgCellIaniso'};
% NB: ALL quantities are CALCULATED anyway in AOA, DBA, *BUT* in POA, ONLY those listed here will be calculated and plotted in POA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Filtering of data beyond threshold:
AOAvalidityThreshold = 0.1;                                 % NB: for TA quantities, 1 corresponds to a rate of 100 %/h
QnameFilter = {'ER';'ES';'EG';'EA';'ED';'EF';'EN';'EJ'};    % list of quantities whose components will be compared to threshold
% NB: if a single quantity component is beyond threshold in a grid box, all
% quantities will be discarded in that box
% NB: to avoid any filtering, make QnameFilter empty or use high threshold

tagProjPlot = {'d'}; % Plot projected quantities with corresponding 'i','d','do' tags (e.g. EGdotEG_d)
scaleRatioFactorDBA = 2; % ONLY USED IN POA (TO BE REMOVED?)
scaleRatioFactorPOA = 3; % ONLY USED IN POA (TO BE REMOVED?)

skipAOAplots = false; 
% NB: "makePlotsAllAOT" in SAP_parameters must ALSO authorize plot
skipPOAplots = false;

%%% Common Plot parameters for tensor maps
% NOT relevant for PTE:   
PLOT.makeItFull = false;            % only applies when processing HALF notums (2.3)
PLOT.refBoxSizeMicron = [1 1]*90; % reference box size IN MICRON AND COMMON TO each animal processed in SAP 
PLOT.refScale1D = 0.322;            % Value to mimic the reference scale to keep using the same scale factors than in SAP
% PLOT.boxSize = [1 1] .* 128;        % generic box size in pixels
PLOT.significance = false;           % grey non significant values in plots
PLOT.SignOpacityMap = [0.4 0.4];    % significance opacity [iso dev]
PLOT.resolution = 150;              % plot resolution
PLOT.fontSizeInfo = 15;             % font size to display info on maps (4.2)
PLOT.displayOrigin = true;          % 2.6
PLOT.drawMidline = true;            % 2.3
PLOT.macroSize = 100;                % size of macrocaetes


% ALSO for PTE:
PLOT.imageFormatOutput = 'png';     % plot image type (png | svg). For PTE, pdf also works


%% DBA Parameters %%

% This process calculate the difference between two averaged animals.
% Each average animals is an output of a Process (AOA, DBA, COQ, other)
% Both averaged animals outputs MUST BE COMING from the same program (AOA or DOA, no mixing)
% As this is a simple A - B substraction, both individual must have the same spatial and temporal size, with same overlap

% NB: single animal do NOT work because one must build a COMMON grid before subtraction => to perform the difference between a quantity Q
% from 2 single animals (Qa1-Qa2), one HAS TO first "average" each of them through AOA in order to build a grid COMMON to BOTH animals.

% Animal #1 minus Animal #2: the name of the output animal will be "A1-A2"
deltaAnimals  =  { 'KO' ; 'WT'};

%% POA Parameters %%

OnameProjection = 'DBA'; % name of output to be projected ('AOA' or 'DBA') for current "mapAnimal" (AOA) or current "deltaAnimals" (DBA, actually "DBAname")

% Definition of unitary tensor for projection:
uAnimal = 'WT';
% uAnimal = mapAnimal;

uTimeWidth = 10;
% uTimeWidth = 20;

uTimeOverlap = 0;
uOname = 'AOA';
uQname = 'EG';

% REF:
% uAnimal = 'BIGwt2';
% uTimeWidth = 20;
% uTimeOverlap = 0;
% uOname = 'AOA';
% uQname = 'EG';


%% PTE %%

QplotOrigin = 'DBA';        % origin of the quantities to plot: "AOA" or "DBA"
QplotType = 'cum';         % "inst" or "cum" for cumulative
QplotRenorm = 'raw';        % "raw" or "renorm" (all curves datapoints have their absolute max reset to 1 and become dimensionless)  

%%% Enter any quantity listed in "allQs" of "AllQsColorsUnits.m" file:
QnamePTE = {'EG' 'ES' 'ER'};
% QnamePTE = {'UPIV'};
% QnamePTE = {'UPIV' 'EpsilonPIV' 'OmegaPIV'};
%--------------------------------------------------------------------------
% NB: for VM quantities, must add 'PIV' or 'CT'. Ex: U-> UPIV,...
%--------------------------------------------------------------------------

%%% Enter component ('xx','yy','xy','yx') or unitary tensor ('u0','u1','u3','uPar','uOrt') you want to project on:
Qtags = {'uPar'};
% Qtags = {'u0','u1','u3','uPar','uOrt','xx','xy','yy'};
%--------------------------------------------------------------------------
% NB: to determine 'uPar' and 'uOrt', parameters defined in POA section
% will be used to load corresponding animal backup.
% NB: scalar quantities listed in "QnamePTE" will just NOT be projected
%--------------------------------------------------------------------------

%%% Max values
%--------------------------------------------------------------------------
% NB: ONLY relevant when "QplotRenorm = 'renorm'".
% - if empty, will use each quantity max value.
% - if one value, will be used for all.
% - if NaN, will use max value for corresponding quantity.
%--------------------------------------------------------------------------
rateMax = 0.02;
rateDiv = NaN;
Umax = 7;

QmaxValues = {}; 
% QmaxValues = {Umax}; 
% QnamePTE = {'EG';'Epsilon';'ES';'ER';'ED';'EA';'U'};  % INST
% QmaxValues = {rateMax; rateMax; rateMax; rateMax; rateMax; rateMax; Umax}; 

% QDevRenorm = {'I';'CellIaniso'};     
% QDevMaxValues = {0.92; 0.56};         % specific max values to apply to dev parts renormalized by Qo
QDevRenorm = {'I';'S';'CellIaniso'};    
QDevMaxValues = {0.86; 0.57; 0.45};         % specific max values to apply to dev parts renormalized by Qo
% QDevMaxValues = {2.2; 1.7; 0.56};         % specific max values to apply to dev parts renormalized by Qo
%--------------------------------------------------------------------------
% NB: when NOT plotting projection of Q on u0, instead of raw Q, will plot
% QDEV/Qo = (eta - Id). For POSITIVE DEFINITE quantities (Qo = (detQ)^1/2
% is always defined: Qiso~Qo*Id and Qdev~Qo*(eta - Id))
% NB: for scalar quantities, will do nothing except from excluding them
% from "cum" option if "QplotType" = 'cum'.
%--------------------------------------------------------------------------


% range of zone to analyse over time, box COORDINATES XYs centered on animal origin
% NB: COORDINATE [0 0] corresponds to box having the animal origin at its ULC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Qboxes = {[xMin yMin xMax yMax]};    % for defining a rectangle area
% Qboxes = {[x y];[x y]; ... ;[x y]};  % for defining a list of boxes
% Qboxes = 'full';                     % for analysing the entire grid
% Qboxes = [];                         % for starting the GUI
% Qboxes = {[0 0]};                    % [0 0] corresponds to box containing the origin 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Qboxes = [];    % for defining a rectangle area
path2BackgroundMap = '';
% path2BackgroundMap = 'path\to\pdm3\pdm3.MAP\AOA_pdm3s_18h_0olap\AOA_split+\AOA_UPIV_14h06to31h58_sr=50.png';
% path2BackgroundMap = 'path\to\MAP\AOA_whiteRNAis_18h_0olap\AOA_split+\AOA_UPIV_14h08to32h01_sr=50.png';
% path2BackgroundMap = 'D:\BigMovies\BIGs.MAP\AOA_BIGs_18h_0olap\AOA_split+\AOA_UPIV_14h05to32h00_sr=50.png';
% Qboxes = {'full'};    % for defining a rectangle area
% Qboxes = {[2 0 5 1]};    % for defining a rectangle area

% Axis range, leave empty for automatic range selection, otherwise like this: {[400 410]}
Qrange = {};
% Qrange = {[-0.06 0.14]};


%% MAP execution (4.2) %%

MAP


%% History %%

% 04/10/2024: (Boris & Mehdi)
% - added parameters, AOAvalidityThreshold, QnameFilter,
% scaleRatioFactorDBA, scaleRatioFactorPOA

% 02/07/2019: 4.3 (Boris)
% - LocalTimeAnalysis (LTA) became PlotTimeEvolution (PTE)

% 28/06/2018: 4.2 (Boris)
% - extracted "MAP" part into separate script
% - definition of "fontSizeInfo" in structure PLOT now

% 27/06/2018: 4.1 (Boris)
% - fixing RA execution after Stephane update

% 24/05/2018: 4.0 (Stephane)
% - major update to make AOA, POA and LTA work again

% 24/04/2018: 3.0 became "MAP_parameters" (Boris)
% - included execution of "RescaleAnimals" v4.0 that now integrates
% "CreateArchetype".
