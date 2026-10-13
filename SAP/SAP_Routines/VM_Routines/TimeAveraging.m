function [STACK, GRID] = TimeAveraging(SAPparameterFile)
%
% [STACK, GRID] = TimeAveraging(Index, spaceScale, gridOverlap, scale1D, timeScale, timeOverlap, GRID, V, areasRatio)
%
% Calculate and plot velocity, deformation rate and rotation rate from PIV
% or center of mass tracking.
%
% Index = indices of pictures to take into account
% space_scale = spatial correlations window size in pixel 128
% grid_overlap = grid overlap to smooth values
% time_scale = temporal correlations window size in pictures relative number (1pic = 5min) 24
% time_overlap = 12 ; % progress in time (in frame number)
% V areasRatio Inertia : tracking input. Can be omitted : will produce PIV outputs;
%
% version 3.2 (formerly "Time_Averaged_Quantities")
% Anais Bailles
% Stephane Rigaud
% Boris Guirao


%% Initialisation %%

load(SAPparameterFile); %#ok<LOAD>

if exist(pathGridDefFile,'file')
    GRID = load(pathGridDefFile);
end

%%% variable definition -----------------------------------------------
firstFrame = startFrame;
lastFrame  = finalFrame; % 2.3
nx         = GRID.size(1,2); % grid size x
ny         = GRID.size(1,1); % grid size y
nBoxes     = nx * ny;        % number of grid compartment
dGrid_x = (1 - gridOverlap) * scale1D * spaceScale(1); % spacing parameter IN MICRON
dGrid_y = (1 - gridOverlap) * scale1D * spaceScale(2); % spacing parameter IN MICRON
%--------------------------------------------------------------------------

%%% Determination of timepoints --------------------------------------------
[frameAverageMin, frameAverageMax] = MakeFrameIntervals(firstFrame, lastFrame, timeScale, timeOverlap); % 2.3, 3.1
frameAverageMax = frameAverageMax - 1;  % -1 because interframe, to avoid getting outside boundaries
nInterFrames = size(frameAverageMin,1); % 2.4
% NB: time averages are done between "frameAverageMin" and "frameAverageMax" = frameAverageMin + round(interframeWidth - 1);
%--------------------------------------------------------------------------

%%% output definition -----------------------------------------------------
DeformationStack   = cell(ny, nx, nInterFrames);
RotationStack      = cell(ny, nx, nInterFrames);
weightStack       = zeros(ny, nx, nInterFrames);
weightNeighborStack = zeros(ny, nx, nInterFrames);
VelocityStack     = cell(ny, nx, nInterFrames);
%--------------------------------------------------------------------------

%%% sliding time window verification --------------------------------------
% TODO
%--------------------------------------------------------------------------

%% Iteration processes over inter frames %%

progressbar(['TimeAveraging iteration over ' GRID.Animal ' frames...']); % 2.5

for it = 1:nInterFrames
    
%     %%% indexes convertion ------------------------------------------------
%     % convertion from frame iteration to stack iteration
%     h = frameAverageMin(it) - firstFrame + 1;
%     % Time window parameters :
%     j = h + round(timeScale - 1);
%     % NB: interval calculation make loose one frame,
%     %     we need to adapt the time_scale to interval (-1)
%     %----------------------------------------------------------------------
    
%     %%% indexes convertion ------------------------------------------------ DOESN'T WORK!!
%     % convertion from frame iteration to stack iteration
%     h = frameAverageMin(it);
%     % Time window parameters :
%     j = frameAverageMax(it);
%     % NB: interval calculation make loose one frame,
%     %     we need to adapt the time_scale to interval (-1)
%     %----------------------------------------------------------------------
    
    %%% indexes convertion (3.1)------------------------------------------------
    % convertion from frame iteration to stack iteration
    h = frameAverageMin(it) - frameAverageMin(1) + 1;
    % Time window parameters :
    j = frameAverageMax(it) - frameAverageMin(1) + 1;
    %----------------------------------------------------------------------
    
    %% Compute temporal and spatial mean of <V> %%  
    % temporary variable initialisation
    V_x_t       = NaN(ny, nx);
    V_y_t       = NaN(ny, nx);
    Velocity_xy = cell(ny, nx);
    % for each compartment of the grid
    for b = 1:nBoxes
        % turns linear index into grid coordinate
        [ky, kx] = ind2sub([ny nx], b); 
        % ponderate mean of the value
        V_x_noNaN = RemoveNaNs(V.v_x(ky,kx,h:1:j) .* AreaRatios(ky,kx,h:1:j)); % 3.1
        if isempty(V_x_noNaN) == 0
            V_x_t(ky,kx) = sum(V_x_noNaN) / (sum(AreaRatios(ky,kx,h:1:j),3)) ;
        end
        V_y_noNaN = RemoveNaNs(V.v_y(ky,kx,h:1:j) .* AreaRatios(ky,kx,h:1:j));% 3.1
        if isempty(V_y_noNaN) == 0
            V_y_t(ky,kx) = sum(V_y_noNaN) / (sum(AreaRatios(ky,kx,h:1:j),3)) ;
        end
        % Reshape velocity to fit tensorCorrelator
        Velocity_xy{ky, kx} = [V_x_t(ky,kx) V_y_t(ky,kx)];
    end
    % Save
    VelocityStack(:,:,it) = Velocity_xy;
    
    
    %% Compute temporal and spatial mean of <AR> %%
    area_ratio_t = mean(AreaRatios(:,:,h:1:j),3);
    weightStack(:,:,it) = area_ratio_t ;
    area_ratio_t_neighb = mat_local_min(area_ratio_t);
    weightNeighborStack(:,:,it) = area_ratio_t_neighb ;    
    
    %% Compute Deformation and Rotation rate from <V> %%

    % gradient of velocity
    [dx_vx, dy_vx] = gradient(V_x_t, dGrid_y, dGrid_x);
    [dx_vy, dy_vy] = gradient(V_y_t, dGrid_y, dGrid_x);
    
    
    % temporary variable initialisation
    Deformation = cell(ny,nx);
    Rotation    = cell(ny,nx);
    % for each compartment of the grid
    for b = 1:nBoxes
        % turns linear index into grid coordinate
        [ky, kx] = ind2sub([ny nx], b);
        % Compute Deformation and Rotation
        Deformation{ky,kx} = [2*dx_vx(ky,kx) dx_vy(ky,kx)+dy_vx(ky,kx) ...
                              dx_vy(ky,kx)+dy_vx(ky,kx) 2*dy_vy(ky,kx)];
        Rotation{ky,kx} = (dx_vy(ky,kx) - dy_vx(ky,kx));
        Deformation{ky,kx} = 1/2 * Deformation{ky,kx};
        Rotation{ky,kx}    = 1/2 * Rotation{ky,kx};
    end
    % Save
    DeformationStack(:,:,it) = Deformation ;
    RotationStack(:,:,it)    = Rotation ;    
    
    progressbar(it/nInterFrames) % 2.5
end

%%% Save all mean values --------------------------------------------------
STACK.DeformationStack   = DeformationStack;
STACK.RotationStack     = RotationStack;
STACK.weightStack       = weightStack;
STACK.weightNeighborStack = weightNeighborStack;
STACK.VelocityStack     = VelocityStack;
%--------------------------------------------------------------------------

end

%% History

% 28/05/2018: 3.1 (Boris)
% - changes to adapt it to new SAP structure
% - removed all parts related to inertia calculation
% - changed variable "_mem" suffix to "Stack "

% 27/04/2016: 3.0 (Stephane)
% - remove PIV mode accordingly with the modification in VelocityMap
%   now, if PIV, we interpolate the PIV on the grid and assume it equivalent to V (see PIV2GridInterpolator)
%   the rest of quantities are processed from V as if we are in Tracking mode
% - PIV mode flag is now used to skip Inertia calculation, not possible without the tracking
% - Code cleaning and variable renaming

% 15/01/2016: 2.5 changed name to "TimeAveraging" (Boris)
% - support of mode_PIV = 1: update input argument GRID with some quantities required in PlotField
% - fixed weight issue with PIV time averaging (division by "time_scale" instead of time_scale+1)
% - added argument "PIV_grid" and removed the part that was checking that the entered value of box_size were matching a PIV size.
% - turned all double iterations over compartments into linear iterations.

% 31/10/2014 : 2.4
% - fix warning caused by nInterFrames not beeing a scalar
% - adapt time_scale to frame interval calculation and not frame calculation

% 10/10/2014 : 2.3
% - replaced all size(uq,2) with nx, all size(uq,1) with ny, and do not load nx an ny from GRID anymore
% - removed all hard-coded references to start frame being #9

% 05/09/2014 : 2.2 parfor loop
% 03/09/2014 : 2.1 adapted to AIA_parameters
% 21/03/2014 : 2.0 functionalization in order to automatize scale changes :
%   symmetry test supressed, gradient test suppressed, split in two, changed
%   name
% 27/02/2014 : 1.2 PIV plots added, weighted plots, test plots, possibility not to replot all the backup pictures
% 10/02/2014 : 1.1 average and not sum of displacements anymore, values in micrometers, overlapping grid.
% 31/01/2014 : 1.0 creation