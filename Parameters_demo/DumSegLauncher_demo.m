%% Dummy Seed Propagation Pipeline
%% Episeg launcher script
clear; close all; clc;  % sanity clean
EPIcall = false;            % do not modify
EPIdebug = false;           % do not modify
nbMatlabPoolWorker = 12;    % Number of parallel worker used for PIV and other filter
                            % NB: Be cautious of the number you decide, your computer has limits

% FYI - Folder structure should look like the following:
% SEG_XXXX
% |- results_XXXX
%     |-Seg_XXXX_YYYY.png
%     |-Seg_XXXX_YYYY.png
% |- roi_XXXX
%     |-Roi_XXXX_YYYY.png
%     |-Roi_XXXX_YYYY.png
%
% XXXX : animal name
% YYYY : frame numbering
                            
                            
                            
                            
animal = 'movie7bottom';      % Animal generic name to process, reference to an AIA_info file
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
%
runManualCorrection = 1;

%% Step 1 - Particle Image Velocimetry
runPIV = 0;
% Compute PIV analysis of the movie 
% NB1: Grid size parameter defined in AIA_info file.
% NB2: Only need to be compute once.


%% Step 2 - Compute segmentation
% Output_initialisation folder must contain the initialisation seed of the 
% first image (either segmentation or dots, binary image)
runDummySeedSegmentation = 0;


%% Step 3 - Preparing movie for Boris pipeline
runTracking = 1;
% Run a full tracking on the segmented movie and compute interface help
% NB: it should always be the last thing to run in an analysis


% %% Step 4 - Junction Tracking
% % Re-use the cell tracking and extend it to the junction
% % C++ program - C18
% runJunctionTracking = 0;

% %% Step 5 - Quantitative Interface
% % Run the Quantitative Interface
% % It provide information on junction and generate Kymographs
% runQuantitativeInterface = 0;





%% /!\ DO NOT MODIFY - Call segmentation suite - DO NOT MODIFY /!\
DummyCall = true;  % Silence Episeg variables
SegmentationSuite  % call for SegmentationSuite

