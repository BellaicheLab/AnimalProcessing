function sideCategoryTable = SideDataTable(sideCategory, SIDES, filenameRawMod)

% Version 1.2
% Boris Guirao

% Builds table to save single side data for each side category in each frame.
% NB: no use of side_STATISTICS!


%% Code

%%% Extraction:
Data_Extractor(SIDES,'side_', 'caller');
n_raw_images = size(filenameRawMod,1);                                                                                % 1.2

%%% Cropping to side category:
side_category_cells_1st = side_cells(sideCategory,1);
side_category_cells_2nd = side_cells(sideCategory,2);
side_category_lengths = side_lengths(sideCategory);
side_category_chord_lengths = side_chord_lengths(sideCategory);
side_category_chord_angles = side_chord_angles(sideCategory);
% Adaptation to >1 raw image (1.1):
side_category_intensity_headings = [];
side_category_intensity_values = [];

for r = 1:n_raw_images
    this_side_intensities = evalin('caller',['side_intensities_' filenameRawMod{r}]);                                 % gives "this_side_intensities" value of variable ['side_intensities_' num2str(r)]
    this_side_category_intensities = this_side_intensities(sideCategory);                                              % get intensities of this category FOR THIS RAW IMAGE
    side_category_intensity_headings = [side_category_intensity_headings {['Side I # ' filenameRawMod{r}]}];          %#ok<AGROW> Concatenates headings
    side_category_intensity_values = [side_category_intensity_values this_side_category_intensities];                   %#ok<AGROW> Concatenates intensity vector values
end

%%% Builds a side table to save as a xls file:
% Headings:
side_category_headings = {  'Side numbers'                  '1st side cells'              '2nd side cells'              'Side lengths (�m)'     ...
                            'Chord lengths (�m)'            'Chord angles (�)'            };
                                             
side_category_headings = [side_category_headings  side_category_intensity_headings];         % (1.1)

% Values:
side_category_quantities = [ sideCategory                   side_category_cells_1st       side_category_cells_2nd       side_category_lengths   ...
                             side_category_chord_lengths     side_category_chord_angles    ];
                                               
side_category_quantities = [side_category_quantities side_category_intensity_values];        % (1.1)  

% Full table:
sideCategoryTable = [side_category_headings ; num2cell(side_category_quantities)];



%% History %%

% 06/12/2011: 1.2
% - fixed bug: side itensities were not saved (added "Filename_Raw_mod" as input)

% 30/11/2010: 1.1
% - adaptation to >1 raw images and processing of several set of intensities 

% 05/08/2010: creation