function DisplayHLCs(segImage, PLOT_HLC, SAVE, n)
%
% DisplayHLCs(segImage, PLOT_HLC, SAVE, n)
%
% NB : IN THE CASE OF GRID PROCESSING, argument "TENSORS" CORRESPONDS TO A "GRID" STRUCTURE IN THE MAIN PROGRAM.
% The actual cell array TENSORS that contains tensor info must be extracted: (grid_TENSORS = TENSORS.TENSORS).
%
% Plots all Half-Links (HL) per categories ('B', 'R+',...) with specific color and linestyle according to their category
% listed in "all_HLC", using coordinate values listed in "all_Lijplots", link weights "all_Wijs", and colors and
% linestyles defined in cell array "HLC_plotstyle".
% Also displays tensor ellispes, axes, names, titles and scalebars next to "image" (addition of a white stripe ~half the
% image width) for main instantaneous AND cumulated contributions. Input "SAVE" (structure) contains all required info
% to directly save images.
% NB: as of 1.12, ERRORS is looked for within TENSORS.
%
% Parameter "HL_display" = 'all' (also display HL tagged with "n/a") OR 'core' (won't) OR 'none' (won't display HL maps)
% HLC = Half-Link Categories
%
% Version 4.2
% Boris Guirao


%% Grid usage and parameters %%

% Extracts info from SAVE:
ExtractData(SAVE,'','caller');

if ~exist('plotAnimal','var')
    plotAnimal = Animal;
end

if ~isempty(gridType) % 4.1
    
    % PLOT corresponds to structure GRID
    if strcmp(use,'old')
        all_HLC = PLOT_HLC.HLCold;
        all_LijPlots = PLOT_HLC.LiokoPlots/scale1D; % conversion in PIXELS
        all_Wijs = PLOT_HLC.Wiokos;
    elseif strcmp(use,'current')
        all_HLC = PLOT_HLC.HLC;
        all_LijPlots = PLOT_HLC.LijPlots/scale1D;   % conversion in PIXELS
        all_Wijs = PLOT_HLC.Wijs;
    end
else
    % PLOT corresponds to structure LINKS
    if strcmp(use,'old')
        all_HLC = PLOT_HLC.all_HLCold;
        all_LijPlots = PLOT_HLC.all_LiokoPlots/scale1D; % conversion in PIXELS
        all_Wijs = PLOT_HLC.all_Wiokos;
    elseif strcmp(use,'current')
        all_HLC = PLOT_HLC.all_HLC;
        all_LijPlots = PLOT_HLC.all_LijPlots/scale1D;   % conversion in PIXELS
        all_Wijs = PLOT_HLC.all_Wijs;
    end
end


%% Preparing segmented image, adding grid if any (mod 4.1) %%

% extracting info from "HLC_plotstyle"
allCat = HLCplotstyle(:,1); %#ok<*IDISVAR,NODEF>
nCat = size(allCat,1);

if ~display_naHL
    nCat = nCat-1;          % won't iterate up to category 'n/a' in "HLCplotstyle", stopping at "Jb-" (3.0)
end

% Making figure and plotting HLs
figure('PaperPositionMode','auto')   % REQUIRED TO SAVE WITHOUT BORDERS!!

% Getting macrochaetes pixels in image:
macrochaetesPixelsTF = [];
if exist('macroRNs','var') && ~isempty(macroRNs)
    macrochaetesPixelsTF = ismember(segImageLabels, macroRNs);                        % directly using imageLabels to find regions
end

% Coloring macrochaetes:
segImage = double(segImage); % 
segImage = Paint(segImage, macrochaetesPixelsTF, colorMacrochaetes); % turns segImage into RGB image

% Coloring BC and FLC (4.2)
% Blending existing colors with "colorBorderCells" and "colorFLCells" for FLC display:
FLCpixelsTF = ismember(segImageLabels, FLRNs);                                              % directly using imageLabels to find regions
segImage = Blend(segImage, FLCpixelsTF, colorFLCells, 0.8);
% Overriding ALL BC colors (not just #1) with "colorBorderCells" by using Paint instead of Blend
BCpixelsTF = ismember(segImageLabels, borderRNs);                                           % directly using imageLabels to find regions
segImage = Paint(segImage, BCpixelsTF, colorBorderCells);   

% Adding grid 
if strcmp(gridType,'L')
    if isfield(SAVE,'contourIndices')
        contourDilation = 1;                                                                % in pixels
        countourIndices = unique(cell2mat(contourIndices(:)));                              %#ok<NODEF>
        dilatedCountourIndices = SideDilator(imageSize,countourIndices, contourDilation);   % dilation
        segImage = Paint(segImage, dilatedCountourIndices, PLOT_HLC.color);
    end
end

segImage = im2uint8(segImage);          % converting to 8bit image otherwise imshow crashes
imshow(segImage,'Border', 'tight')      % 'tight' removes gray borders in displayed figure

if strcmp(gridType,'E')
    PlotGrid([], PLOT_HLC);
end
hold on

%% ITERATION over ALL Half-Links %%

% NB: BUT 'n/a' links that do NOT contribute to balance will be displayed (3.0)

for c = 1:nCat
    
    % Retrieving this category plotstyle from "HLC_plotstyle":
    HLcat = HLCplotstyle{c,1};
    HLcolor = HLCplotstyle{c,2};
    HLstyle = HLCplotstyle{c,3};
    
    % Finding lines corresponding to this category in "all_HLC_crop":
    HLcatLoc = strcmp(all_HLC, HLcat);
    % Finding lines corresponding to 4-vertex links (1.1):
    HL4VsLoc = ismember(all_Wijs, 1/2);
    
    % Splitting "HL_cat_loc" into "4Vs" and "no4Vs":
    HLcatLocNo4Vs = all([HLcatLoc ~HL4VsLoc],2);
    HLcatLoc4Vs = all([HLcatLoc HL4VsLoc],2);
    
    if any(HLcatLoc)
        %%% Regular links (no4Vs):
        HLcatNo4VsXYs = (all_LijPlots(HLcatLocNo4Vs,:))';     % turning {{[Xi XMj1 Yi YMj1] ; [Xi XMj2 Yi YMj2] ; ...} ; ...}
        % into a 4x(2*n_HL) matrix: [[Xi XMj1 Yi YMj1]' [Xi XMj2 Yi YMj2]' ...]
        HLcatNo4VsXs = HLcatNo4VsXYs(1:2,:);
        HLcatNo4VsYs = HLcatNo4VsXYs(3:4,:);
        
        %%% 4-vertex links (4Vs):
        HLcat4VsXYs = (all_LijPlots(HLcatLoc4Vs,:))';
        HLcat4VsXs = HLcat4VsXYs(1:2,:);
        HLcat4VsYs = HLcat4VsXYs(3:4,:);
        
        %%% Assigning smaller width to conserved links (3.1)
        linkWidthPlot = linkWidth;   % default
        thinningFactor = 1;           % 3.2
        if strcmp(HLcat,'G') || strcmp(HLcat,'G/R+')|| strcmp(HLcat,'G/R-')
            linkWidthPlot = linkWidth*thinningFactor;
        end
        
        % Plot all HL of BOTH categories AT ONCE:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        HLcolor4Vs = FadeColor(HLcolor,0.5);
        line(HLcatNo4VsXs, HLcatNo4VsYs,'Color', HLcolor, 'LineStyle', HLstyle, 'LineWidth', linkWidthPlot); % using link_width_plot (3.1)
        line(HLcat4VsXs, HLcat4VsYs,'Color', HLcolor4Vs, 'LineStyle', HLstyle, 'LineWidth', linkWidthPlot);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
end

%% Adding info on image %%

% option to display minimal info (3.2)
textAnimal = '';
textQuantity = '';
if ~minimalInfoDisplay
    textAnimal = [plotAnimal ' # ' num2str(n)];
    textQuantity = 'Half-Links';
end
textTime =  frame2time(n, timeRef, frameRef, dt,'str'); % 3.4
PlotInfo(textQuantity, '', 0, colorInfo, '{\mu}m', textAnimal, textTime, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 3.3


%% History %%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FUTURE IMPROVEMENTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 26/07/2018: 4.2
% - now displays border and FL cells in their respective colors
% - stopped generating "segImageLabels" that is now loaded in SAVE for
% faster execution

% 21/12/2017: 4.1
% - added display of macrocahetes in "colorMacrochaetes"
% - stopped using "LGridPlotter" to display lagrangian grid

% 16/10/2017: 4.0
% - removed all commented parts related to plot of ellipses

% 28/04/2016: 3.4
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage

% 26/05/2015: 3.3
% - adjustments to match new notations in AIA_parameters 5.4 and TA 2.2.1

% 30/04/2015: 3.2
% - apply a "thinningFactor" to conserved links to better see topological changes
% - support of "minimalInfoDisplay" to only display time APF and scalebar (and not the quantity being plotted nor the frame number)

% 03/04/2015: 3.1
% - support of Lagrangian grid

% 04/03/2015: 3.0 & changed name to "HLCdisplay"
% - supports GRID mode (Eulerian)
% - many changes to make it run with TA 2.0.7

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NEW FRAMEWORK RENORMALIZATION (TA 2.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 18/02/2015: 2.2
% - In "InfoPlotter", added killTr (=0) as 3rd argument, and scalebar_width (used to be []) everywhere

% 21/09/2014: 2.1
% - look for "2.1" in the code to see changes

% 02/08/2014: 2.0 Display for Lagrangian grid!
% - display of patches boundaries in color specified by "grid_color" in AIA_info (using parameter "fader" with "Blend" function)
% - tensor are plotted at centroid of moving patches using "Lcentroids"
% - replaced 'Balance Error' by 'BE'

% 22/07/2014: 1.4
% - extensive use of "filesep" for mac compatibility

% 08/04/2014: 1.3.5
% - use of "print_resolution" that was stored in SAVE structure but not used ('-r200' was always used instead!!)
% - removed some commented old parts

% 04/04/2014: 1.3.4
% - display of midline under tensor display using Midline_Plotter

% 03/04/2014: 1.3.3
% - adjustments to run with latest version of Tensor_Plotter (1.7) that now uses parameter "sign_opacities" to display
% black/white disks according to sign of tensor isotropic part and with variable opacity

% 10/03/2014: 1.3.2
% - use of "Info_Plotter" for both tensor AND half-link plots

% 28/01/2014: 1.3.1
% - small adjustments to match new version of Scalebar_Plotter (v 1.3)

% 24/12/2013: 1.3
% - adjustments to match new version of Tensor_Analysis (Tensor_Plotter_BETA_1.5 that became 1.6)
% - removed variable "full_tensor_type" to only use variables defined in AIA
% - now uses "sign_tag" to plot OPPOSITE values of tensors when 'sign_tag' = '-' (it's ALWAYS the + values of tensors that are stored though)
% - display of time APF instead of frame numbers
% - now indicates in images which eigenvalue is represented by the bar (+ or -)
% - added "scale_ratio" values in filenames
% - improved display of information
% - if "TA_signs" is empty, all contributions are plotted as such (i.e. with + sign)
% - added "signs" in output filenames when "TA_signs" is not empty
% - changed naming of pdf when using centered average so that pages could be appended for each contribution (look for mean_addon).

% 13/06/2013: 1.22
% - solved bug when using TA display in AIA_runner "average" mode by checking for existence of "AIA_runner_call" parameter

% 16/11/2012: 1.21
% - now display faded segmented image below tensor ellipses instead of white background and display frame number shown

% 10/05/2012: 1.20
% - included choice of tensor contributions to plot in AIA_parameters (parameter "tensor_list" in SAVE) (GRID MODE ONLY).

% 08/05/2012: 1.19: FINALIZED SLIDING TIME-WINDOW IMPLEMENTATION
% - added display of average frame number when using centered cumulative data
% - adjustments to support grid display with new type of cumulated data (centered vs classic)

% 08/05/2012: 1.18: sliding time window on full image ok
% - adjustments to TA 1.2.0 and new type of cumulated data (centered vs classic)

% 04/05/2012: 1.17
% - uses "filename_TA" loaded from SAVE to name files after "M/OM" and PIV grid size.
% - fixed mistake: "min_Q_ratio" to "1/min_Q_ratio" in "Scalebar_Plotter"

% 02/05/2012: 1.16
% - added "&& strcmp(HL_display,'none')" in if statement for Grid processing (CASE 2) to prevent wrong overwritting of
% ellipses/bars on grid when "HL_display" is not set to "none" in AIA_parameters. Indeed "TA_Display" is then called 2
% additional times for Half-Link display in "Tensor_Analysis", whereas ellipses/bars should only be drawn when first
% called by line "TA_Display(image, GRID, [], [], [], HLC_plotstyle, TA_plotstyle, SAVE, n, 'none',tensor_display".
% - added scalebar display in original image (distance)

% 27/04/2012: 1.15
% - reverting some changes made specifically for Dachs paper

% 13/02/2012: 1.14: LAST VERSION USED FOR DACHS PAPER
% - adjustments to make parameter "tensor_display" (in AIA parameters) also relevant for full image plot
% - emphasize R+/- HL categories by increasing link_width

% 06/02/2012: 1.13
% - added macrochaetes display
% - added a 10?m long scalebar to scale images

% 06/02/2012: 1.12
% - removed input "std_TENSORS" and look into "TENSORS" for field "ERRORS"
% - added if sections involving parameters "grid_display" and "scale_ratio"

% 1/02/2012: 1.11
% - added input "std_TENSORS" to display differently values above or below threshold

% 1/02/2012: 1.10
% - adjustments to match "Tensor_Plotter" 1.3 (added cases "deviatoric+" or "deviatoric-")

% 31/01/2012: 1.9
% - adjustments to match Tensor_Plotter 1.2 (extra input "tensor_type" stored in SAVE)
% - grid use: created subfolders "Tensor_raw/deviatoric" now
% - grid use: added "tensor_type" in title to know whether one's plotting raw or deviatoric part of tensor
% - added option text(...,'Interpreter','none') to avoid messed up animal names that used to be latex interpreted

% 30/01/2012: 1.8
% if n_interframes == 1, will append ALL tensor contributions into one single pdf

% 25/01/2012: 1.7
% - introduced "plot_Animal" to display on images (default: plot_Animal = Animal)
% - moved parameters: "font_size", "point_size", "line_width", "EV_styles" to AIA and now stores them in "SAVE"
% - allowed overwritting of pdfs for display of tensor ellipses over grid ALSO when (exist('AIA_call','var') && AIA_call == 1)
%
% 23/01/2012: 1.6
% - adjustments for replot mode support

% 19/01/2012: 1.4
% - reduced number of inputs: now always call "SAVE" that contains all required info (including "tensor_scalebars")
% - now always left justifies ALL scalebar values.

% 16-18/01/2012: 1.3
% - use of "export_fig" instead of print
% - finalized representation of both main and main_cumul quantities
% - added "EV_styles = {'-' ':'} in parameters
% - saves tensor ellipses in appended pdfs with "export_fig" in "Tensors" subfolder
% - added "n" as input paramater
% - displays frame # in lower left corner of image
% - plots only selected type of ellipses (main, main_cumul)

% 16/01/2012: 1.2, 1.3
% - now loading structure "SAVE" containing required info to save files from this function AND frame number "n".

% 12/01/2012: 1.1
% - adaptation for grid support

% 26/11/2011: 1.0 becomes "TA_Display"
% - displays tensor ellispes and axes (main instantaneous AND cumulated contributions) next to "image"

% 22/11/2011: 1.1
% - Specific display of links involved in 4 vertices with category color faded with factor 0.5
% - added "all_Wijs" and "link_width" as input parameters

% 21/11/2011: creation (starting point: "HLC_Display" version 1.1)
