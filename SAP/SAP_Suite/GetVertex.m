% GetVertex
%
% NB: can either be running normally or in parallel by turning the "for" loop into a "parfor" one (l22)
%
% Version 2.1
% Boris Guirao
% GOYA Yuki

%% Creation of directories (2.0)

% creates subfolder to store "NEG.Unionseg" images:
NEGfolder = [pathFolderGV filesep 'NEG.Output_results'];
mkdir(NEGfolder)

% Creating backup and frame folders (2.0)
backupFolder = [pathFolderGV filesep 'Backups'];
frameFolder = [pathFolderGV filesep 'Frames'];

if ~exist(backupFolder,'dir')
    mkdir(backupFolder);
end
if ~exist(frameFolder,'dir')
    mkdir(frameFolder);
end


%% Exectution of "GetVertex.exe" over frames %%

failed = [];                                                % builds a list of frames that could not be analyzed
why = {};                                                   % adding why it has failed
frames2processMod = frames2process;                         % 2.0
progressbar(['GV iteration over ' Animal ' frames...']);    % Progressbar initialization (2.0)

% Loop over frames
for n = frames2process

    raw_fn = [rootFilename num2str(n,digitsFormat)];
    disp(' '); disp(' ');
    disp(['Running "GetVertex" on "' raw_fn '"...']);
    disp('--------------------------------------------------------------------------------------------------------------');    
    %%% Makes NEGATIVE of segmented image:
    inputSeg = [filename num2str(n,digitsFormat) '.' imageFormat]; % 2.1
%     inputSeg = ['Unionseg_' raw_fn '.png'];
    fullInputSeg = [pathFolder filesep inputSeg];
    imageNEG = imread(fullInputSeg);
    imageNEG = ~imageNEG;
    % NB: removed all functions trying to remove 4block pixels: THIS SHOULD BE TAKEN CARE OF BEFORE USING getVERTEX!!
    
    % Check if any 4-pixel blocs left
    % NB: should not occur anylonger after "FourPixelBlockFilter"
    %------------------------------------------------------------------------
    [fy, fx] = fourpixelblockdetector(imageNEG);   
    % found !
    if ~isempty(fx)                         % just check one coordinate
        disp('four-pixel block found!');
        for k = 1:numel(fx)
           xyString = ['@(x=' num2str(fx(k)) ',y=' num2str(fy(k)) ')'];
           disp(xyString) 
        end
        failed =[failed; n];                              %#ok<*AGROW>
        why = [why; ['four pixel block ' xyString]];   
        continue;
    end
    %------------------------------------------------------------------------
     
    %%% path to raw image:
    inputRaw = [raw_fn '.' imageFormatRaw];         % 1.13
    fullRawPath = [pathFolderRaw filesep inputRaw]; % "pathFolderRaw" replaced "raw_path" (1.11)
    
    %% vertex
   
    pathDataFile = [backupFolder filesep filenameGV '_' num2str(n,digitsFormat) '.txt'];      % 2.0
    pathVertexImage = [frameFolder filesep filenameGV '_' num2str(n,digitsFormat) '.png'];    % 2.0
     
    %% Execute  "GetVertex.exe"

    if ~exist(pathDataFile,'file')
        
        % Temporaly writes negative segmented image:
        fprintf('Making and saving negative segmented image...')
        outputSeg = ['NEG.' inputSeg];
        fullOutputSeg = [NEGfolder filesep outputSeg];
        imwrite(imageNEG,fullOutputSeg);
        fprintf('Done.\n')
        
        cmd = [GVexe ' "' fullRawPath '" "' fullOutputSeg '" "' pathVertexImage '" "' pathDataFile '"']; % added missing " (1.7); use "GVexe" (2.1)
        system(cmd);
        
        % check if output generated
        if ~exist(pathVertexImage,'file') || ~exist(pathDataFile,'file')
            
            disp('Failed !')
            failed=[failed; n];
            why = [why; 'no "vertex" image or no "dat.txt" file (likely due to an infinite loop: check Matlab command window!)'];
            %why = [why; 'no "vertex" image or no "dat.txt" file'];   %#ok<AGROW>
            
        elseif exist(pathDataFile,'file') % check if data not empty
            
            dirinfos=dir(pathDataFile);
            if dirinfos.bytes==0
                disp('Failed !')
                failed =[failed; n];
                why = [why; 'empty "dat.txt" file (likely due to separate cell leading to inconsistency in numbers of cells, edges and vertices: check Matlab command window and image!)'];
                % why = [why; 'empty "dat.txt" file'];   %#ok<AGROW>
            end
        end
        
    else
        frames2processMod = setdiff(frames2processMod, n); % removes this frame from list of processed frame in this run (2.0)
        disp(['GV WARNING: data file "' filenameGV '_' num2str(n,digitsFormat) '.txt' '" already exists => skipped "GetVertex" execution for this frame.'])
    end
    
    % Progressbar update (2.0)
    nFramesProcessed = sum(frames2process <= n);
    progressbar(nFramesProcessed/nFrames);

    disp('--------------------------------------------------------------------------------------------------------------');
end


%% Saving list of failed frames (1.5) %%

% % testing:
% failed = [1;2;3];
% why = {'four pixel block @ x=1, y=2'; 'no "vertex" image or no "dat.txt" file' ; 'empty "dat.txt" file'};

fprintf('Saving log of failed frames...')
failed_why = [num2cell(failed) why];
if ~isempty(failed)
    filenameLog = [pathFolderGV filesep 'failed_frames_between_#' num2str(min(frames2processMod)) '-' num2str(max(frames2processMod)) '.txt']; % 1.11, 2.0
    dlmcell(filenameLog, failed_why,'      ');
end
fprintf('Done.\n')

%% Deleting "NEG" folder (2.0)

if exist(NEGfolder,'dir')
    fprintf('Deleting "NEG" folder...')
    rmdir(NEGfolder,'s');
    fprintf('Done.\n')
end

%% History %%

% 30/04/2018: 2.1
% - changes to make it work with SAP

% 02/03/2018: 2.0
% - stopped using parallel processing that often caused pb
% - now skipping GetVertex execution when backup "txt" file already exists.
% - created subfolders "Backups" and "Frames" like for other programs
% - renamed former "..._dat.txt" files that are now "GV_animal_XXX.txt" files
% - renamed former "..._Vertex.txt" files that are now "GV_animal_XXX.png" files
% - renamed "NEG" seg image folder and images
% - now delete the "NEG" folder at the end of execution
% - added progress bar (thanks to removal of parallel processing)
% - renamed "filename" into "filenameLog" to avoid overwritting the one
% defined in AIA_info.

% 26/02/2018: 1.14
% - adjustments to work with Matlab 2017.

% 18/07/2016:
% - fixed bug using '.tif' to load raw images instead of ['.' imageFormatRaw]

% 28/05/2015: 1.13
% - changed parameter names to match AIA 6.0

% 21/05/2015: 1.12 PARALLELIZATION
% - parallelized execution with parfor
% - "digits" became "nDigits"

% 08/10/2014: 1.11: small adjustments for integration into AIA workflow
% - "folder_path_in" became "pathFolderGV"
% - "seg_path" became "pathFolder"

% 23/07/2014: 1.10
% - use of filesep for mac compatibility

% 21/02/2014: 1.9 changed name to "GetVertex" from "run_GetVertex"
% - removed all user-defined paths and filenames: now called from "STP_runner" where they are defined
% - removed all creation of folders. Now all done in STP_runner
% - "seg_input_path" became "seg_path"
% - "seg_output_path" became "folder_path_in" (since it's STP input folder)

% 21/02/2014: 1.7
% - removed use of function trying to remove 4pixel blocks: THIS SHOULD BE TAKEN CARE OF BEFORE USING getVERTEX:
%       Four_Pixel_Vertex_Removal(image)
%       image = sunnyremover(~image);
% - added some comments on failed images in saved txt log file.

% 29/08/2013: 1.6
% - possibility to manually define the parent output folder "seg_output_path"

% 15/05/2013: 1.5
% - automatically looks for segmented images in default folder and creates "Output_getVertex" folder
% - saving list in a txt file of frame numbers for which vertex analysis has failed, and why.
% - saving "NEG_Unionseg" images in a specific subfolder

% 2013-01-23: 1.4 (Yuki)
% - 4-pixel blocs filters added.
% - outputs check added.

% 30/10/2012: 1.3
% - adjustments on paths and filenames

