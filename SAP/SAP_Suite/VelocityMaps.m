% VelocityMaps
%
% Calculates and/or draw maps of velocity, deformation rate and rotation rate.
%
% Anais Bailles
% Stephane Rigaud
% Boris Guirao

version = '4.4';

%% Define folders %%

disp(' '); disp(' ');
disp(['VM' ' (' version  '): processing "' Animal '" between frames # ' num2str(startFrame) ' and ' num2str(finalFrame)]);
disp('----------------------------------------------------------------------------');

% Overriding L grid when modeVM = PIV
% gridFolderAOTVM = gridFolderAOT;	% default
if strcmp(gridType,'L') && strcmp(modeVM,'PIV')
    
    warnHandle = warndlg('VM run in "PIV" mode only supports EULERIAN grids so far!! Processing corresponding Eulerian grid.','WARNING!');
    gridSpecsVM = substr(gridSpecs, 0, 1, 'E');     % replaces "L" by "E"
    gridSpecsVM = substr(gridSpecsVM, 0, -6);       % removes last characters specifying grid time hAPF when using L grid
    
%     gridFolderAOTVM = [pathFolderAOT filesep gridSpecsVM];
elseif strcmp(gridType,'E') % 4.4
    gridSpecsVM = gridSpecs; % using defined "gridSpecs"
elseif strcmp(gridType, 'L')
    gridSpecsVM = gridSpecs;
end
gridFolderAOTVM = [pathFolderAOT filesep gridSpecsVM];

% Creates AOT backup folder if doesn't already exist
if ~exist(gridFolderAOTVM,'dir')
    mkdir(gridFolderAOTVM);
end

% "alltime" backup mat file DIRECTLY saved in AOT folder:
outputPath = [gridFolderAOTVM filesep 'alltime_' filenameVM '.mat'];


%% Generating "UVMmodeStack", "AreaRatiosStack" from PIV or cell tracking (4.0, 4.2, 4.3) %%

if ~exist(outputPath,'file')
    
    if strcmp(modeVM,'PIV')
        
        disp('Calculating Velocity, and Areas Ratio, based on *PIV*...')
        [UVMmodeStack, AreaRatiosStack, MissingFrames] = PIV2GridInterpolator(SAPparameterFile); % mod 4.3
    else
        disp('Calculating Velocity, Inertia, and Areas Ratio, based on *cell tracking*...')
        [UVMmodeStack, AreaRatiosStack, MissingFrames] = TrackingVelocityField(SAPparameterFile); % mod 4.3
    end
    
    % Storage into "VMbackup" before saving:
    VMbackup.(['U' modeVM 'Stack']) = UVMmodeStack; % mod 4.3
    VMbackup.AreaRatiosStack = AreaRatiosStack;
    VMbackup.MissingFrames = MissingFrames;
    VMbackup.startFrame = startFrame;
    VMbackup.finalFrame = finalFrame;
    
    save(outputPath,'-struct','VMbackup')
end

%% Calculating velocity gradients and updating "AreaRatiosStack" (4.0, 4.2, 4.3) %%

if ~exist('VMbackup','var')
    VMbackup = load(outputPath);
end

if (strcmp(modeVM,'PIV') && ~isfield(VMbackup,'EpsilonPIVStack'))... 
|| (strcmp(modeVM,'CT')  && ~isfield(VMbackup,'EpsilonCTStack'))        % mod 4.3
     
    UVMmodeStack = VMbackup.(['U' modeVM 'Stack']); % mod 4.3
    AreaRatiosStack = VMbackup.AreaRatiosStack;
    
    load(SAPparameterFile);
    
    if exist(pathGridDefFile,'file')
        GRID_DEF = load(pathGridDefFile);
    else
        disp('"VelocityMaps" ERROR: "pathGridDefFile" could not be found! Stopped execution.')
    end
    
    [EpsilonVMmodeStack, OmegaVMmodeStack, AreaRatiosStack] = CalculateGradient(UVMmodeStack, AreaRatiosStack, GRID_DEF, scale1D);
    
    % Creating variables with "modeVM" in name (4.3)
    eval(['Epsilon' modeVM 'Stack = EpsilonVMmodeStack;']);
    eval(['Omega' modeVM 'Stack = OmegaVMmodeStack;']);
    
    save(outputPath,['Epsilon' modeVM 'Stack'],['Omega' modeVM 'Stack'],'AreaRatiosStack','-append'); % mod 4.3
%     save(outputPath,'EpsilonVMStack','OmegaVMStack','AreaRatiosStack','-append')
    % NB: overwrites "AreaRatiosStack" with their Min version
    
else
    disp(['VM WARNING: alltime backup "' 'alltime_' filenameVM '.mat' '" already exists! Skipped execution.'])
end

% closing warndlg figure if still open:
try
    close(warnHandle);
catch err
end

disp('----------------------------------------------------------------------------');

%% History

% 05/11/2018: 4.4 (Boris)
% - fixed bug where "gridFolderAOTVM" was not defined in the case of an
% Eulerian grid

% 17/09/2018: 4.3 (Boris)
% - now using parameter "modeVM" to add suffix to U,Epsilon and Omega
% (hence removing the previous VM suffix).

% 06/09/2018: 4.2 (Boris)
% - every U, Epsilon, Omega gained a "VM" suffix so as not to be confused
% with AOS quantities

% 11/06/2018: 4.1 (Boris)
% - only input parameter of "TrackingVelocityField" is now "SAPparameterFile"

% 31/05/2018: 4.0 Overhaul (Boris)
% - NOW supports L grids in "CT" mode

% 30/05/2018: 3.1 (Boris)
% - removed all parts related to inertia calculation
% - integrated script "FormatVMOutputs"
% - removed SAP parameter "replotVM"

% 29/05/2018: 3.0 (Boris)
% - changes to adapt it to new SAP structure

% 28/04/2016: 2.2 (Stephane)
% - integrate the PIV2GridInterpolator allowing to map the PIV analysis on to the animal grid
%   the interpolation of the PIV on the GRID is then considered as equivalent as the Velocity
%   computed from the cell tracking
% - small modifications for code cleaning and pipeline adjusting to take the PIVmode changes into account
% - armonisation with frameintervalmaker usage

% 16/02/2016: 2.1
% - solved conflict with other AIA programs due to overwritting of "pathFolder", therefore renamed "pathAverageFolder"

% 14/01/2016: 2.0 changed name to "VelocityMaps" (Boris)
% - INTEGRATION IN AIA_parameters

% 13/01/2016: 1.8 (Boris)
% - support of PIVmode = 1 when we don't have segmented images
% - in PIV mode, changed folder for saving output images and mean backup

% 24/02/2015: 1.7 (Boris)
% - thorough use of "filesep"

% 21/01/2015: 1.6
% - fixed bug when nb time point in average == 1
% - change grid construction process from AIA_parameters to Velocity_Maps_Maker

% 30/10/2014 : 1.5
% - style: add comment and clean the code
% - fix background display
% - print always in png

% 30/10/2014 : 1.4
% - add formating function for output
% - fix Index missing one frame

% 13/10/2014 : 1.3
% - call to "Tracking_Velocity_Field"
% - use of "replotVM" instead of "replot_mode"

% 10/10/2014 : 1.2
% - adjustments to make it run on Boris computer
% 03/09/2014 : 1.1 adapted to AIA_parameters
% 09/04/2014 : 1.0 creation