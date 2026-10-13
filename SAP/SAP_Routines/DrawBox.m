function [BOX, chosenImage] = DrawBox(pathSelectedImage, defaultPath, predefinedBoxData, boxSideThickness, BOX, reloadBox)
%
% [BOX, chosenImage] = DrawBox(pathSelectedImage, defaultPath, predefinedBoxData, boxSideThickness, BOX, reloadBox)
%
% Enables drawing of a box to define a subset of cells.
%
% INPUTS:
% path_selected_image = path to previously selected image
% default_path = path to look for image to be selected
% box_side_thickness = border thickness
% BOX = preexisting structure box (can be made of empty fields)
% reload_box = option to reload box from backup

% OUTPUT:
% Structure BOX (1.1+) containing:
% box_matrix_in = matrix materializing the inside+borders of box drawn (same dimensions as image).
% box_matrix_out = matrix materializing the outside (excluding borders) of box drawn (same dimensions as image).
% box_choice = box number selected by user (1=Full frame, 2=Rectangle,...)
% box_XY = XY coordinates allowing to draw polygon
% and image_chosen = whether an image over which a box will be drawn has been chosen
%
% Version 1.4
% Boris Guirao


%% Loading image to draw box on %%

%%% If some arguments are not specified:
if nargin == 0
    pathSelectedImage = '';
    defaultPath = '';
elseif nargin ==1
    defaultPath = '';
end

%%% Choice of path to load image:
if isempty(pathSelectedImage)
    pathTaken = defaultPath;                                             % default path if no image was selected before
else
    pathTaken = pathSelectedImage;
end

%%% Loads and display image:
[filename, pathname] = uigetfile({'*.*'},'Please select image to draw box on.', pathTaken);
fullPath = [pathname filename];

if any(fullPath)
    imageBox = imread(fullPath);
    chosenImage = 1;               % 1.2
 else
%     box_matrix_in = NaN;
%     box_matrix_out = NaN;
%     box_choice = NaN;
%     box_XY = NaN;
     chosenImage = 0;               % 1.2
end

if reloadBox
    ExtractData(BOX,'box','caller'); % 1.3
end


if chosenImage                     % checks an image was chosen (1.2)
    
    figure(1)
    imshow(imageBox, 'Border', 'tight')
    assignin('base','pathSelectedImage',fullPath);  % Updates full path to image that was just selected in workspace to take it as default for next choice
    imageSize = size(imageBox);
    
    
    if ~reloadBox
        %% Box Selection and Box Drawing %%
        
        boxChoice = menu('Please choose the type of box to use?','Full Frame','Rectangular Box','Polygonal Box','Predefined Box', 'Circular Box', 'Single Cells');
        if boxChoice == 0
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% No box selected (1.2)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            boxMatrixIn = NaN;
            boxMatrixOut = NaN;
            boxXYs = NaN;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
        elseif boxChoice==1
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Full frame
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            boxMatrixIn = ones(imageSize);
            boxMatrixOut = zeros(imageSize);
            image_height = imageSize(1);
            image_width = imageSize(2);
            xb = 1; yb = 1; a = image_width ; b = image_height;
            boxXYs = [xb yb a b];
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
        elseif boxChoice==2
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Rectangular box
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % See comments in "Polygonal Box"
            
            rect=getrect(gcf);
            xb=round(rect(1));
            yb=round(rect(2));
            a=round(rect(3));
            b=round(rect(4));
            
            boxXYs = [xb yb a b];                                                  % changed "rec_M" to "box_XY"
            %save([Today_Path_save_folder '\' Statistics_folder  '\' 'box_coord.txt'],'rec_M','-ascii') % commented in BCT
            
            % Creation of a matrix of the full box (inside + borders)
            boxMatrixIn = zeros(imageSize);
            boxMatrixIn(yb:yb+b-1,xb:xb+a-1)=ones(b,a);
            
            % outer domain matrix:
            boxMatrixOut = ones(imageSize) - boxMatrixIn;                     % new in Draw_Box
            
        elseif boxChoice==3
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Polygonal box
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Gets polygon coordinates:
            [xv, yv] = getline;                  % gets the user click coordinates
            hold on
            
            % box_XY_temp = [xv yv];                     % stores polygon coordinates      % changed "pol_M" to "box_XY"
            % save([Today_Path_save_folder '\' Statistics_folder  '\' 'polygon_coord.txt'],'pol_M','-ascii') % commented in BCT
            
            % Creation of a matrix of the full polygon (inside + boders)
            nx = imageSize(1); ny = imageSize(2);
            xv = [xv ; xv(1)]; yv = [yv ; yv(1)];
            boxXYs = [xv yv];                     % output = closed polygon
            % list pixels laying inside and on the polygon sides, and those outside:
            [boxMatrixIn, boxMatrixOut] = FindInOnPoly(xv,yv,nx,ny);
            
            
        elseif boxChoice == 4 % IN CONSTUCTION
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Predefined Box
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            xb = predefinedBoxData(1);
            yb = predefinedBoxData(2);
            a = predefinedBoxData(3);
            b = predefinedBoxData(4);
            
            boxXYs = [xb yb a b];
            
            % Creation of a matrix of the full box (inside + borders)
            boxMatrixIn = zeros(imageSize);
            boxMatrixIn(yb:yb+b-1,xb:xb+a-1)=ones(b,a);
            
            % outer domain matrix:
            boxMatrixOut = ones(imageSize) - boxMatrixIn;                     % new in Draw_Box
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
        elseif boxChoice == 5
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Circular Box (IN CONSTRUCTION)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            warndlg('Circular Box has not been implemented yet. Please choose among the three first options.','Warning!')
            boxMatrixIn = NaN;
            boxMatrixOut = NaN;
            boxChoice = 0;
            boxXYs = NaN;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
        elseif boxChoice == 6
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% Single Cells (IN CONSTRUCTION)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            warndlg('Single cell choice has not been implemented yet. Please choose among the three first options.','Warning!')
            boxMatrixIn = NaN;
            boxMatrixOut = NaN;
            boxChoice = 0;
            boxXYs = NaN;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
        end % end of "box_choice ==..."
        
        %% Storage into structure BOX (1.1, moved 1.3) %%
        
        BOX.XYs = boxXYs;
        BOX.Choice = boxChoice;
        BOX.MatrixIn = boxMatrixIn;
        BOX.MatrixOut = boxMatrixOut;
        
    end
    
    %% Box Drawing %%
    
    hold on
    if boxChoice == 1 || boxChoice == 2 || boxChoice == 4                    % 1.2
        rectangle('Position',[xb,yb,a,b],'Curvature',[0,0],'LineWidth',boxSideThickness,'EdgeColor','r');
    elseif boxChoice == 3
        plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',boxSideThickness);                       % redraws the box drawn by the user
    end
end





%% History %%

% 23/01/2018: 1.4
% - changes for SIA 3.1 compatibility

% 06/02/2013: 1.3
% - added support of "reload_box" option
% - added "image_chosen" as output

% 05/08/2011: 1.2
% - added possibility to draw a box from "predefined_box_data", added as argument
% - minor bug fixes when not selecting a proper box or not selecting image

% 09/02/2011: 1.1
% - defined structure BOX

% 26/11/2010:
% - added box_choice, box_XY as outputs
% - removed "box_matrix_border" in rectangle case
% - in choice 1, defined box_matrix_in as full image instead of NaN
% - carry out box plot even in Full frame case
% - all outputs are NaN when no image or no box have been selected

% 25/11/2010: creation

