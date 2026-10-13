function [macroCoord] = LandmarkLoader(pathFolderRaw, animal, sideShort, userGridTime)
%
% [macroCoord] = LandmarkLoader(pathFolderRaw, animal, sideShort, userGridTime)
%
% Function that go search for the macrocaete coordinate file in the folder structure
% It uses regular expression in order to work on multiple version of the path
% The path still need to contain specific keywords, see the regular expression,
% and must have the structure of raw / registration / landmarks / macro.txt
% 
% version 1.2
% Stephane Rigaud
% Boris Guirao


%% Code %%

% Retrieves frame number corresponding to 16h30 to find path to macro coordinates (1.1)
AIA_call = 1; %#ok<NASGU>
run(['AIA_info_' animal ]);             % run AIA_info to retrive ... info
gridTime = userGridTime;                % overwrites value specified in AIA_parameters (1.2)
gridFrame = round(time2frame(gridTime, timeRef, frameRef, dt));
strGridFrame = num2str(gridFrame);

if strcmp(sideShort,'r'),     sideLong = ['RIGHT_' strGridFrame];   % mod 1.1
elseif strcmp(sideShort,'b'), sideLong = ['BOTH_' strGridFrame];    % mod 1.1
else                          sideLong = ['LEFT_' strGridFrame];    % mod 1.1
end

%%% Regular Expression ----------------------------------------------------
regexpRegistrationFolder = '\w*Spacetime\w*Registration';
regexpLandmarksFolder    = [animal '\w*Landmarks\w*' sideLong];
regexpMacroFile          = ['\w*Macro\w*[Cc]oordinate\w*' animal];
%--------------------------------------------------------------------------

%%% Registration Folder ---------------------------------------------------
dirRawFolder = dir(pathFolderRaw);
dirRawFolder(strncmp({dirRawFolder.name}, '.', 1)) = [];
ind = cellfun(@(x)( ~isempty(x) ), regexpi({dirRawFolder.name}, regexpRegistrationFolder));
dirRawFolder(~ind) = [];
if length(dirRawFolder) ~= 1
    disp('Error LandmarkLoader: could not find the Registration Folder!');
    return
else
    RegistrationFolder = dirRawFolder.name;
end
%--------------------------------------------------------------------------

%%% Landmarks Folder ------------------------------------------------------
dirRegistrationFolder = dir([pathFolderRaw filesep RegistrationFolder]);
dirRegistrationFolder(strncmp({dirRegistrationFolder.name}, '.', 1)) = [];
ind = cellfun(@(x)( ~isempty(x) ), regexpi({dirRegistrationFolder.name}, regexpLandmarksFolder));
dirRegistrationFolder(~ind) = [];
if length(dirRegistrationFolder) ~= 1
    disp('Error LandmarkLoader: could not find the Landmarks Folder!');
    return
else
    LandmarksFolder = dirRegistrationFolder.name;
end
%--------------------------------------------------------------------------

%%% Macro File ------------------------------------------------------------
dirLandmarksFolder = dir([pathFolderRaw filesep RegistrationFolder filesep LandmarksFolder]);
dirLandmarksFolder(strncmp({dirLandmarksFolder.name}, '.', 1)) = [];
ind = cellfun(@(x)( ~isempty(x) ), regexpi({dirLandmarksFolder.name}, regexpMacroFile));
dirLandmarksFolder(~ind) = [];
if length(dirLandmarksFolder) ~= 1
    disp('Error LandmarkLoader: could not find the Coordinate File!');
    return
else
    MacroFile = dirLandmarksFolder.name;
end
%--------------------------------------------------------------------------

%%% lock and load ---------------------------------------------------------
macroCoordPath = [pathFolderRaw filesep RegistrationFolder filesep LandmarksFolder filesep MacroFile];
macroCoord = dlmread(macroCoordPath);
%--------------------------------------------------------------------------
end

%% History %%

% 05/01/2017: 1.2 (Boris)
% - added input "userGridTime" (purposely not named "gridTime" that would be overwritten when running AIA_info)

% 08/12/2016: 1.1 (Boris)

% 09/05/2016: v1.0


