%% Frames to process %%

startFrame = 1;       % starts @ 1        
finalFrame = 177;       % ends @ 177

%% Path to raw images %%

pathFolderRaw = 'path/to/Reference_Movie';
filenameRaw = {'Reference_Movie1_'};                  % can be multiple: {'pten_myo_' ; 'pten_baz_' ; ...}. NB: PIV will use FIRST listed
signalName = {'Cad'};                       % "Cad", "Myo", "Mud"... (start with capital, names must be used consistently between animals)
nDigits = 4;                                % number of digits that WAS used for naming RAW IMAGES.
imageFormatRaw = 'tif';                     % image extension

%Cells below MUST BE changed/actualised


%% Synchronization & Scale %%

halfNotum = 'r';                            % Chose between 'l' (left) 'r' (right) and 'b' 'both'
frameRef = 71;                              % frame # corresponding to "timeRef" determined by "TimeRegistration"              
timeRef = '20h15';                          % "timeRef" ('HH f:MM' or decimal) corresponding to "frameRef" above
dt = 5;                                     % time IN MINUTES between two frames
temperature = 29;                           % temperature (25 or 29C) at which development was filmed
yMid = [];                                 % y of midline IN PIXELS (leave empty [] if unknown)
scale1D = 0.161;                            % Length of one pixel IN MICRONS (if 1 pixel is 0.1 um enter 0.1) 
%Bin 1: 0.161, Bin 2: 0.322;

%% Box/Grid specifications (PIV, CPT, AOS, TA, SM) %%

xFactor = 1;                                % X scaling factor from "RescaleAnimals". Animals LONGER than archetype: xFactor > 1
yFactor = 1;

boxSize = [40 40]/scale1D  ./ [xFactor yFactor];  	% grid compartment size IN PIXELS [WIDTH HEIGHT]. One value => square grid
xyStart = [1103 744];                               % xy coordinates (Upper Left Corner)of FIRST compartment. If empty, starts at image center.
gridSize = [];                                      % number of compartments [ny nx]. If empty grid fills up image.


%% Path to clone Mask %% 

% cloneMaskFrame = 9;                    % frame number corresponding to clone mask
% cloneName = 'COMP';                         % name to give to clone ("a-act", "fat"...)
% path2cloneMask = 'D:\BigMovies\BIGwt2\Masks\COMP_mask_BIGwt2_0009.png'; 

%% Scale Bar & Display %%

scaleBarLength = 50;                    % scale bar length in microns
scaleBarWidth = 3;                      % scale bar width (in PIXELS). Used 3 for BIG
xyOffset = [30 70];                     % scale bar offset @ bottom right of image IN PIXELS ([30 30] for Potts)
colorBarXYWH = [0.75 0.025 0.15 0.02];    % [left, bottom, width, height] in figure units
imageFading = 0.7;                      % fading of background image for tensor maps (0.7 for eLife article)
fontSizeInfo = 18;                      % 27 TRBL8(res 200), 35 BIG_X,TRBL9,TRBL4(res 150), 55 TRBL7(res 100), 20 BIG (res 300), 40 JESUS(res 200), but 27 (res300) for cad4
imageResolution = 125;                  % 300 used for formalism article, 200 for Potts CppTD images, between 300 and 150 for CppTD images

%% "SAP_parameters" call %%

Animal = mfilename;
Animal = Animal(10:end);
SAP_parameters

