function cellCategoryTable = CellDataTable(cellCategory, CELLS)
%
% cellCategoryTable = CellDataTable(cellCategory, CELLS)
%
% Builds table to save single cell data for each cell category in each
% frame.
% NB: no use of cell_STATISTICS!
%
% Version 1.1
% Boris Guirao

%% Code

% Extraction:
Data_Extractor(CELLS,'cell_', 'caller');
cell_M_quantities = Tensor_Quantities(cell_Ms);

% Cropping to cell category:
cell_category_areas = cell_areas(cellCategory);
cell_category_contour_lengths = cell_contour_lengths(cellCategory);
cell_category_roundnesses = cell_roundnesses(cellCategory);
cell_category_n_neighbors = cell_n_neighbors(cellCategory);
cell_category_anisotropies = cell_anisotropies(cellCategory);
cell_category_orientations = cell_orientations(cellCategory);
cell_category_side_disorders = cell_side_disorders(cellCategory);
cell_category_rsp_sides = cell_rsp_sides(cellCategory);
cell_category_rsp_chords = cell_rsp_chords(cellCategory);
cell_category_chord_disorders = cell_chord_disorders(cellCategory);
cell_category_X_values = cell_centroids(cellCategory,1);
cell_category_Y_values = cell_centroids(cellCategory,2);
cell_category_n_sides = cell_n_sides(cellCategory);
cell_category_n_links = cell_n_links(cellCategory);
cell_category_eta_M = cell_M_quantities(cellCategory,1);
cell_category_s_M = cell_M_quantities(cellCategory,2);
cell_category_theta_M = cell_M_quantities(cellCategory,3);
% Adaptation to >1 raw image (1.1):
r = 1;
cell_category_side_I_disorders_headings = [];      
cell_category_side_I_disorders_values = [];
while exist(['cell_side_intensity_disorders_' num2str(r)],'var')
    this_cell_side_intensity_disorders = evalin('caller',['cell_side_intensity_disorders_' num2str(r)]);  
    this_cell_side_category_I_disorders = this_cell_side_intensity_disorders(cellCategory);                              % get intensities of this category FOR THIS RAW IMAGE
    cell_category_side_I_disorders_headings = [cell_category_side_I_disorders_headings {['Cell Side I Disorders # ' num2str(r)]}];      %#ok<AGROW> Concatenates headings
    cell_category_side_I_disorders_values = [cell_category_side_I_disorders_values  this_cell_side_category_I_disorders];                        %#ok<AGROW> Concatenates intensity vector values
    r = r+1;
end



%%% Builds a cell table to save as a xls file:
% Headings:
cell_category_headings = {     'Cell Numbers'                    'Cell Areas (�m�)'               'Cell Contours (�m)'             'Cell Roundness'      ...
                               'Cell n_neighbors'                'Cell Anisotropies'              'Cell Orientations(�)'           'Cell Side Disorders' ...
                               'Cell Chord Disorders'            'Cell RSP Sides'                 'Cell RSP Chords'                'Cell Xs (�m)'        ...    
                               'Cell Ys (�m)'                    'Cell n_sides'                   'Cell n_links'                   'Cell eta_M'          ...        
                               'Cell s_M (�m�)'                  'Cell theta_M (�)' };
                           
cell_category_headings = [cell_category_headings cell_category_side_I_disorders_headings];          % 1.1 

% Values:                           
cell_category_quantities = [    cellCategory                     cell_category_areas              cell_category_contour_lengths    cell_category_roundnesses    ...
                                cell_category_n_neighbors         cell_category_anisotropies       cell_category_orientations       cell_category_side_disorders ...
                                cell_category_chord_disorders     cell_category_rsp_sides          cell_category_rsp_chords         cell_category_X_values       ...
                                cell_category_Y_values            cell_category_n_sides            cell_category_n_links            cell_category_eta_M          ...
                                cell_category_s_M                 cell_category_theta_M       ];
                            
cell_category_quantities = [cell_category_quantities  cell_category_side_I_disorders_values];                    
                            
% Full table:             
cellCategoryTable = [cell_category_headings ; num2cell(cell_category_quantities)];



%% History

% 26/01/2011: 1.1
% - included storage of "cell_side_intenisty_disorders" for each raw image and for each category

% 05/08/2010: creation