
%% Bridge_Pipeline_ONEAT_csv_creation.m %%


% Creation of CSV files for ONEAT to evaluate MATLAB predictions (Apoptose and Divisions).
% Lucas Sancéré


%% Select Animal if  %%

%Animal = 'wt_mov8_DLcorr';

%% Load informations in SAP_info and CPT

MAPcall = true;
eval(['SAP_info_' Animal ';']);
number_of_frame = finalFrame;

load([pathFolderCTD filesep 'allDelaminatingCells.mat']);
load([pathFolderCTD filesep 'allDividingCells.mat']);

%% Creation of csv for bridge

%Table.mat for delaminations

Coordinates_Delaminations = round(allDelaminatingLastXYs);
T_Y_X_table_Del = zeros(length(allDelaminatingLastXYs),3);
T_Y_X_table_Del(:,1) = allLastFramesDel;  % allLastFramesDel comes from allDelaminatingCells.mat from CTD
T_Y_X_table_Del(:,2) =  Coordinates_Delaminations(:,2);
T_Y_X_table_Del(:,3) =  Coordinates_Delaminations(:,1);


%Table.mat for divisions

Coordinates_Divisions = round(allDividingLastXYs);
T_Y_X_table_Div =  zeros(length(allDividingLastXYs),3);
T_Y_X_table_Div(:,1) = allLastFramesDiv;  %  allLastFramesDiv comes from allDividingCells.mat from CTD
T_Y_X_table_Div(:,2) = Coordinates_Divisions(:,2);
T_Y_X_table_Div(:,3) = Coordinates_Divisions(:,1);




%% Conversion of files and saving

% Creation of Folders

 pathCPT_ONEAT_Input = [gridFolderCPT filesep 'ONEAT_Input'];
 mkdir(pathCPT_ONEAT_Input)
 
 gridFolderONEAT_Input = [pathCPT_ONEAT_Input filesep];
 pathCPT_ONEAT_Input_Del = [gridFolderONEAT_Input filesep 'Delaminations_Coordinates_TYX'];
 mkdir(pathCPT_ONEAT_Input_Del)
 pathCPT_ONEAT_Input_Div = [gridFolderONEAT_Input filesep 'Divisions_Coordinates_TYX'];
 mkdir(pathCPT_ONEAT_Input_Div)

 
% Save files into this folders

 save([pathCPT_ONEAT_Input_Del filesep Animal '_Delaminations_Coordinates_TYX.mat'], 'T_Y_X_table_Del');
 save([pathCPT_ONEAT_Input_Div filesep Animal '_Divisions_Coordinates_TYX.mat'], 'T_Y_X_table_Div');
 

% Convert into csv files 

 T_Y_X_csv_Del = load([pathCPT_ONEAT_Input_Del filesep Animal '_Delaminations_Coordinates_TYX.mat']);
 csvwrite( 'Delaminations_Coordinates_TYX.csv', T_Y_X_csv_Del.T_Y_X_table_Del);
 
 T_Y_X_csv_Div = load([pathCPT_ONEAT_Input_Div filesep Animal '_Divisions_Coordinates_TYX.mat']);
 csvwrite( 'Divisions_Coordinates_TYX.csv', T_Y_X_csv_Div.T_Y_X_table_Div);

%% History

%10/09/2020: 1.0 (Lucas)
% -Creation


