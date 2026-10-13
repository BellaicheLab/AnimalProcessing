function imagePlot = PlotField(Qname, QkillTr, Qcolor, Qunits, Qsr, Qscalebar, GRID, imageIn, DISPLAY)
%
% imagePlot = PlotField(Qname, QkillTr, Qcolor, Qunits, Qsr, Qscalebar, GRID, imageIn, DISPLAY)
%
% Arguments:
%------------------------------------------------------------
% - Qname
% - QkillTr
% - Qcolor
% - Qunits
% - Qsr
% - Qscalebar
% - imageIn
%------------------------------------------------------------
%
% GRID structure contains fields:
%------------------------------------------------------------
% MANDATORY:
% - Qname
% - AreaRatios
% - xywh
% - size
% - ULCs
% - linewidth
% - color
% OPTIONAL:
% - centroids           does NOT exist in case of clone tracking (became optional in 1.25)
% - RConds              matrix of conditional numbers ("rcond", not "cond") in each grid compartments (1.8)
% - errorPs             matrix of norm of differences between EG and sum of EP (1.8)
% - errorDnPs           matrix of abs of differences between (nf-ni) and sum of dnP, variation of cell number through process P (1.8)
% - errorPsMin          threshold value to show error (1.8)
% - errorDnPsMin        threshold value to show error (1.8)
% - errorFontSize       font size to display errors (1.8)
%------------------------------------------------------------
%
% DISPLAY structure contain fields:
%------------------------------------------------------------
% MANDATORY:
% - plotType            "merged" (ellipse), "split+"/"split-" (circle & dev+/- parts), "circle", "dev+" and "dev-"
% - gridDisplay         true/false
% - lineWidth           thickness of tensor lines
% - EVstyles            ONLY relevant for "merged" plotType: styles to display ellipse axes representing tensor eigenvalues (default {'-' ':'})
% - signOpacities       ONLY relevant for "split+/-" and "circle" display types: specifies opacity of positive(white) and negative(black) disks, respectively.
% - Animal              animal name
% - fontSizeInfo        font size for info
% - imageFading         between 0 (no fading) and 1 (total fading)
% - scaleBarWidth       thickness of scale bar
% - time                time to display on image
% - n                   frame number corresponding to image displayed
% OPTIONAL:
% - step                if Q corresponds to a "stack" matrix of several timepoints, "step" is Q step-th time point (1.1)
% - fadeColor           color to which Qcolor will be faded according to weights
% - colorInfo           color to display info
% - SignificanceMap     significance map (v1.6)
% - macrocaete          macrocaete position (v1.6)
% - Lcentroids          coordinates of lagrangian centoids in image (1.11)
% - ContourIndices     linear indices making up boundaries of lagrangian boxes (1.11)
% - displayOrigin       boolean to display a small black circle showing grid origin (1.14)
% - minimalInfoDisplay  to only display time and scale bar (1.15)
% - xyOffset            distance of scale bar to image boundaries (1.16)
% - nReal               number of frame actually shown as background (because requested frame doesn't exist) (1.18)
% - GridBulkThreshold   kills any weights that are less than the threshold set (2.0)
% - makeItFull          to flip half mean animals % to midline to reconstruct a full animal (1.20)
% - yMid                y coordinate of midline (1.20)
% - drawMidline         whether to draw midline (1.20)
% - midlineColor        color of midline pixels (1.20)
% - cloneTracking       grid patch tracking (false) OR clone tracking (true(1.23)
% - macroRNs            RNs of macrochaetaes in image (1.24)
% - colorMacrochaetes   RGB color to use for macrochaetes (1.24)
%------------------------------------------------------------
%
% version 2.5
% Boris Guirao
% Stephane Rigaud


%% Code %%

CustomColors;
ExtractData(DISPLAY,'','caller'); % extracts ALL DISPLAY quantities

if isfield(GRID,Qname) % 1.7
    %% Defining all variables for plot %%
    
    Q = GRID.(Qname);
    nx = GRID.Size(2);
    ny = GRID.Size(1);
    nBoxes = nx*ny; % 1.20
    
    % NOT loading "centroids" in clone tracking mode as this field does NOT exists.
    if ~exist('cloneTracking','var') || ~cloneTracking  % 1.23
        gridCentroids = GRID.Centroids;                 % 1.11
    end
    
    
    % Defining weights (mod 1.8)
    %-------------------------------------------------------------------------------------------------------------------
    Weights = GRID.AreaRatios;                      % changed name of weights to Weights from AreaRatios (1.8)
    % Includes "RConds" in Weights when exists (1.12) (stef)
    AllQsColorsUnits;
    if length(Qname)>1 && isfield(GRID,'RConds')
        if sum(ismember(allQsTA,Qname(1:2))) || sum(ismember(allQsTA,Qname(end-1:end)))
            RConds = GRID.RConds;
            Weights = Weights.*RConds;             % redefines weights with RConds values (1.8)
        end
    end
    %     Weights = Weights.^2;                       % takes square to sharpen decrease at animal boundaries (1.8)
    %-------------------------------------------------------------------------------------------------------------------
    
    % Killing weights outside bulk (1.19)
    %-------------------------------------------------------------------------------------------------------------------
    if exist('gridBulkThreshold','var') && (gridBulkThreshold>0)
        Weights(Weights < gridBulkThreshold) = 0;
    end
    %-------------------------------------------------------------------------------------------------------------------
    
    % Turns color letter into rgb vector
    if ischar(Qcolor)
        Qcolor = str2rgb(Qcolor);
    end
    
    % manage scale values for plotting (v1.5):
    patchQsr = true;
    if length(Qsr) == 1         % 1.13
        Qsr = [Qsr(1) Qsr(1)];
        patchQsr = false;
    elseif length(Qsr) > 2 % 1.13
        disp('PlotField ERROR: length(Qsr) must be 1 or 2!')
        return
    end
    % Warning message if "merged" is selected with two values, the isotropic value will be use for the plot (v1.5)
    if strcmp(DISPLAY.plotType,'merged') && patchQsr
        disp('!! WARNING !!');
        disp('You have specified Qsr with two values for "merged". Only the first value will be used');
    end
    
    if ~isfield(DISPLAY,'xyOffset') % 1.16
        xyOffset = [];
    end
    
    % Assignment of "colorInfo" value if not provided (1.2, moved here 1.16)
    if ~exist('colorInfo','var')
        colorInfo = black;      % default value: used for segmented image (Imax<1) or for negative raw image
    end
    
    % Overrides Eulerian centroids in GRID (moved out of "if ~isempty(imageIn)" in 1.25)
    if isfield(DISPLAY,'Lcentroids') && isfield(DISPLAY,'ContourIndices')
        gridCentroids = DISPLAY.Lcentroids;
    end
    
    if ~isempty(imageIn) % 1.14
        
        gridColor = GRID.Color; % 1.16
        
        % Overidding "colorInfo" AND "gridColor" to "custom_white" when raw image detected (mod 1.16):
        %------------------------------------------------------------------------------------------------------------------
        Imax = max(double(imageIn(:)));
        Imed = median(double(imageIn(:))); % median instead of mean to limit the impact of processed image where pixels outside the animal were set to 0
        if Imax > 1 && Imed <= 128              % this is a regular raw-like image
            colorInfo = custom_white;
            gridColor = light_grey;             % 1.16
            imageFading = imageFading/2;        % milder fading when using raw image (2.1)
        elseif Imax > 1 && Imed >= 128          % most likely negative raw image
            gridColor = custom_white;           % 2.1
            imageFading = imageFading/2;        % milder fading when using raw image (2.1)
        end
        %---------------------------------------------------------------------------------------------------------------
        
        % Fading background image for better field display (mod 1.11):
        %---------------------------------------------------------------------------------------------------------------
        imagePlot = imageIn; % default
        
        if 0 <= imageFading && imageFading <= 1
            
            imagePlot = mat2gray(imagePlot);          % 1.11
            
            if isfield(DISPLAY,'Lcentroids') && isfield(DISPLAY,'ContourIndices')
                
                % Drawing patch boundaries with "LGridPlotter"
                boundThickness = 1;
                imagePlot = PlotLGrid(imagePlot, DISPLAY.ContourIndices, gridColor, imageFading, boundThickness); % 1.25
            else
                imagePlot = Blend(imagePlot,[],custom_white,imageFading); % 2.1
%                 imagePlot = imagePlot + imageFading; % 1.11
            end
            
        elseif 0 > imageFading || imageFading > 1
            disp('PlotField ERROR: parameter "imageFading" must lie within [0 1]!')
        end
        
        % Coloring macrochaetaes (1.24)
        if exist('macroRNs','var') && ~isempty(macroRNs)
            imageLabels = GetImageLabels(imageIn);
            macroPixelsTF = ismember(imageLabels, macroRNs);
            imagePlot = Paint(imagePlot, macroPixelsTF, colorMacrochaetes);
        end
        %---------------------------------------------------------------------------------------------------------------
    end
    
    % If Plotting error (1.9)
    %-------------------------------------------------------------------------------------------------------------------
    plotError = false;              % default
    if strcmp(Qname,'EG') && (isfield(GRID,'errorPs') || isfield(GRID,'errorDnPs')) % only plots it on EG
        plotError = true;
        errorPs = GRID.errorPs;
        errorDnPs = GRID.errorDnPs;
        
        % Defining default values when not specified in DISPLAY (1.8, moved 1.9)
        if ~isfield(DISPLAY,'errorPsMin')
            errorPsMin = 0;
        end
        if ~isfield(DISPLAY,'errorDnPsMin')
            errorDnPsMin = 0;
        end
        if ~isfield(DISPLAY,'errorPsMin')
            errorFontSize = fontSizeInfo;
        end
    end
    %-------------------------------------------------------------------------------------------------------------------
    
    if isfield(DISPLAY,'animalIdx')
        animalIdx = DISPLAY.animalIdx;
    else
        animalIdx = 1;
    end
    
    % Start filling TDISPLAY for "PlotTensor" (1.8)
    TDISPLAY.plotType = plotType; %#ok<*NODEF>
    TDISPLAY.Qsr = Qsr;
    TDISPLAY.lineWidth = lineWidth;
    TDISPLAY.EVstyles = EVstyles; % 1.16
    
    
    %% Plotting figure %%
    
    if ~isempty(imageIn) % 1.14
        figure('PaperPositionMode','auto','visible',DISPLAY.displayImages);
        imshow(imagePlot,[],'Border', 'tight');
        hold on                                 % mandatory to keep "image" as background of plot field
    end
    
    % Draws tensor in each grid compartment:
    
    %% Q is a 4D matrix (overhaul 2.0, mod 2.4) %%
    
    % Checks existence of field "step" in "DISPLAY" (1.1)
    % NB: this means that Q is a "stack" of several average timepoints ("steps"), step-th step of which must be retrieved for plot:
    if isfield(DISPLAY,'step')                         % 2.4
%     if exist('step','var')                          % 1.2
        
        % Retrieving step-th slice of Q:
        Q = Q(:,:,:,DISPLAY.step,animalIdx);
        Weights = Weights(:,:,:,DISPLAY.step,animalIdx);            % Retrieving step-th slice of AreaRatios (1.4):
        
        % Taking step-th slice of error matrices (1.9)
        if plotError
            errorPs = errorPs(:,:,:,DISPLAY.step,animalIdx);
            errorDnPs = errorDnPs(:,:,:,DISPLAY.step,animalIdx);
        end
    end
    
    Qdepth = size(Q,3);
    
    %--------------------------------------------------------------------
    %%% 4D Matrix of SCALARS
    %--------------------------------------------------------------------
    if Qdepth == 1
        
        % When comparing left & right side of animals:
%         QFlippedUD = flipud(Q);
%         Q = Q+QFlippedUD; % because the other side is negative
%         disp('Flipped DONE!');
        
        if QkillTr
            QWm = WeightedMean(Q, Weights);    % calculates weighted average of Q over all compartments
            TrQWm = 2*QWm;                     % NB: added MISSING factor 2 because of how the tensor is built from the scalar (see below Es_box) (1.17)
        end
        % Loop over grid compartments
        for b = 1:nBoxes
            [ky,kx] = ind2sub([ny nx],b);                           % turns linear index b into (i,j) grid coordinate (1.20)
            
            % Turning scalar into tensor:
            boxEs = [Q(ky,kx) Q(ky,kx)];       % => put Q and not Q/2 otherwise the circle diameter would measure Q/2 => <Tr> = 2<Q>
            boxAngles = [0 90];
            boxXYs = gridCentroids{ky,kx};    % 1.11
            if QkillTr
                boxEs = boxEs - TrQWm/2;      % removes HALF the trace toe EACH eigenvalues => <Trace>=0 (3.11)
            end
            
            % Completion of TDISPLAY (1.8) (1.12):
            TDISPLAY.signOpacities = signOpacities*Weights(ky,kx);                 % goes to 0 (100% transparency) when weight = 0 (1.4)
            TDISPLAY.lineOpacity = [Weights(ky,kx); Weights(ky,kx)];
            
            % Overrides Qcolor with Filtered Qcolor (gray) when not found significant (mod 1.8) :
            FQcolor = [Qcolor;Qcolor]; %(1.10)
            if exist('SignificanceMap','var') % (v1.6)
                if SignificanceMap(ky,kx,1) == 0
                    FQcolor(1,:) = grey;
                end
                if SignificanceMap(ky,kx,2) == 0
                    FQcolor(2,:) = grey;
                end
                if size(SignificanceMap,3) == 4  %(1.12)
                    TDISPLAY.signOpacities = TDISPLAY.signOpacities .* DISPLAY.SignificanceMap(ky,kx,3);                 % goes to 0 (100% transparency) when weight = 0 (1.4)
                    TDISPLAY.lineOpacity(1) = TDISPLAY.lineOpacity(1) .* DISPLAY.SignificanceMap(ky,kx,3);
                    TDISPLAY.lineOpacity(2) = TDISPLAY.lineOpacity(2) .* DISPLAY.SignificanceMap(ky,kx,4);
                end
            end
            
            TDISPLAY.lineColor = FQcolor;
            PlotTensor(boxEs, boxXYs, boxAngles, TDISPLAY); % 1.8
            
            % Plotting symmetric % to midline (1.20)
            if exist('makeItFull','var') && makeItFull
                % Case of rotation
                if strcmp(Qname,'Phi') || strcmp(Qname,'Phigeo') || strcmp(Qname,'Phieig')...
                    || strcmp(Qname,'Omega') || strcmp(Qname,'OmegaPIV') || strcmp(Qname,'OmegaCT') % added all "Omega" (2.2)
                    boxEs = - boxEs;
                end
                boxXYs(2) = 2*yMid - boxXYs(2);
                PlotTensor(boxEs, boxXYs, boxAngles, TDISPLAY);
            end
        end
        %
        %--------------------------------------------------------------------------------------------------
        %%% 4D matrix of 4-components TENSOR
        %--------------------------------------------------------------------------------------------------
    elseif Qdepth == 4              % TENSOR case
        
        % When comparing left & right side of animals:
%         QFlippedUD = flipud(Q);
%         Q = Q-QFlippedUD;
%         disp('Flipped DONE!');
         
        % Calculatig weighted average of Trace(Q) over all compartments:
        if QkillTr
            TrQ = Q(:,:,1) + Q(:,:,4);            % sum matrices of Qxx and Qyy components
            TrQWm = WeightedMean(TrQ, Weights);   % calculates weighted average of TrQ over all compartments
        end
        % Loop over grid compartments
        for b = 1:nBoxes
            [ky,kx] = ind2sub([ny nx],b);           % turns linear index b into (i,j) grid coordinate (1.20)
            
            Qbox = squeeze(Q(ky,kx,:,:,animalIdx)); % flatten this compartment Q into a vector
            if sum(isnan(Qbox(:)))>0                % skips this compartment if NaN found (1.3)
                continue;
            end
            boxQdata = TensorData(Qbox);            % removed argument minAEV (1.7)
            boxEs = boxQdata.Es;
            boxAngles = boxQdata.Angles;
            boxXYs = gridCentroids{ky,kx};          % 1.11
            if QkillTr
                boxEs = boxEs - TrQWm/2;            % removes HALF the trace from EACH eigenvalues => <Trace>=0 (3.11)
            end
  
            % Completion of TDISPLAY (1.8) (1.12):
            TDISPLAY.signOpacities = signOpacities*Weights(ky,kx);                 % goes to 0 (100% transparency) when weight = 0 (1.4)
            TDISPLAY.lineOpacity = [Weights(ky,kx); Weights(ky,kx)];
                     
            % Overrides Qcolor with Filtered Qcolor (gray) when not found significant (mod 1.8):
            FQcolor = [Qcolor;Qcolor];              % 1.10
            
            
            if exist('SignificanceMap','var')       % 1.6
                if SignificanceMap(ky,kx,1) == 0
                    FQcolor(1,:) = grey;
                end
                if SignificanceMap(ky,kx,2) == 0
                    FQcolor(2,:) = grey;
                end
                if size(SignificanceMap,3) == 4  % 1.12
                    TDISPLAY.signOpacities = TDISPLAY.signOpacities .* DISPLAY.SignificanceMap(ky,kx,3);                 % goes to 0 (100% transparency) when weight = 0 (1.4)
                    TDISPLAY.lineOpacity(1) = TDISPLAY.lineOpacity(1) .* DISPLAY.SignificanceMap(ky,kx,3);
                    TDISPLAY.lineOpacity(2) = TDISPLAY.lineOpacity(2) .* DISPLAY.SignificanceMap(ky,kx,4);
                end
            end
            
            TDISPLAY.lineColor = FQcolor;
            PlotTensor(boxEs, boxXYs, boxAngles, TDISPLAY); % 1.8
            
            % Plotting symmetric % to midline (1.20)
            if exist('makeItFull','var') && makeItFull
                Qbox(2:3) = - Qbox(2:3);                % changing sign of Txy and Tyx
                boxQdata = TensorData(Qbox);
                boxAngles = boxQdata.Angles;
                boxXYs(2) = 2*yMid - boxXYs(2);
                PlotTensor(boxEs, boxXYs, boxAngles, TDISPLAY);
            end
            
            % Checking balances on Processes and cell number variation by each process (1.8, mod 1.9)
            %-----------------------------------------------------------------------------------------------
            if plotError
                if errorPs(ky,kx) > errorPsMin
                    errorPstxt = ['\epsilon = ' num2str(errorPs(ky,kx),'%0.1e')]; % 1.9
                    text(boxXYs(1),boxXYs(2),errorPstxt,'Color',red,'FontSize',errorFontSize,...
                        'VerticalAlignment','Bottom','HorizontalAlignment','Center','FontWeight','bold');
                end
                if errorDnPs(ky,kx) > errorDnPsMin
                    errorDnPstxt = ['\epsilon_n = ' num2str(errorDnPs(ky,kx),'%0.1e')]; %1.9
                    text(boxXYs(1),boxXYs(2),errorDnPstxt,'Color',red,'FontSize',errorFontSize,...
                        'VerticalAlignment','Top','HorizontalAlignment','Center','FontWeight','bold');
                end
            end
            %-----------------------------------------------------------------------------------------------
        end
        
    elseif Qdepth == 2      % we are plotting vectors  % 1.6
        
        plotType = 'dev+';  % override to plot a scale BAR (no circle)
        for b = 1:nBoxes
            [ky,kx] = ind2sub([ny nx],b);                  % turns linear index b into (i,j) grid coordinate (1.20)
            Qbox = [ squeeze(Q(ky,kx,:,:,animalIdx)) ; 0]; % flatten this compartment Q into a vector
            boxXYs = [gridCentroids{ky,kx} 0]; % 1.17
            FQcolor = MixColors(Qcolor, custom_white, Weights(ky,kx));       % fades color to dark_grey according to weight based on AreaRatios value
            arrow3D(boxXYs,Qbox.*Qsr(2),FQcolor,0.75);
            
            % Plotting symmetric % to midline NOT TESTED HERE (1.20)
            if exist('makeItFull','var') && makeItFull
                Qbox(2) = - Qbox(2);                                            % changing sign of Qy
                boxXYs(2) = 2*yMid - boxXYs(2);
                FQcolor = MixColors(Qcolor, custom_white, Weights(ky,kx));       % fades color to dark_grey according to weight based on AreaRatios value
                arrow3D(boxXYs,Qbox.*Qsr(2),FQcolor,0.75);
            end
        end
    end
    
    % displays grid (mod 1.11):
    if gridDisplay && ~isfield(DISPLAY,'Lcentroids')
        PlotGrid([], GRID); % 2.5
    end
    
    % Display of origin (mod 2.2)
    if isfield(DISPLAY,'displayOrigin') && displayOrigin % 1.14
        scatter(GRID.xywh(1),GRID.xywh(2),DISPLAY.macroSize,red,'Marker','+','LineWidth',lineWidth)
    end
    
    % Display of macrocaetes (mod 2.2)
    if isfield(DISPLAY,'macrocaetes')
        scatter(DISPLAY.macrocaetes(1,:),DISPLAY.macrocaetes(2,:),DISPLAY.macroSize,...
            'MarkerFaceColor',DISPLAY.colorMacrochaetes,'MarkerEdgeColor',black,'LineWidth',lineWidth)
    end
    
    % draws midline (1.20)
    if exist('drawMidline','var') && drawMidline
        if ~exist('midlineColor','var')
            midlineColor = cyan; % default
        end
        PlotMidline([],yMid,midlineColor); % 2.1
    end
    
    % Regular vs "fullImage" mode (1.14)
    QnamePlot = Qname;
    if isfield(GRID,'fullImage') && GRID.fullImage % 1.25
        QnamePlot = '';
        xText = GRID.ULCs{1}(1) + GRID.xywh(3);
        yText = GRID.ULCs{1}(2) + GRID.xywh(4);
        text(xText,yText,Qname,'Color',Qcolor,'FontSize',fontSizeInfo,'HorizontalAlignment','Right','VerticalAlignment','Bottom','FontWeight','Bold');
    end
    % Plotting info (quantity plotted, time hAPF, animal and scalebar) (3.3,3.4):
    textAnimal = '';
    textQuantity = '';
    if ~minimalInfoDisplay
        if ~exist('nReal','var') || isempty(nReal)  % 1.18
            textAnimal = [Animal ' # ' num2str(n)];
        else
            textAnimal = [Animal ' # ' num2str(nReal) ' (instead of ' num2str(n) ')']; % indicates actual frame being plotted (1.18)
        end
        textQuantity = QnamePlot;
        textQuantity = regexprep(textQuantity, 'plus', '+');    % 1.21
        textQuantity = regexprep(textQuantity, 'minus', '-');   % 1.21
        textQuantity = regexprep(textQuantity, 'dot', '.u');    % 1.21
    end
    hFactor = 1;            % 1 when scalebar in hours (and tensors expressed per hours), 24 when scalebar in days (1.15)
    % NB: must match units that are specified in "AllQsColorsUnits"
    PlotInfo(textQuantity, plotType, QkillTr, Qcolor, Qunits, textAnimal, time, colorInfo, Qscalebar*hFactor, hFactor*1./Qsr, fontSizeInfo, xyOffset, scaleBarWidth); % 1.15, 1.16
    
else
    disp(['WARNING: field ' Qname ' was not found in GRID and was skipped!']); % 1.7
end


%% History %%

% TO Do:
% - update part plotting velocity field with transparency of arrows if possible
% - remove part testing that Q is a structure (OBSOLETE) => should only be matrices now

% 05/09/2023: 2.5
% - removed call to "GridPlotter" to replace it by "PlotGrid"

% 05/10/2020: 2.4
% - solved conflict with Matlab function "step" by directly calling
% "DISPLAY.step" instead.

% 29/09/2020: 2.3
% - fixed issue when plotting in "makeItFull" mode where rotation sign was
% the same on the other side of the animal. Was NOT changed for Omega,
% OmegaPIV and OmegaCT.

% 02/06/2020: 
% - "significant_map" became "SignificanceMap" everywhere

%  28/04/2020: 2.2 (Boris)
% - updated display of macrocaetes and origin that was obsolete (relevant
% for MAP processing)

%  05/06/2018: 2.1 (Boris)
% - updated display of raw image (or its negative version) (look for 2.1 occurrences).

%  03/03/2018: 2.0 (Boris)
% - removed support of structure quantities
% - now always takes 4D matrices as input (matching AOT 4.1+)

%  28/02/2018: 1.25 (Boris)
% - changes to adapt Matlab 2017 and new variable and function names
% - fixed bug in clone tracking mode (where "centroids" is NOT a grid
% field) and "gridCentroids" was not defined when "imageIn" was not
% provided as input.

%  12/10/2017: 1.24 (Boris)
% - now colors macrochaetaes in background image using "macroRNs" and "colorMacrochaetes".

%  03/08/2017: 1.23 (Boris)
% - adjustments to support plot in "cloneTracking" mode

%  18/07/2017: 1.22 (Boris)
% - added "imagePlot" as output. "imagePlot" is a 8 bit RGB color image.

%  06/07/2017: 1.21 (Boris)
% - in quantity text to plot in InfoPlotter, replaces "plus", "minus", "dot", by "+","-",".u"

%  19/01/2017: 1.20 (Boris)
% - replaced double loop over grid compartments by single loop over linear indices
% - added parameters in "DISPLAY" to be able to flip plots normally done on half animal with respect to midline to make a full one

%  13/01/2017: (Boris)
% - made marcrochaetes FaceColor "yellow" instead of "grey"

%  09/06/2016: 1.19 (Boris)
% - use of optional parameter "gridOnlyBulk" ton only display bulk values with weight = 1 (weights < 1 set to 0 in the display)

%  24/05/2016: 1.18 (Boris)
% - added optional field "nReal" in DISPLAY when the frame that should be displayed do not exist (following AOT update 2.0).

%  04/06/2015: 1.17 (Boris)
% - added MISSING factor 2 for TrQWm because of how scalar field is turned into tensor field (2D matrix case like Rho).
% - plot of a scale BAR (without circle) when plotting vectors

% 26,29/05/2015: 1.16 (Boris)
% - added xyOffset as optional parameter in "DISPLAY"
% - changed parameters names to match AIA_parameters 5.4
% - support of lagrangian grid plot for cortical distributions
% - accordingly overrides "colorInfo" and "gridColor" to respectively custom_white and light_grey when raw image is detected
% - cleaned up some old comments

% 29/04/2015: 1.15 (Boris)
% - loading of "minimalInfoDisplay" to only display time APF and scalebar (and not the quantity being plotted nor the frame number)
% - introduced "hFactor" when deciding to plot in d^-1 instead of h^-1 (formalism paper)
% - indroduced offset of [50 50] in "InfoPlotter"

% 19/04/2015: 1.14 (Boris)
% - supports empty vector [] instead of "image" => won't open a new figure (when used in full image plot mode)
% - added optional field "displayOrigin" in DISPLAY to display grid origin

% 09/04/2015: 1.13 (Boris)
% - fixed bug when Qsr was a col 2x1 vector instead of a row 1x2 vector: was overwriting Qsr as [Qsr(1) Qsr(1)]

% 08/04/2015: 1.12 (Stephane)
% - add Significance Opacity Map to apply a specific alpha opacity when ploting
%   SignificantMap can now have 4 values in the 3rd Dimension [ significanceIso, significanceDev, OpacityIso, OpacityDev ]
%   OpacityIso and OpacityDev are optionnal, if present, they apply a specified opacity factor to the plot

% 02/04/2015: 1.11 (Boris)
% - support of Lagrangian grid: requires existence of fields "Lcentroids" and "ContourIndices" in DISPLAY: Lcentroids will override
% centroids in the plot, borders of cell patches will be colored according to GRID.color.

% 26/03/2015: 1.10 (Stephane)
% - add plot of grid origin
% - correction plot macroceates
% - correction of color display when significant or not

% 18/03/2015: 1.9 (Boris)
% - display of errors (relevant for TA) with num2str with format '%0.1e' instead of precision 2 before
% - fixed plot of error (for TA) when 4D matrices were involved by now properly taking step-th slice of error matrices errorPs/DnPs

% 02/03/2015: 1.8 (Boris)
% - display of errors on balances on processes (errorPs) or cell numbers (errorDnPs) (see TA)
% - included matrix of (r)conditional values "RConds" in weights that are now AreaRatios.*RConds (when RConds exists in GRID)
% - takes SQUARE of weights to sharpen decrease at animal boundaries
% - use of transparency of lines => dropping parameter "fadeColor" and all parts involving mixing of Qcolor with it (with MixColors).
% - call to TensorData

% 25/02/2015: 1.7 (Boris)
% - removed minAEV variable and use new version of Tensor_Data (2.0)
% - skipping plot when Qname field not found in GRID

% 24/02/2015: 1.6 (Stephane)
% - plot vector using quiver3d
% - draw macrocaete if given in the structure DISPLAY
% - draw significance if given in the structure DISPLAY

% 04/11/2014 : 1.5 (Stephane)
% - manage two scale values structure for plotting. first is the isotropic scale value, second is the anisotropic scale value
% - add warning in the case of "merged" plot with two values. merged will use the isotropic value

% 15/10/2014: 1.4
% - fixed bug only taking first slice of AreaRatios when processing stacked quantities. Now get step-th slice of AreaRatios as well
% - use of weights in transparencies: opacity goes to 0 (100% transparency) when weight = 0
%       WsignOpacities = signOpacities*AreaRatios(ky,kx);

% 08/10/2014: 1.3
% - fixed bug where Qbox contains NaNs

% 08/10/2014: 1.2
% - made presence of "fadeColor" and "colorInfo" in DISPLAY optional. If not specified, now infers type of image and determines values
% accordingly.

% 06/10/2014: 1.1
% - added support of "stack" matrices possibility to plot a given timepoint by researching field "step" in DISPLAY and
% retrieving Q step-th value.

% 29/09/2014: creation