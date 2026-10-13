function Mout = GlobalCellStatistics(Min, cellCategory, cellCategoryName, cellSTATISTICS, n, iterationIndex, filenameRawMod)
%
% Mout = GlobalCellStatistics(Min, cellCategory, cellCategoryName, cellSTATISTICS, n, iterationIndex, filenameRawMod)
%
% cellCategoryName = CC, FLC or NBC
%
% Version 1.3
% Boris Guirao

%% Initialize:

Mout = Min;

%% Extracts all quantities from cell_STATISTICS (1.2)%%

ExtractData(cellSTATISTICS,'','caller')

nRawImages = size(filenameRawMod,1); % 1.3


%% Calculates additional quantities:

nCellCategories = length(cellCategory);


%% Extracts mean and std from cell_STATISTICS:

% means:
mean_cell_areas_category = evalin('caller',['mean_cell_areas_' cellCategoryName]);
mean_cell_contour_lengths_category = evalin('caller',['mean_cell_contour_lengths_' cellCategoryName]);
mean_cell_roundnesses_category = evalin('caller',['mean_cell_roundnesses_' cellCategoryName]);
mean_cell_n_neighbors_category = evalin('caller',['mean_cell_n_neighbors_' cellCategoryName]);
mean_cell_anisotropies_category = evalin('caller',['mean_cell_anisotropies_' cellCategoryName]);
mean_cell_orientations_category = evalin('caller',['mean_cell_orientations_' cellCategoryName]);
mean_cell_side_disorders_category = evalin('caller',['mean_cell_side_disorders_' cellCategoryName]);
mean_cell_chord_disorders_category = evalin('caller',['mean_cell_chord_disorders_' cellCategoryName]);
mean_cell_rsp_sides_category = evalin('caller',['mean_cell_rsp_sides_' cellCategoryName]);
mean_cell_rsp_chords_category = evalin('caller',['mean_cell_rsp_chords_' cellCategoryName]);
mean_cell_Ms_category = evalin('caller',['mean_cell_Ms_' cellCategoryName]);

% stds:
std_cell_areas_category = evalin('caller',['std_cell_areas_' cellCategoryName]);
std_cell_contour_lengths_category = evalin('caller',['std_cell_contour_lengths_' cellCategoryName]);
std_cell_roundnesses_category = evalin('caller',['std_cell_roundnesses_' cellCategoryName]);
std_cell_n_neighbors_category = evalin('caller',['std_cell_n_neighbors_' cellCategoryName]);
std_cell_anisotropies_category = evalin('caller',['std_cell_anisotropies_' cellCategoryName]);
std_cell_orientations_category = evalin('caller',['std_cell_orientations_' cellCategoryName]);
std_cell_side_disorders_category = evalin('caller',['std_cell_side_disorders_' cellCategoryName]);
std_cell_chord_disorders_category = evalin('caller',['std_cell_chord_disorders_' cellCategoryName]);
std_cell_rsp_sides_category = evalin('caller',['std_cell_rsp_sides_' cellCategoryName]);
std_cell_rsp_chords_category = evalin('caller',['std_cell_rsp_chords_' cellCategoryName]);

% R:
R_cell_orientations_category = evalin('caller',['R_cell_orientations_' cellCategoryName]);


%% Calculates additional quantities:

ratio_areas_category = std_cell_areas_category/mean_cell_areas_category;
ratio_contours_category = std_cell_contour_lengths_category/mean_cell_contour_lengths_category;
ratio_roundnesses_category = std_cell_roundnesses_category/mean_cell_roundnesses_category;
ratio_n_neighbors_category = std_cell_n_neighbors_category/mean_cell_n_neighbors_category;
ratio_side_disorders_category = std_cell_side_disorders_category/mean_cell_side_disorders_category;
ratio_chord_disorders_category = std_cell_chord_disorders_category/mean_cell_chord_disorders_category;
ratio_anisotropies_category = std_cell_anisotropies_category/mean_cell_anisotropies_category;
ratio_rsp_sides_category = std_cell_rsp_sides_category/mean_cell_rsp_sides_category;
ratio_rsp_chords_category = std_cell_rsp_chords_category/mean_cell_rsp_chords_category;
mean_M_quantities_category = Tensor_Quantities(mean_cell_Ms_category);
eta_mean_M_category = mean_M_quantities_category(1);
s_mean_M_category = mean_M_quantities_category(2);
theta_mean_M_category = mean_M_quantities_category(3);


%% Fills up global_cell_statistics_'category':

global_cell_statistics_partI =  [ n                                          nCellCategories   ...
                              mean_cell_areas_category                   std_cell_areas_category                 ratio_areas_category ...
                              mean_cell_contour_lengths_category         std_cell_contour_lengths_category       ratio_contours_category ...
                              mean_cell_roundnesses_category             std_cell_roundnesses_category           ratio_roundnesses_category ...
                              mean_cell_n_neighbors_category             std_cell_n_neighbors_category           ratio_n_neighbors_category ...
                              mean_cell_anisotropies_category            std_cell_anisotropies_category          ratio_anisotropies_category ...
                              mean_cell_orientations_category            std_cell_orientations_category          R_cell_orientations_category ...
                              mean_cell_side_disorders_category          std_cell_side_disorders_category        ratio_side_disorders_category ...
                              mean_cell_chord_disorders_category         std_cell_chord_disorders_category       ratio_chord_disorders_category ...
                              mean_cell_rsp_sides_category               std_cell_rsp_sides_category             ratio_rsp_sides_category ...
                              mean_cell_rsp_chords_category              std_cell_rsp_chords_category            ratio_rsp_chords_category ...
                              eta_mean_M_category                        s_mean_M_category                       theta_mean_M_category          ];


% Adaptation to >1 raw images (1.2):
global_cell_statistics_partII = [];                                      
for r = 1:nRawImages
    mean_cell_side_I_disorders_category = evalin('caller',['mean_cell_side_intensity_disorders_' filenameRawMod{r} '_' cellCategoryName]);
    std_cell_side_I_disorders_category = evalin('caller',['std_cell_side_intensity_disorders_' filenameRawMod{r} '_' cellCategoryName]);
    ratio_cell_side_I_disorders_category = std_cell_side_I_disorders_category/mean_cell_side_I_disorders_category;
    
    %%% putting the 3 columns together:
    this_r_data_set =  [mean_cell_side_I_disorders_category  std_cell_side_I_disorders_category  ratio_cell_side_I_disorders_category];
    
    %%% adding this raw image data to part II of global cell statistics (1.3)
    global_cell_statistics_partII = [global_cell_statistics_partII      this_r_data_set];                            %#ok<AGROW>
end


%% Fills up global_cell_statistics_'category':

Mout(iterationIndex,:) = [global_cell_statistics_partI    global_cell_statistics_partII ];
                                           
                                           

%% History %%

% 11/08/2011: 1.3
% - adaptation to SIA 2.1e: choice of raw images on which polarity is calculated + naming
% - replaced all num2str(r) by Filename_Raw_mod{r}
% - removed while loop

% 26/01/2011: 1.2
% - included storage of "cell_side_intenisty_disorders" for each raw image and for each category

% 22/11/2010: 1.1
% - added "iteration_index" as input. Before, n was taken as such, causing
% problems when starting at n>1

% 05/08/2010: creation