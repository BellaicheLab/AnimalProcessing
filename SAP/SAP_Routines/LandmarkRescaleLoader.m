function [moviesName,dataMacroX,dataMacroY,dataMidLin,dataNeck] = LandmarkRescaleLoader(inputFolder, halfNotum)
%
% function [moviesName,dataMacroX,dataMacroY,dataMidLin,dataNeck] = LandmarkRescaleLoader(inputFolder, halfNotum)
%
% Version 1.2
% Stephane Rigaud
% Boris Guirao

%% Code %%

nLandmarksMax = 8;
if halfNotum == 'b'
    nLandmarksMax = 16;
end

txtFiles  = dir([inputFolder filesep '*.txt' ]); % List all the .txt files in inputFolder

% Get the index list of file containing the regexp
txtFiles(strncmp({txtFiles.name}, '.', 1)) = []; % remove trash files

% Removing the parameter file from "txtFiles"(1.1)
indexParam = cellfun(@(x)( ~isempty(x) ), regexp({txtFiles.name}, '_SR_')); % 1.1 % 1.2
txtFiles = txtFiles(~indexParam); % updates txtFiles

% Finds rows of Macro, Midline and Neck in txtFiles:
indexMacro = cellfun(@(x)( ~isempty(x) ), regexpi({txtFiles.name}, 'Macro'));   
indexMidli = cellfun(@(x)( ~isempty(x) ), regexpi({txtFiles.name}, 'Midline')); 
indexNeckP = cellfun(@(x)( ~isempty(x) ), regexpi({txtFiles.name}, 'Neck'));    

% Count the number of landmark type to load 
nLandmarkType = any(indexMacro(:)) + any(indexMidli(:)) + any(indexNeckP(:));

% is there a even number of files
nTxtFiles = size(txtFiles,1);                       % Number of .txt files loaded
if mod(nTxtFiles, nLandmarkType)~=0
    fprintf('Error landmarks: Please, check the .txt files. One or more are missing.')
    return
end

nMovies    = nTxtFiles ./ nLandmarkType;
moviesName = cell(nMovies,1);
dataMacroX = NaN(nLandmarksMax,nMovies);
dataMacroY = NaN(nLandmarksMax,nMovies);
dataMidLin = NaN(3,nMovies);
dataNeck   = NaN(3,nMovies);
iMacro     = 0; % iterator on Macro txt files of animals (starting at 0 now (1.2))
iMidLine   = 0; % iterator on Midline txt files of animals (starting at 0 now (1.2))
iNeck      = 0; % iterator on Neck txt files of animals (starting at 0 now (1.2))


% for each file loaded
for n = 1:nTxtFiles 
    
    % Get landmark info
    filename = txtFiles(n).name;
    data = dlmread([inputFolder filesep filename]);
    nbLandmark = size(data,1);
    
    if strfind(filename,'Macro')==1
        % get macro coordinate data
        iMacro = iMacro + 1;
        dataMacroX(1:nbLandmark,iMacro) = data(:,1); % x coodinates of macro
        dataMacroY(1:nbLandmark,iMacro) = data(:,2); % y coodinates of macro
        % extract animal name
        [~, indMacroCoordEnd] = regexp(filename, 'Macro_XYs_'); % 1.1
        indSideStart = regexp(filename, '_side');
        indAnimal = indMacroCoordEnd+1:indSideStart-1;
        animal = filename(indAnimal);
        moviesName{iMacro}= animal;
    elseif strfind(filename,'MidLine')==1
        iMidLine = iMidLine + 1;
        dataMidLin(1,iMidLine) = data(1,2); % first click Y coordinate
        dataMidLin(2,iMidLine) = data(2,2); % second click Y coordinate
        dataMidLin(3,iMidLine) = mean([data(1,2) data(2,2)]);
    elseif strfind(filename,'Neck')==1
        iNeck = iNeck + 1;
        dataNeck(1,iNeck) = data(1,1); % first click X coordinate
        dataNeck(2,iNeck) = data(2,1); % second click X coordinate
        dataNeck(3,iNeck) = mean([data(1,1) data(2,1)]);
    end
    clear data
    
end

% cropping to minimal size (1.2)
dataMacroX = dataMacroX(1:nLandmarksMax,:); % (pxl)
dataMacroY = dataMacroY(1:nLandmarksMax,:); % (pxl)

end

%% History %%

% 06/07/2018: 1.2
% - make file managing case sensitive to avoid similar name error

% 13/04/2018: 1.1
% - now support cases where there is a parameter file in the folder
% containing the Macro, Midline, Neck txt files from clicks. Motivation was
% to create archetype from single animal directly using folder of clicks in
% order to later create fake clones for WT.
