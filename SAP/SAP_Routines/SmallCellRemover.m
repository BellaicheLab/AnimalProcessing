function segimage = SmallCellRemover(segimage, min_n_pixels)

% Version 1.1
% Boris Guirao
% NB: thorough rewriting of "SmallCellRemover"

% Take a binary segmented "segimage" image as input and a minimal cell size
% in pixels "min_n_pixels" beneath which cells are removed.
% NB: CELLS FILLED WITH 1s (white), MEMBRANE MADE UP BY 0s (black).

%% Code

% Use of "regionprops" IN CONNECTIVITY 4:
image_CC = bwconncomp(segimage, 4);
REG_STATS = regionprops(image_CC, 'Area','PixelIdxList');
REG_STATS_cell = (struct2cell(REG_STATS))';                                % fromatting this structure to a cell

cell_areas = cell2mat(REG_STATS_cell(:,1));                                % vector of cell areas
cell_pixels = REG_STATS_cell(:,2);                                         % cell of cell pixels
index_small_cells = find(cell_areas <= min_n_pixels);                      % numbers of "small" cells

% Display number of cells found in image (changed 1.1):
if isempty(index_small_cells)
    return                                                                 % stop execution of function here
end

pixels_small_cells = cell2mat(cell_pixels(index_small_cells));             % merge all pixels of small cells in a row into a single vector column
segimage(pixels_small_cells) = 0;                                          % sets all pixels of small cells to 0 to remove them (make holes)

% Skeletonizes to 1 pixel thick skeleton:
% NB: OPERATION bwmorph(image, 'thin', Inf) MUST RUN ON WHITE MEMBRANES TO
% THIN THEM TO 1PIXEL THICKNESS!!
segimage = bwmorph(~segimage,'skel',Inf);                                  % hence the negative image % 2012-06-12: thin->skel
segimage = ~segimage;                                                      % take negative again to go back to white cells, black membranes


%% History

% 17/09/2010: 1.1
% - stopped displaying info about number of small cells found

% 03/09/2010:
% fixed display bug: "num2cell instead" of "num2str" in 2nd display.

% 02/09/2010: 1.0: rewriting of "Remove_Small_Cells"
% - use of regionprops only (and not bwlabel)
% - straightforward coding
% - Removal of extra watershed!
