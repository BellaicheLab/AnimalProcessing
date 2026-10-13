function [cellCATEGORIES, BOX, proceed] = StaticBox(image, CELLS, oneCellFrontier, pathSelectedImage, pathFolderRaw, predefinedBoxData, boxSideThickness, BOX, reloadBox)
%
% [cellCATEGORIES, BOX, proceed] = StaticBox(image,CELLS, oneCellFrontier, pathSelectedImage, pathFolderRaw, predefinedBoxData, boxSideThickness, BOX, reloadBox)
%
% - calls function "Draw_Box" as long as user redraws the box
% - defines cell categories in image according to drawn box
%
% Version 1.5
% Boris Guirao


%% Extraction from structures %%

ExtractData(CELLS,'cell','caller');
[~, FLRNs, borderRNs] = GetCellCategories(cellCategoryTags); % 1.5
% ExtractData(cellCATEGORIES,'','caller');                                %#ok<NODEF>
ExtractData(BOX,'box','caller');                                        % extracts: box_XY, boxChoice, box_matrix_in, box_matrix_out

proceed = 1; % default value

%% Box Drawing %%

if isempty(boxChoice) || reloadBox                                                     % means that "Static_Box" is called for the first time: the user must draw a box
    
    %%% Worspace message (1.2):
    if ~reloadBox
        disp('Waiting for completion of box drawing by user...')
    else
        disp('Waiting for validation of reloaded box by user...')
    end
     
    imageSize = size(image);
    
    goodBox = 0;
    while goodBox == 0
        
        %%% DrawBox & defines box_matrix_in/out:
        [BOX, chosenImage] = DrawBox(pathSelectedImage, pathFolderRaw, predefinedBoxData, boxSideThickness, BOX, reloadBox);      % NB: this creates "path_selected_image" that contains path to image selected
                                                                                                                                             % added arguments BOX and reload_box (1.2)
        ExtractData(BOX,'box','caller');
        pause(0.1);
        
        %%% Case no image or no proper box selected (1.1)
        if ~chosenImage
        %if isnan(boxChoice)   
            proceed = 0;
            disp('No image has been selected by user.')
            return
        elseif boxChoice == 0                     % (1.1)
            proceed = 0;
            disp('No proper box has been selected by user.')
            close(1)
            return
        end
        
        %%% Checking sizes of image_Seg and image_box (2.0GMa, robustness of box 2.0GMc)
        imageBoxSize = size(boxMatrixIn);
        if imageSize(1) ~= imageBoxSize(1) || imageSize(2) ~= imageBoxSize(2)
            button = questdlg(['Size of chosen image (' num2str(imageBoxSize) ') does not match size segmented image (' num2str(imageSize) ').'],...
                'Image Size Mismatch!','Cancel','Continue','Cancel');
            
            if strcmp(button,'Cancel') || isempty(button)      % added "isempty(button)" and removed else case (2.0GMd)
                close(1)
                return
            elseif strcmp(button,'Continue')
                % Crops box to segmented image size if necessary (no effect if segmented image is larger in both dimensions):
                boxMatrixIn = boxMatrixIn(1:min(imageSize(1),imageBoxSize(1)), 1:min(imageSize(2),imageBoxSize(2)));
                boxMatrixOut = boxMatrixOut(1:min(imageSize(1),imageBoxSize(1)), 1:min(imageSize(2),imageBoxSize(2)));
                % NB: now the box has same size as segmented image or is smaller along one or both directions
                % update:
                imageBoxSize = size(boxMatrixIn);
                % Case of smaller image box:
                if imageSize(1) > imageBoxSize(1) || imageSize(2) > imageBoxSize(2)
                    new_box_matrix_in = zeros(imageSize);
                    new_box_matrix_out = ones(imageSize);
                    new_box_matrix_in(1:imageBoxSize(1),1:imageBoxSize(2)) = boxMatrixIn;
                    new_box_matrix_out(1:imageBoxSize(1),1:imageBoxSize(2)) = boxMatrixOut;
                    % update of box_matrix_in/out:
                    boxMatrixIn = new_box_matrix_in;
                    boxMatrixOut = new_box_matrix_out;
                end
            end
        end
        
        %%% Box check dialog:
        if ~reloadBox
            button = questdlg('Are you satisfied with this box?','Box check','Calculate','Redraw', 'Quit','Calculate');
        else
            button = questdlg('Are you satisfied with this box?','Box check','Calculate', 'Change image', 'Quit','Calculate'); % no redraw option (1.2)
        end
        if strcmp(button,'Calculate')
            goodBox = 1;
        elseif strcmp(button,'') || strcmp(button,'Quit')
            proceed = 0;
            close(1)
            return
        else
            close(1)
        end
    end
    close(1)
    
    %%% Update of BOX quantities:
    BOX.XYs = boxXYs;
    BOX.Choice = boxChoice;
    BOX.MatrixIn = boxMatrixIn;
    BOX.MatrixOut = boxMatrixOut;
end

% NB: if "boxChoice" is empty box_XY, box_matrix_in, box_matrix_out remain unchanged.


%% Determination of 3 cell categories defined by box (2.0GMa) %%

%%% Worspace message:
disp('Update of cell categories corresponding to box...')

%%% Defining image regions:
imageLabel = bwlabel(image,4);   % Attributes regions a unique number in each frame


%%% Defining cell inside/outside box:
% cell_in : intersection between image_label and box_matrix_in (cell relative numbers with 1+ pixel inside (+ borders) the box)
% cell_out : same thing
tempoIn = imageLabel .* boxMatrixIn;
tempoOut = imageLabel .* boxMatrixOut;
cellIn = unique(tempoIn(tempoIn > 0));
cellOut = unique(tempoOut(tempoOut > 0));

% 1st layer_cells: intersection between cell_in and cell_out
FLRNs2 = intersect(cellIn, cellOut);
coreRNs2 = setdiff(cellIn, FLRNs2);

% Inference of new Non_Border_cells and Border_cells
nonBorderRNs2 = [coreRNs2;FLRNs2];
borderRNs2 = setdiff(cellNumbers, nonBorderRNs2);              % Replace "cell2mat(Cellule(:,1))" by "cell_numbers" (1.0b)


%%% Checking new Core_cells (Core_cells2) are not Border_cells for the image or exclude them:
ind1=find(ismember(coreRNs2, borderRNs)==1);                          %Core_cells2 which are Border_cells

if ~isempty(ind1)
    % redefines Border_cells including new Core_cells involved:
    borderRNs3 = unique([borderRNs2; coreRNs2(ind1)]);
    % removing these cells from Core_cells:
    coreRNs3 = unique(setdiff(coreRNs2,coreRNs2(ind1)));
    FLRNs3 = FLRNs2;
else
    % keep cell partionning as it is:
    borderRNs3=borderRNs2;
    coreRNs3=coreRNs2;
    FLRNs3=FLRNs2;
end


%%% Checking cells remaining in Core_cells (Core_cells3) are not First_Layer for the image cells or exclude them:
ind2=find(ismember(coreRNs3,FLRNs)==1);                               %Core_cells3 which are FL_cells

if ~isempty(ind2)
    % redefines FL_cells including new Core_cells involved:
    FLRNs4=unique([FLRNs3; coreRNs3(ind2)]);
    % removing these cells from Core_cells:
    coreRNs4=setdiff(coreRNs3,coreRNs3(ind2));
    borderRNs4=borderRNs3;
else
    % keep cell partionning as it is:
    FLRNs4=FLRNs3;
    coreRNs4=coreRNs3;
    borderRNs4=borderRNs3;
end


%%% Checking cells remaining in FL_cells (FL_cells4) are not Border_cells for the image:
ind3=find(ismember(FLRNs4,borderRNs)==1); %FL_cells3 which are Border_cells

if ~isempty(ind3)
    % redefines Border_cells including new FL_cells involved:
    borderRNs5=unique([borderRNs4; FLRNs4(ind3)]);
    FLRNs5=setdiff(FLRNs4,FLRNs4(ind3));
    coreRNs5=coreRNs4;
else
    FLRNs5=FLRNs4;
    borderRNs5=borderRNs4;
    coreRNs5=coreRNs4;
end


if oneCellFrontier == 1
    %%%% "Rescuing" some FL_cells without borderRNs neighbors into coreRNs:
    %%%% "Excluding some FL_cells without coreRNs neighbors into borderRNs:
    
    % list all neighbors RN of First layer cells in a 1-column vector:
    FLneighbors = cell2mat(cellNeighbors(FLRNs5)')';                         % Replaced "cell2mat(Cellule(FL_cells5,8)')'" by "cell2mat(cell_neighbors(FL_cells5)')'" (1.0b)
    nFLneighbors = cellnNeighbors(FLRNs5);                                 % Replaced "cell2mat(Cellule(FL_cells5,9))" by "cell_n_neighbors(FL_cells5)" (1.0b)
    
    % builds a vector column of corresponding first layer cell RN:
    FL_cells_RN = cell(size(nFLneighbors,1),1);
    for c = 1:size(nFLneighbors,1)
        FL_cells_RN{c} = FLRNs5(c)*ones(nFLneighbors(c),1);
    end
    FL_cells_RN = cell2mat(FL_cells_RN);
    
    %%% Including First without Border neighbor into Core:
    whosBorderCellsTF = ismember(FLneighbors, borderRNs5);                               % checks among neighbors which cells are among Border_cells5
    %index_border_cells = find(whos_border_cells);                                              % gets indices (in whos_border_cells) of neighbors that are border cells (commented 1.1)
    FL_cells_with_border_neighbor_RN = unique(FL_cells_RN(whosBorderCellsTF));               % First layer cells that have at least one neighbor among Border_cells5
    firstBecomingCore = setdiff(FLRNs5, FL_cells_with_border_neighbor_RN);                 % Cells to rescue (the ones that does not have any neighbor among Border_cells5)
    
    %%% SIMILARLY, Exluding First without Core neighbors into Border:
    coreRNs5 = [coreRNs5 ; firstBecomingCore];                                                % updating Core_cells5 to include newly added First layer cells:
    TF_whos_core_cells = ismember(FLneighbors, coreRNs5);
    %index_core_cells = find(whos_core_cells);                                                        %(commented 1.1)
    FL_cells_with_core_neighbor_RN = unique(FL_cells_RN(TF_whos_core_cells));
    firstBecomingBorder = setdiff(FLRNs5, FL_cells_with_core_neighbor_RN);
    
    % Updating cell types (moving "First_becoming_Core" from First to Core):
    borderRNs5 = [borderRNs5 ; firstBecomingBorder]; 
    firstExcluded = [firstBecomingCore ; firstBecomingBorder];
    FLRNs5 = setdiff(FLRNs5, firstExcluded); % now strict first layer of cells
end

%%%% UPDATE OF cell categories FOR BOX DRAWN:
% RESTRICTING Border_cells to Image Border cells and EXTENDING first layer cells to all other cells except Core cells:
coreRNs = coreRNs5;
FLRNs = FLRNs5;
borderRNs = setdiff(borderRNs5, [coreRNs ; FLRNs]); % All remaining cells
nonBorderRNs = [coreRNs ; FLRNs];

%%%% UPDATE OF CATEGORIES IN "cell_CATEGORIES":
cellCATEGORIES.coreRNs = coreRNs;
cellCATEGORIES.FLRNs = FLRNs;
cellCATEGORIES.borderRNs = borderRNs;
cellCATEGORIES.nonBorderRNs = nonBorderRNs;


%% History %%

% 04/05/2018: 1.5
% - use of "GetCellCategories"

% 23/01/2018: 1.4
% - changes for SIA 3.1 compatibility

% 06/02/2013: 1.3
% - added support of "reload_box" option
% - added "proceed" as output

% 06/08/2011:
% - minor bug fixes when not selecting a proper box or not selecting image

% 09/02/2011: 1.0 Creation from lines of SIA 2.0GMo to make it shorter




