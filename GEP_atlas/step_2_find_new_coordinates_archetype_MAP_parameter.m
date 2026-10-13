% MAP_parameters
%
% Defines the set of animals to analyze as well as parameters specific to
% this multi-animal analysis to run "MAP".
% Parameters specific to single animals must be set in "parametersSAP".
%
% Version = 4.3;
% Stephane Rigaud
% Boris Guirao

clear; close all; clc;  % Cleaning of workspace (DO NOT MODIFY)

resol=40; 
gridOverlap = 0.5;
val_plot_refBoxSizeMicron = [resol resol];

main_path = '/path/to/data/GEPs/24hAPF/results/'

path_SAP_to_use = {'/path/to/data/GEPs/24hAPF/SAP_infos/protein/resol40um/',... 
                   '/path/to/data/GEPs/24hAPF/SAP_infos/validation_fish/resol40um/',...
                   '/path/to/data/GEPs/24hAPF/SAP_infos/validation_protein/resol40um/'}
                       
path_data = {'/path/to/data/GEPs/24hAPF/data/protein/',...
             '/path/to/data/GEPs/24hAPF/data/validation_fish/',...
             '/path/to/data/GEPs/24hAPF/data/validation_protein/'}
         
for p = 1:length(path_SAP_to_use)
    addpath(path_SAP_to_use{p});
end

parentRescaledAnimalsFolder = main_path;
%folder output: pour AOA
PathName = [parentRescaledAnimalsFolder,'AOA_',num2str(resol),'um_olap',num2str(gridOverlap)];

list_genes = {};

for idx = 1:length(path_SAP_to_use)
    current_path = path_SAP_to_use{idx};
    listdir = struct2table(dir(current_path));
    listdir(ismember(listdir.name, {'.', '..', '.DS_Store'}), :) = [];
    current_genes = cellfun(@(x) {x(length('SAP_info_') + 1:end - 2)}, listdir.name);
    
    % exclude files that do not have the right number of macrocheats
    t_nmacro     = MacrocheatClicked(path_data{idx});
    current_genes   = t_nmacro.gene(t_nmacro.nmacro>=4,:);
    
    list_genes = [list_genes; current_genes]; % Append genes from current path 
    
end

%list_genes = list_genes(~ismember(list_genes,'frm_s3l'),:)




rescaleName = 'Gene_40um_'; % prefix that will appear before "rescaled_..." in folder name
  
%--------------------------------------------------------------------------
avgAnimals = sort(list_genes);
mapAnimal  = 'default';
allAnimals = avgAnimals;

fprintf('************* COMPUTE AVERAGE : %d NOTUMS**************',length(avgAnimals))
sprintf('%s',cell2mat(avgAnimals'))
fprintf('\n********************************************\n')

%--------------------------------------------------------------------------
%% Operation Name (Oname) Selection / PROGRAMS TO RUN %%
% PRE-segmentation
RA = 1;                % "RescaleAnimals"

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

rescaleMode = 'Rescale';       % enter "Archetype" to CREATE archetype OR "Rescale" to use existing archetype for RESCALING
clickTimeAll = '24h00';        % time at which landmarks were clicked IN ALL MOVIES

nMacroMin = 4;                 % MIN number of macrochaetes AVAILABLE (ON EACH SIDE OF ANIMAL if halfNotum = 'b') in all animals to process (USED TO CALCULATE BARYCENTERS)

%%% Archetype related:
parentArchetypeFolder = '/path/to/data/Movies/Archetypes/';
archetypeName = 'Gene_';                                          % prefix that will appear before "archetype_..." in folder name

makeSVG = false;


%% Quantities to be PLOTTED and PROJECTED

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Qname = {'ER';'ES';'EG';'EA';'ED';'Epsilon';'S';'I';'U'};
% Qname = {'ER';'ES';'EG';'EA';'ED';'Epsilon';'S';'I';'U'};
%  Qname = {'dnD';'dnA';'nCoreRNs'};
% Qname = {'UPIV'};
% % Qname = {'OmegaPIV'};
%Qname = {'UPIV' ; 'EpsilonPIV' ; 'OmegaPIV'};
% Qname = {'U' ; 'Epsilon' ; 'Omega'};
Qname = {'ER';'ES';'EG';'EA';'ED';'dnD';'dnA';'AvgCellArea';'AvgCellIaniso'};
% NB: ALL quantities are CALCULATED anyway in AOA, DBA, *BUT* in POA, ONLY those listed here will be calculated and plotted in POA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tagProjPlot = {'d'}; % Plot projected quantities with corresponding 'i','d','do' tags (e.g. EGdotEG_d)
scaleRatioFactor = 0.15;

skipAOAplots = false;
% NB: "makePlotsAllAOT" in SAP_parameters must ALSO authorize plot
skipPOAplots = true;

%%% Common Plot parameters for tensor maps
% NOT relevant for PTE:
PLOT.makeItFull = true;            % only applies when processing HALF notums (2.3)
%je feini ce parametre plus haut pour ne pas l'oublier
PLOT.refBoxSizeMicron = val_plot_refBoxSizeMicron%[1 1]*20.6; % reference box size IN MICRON AND COMMON TO each animal processed in SAP
PLOT.refScale1D = 0.322;            % Value to mimic the reference scale to keep using the same scale factors than in SAP
% PLOT.boxSize = [1 1] .* 128;        % generic box size in pixels
PLOT.significance = true;           % grey non significant values in plots
PLOT.SignOpacityMap = [0.5 0.5];    % significance opacity [iso dev]
PLOT.resolution = 200;              % plot resolution
PLOT.fontSizeInfo = 15;             % font size to display info on maps (4.2)
PLOT.displayOrigin = true;          % 2.6
PLOT.drawMidline = true;            % 2.3
PLOT.macroSize = 50;                % size of macrocaetes

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
deltaAnimals  = { 'whiteRNAis' ; 'pdm3s'};
% deltaAnimals  = { 'meanWT_grid26h' ; 'meanWT_grid26h'};


%% POA Parameters %%

% uAnimal = mapAnimal;
% uAnimal = 'WTmfX';
uTimeWidth = 18;
% uTimeWidth = 20;
uAnimal = 'BIGs';
% uAnimal = 'whiteX';
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

QplotOrigin = 'AOA';        % origin of the quantities to plot: "AOA" or "DBA"
QplotType = 'inst';         % "inst" or "cum" for cumulative
QplotRenorm = 'raw';        % "raw" or "renorm": all curves datapoints have their absolute max reset to 1 and become dimensionless

%%% Enter any quantity listed in "allQs" of "AllQsColorsUnits.m" file:
% QnamePTE = {'UPIV'};
QnamePTE = {'UPIV' 'EpsilonPIV' 'OmegaPIV'};
%--------------------------------------------------------------------------
% NB: for VM quantities, must add 'PIV' or 'CT'. Ex: U-> UPIV,...
%--------------------------------------------------------------------------

%%% Enter component ('xx','yy','xy','yx') or unitary tensor ('u0','u1','u3','uPar','uOrt') you want to project on:
Qtags = {'xx','yy'};
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
path2BackgroundMap = '';%'path\to\pdm3\pdm3.MAP\AOA_pdm3s_18h_0olap\AOA_split+\AOA_UPIV_14h06to31h58_sr=50.png';
%path2BackgroundMap = 'path\to\MAP\AOA_whiteRNAis_18h_0olap\AOA_split+\AOA_UPIV_14h08to32h01_sr=50.png';
% path2BackgroundMap = 'D:\BigMovies\BIGs.MAP\AOA_BIGs_18h_0olap\AOA_split+\AOA_UPIV_14h05to32h00_sr=50.png';
% Qboxes = {'full'};    % for defining a rectangle area
% Qboxes = {[2 0 5 1]};    % for defining a rectangle area

% Axis range, leave empty for automatic range selection, otherwise like this: {[400 410]}
Qrange = {};
% Qrange = {[-0.06 0.14]};


%% MAP execution (4.2) %%

MAP



%% compte macrocheat
function t_nmacro = MacrocheatClicked(root_path)

listdir   =struct2table(dir(root_path)); % list directory from

listdir(ismember(listdir.name,{'.';'..'}),:) =[]; % remove first 2 rows
listdir(listdir.isdir~=1,:) =[];

height(listdir);

for f = 1:height(listdir)
    disp(f)
    disp(listdir.name{f})
    
    my_file =  [root_path,listdir.name{f},'/SAP_',listdir.name{f},'/spaceReg_',listdir.name{f},'_1/Macro_XYs_',listdir.name{f},'.txt'];
    
    isfile(my_file)
    if isfile(my_file) % if I have a SAP_info
        M            = importdata(my_file);
        if length(M)>0
        ix           = isnan(M(:,1));
        nmacro(f,1)  = length(M);
        if(find(ix))
            nmacro(f,1)  = min(find(ix))-1;
        end
        namegene(f,1)= listdir.name(f);
        end
    else % no SAP_info
        namegene(f,1)=listdir.name(f);
        nmacro(f,1)=0;
    end
end

t_nmacro = table(namegene,nmacro);
t_nmacro.Properties.VariableNames = {'gene','nmacro'};

end


