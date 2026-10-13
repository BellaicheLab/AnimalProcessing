% MAP_parameters
%
% Defines the set of animals to analyze as well as parameters specific to
% this multi-animal analysis to run "MAP".
% Parameters specific to single animals must be set in "parametersSAP".
%
% Version = 4.3;
% Stephane Rigaud
% Boris Guirao

% pour executer ce code, il faut creer manuellement une table 'list_name' contenant la
% liste des images a traiter ('long') et les moyenner ensemble ('short')

%restoredefaultpath
clear all; close all; clc;  % Cleaning of workspace (DO NOT MODIFY)
%% ANIMALS TO INCLUDE %%
resol=40;gridOverlap = 0.5;timing='17hAPF'

%Paths definition
%Animal processing framework

%Path where I'll be doing the bulk of the analysis
main_path = '/path/to/data/GEPs/';

% adding the path to the SAP parameters
addpath('/path/to/data/GEPs/scripts/SAP_parameters.m')

%% Movies
% Movies wt - Toll8RNAi - vRNAi
path_SAP_movies = '/path/to/data/Movies/movies_v_Tollo/SAP_infos/';

%% 17hAPF

% Path to SAP_infos
path_SAP_protein_17hAPF  = fullfile(main_path, "17hAPF", "SAP_infos", 'protein', strcat("resol",num2str(resol),'um/'));
% FISH wt
path_SAP_fish_17hAPF     = fullfile(main_path, "17hAPF", "SAP_infos", 'fish', strcat("resol",num2str(resol),'um/'));
% FISH Validation Toll8RNAi vs vRNAi
path_SAP_fishRNAi_17hAPF = fullfile(main_path, "17hAPF", "SAP_infos", 'fish_RNAi', strcat("resol",num2str(resol),'um/'));


list_name_fish_RNAi_17hAPF = update_list_name(path_SAP_fishRNAi_17hAPF, false, 'RNA', 'new');
list_name_fish_17hAPF = update_list_name(path_SAP_fish_17hAPF, false, 'RNA', 'old', 2);
list_name_protein_17hAPF = update_list_name(path_SAP_protein_17hAPF, false, 'protein');

list_name_17hAPF = vertcat(list_name_fish_RNAi_17hAPF, list_name_fish_17hAPF, list_name_protein_17hAPF);

%% 24hAPF

path_SAP_protein_24hAPF = fullfile(main_path, "24hAPF", "SAP_infos", "protein", strcat("resol",num2str(resol),'um/'));
path_SAP_validation_fish_24hAPF = fullfile(main_path, "24hAPF", "SAP_infos", "validation_fish", strcat("resol",num2str(resol),'um/'));
path_SAP_validation_protein_24hAPF = fullfile(main_path, "24hAPF", "SAP_infos", "validation_protein", strcat("resol",num2str(resol),'um/'));
path_SAP_validation_protein_25hAPF_badly_named = fullfile(main_path, "24hAPF", "SAP_infos", "validation_protein", strcat("resol",num2str(resol),'um'), "badly_named");

list_name_protein_24hAPF = update_list_name(path_SAP_protein_24hAPF, true, 'protein', 'old', 2);
list_name_validation_fish_24hAPF = update_list_name(path_SAP_validation_fish_24hAPF, true, 'RNA', 'old', 2);
list_name_validation_protein_24hAPF = update_list_name(path_SAP_validation_protein_24hAPF, true, 'protein', 'old', 3);


list_name_24hAPF = vertcat(list_name_protein_24hAPF, list_name_validation_fish_24hAPF, list_name_validation_protein_24hAPF);

%% output

% Output Path of the analysis
PathName = fullfile(main_path,'17hAPF','results', strcat('AOA_',num2str(resol),'um_olap',num2str(gridOverlap),'/'));

% Setting paths 

% Loading the SAP parameters of each file
addpath(genpath(path_SAP_movies));

addpath(genpath(path_SAP_fish_17hAPF));
addpath(genpath(path_SAP_protein_17hAPF));
addpath(genpath(path_SAP_fishRNAi_17hAPF));

addpath(genpath(path_SAP_protein_24hAPF));
addpath(genpath(path_SAP_validation_fish_24hAPF));
addpath(genpath(path_SAP_validation_protein_24hAPF));

val_plot_refBoxSizeMicron = [resol resol];

% Listing the files for each image / movie

% Movies
listdir = struct2table(dir(path_SAP_movies));
acceptableNames = {'SAP_info_19XXXX_wt_pupa10.m' , 'SAP_info_210507_vi_pupa2.m' , 'SAP_info_210818_Tolloi_pupa2.m' ,...
                   'SAP_info_19XXXX_wt_pupa13.m' , 'SAP_info_210507_vi_pupa3.m' , ...
                   'SAP_info_19XXXX_wt_pupa9.m' , ...
                   'SAP_info_210409_vi_pupa1.m' , 'SAP_info_210823_Tolloi_pupa2.m' ,...
                   'SAP_info_210409_vi_pupa2.m' , 'SAP_info_210603_Tolloi_pupa1.m' , 'SAP_info_210823_vi_pupa1.m' ,...
                   'SAP_info_210428_vi_pupa1.m' , 'SAP_info_210603_Tolloi_pupa3.m' ,...
                   'SAP_info_210604_Tolloi_pupa6.m' ,...
                   'SAP_info_220218_vi_pupa3.m' ,...
                   'SAP_info_210507_vi_pupa1.m' , 'SAP_info_220902_vi_pupa1.m'}; % Add the actual names or patterns you're looking for
               
listdir = listdir(ismember(listdir.name, acceptableNames), :);
list_movies = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

% Images 17hAPF
listdir        = struct2table(dir(path_SAP_fish_17hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'; 'SAP_parameters.m'}),:) =[];
list_fish_17hAPF      = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

listdir        = struct2table(dir(path_SAP_protein_17hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'}),:) =[]; 
list_protein_17hAPF   = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

listdir        = struct2table(dir(path_SAP_fishRNAi_17hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'}),:) =[]; 
list_fishRNAi_17hAPF   = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

% Images 24hAPF
listdir        = struct2table(dir(path_SAP_protein_24hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'; 'SAP_parameters.m'}),:) =[]; 
list_protein_24hAPF   = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

listdir        = struct2table(dir(path_SAP_validation_fish_24hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'; 'SAP_parameters.m'}),:) =[]; 
list_validation_fish_24hAPF   = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

listdir        = struct2table(dir(path_SAP_validation_protein_24hAPF));
listdir(ismember(listdir.name,{'.';'..';'.DS_Store'; 'SAP_parameters.m'}),:) =[]; 
list_validation_protein_24hAPF   = cellfun(@(x){x(length('SAP_info_')+1:end-2)}, listdir.name);

% Generating union of everyting
% NB: list_for_common = allAnimals; MAP evalc's allAnimals{1} to set the AOT
% time window. The 24hAPF animals (e.g. 141029_..._24apf, which sorts first)
% carry timeRef='24h00' and would force noAverage_24h00 on the whole 17hAPF run.
% So only union the 24hAPF set for a 24hAPF build.
list_for_common = union(list_fish_17hAPF,list_protein_17hAPF);
list_for_common = union(list_for_common, list_fishRNAi_17hAPF);
if strcmp(timing,'24hAPF')
    list_for_common = union(list_for_common, list_protein_24hAPF);
    list_for_common = union(list_for_common, list_validation_fish_24hAPF);
    list_for_common = union(list_for_common, list_validation_protein_24hAPF);
end
list_for_common = union(list_for_common, list_movies);

%-----------
% Exclusion of "bad" Notums

% 17hAPF 
% Excluded: first QC selection
% Proteins wt
list_to_excl_1 = {'190830_QSox2_15APF_s4l','190904_nw_15APF_s1l','190904_nw_15APF_s1r',...
                'Dpp_190821_15apf_s1r','Dpp_190821_15apf_s2l','Dpp_190821_15apf_s2r',...
                'Dpp_190821_15apf_s3r','Dpp_190920_15APF_s4r','hbs_191204_15APF_s3r',...
                'robo_191120_15APF_s1l','robo_191120_15APF_s1r','robo_191120_15APF_s4r',...
                'robo_191218_15APF_s2r','slit_191122_15APF_s1r','slit_191206_15APF_s1r',...
                'slit_191206_15APF_s1l',... % data dir deleted (stale SAP_info); siblings s1r/s2l already excluded
                'slit_191206_15APF_s2l','slow_191204_15APF_s2r',...
                'Tollo_190920_15APF_s1l','Wnt6_191031_15APF_s3r','en_191114_s2l',...
                '18w_190909_15APF_s1l','C15_200115_15APF_s4r','C15_200115_15APF_s5r',...
                '200607_Pvr_15APF_s4r','200607_Pvr_15APF_s4l','200531_Pvr_15APF_s1l',...
                '200607_Pvr_15APF_s3l', '200531_Pvr_15APF_s2r',...
                 '200607_crp_15APF_s2r','200607_crp_15APF_s4l',...
                '200604_Pdm3_15APF_s1r','200604_Pdm3_15APF_s2r','200604_Pdm3_15APF_s3l'};
            
% Excluded: second QC selection,
% after seeing the effects of
% saturation (we perecentiled noramlized by the minimum common region
% accross all notum and >1 becomes 1)
list_to_excl_2 = {'220922_d2__ActTolloi_96h_cda4__p1r', '220922_d2__ActTolloi_96h_cda4__p1r', '221024__ActTolloi_96h_frm__p1r', ...
                    '221024__ActTolloi_96h_frm__p4r', '220905__ActTolloi_96h_hid__p3l', '220905__ActTolloi_96h_hid__p3r', ...
                    '220905__ActTolloi_96h_hid__p9r', '220905__Actvi_96h_hid__p3r', '220905__Actvi_96h_hid__p5l', ...
                    '220922_d2__ActTolloi_96h_cda4__p1l', '220922_d2__ActTolloi_96h_cda4__p1r', '220913__Actvi_96h_kek5__p2l', ...
                    '220913__Actvi_96h_kek5__p4l', '220913__Actvi_96h_kek5__p5l', '220913__Actvi_96h_kek5__p7l', ...
                    'Tollo_191023_15APF_s1l', 'Tollo_191023_15APF_s1r', 'h_151105_4r', ...
                    'hbs_191204_15APF_s3l', '190904_nw_15APF_s2l', 'salm_160622_2l', ...
                    'salm_160622_1l'
                    };
                
% Excluded: failed rescaling
list_to_excl_3 = {'Dpp_190821_15apf_s1l', '220922_d1__ActTolloi_96h_cda4__p4r',...
                '220922_d1__Actvi_96h_cda4__p4l',...
                '220922_d1__ActTolloi_96h_cda4__p4l',...
                '220516__Actvi_96hr_puc__p1r',...
                '220913__ActTolloi_96h_kek5__p3l',...
                '220913__ActTolloi_96h_kek5__p3r',...
                '220510__Actvi_48h_puc__p3r',...
                '220516__Actvi_96h_puc__p1r'};

list_to_excl_17hAPF = union(list_to_excl_1, list_to_excl_2);
list_to_excl_17hAPF = union(list_to_excl_17hAPF, list_to_excl_3);

list_for_common  = list_for_common(~ismember(list_for_common,list_to_excl_17hAPF));

%24hAPF

            

%list_for_common
% Removal of somme gene names
list_for_common(contains(list_for_common,'nls'),:)=[];
list_for_common(contains(list_for_common,'neg_control'),:)=[];
list_for_common(contains(list_for_common,'Mnt'),:)=[];
list_for_common(contains(list_for_common,'Ds'),:)=[];
list_for_common(contains(list_for_common,'emc'),:)=[];
list_for_common(contains(list_for_common,'msn'),:)=[];
list_for_common(contains(list_for_common,'yrt'),:)=[];


% Taking the intersection of the list of names and the list of files
list_name_17hAPF = list_name_17hAPF(ismember(list_name_17hAPF.long,list_for_common),:);
list_name_24hAPF = list_name_24hAPF(ismember(list_name_24hAPF.long, list_for_common),:);

% Each gene is the unique of the short list
if strcmp(timing,"17hAPF")
    list_genes_short = unique(list_name_17hAPF.short);
elseif strcmp(timing,"24hAPF")
    list_genes_short = unique(list_name_24hAPF.short);   
end

% GEP atlas: keep the existing (protein + 'old' fish) genes, plus only the 9 new
% control FISH genes (Actvi, 96h). Excludes the Tollo-RNAi perturbation, the 48h
% duplicates, and new FISH of genes already in the atlas (hid/rpr/Tollo).
new_atlas_shorts = {'Actvi_96h_CG10175_RNA','Actvi_96h_Kay_RNA','Actvi_96h_cda4_RNA',...
    'Actvi_96h_daw_RNA','Actvi_96h_espl_RNA','Actvi_96h_frm_RNA','Actvi_96h_kek5_RNA',...
    'Actvi_96h_slf_RNA','Actvi_96h_puc_RNA'};
is_fishRNAi = startsWith(list_genes_short,'Actvi_') | startsWith(list_genes_short,'ActTolloi');
list_genes_short = list_genes_short(~is_fishRNAi | ismember(list_genes_short, new_atlas_shorts));

for iname = 1:length(list_genes_short)
    clearvars -except f list_name_17hAPF list_name_24hAPF timing main_path list_wt gridOverlap igrid path* list_name list_name_fish_RNAi list_genes_short iname list_for_common path_data PathName parentRescaledAnimalsFolder val_plot_refBoxSizeMicron list_RNAi
    %--------------------------------------------------------------------------
    
    if strcmp(timing,"17hAPF")
        avgAnimals = sort((list_name_17hAPF.long(ismember(list_name_17hAPF.short,list_genes_short{iname}))));
    elseif strcmp(timing,"24hAPF")
        avgAnimals = sort((list_name_24hAPF.long(ismember(list_name_24hAPF.short,list_genes_short{iname}))));
    end
    
    %avgAnimals = sort(list_wt);
    mapAnimal  = list_genes_short{iname};
    %mapAnimal  = 'wt';
    
    allAnimals = sort(list_for_common);
    %allAnimals = avgAnimals
    %parentRescaledAnimalsFolder = [main_path,'SAPfish_RNAi/data_rescaled/'];

    fprintf('************* COMPUTE AVERAGE : %d NOTUMS**************',length(avgAnimals))
    sprintf('%s',cell2mat(avgAnimals'))
    fprintf('\n********************************************\n')
  
    %--------------------------------------------------------------------------
    %% Operation Name (Oname) Selection / PROGRAMS TO RUN %%
    % PRE-segmentation
    RA = 0;                % "RescaleAnimals"
    
    % POST-segmentation
    AOA = 1;               % "AverageOverAnimals"
    DBA = 0;               % "DifferenceBetwenArchetypes"
    POA = 0;               % "ProjectionOverAnimals"
    PTE = 0;               % "PlotTimeEvolution"
    
    % NOT updated
    % COQ = 0;               % "CalculOverQuantities"
    % CCF = 1;              % Cross-Correlation Function
    % TC  = 0;               % Tensor Corelator (in progress)
    
    
    %% RA - RescaleAnimals (3.0)%%
    
    rescaleMode = 'Rescale';       % enter "Archetype" to CREATE archetype OR "Rescale" to use existing archetype for RESCALING
    %clickTimeAll = '17h00';        % time at which landmarks were clicked IN ALL MOVIES
    clickTimeAll = '17h00';        % time at which landmarks were clicked IN ALL MOVIES
    
    nMacroMin = 4;                 % MIN number of macrochaetes AVAILABLE (ON EACH SIDE OF ANIMAL if halfNotum = 'b') in all animals to process (USED TO CALCULATE BARYCENTERS)
    
    %%% Archetype related:
    parentArchetypeFolder = 'Archetypes/';
    archetypeName = 'Gene_';                                          % prefix that will appear before "archetype_..." in folder name
    
    makeSVG = false;
    
    %rescaleName = 'Gene_'
    
    
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

    % AOA validity filter (added to AverageOverAnimals ~2024-11; absent from the
    % original GEP config). No-op for the GEP atlas since we average the Gene
    % field, not these morphodynamic tensors. Reference defaults (MAP_parameters_reference.m).
    AOAvalidityThreshold = 0.1;
    QnameFilter = {'ER';'ES';'EG';'EA';'ED';'EF';'EN';'EJ'};
    
    tagProjPlot = {'d'}; % Plot projected quantities with corresponding 'i','d','do' tags (e.g. EGdotEG_d)
    scaleRatioFactor = 0.15;
    
    skipAOAplots = true;
    % NB: "makePlotsAllAOT" in SAP_parameters must ALSO authorize plot
    skipPOAplots = true;
    
    %%% Common Plot parameters for tensor maps
    % NOT relevant for PTE:
    PLOT.makeItFull = false;            % only applies when processing HALF notums (2.3)
    %je feini ce parametre plus haut pour ne pas l'oublier
    PLOT.refBoxSizeMicron = val_plot_refBoxSizeMicron;%[1 1]*20.6; % reference box size IN MICRON AND COMMON TO each animal processed in SAP
    PLOT.refScale1D = 0.322;            % Value to mimic the reference scale to keep using the same scale factors than in SAP
    % PLOT.boxSize = [1 1] .* 128;        % generic box size in pixels
    PLOT.significance = true;           % grey non significant values in plots
    PLOT.SignOpacityMap = [0.5 0.5];    % significance opacity [iso dev]
    PLOT.resolution = 200;              % plot resolution
    PLOT.fontSizeInfo = 15;             % font size to display info on maps (4.2)
    PLOT.displayOrigin = true;          % 2.6
    PLOT.drawMidline = true;      
    
    % 2.3
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
    QnamePTE = {'dnD'};
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
    rateMax = 0.02;%''
    rateDiv = NaN;
    Umax = 7;
    
    QmaxValues = {};
    % QmaxValues = {Umax};
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
    
    Qboxes = 'full';    % for defining a rectangle area
    path2BackgroundMap ='/path/to/data/15APF/Processing17h00/MoviesRescaled/AOA_40um/AOA_wt_2h_0.96olap/AOA_split+_full/AOA_dnD_15h48to17h51_full_sr=5.png';
    % path2BackgroundMap = 'path\to\pdm3\pdm3.MAP\AOA_pdm3s_18h_0olap\AOA_split+\AOA_UPIV_14h06to31h58_sr=50.png';
    %path2BackgroundMap = 'path\to\MAP\AOA_whiteRNAis_18h_0olap\AOA_split+\AOA_UPIV_14h08to32h01_sr=50.png';
    % path2BackgroundMap = 'D:\BigMovies\BIGs.MAP\AOA_BIGs_18h_0olap\AOA_split+\AOA_UPIV_14h05to32h00_sr=50.png';
    % Qboxes = {'full'};    % for defining a rectangle area
    % Qboxes = {[2 0 5 1]};    % for defining a rectangle area
    
    % Axis range, leave empty for automatic range selection, otherwise like this: {[400 410]}
    Qrange = {};
    % Qrange = {[-0.06 0.14]};
    
    % pathPipeline: folder of the compiled executables
    pathPipeline = "";
    
    
    %% MAP execution (4.2) %%
    
    MAP
    list_notum =['mean_notum',avgAnimals'];
   
    save([PathName,'AOA_',mapAnimal,'_0h_0olap/name_notum'],'list_notum','mapAnimal')
    % writematrix is R2019a+; kept R2018b-compatible. Write the animal-name list with fprintf.
    fid_ln = fopen([PathName,'AOA_',mapAnimal,'_0h_0olap/','list_notum.csv'],'w');
    fprintf(fid_ln, '%s\n', avgAnimals{:});
    fclose(fid_ln);
end

   