%% Episeg launcher script
clear; close all; clc;  % sanity clean
EPIcall = false;            % do not modify
EPIdebug = true;           % do not modify
nbMatlabPoolWorker = 12;    % Number of parallel worker used for PIV and other filter
                            % NB: Be cautious of the number you decide, your computer has limits


                            
                            
                            
                            
animal = 'TomGFP2';      % Animal generic name to process, reference to an AIA_info file
                      % NB: Please keep those name simple, e.i. wt1, trbl4, ...
                         
                         








%% Alternative Step - Manual correction
% Allows user correction of the segmentation. 
% Key usage:
% [ a ] - display/hide added junction
% [ d ] - display/hide deleted junction
% [ b ] - contrast modifier
% [ s ] - display/hide color patches if FinalProcessing is done
% [ j ] - jump to the specific frame number
% [ o ] - change deletion tool size
% [ l ] - lock/unlock interface
% [ h ] or [ p ] - "hand" mode to move image at constant zoom
%
runManualCorrection = 0;
segZone = [];





%% Step 1 - Particle Image Velocimetry
runPIV = 0;
% Compute PIV analysis of the movie 
% NB1: parameter defining grid size is defined in "SAP_parameters" file.
% NB2: only needs to be computed once.



%% Step 2 - Compute ROI
runRoI = 0;
minHoleSize = 2000; % (in um) increase if too much holes, decrease otherwise



%% Step 3 - Compute Marker-Controled Watershed
runSegmentation = 0;
noiseTolerance = 20;   % to determined on a subset of the movie
dummySeg = false;         % if true: manual seed click and automatic propagation
% Compute marker controled watershed segmentation on the images
% If found, use roi file provided in SEG, else segment the entire image




%% Step 4 - Segmentation cleaning filter
runCleaningFilter = 0;
% Remove cells with two or less neighbors






%% Step 5 - Auto correction of the segmentation
runAutoCorrection = 0;
nbCorrectionRound = 1; % advice number of round 1 to 6 
% Automatic correction of the segmentation using tracking inconsistancy.
% NB: Idealy need optimal initialisation by manually correcting the 3 first
% frames of the movie using the manual correction.





%% Step 6 - Preparing movie for Boris pipeline
runTracking = 0;
% Run a full tracking on the segmented movie and compute interface help
% NB: it should always be the last thing to run in an analysis






%% Step 7 -Junction and Kymographs analysis

runJunctionTracking = 0;

runExtractKymographs = 0;
kymoKernel = [0.5 1 0.5 ; ...
               1  2  1  ; ...
              0.5 1 0.5];
          
runQuantitativeInterface = 0;








%% /!\ Call segmentation suite /!\
SegmentationSuite


