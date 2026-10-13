function PlotTensor(EVs, CenterXY, Angles, DISPLAY)
%
% PlotTensor(EVs, CenterXY, Angles, DISPLAY)
%
% ON AN FIGURE ALREADY OPENED, will plot THE SINGLE tensor contribution corresponding to eigenvalues
% "EVs" and angles "Angles" (1X2 vectors) and centered in "CenterXY" (1X2 vector).
% Display parameters are specified in structure DISPLAY that contains
%   - Qsr               scale ratio (scalar or vecor) determining size of circle & bar
% OPTIONAL
%   - plotType          "merged", "split+" or "-", "circle", "dev+" or "-"
%   - signOpacities     only matters for "split+/-" plot: vector specifying opacities of POSITIVE and NEGATIVE disks ("FaceAlpha" patch parameter)
%   - lineColor         can a 2x3 matrix of 2 rgb colors
%   - lineWidth
%   - lineOpacity       opacity of line!
%   - EVstyles          only matters for "merged": defines styles of positive and negative ellipse axes
%   - Qname             contribution name displayed next to ellipse
%   - fontSize          its size
%   - spaceXY           space % ellipse center
%
% Version 2.3
% Boris Guirao
% Anais Bailles
% Stephane Rigaud


%% Extracting Display parameters and assigning default values to OPTIONAL parameters (2.0) %%

if isfield(DISPLAY,'Qsr')
    Qsr = DISPLAY.Qsr;
else
    disp('TensorPlotter ERROR: parameter scale ratio "Qsr" must be specified in DISPLAY')
    return
end


% OPTIONAL PARAMETERS:
if isfield(DISPLAY,'plotType')
    plotType = DISPLAY.plotType;
else
    plotType = 'split+';
end

if isfield(DISPLAY,'signOpacities')
    signOpacities = DISPLAY.signOpacities;
else
    signOpacities = [0.4 0.2]; % opacities of 1) White-Positive patch; 2) Black-Negative patches
end

if isfield(DISPLAY,'lineWidth')
    lineWidth = DISPLAY.lineWidth;
else
    lineWidth = 2;
end

if isfield(DISPLAY,'lineOpacity')
    lineOpacity = DISPLAY.lineOpacity;
else
    lineOpacity = 1; % full opacity by default
end

if isfield(DISPLAY,'lineColor')
    lineColor = DISPLAY.lineColor;
else
    lineColor = [0 0 0] ; % black by default
end

if isfield(DISPLAY,'EVstyles')
    EVstyles = DISPLAY.EVstyles;
else
    EVstyles = {'-' '--'};
end

if isfield(DISPLAY,'Qname')
    Qname = DISPLAY.Qname;
else
    Qname = 'none';
end

if isfield(DISPLAY,'fontSize')
    fontSize = DISPLAY.fontSize;
else
    fontSize = 14;
end

if isfield(DISPLAY,'spaceXY')
    spaceXY = DISPLAY.spaceXY;
else
    spaceXY = [0 0];
end


%% Plot %%

all_types = {'merged' ; 'split+' ; 'split-' ; 'circle' ; 'dev+' ; 'dev-'};      % all acceptable "type" parameters (1.4.1)
% For split+/- and circle types (1.7):
SignColors = {[1 1 1] ; [0 0 0]};                                               % WHITE -> POSITIVE isotropic part, BLACK -> NEGATIVE
thickening = 2;                                                                 % factor of thickening of bar representing deviatoric part, usually = 2


% Turns "scale_ratio" into vector if scalar (1.9):
if length(Qsr) == 1
    Qsr = [Qsr Qsr];
end

% Duplicates color if only one specified (1.10)
if size(lineColor,1) == 1
    lineColor = [lineColor ; lineColor];
end

% Duplicates lineOpacity if only one specified (2.2)
if size(lineOpacity,1) == 1
    lineOpacity = [lineOpacity ; lineOpacity];
end

% Filling display parameters for Ellipse plot (2.0)
EDISPLAY.EdgeColor = lineColor(1,:);
EDISPLAY.EdgeWidth = lineWidth;
EDISPLAY.EdgeOpacity = lineOpacity(1);

if ~isempty(Angles) && ~isnan(Angles(1))

    if strcmp(plotType, 'merged')
        
        % plot ellipse:
        a = abs(EVs(1))/2*Qsr(1);   %(v1.8)                                % a: semimajor axis in pixels
        b = abs(EVs(2))/2*Qsr(1);   %(v1.8)                                % b: semiminor axis in pixels
        Ellipse(a,b, CenterXY(1), CenterXY(2), Angles(1), EDISPLAY)        % 2.0
        
        % plot axes:
        [EVs_Xs,EVs_Ys] = GetAxesEndpoints(EVs, Angles, CenterXY, Qsr(1)); % 1.5 %(v1.8)
        
        if EVs(1) > 0 %(v2.1) (2.2)
            % positive eigenvalues:      
            patchline(EVs_Xs(:,1), EVs_Ys(:,1),'EdgeColor',lineColor(1,:), 'EdgeAlpha', lineOpacity(1),'LineWidth',lineWidth,'LineStyle',EVstyles{1}); % 2.0
        else
            % negative eigenvalues:  
            patchline(EVs_Xs(:,1), EVs_Ys(:,1),'EdgeColor',lineColor(1,:), 'EdgeAlpha', lineOpacity(1),'LineWidth',lineWidth,'LineStyle',EVstyles{1}); % 2.0 
        end
        if EVs(2) > 0 %(v2.1) (2.2)
            % positive eigenvalues:
            patchline(EVs_Xs(:,2), EVs_Ys(:,2),'EdgeColor',lineColor(1,:), 'EdgeAlpha', lineOpacity(1),'LineWidth',lineWidth,'LineStyle',EVstyles{1}); % 2.0
        else
            % negative eigenvalues:
            patchline(EVs_Xs(:,2), EVs_Ys(:,2),'EdgeColor',lineColor(1,:), 'EdgeAlpha', lineOpacity(1),'LineWidth',lineWidth,'LineStyle',EVstyles{1}); % 2.0
        end

    elseif ismember(plotType, all_types)
        
        % defines NEW traceless EVs:
        Trace = EVs(1)+EVs(2);
        iso_EV = Trace/2;
        dev_EVs = EVs-Trace/2;                                                                                           % removes 1/2*trace from each EVs
        
        % Checking dev_EVs scale is the same as circle: OK
        % dev_EVs(1) = iso_EV;
        % dev_EVs(2) = -iso_EV;
        
        % plots circle:
        if strncmp(plotType, 'split',5) || strcmp(plotType, 'circle')
            
            % Completion of EDISPLAY (2.0)
            EDISPLAY.FaceColor = SignColors{1}; 
            EDISPLAY.FaceOpacity = signOpacities(1); 
            if iso_EV<0
                EDISPLAY.FaceColor = SignColors{2};      
                EDISPLAY.FaceOpacity = signOpacities(2);
            end
            R = abs(iso_EV)/2*Qsr(1);          %(v1.8)                                                                        % R: radius in pixels
            Ellipse(R,R, CenterXY(1), CenterXY(2), Angles(1), EDISPLAY)
        end
        
        % plots ONE deviatoric eigenvalue:
        [dev_EVs_Xs,dev_EVs_Ys] = GetAxesEndpoints(dev_EVs, Angles, CenterXY, Qsr(2));  %(v1.8)
        ThickLineWidth = lineWidth*thickening;
        if strcmp(plotType, 'dev+') || strcmp(plotType, 'split+')
            
            % ONLY PLOTS positive eigenvalue: (2.2)
            dev_EVs_pos_loc = find(dev_EVs > 0);
            patchline(dev_EVs_Xs(:,dev_EVs_pos_loc), dev_EVs_Ys(:,dev_EVs_pos_loc),'EdgeColor',lineColor(2,:),'EdgeAlpha',lineOpacity(2),'LineWidth',ThickLineWidth,'LineStyle',EVstyles{1}); % 2.0
        
        elseif strcmp(plotType, 'dev-') || strcmp(plotType, 'split-')
            
            % ONLY PLOTS NEGATIVE eigenvalue: (2.2)
            dev_EVs_neg_loc = find(dev_EVs < 0);
            patchline(dev_EVs_Xs(:,dev_EVs_neg_loc), dev_EVs_Ys(:,dev_EVs_neg_loc),'EdgeColor',lineColor(2,:),'EdgeAlpha',lineOpacity(2),'LineWidth',ThickLineWidth,'LineStyle',EVstyles{1}); % 2.0
        end
    else
        disp('"Tensor_Plotter" ERROR: parameter "plotType" must be picked among:');
        disp(all_types)
        return
    end
end

% Plots Qname when specified:
if ~strcmp(Qname,'none')
    text(CenterXY(1) + spaceXY(1), CenterXY(2) + spaceXY(2), Qname,'HorizontalAlignment','right','VerticalAlignment','middle','FontSize', fontSize,'Color',lineColor)
end



%% History %%

% 26/05/2015: 2.3 (Boris)
% - renamed variables more properly

% 08/04/2015: 2.2 (Stephane)
% - add double lineOpacity for iso and dev part significance

% 17/03/2015: 2.1 (Stephane)
% - correction of usage of patchline in "merge" case

% 02/03/2015: 2.0 (Boris)
% - thorough use of "patchline" to support transparency of lines!
% - drastically reduced number of arguments: all display parameters now gathered in structure "DISPLAY"
% - adjustments to latest version of Ellipse (1.3) that supports edge transparency as well
% - stopped plotting a point at ellipse center
% - defined a lot of default values for display parameters

% 24/02/2015: 1.10 (Boris)
% - supports the use of 2 rgb colors stacked in "colors"

% 18/02/2015: 1.9 (Boris)
% - now turns "scale_ratio" into vector if entered as scalar

% 04/11/2014: 1.8 (Stephane)
% - change scale_ratio by scale_ratio(1) or scale_ratio(2) corresponding to scale ratio of the isotropic and anisotropic values

% 03/04/2014: 1.7
% - adapted Anais' modifications to improve tensor display: now uses parameter "sign_opacities" to display black/white
% disks according to sign of tensor isotropic part and with variable opacity, always with thick lines.

% 18/12/2013: 1.6 REMOVED "BETA" FROM "Tensor_Plotter_BETA" (v1.5)

% 18/11/2013: 1.5
% - moved formerly nested function "GetAxesEndpoints(EVs)" outside as a
% separate function GetAxesEndpoints(EVs, Angles, CenterXY, scale_ratio)

% 10/10/2013: 1.4.2

% 22/07/2013: 1.4.1
% - overhaul to chose beween several types of plots (ellipse, circle & bar...)
% - lowered value of thickening to 2 from 8

% 1/02/2012: 1.3
% - added cases "deviatoric+" or "deviatoric-".

% 31/01/2012: 1.2
% - added input "type" = 'raw' (plots full tensor ellipse) OR just the 'deviatoric' part with a single line (positive eigenvalue)
% - in deviatoric case, uses line_width*4 to plot lines.
% NB: just commented parts ensuring display of circle and negative eigenvalue in deviatoric case.

% 17/01/2012:
% - added "EV_styles" as input

% 13/01/2012: 1.1
% - removed title display

% 27/11/2011: creation
