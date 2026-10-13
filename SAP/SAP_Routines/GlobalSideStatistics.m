function Mout = GlobalSideStatistics(Min, sideCategory, sideCategoryName, sideSTATISTICS, n, iterationIndex, filenameRawMod)
%
% Mout = GlobalSideStatistics(Min, sideCategory, sideCategoryName, sideSTATISTICS, n, iterationIndex, filenameRawMod)
%
% Adds one line to M_in with global statistics corresponding to frame n
% making up the "iteration_index"th row.
%
% Version 1.4
% Boris Guirao

%% Initialize M_out %%

Mout = Min;

%% Extracts all quantities from side_STATISTICS (1.2)%%

ExtractData(sideSTATISTICS,'','caller')

nRawImages = size(filenameRawMod,1); % 1.4


%% Calculates additional quantities:

nSideCategories = length(sideCategory);


%% Select category of interest %%

%%% Means and Stds:
mean_side_chord_lengths_category = evalin('caller',['mean_side_chord_lengths_' sideCategoryName]);
std_side_chord_lengths_category = evalin('caller',['std_side_chord_lengths_' sideCategoryName]);

mean_side_lengths_category = evalin('caller',['mean_side_lengths_' sideCategoryName]);
std_side_lengths_category = evalin('caller',['std_side_lengths_' sideCategoryName]);

%%% Gather this part of statistics (part not depending on raw images, 1.3):
global_side_statistics_partI = [ n                                          nSideCategories   ...
                                mean_side_chord_lengths_category           std_side_chord_lengths_category ...
                                mean_side_lengths_category                 std_side_lengths_category ];

% Adaptation to >1 raw images (1.2):
global_side_statistics_partII = [];                                         % 1.3

for r = 1:nRawImages
    
    mean_side_chord_angles_category = evalin('caller',['mean_side_chord_angles_' filenameRawMod{r} '_' sideCategoryName]); 
    
    std_side_chord_angles_category = evalin('caller',['std_side_chord_angles_' filenameRawMod{r} '_' sideCategoryName]);
    
    mean_side_intensities_category = evalin('caller',['mean_side_intensities_' filenameRawMod{r} '_' sideCategoryName]);
    
    std_side_intensities_category = evalin('caller',['std_side_intensities_' filenameRawMod{r} '_' sideCategoryName]);
    
    %%% R:
    R_side_chord_angles_category = evalin('caller',['R_side_chord_angles_' filenameRawMod{r} '_' sideCategoryName]);
    
    %%% puttining the 5 columns together:
    this_r_data_set = [mean_side_chord_angles_category                      std_side_chord_angles_category                  R_side_chord_angles_category...
                       mean_side_intensities_category                       std_side_intensities_category];
    
    %%% adding this raw image data to part II of global side statistics (1.3)
    global_side_statistics_partII = [global_side_statistics_partII      this_r_data_set];                            %#ok<AGROW>
end


%% Fills up global_cell_statistics_'category':

Mout(iterationIndex,:) = [ global_side_statistics_partI    global_side_statistics_partII ];


%% History  %%

% 11/08/2011: 1.4
% - adaptation to SIA 2.1e: choice of raw images on which polarity is calculated + naming
% - replaced all num2str(r) by Filename_Raw_mod{r}
% - removed while loop

% 09/12/2010: 1.3
% - fixed issue with column order: was not matching the column headings defined in SIA 2.0GMg

% 30/11/2010: 1.2
% - adaptation to >1 raw images and processing of several set of intensities and thus, several circular mean over chords.
% - now uses "Data_Extractor" to extract everything from "side_STATISTICS", then use of "evalin" to select extracted variables

% 22/11/2010: 1.1
% - added "iteration_index" as input. Before, n was taken as such, causing
% problems when starting at n>1

% 30/09/2010: creation 1.0

