% Segmentation Pipeline Suite
if EPIcall
    runManualCorrection = 0;
    runPIV = 0;
    runSegmentation = 0;
    runCleaningFilter = 0;
    runAutoCorrection = 0;
    runTracking = 0;
end


gStart = tic;
fprintf('Processing %s with %d workers \n',animal,nbMatlabPoolWorker);
fprintf('-----------------------------------------------------------------------\n');

%% AIA call %%
% Run AIA info and AIA parameters for full path and variable loading
tStart = tic;
fprintf('Load animal SAP information ..........\t');
SAPcall = true;
evalc(['SAP_info_' animal]);
tEnd = toc(tStart);
fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));





%% Manual correction %%
if runManualCorrection
    if ~exist(pathFolderGUI,'dir')
        mkdir(pathFolderGUI);
    end
    fprintf('Manual user frame correction .........\t');
    IMAGE.pathFolderGUI = pathFolderGUI;
    IMAGE.digitsFormat = digitsFormat;
    IMAGE.rootFilename = rootFilename;
    IMAGE.segFilename = filename;
    IMAGE.imageFormatRaw = imageFormatRaw;
    IMAGE.imageFormat = imageFormat;
    IMAGE.pathFolderSeg = pathFolderRES;
    IMAGE.pathFolderRaw = pathFolderRaw;
    IMAGE.segZone = segZone;
    IMAGE.pathFolderTCT = pathFolderTCT;
    IMAGE.pathFolderONEAT = pathFolderONEAT;
    IMAGE.pathFolderONEATa = pathFolderONEATa;
    IMAGE.pathFolderONEATd = pathFolderONEATd;
    IMAGE.pathSaveFolder = pathSaveFolder;
    IMAGE.glasOn = glasbeyMask;
    IMAGE.imageSize = imageSize;
    IMAGE.ctdDisOn = ctdDisplay;
    IMAGE.pathFolderCTD = pathFolderCTD;
    IMAGE.imageSize = imageSize;
    CorrectionInterface(startFrame, finalFrame, IMAGE);
    fprintf('untimed\n');
end


%% Particle Image Velocimetry %%
if runPIV
    if ~EPIdebug
        tStart = tic;
        fprintf('Particle image velocimetry ...........\t');
        evalc('ParticleImageVelocimetry');
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        ParticleImageVelocimetry
    end
end


%% Region of Interest %%
if runRoI
    if ~EPIdebug
        tStart = tic;
        fprintf('Region of Interest ...............\t');
        evalc('ComputeRoI');
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        ComputeRoI
    end
end


%% Segmentation %%
if runSegmentation
    if dummySeg
        tStart = tic;
        fprintf('Seed Propagation Segmentation ...........\t');
        SeedPropagation
        ItkToMatlabUnionsegConvertionScript
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        if ~EPIdebug
            tStart = tic;
            fprintf('Watershed segmentation ...............\t');
            evalc('MarkerControledWatershedSegmentation');
            tEnd = toc(tStart);
            fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
        else
            MarkerControledWatershedSegmentation
        end
    end
end


%% Segmentation cleaning filter %%
if runCleaningFilter
    tmpPathFolderOUT = pathFolderCLR;
    tmpPathFolderIN  = pathFolderRES;
    if ~EPIdebug
        tStart = tic;
        fprintf('Segmentation cleanning filter ........\t');
        evalc('SegmentationCleaningFilter');
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        SegmentationCleaningFilter
    end
    copyfile(pathFolderCLR, pathFolderRES, 'f');
end

%% Auto-correction %%
% Apply N autocorrection rounds. This require a propre initiallisation done
% in the previous step (manual correction).
if runAutoCorrection
    for i = 1:nbCorrectionRound
        if ~EPIdebug
            tStart = tic;
            fprintf('Auto-Corrrection run %i ...............\t',i);
            evalc('AutocorrectionFilter');
            tEnd = toc(tStart);
            fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
        else
            AutocorrectionFilter
        end
    end
end

%% tracking %%
if runTracking
    DISPLAY.bordercell = true;
    DISPLAY.darkred = true;
    DISPLAY.darkgreen = true;
    DISPLAY.cyan = true;
    
    if ~EPIdebug
        tStart = tic;
        fprintf('Cell Tracking ........................\t');
        evalc('FilterFourPixelBlocks');
        evalc('TrackingAnalysis');
        All_FRAMES = BuildTrackingStructure(trackingFolder, startFrame, finalFrame);
        firstSegPath = [pathFolderRES filesep filename num2str(startFrame, digitsFormat) '.' imageFormat];
        ComputeColorPatches(All_FRAMES, startFrame, finalFrame, firstSegPath, digitsFormat, pathFolderGUI, DISPLAY);
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        FilterFourPixelBlocks
        TrackingAnalysis
        All_FRAMES = BuildTrackingStructure(trackingFolder, startFrame, finalFrame);
        firstSegPath = [pathFolderRES filesep filename num2str(startFrame, digitsFormat) '.' imageFormat];
        ComputeColorPatches(All_FRAMES, startFrame, finalFrame, firstSegPath, digitsFormat, pathFolderGUI, DISPLAY);
    end
end





%% Junction Tracking
if runJunctionTracking
    if ~EPIdebug
        tStart = tic;
        fprintf('Junction tracking processing ...........\t');
        evalc('JunctionTracking');
        tEnd = toc(tStart);
        fprintf('%d minutes and %f seconds\n', floor(tEnd/60), rem(tEnd,60));
    else
        JunctionTracking;
    end
end


%% Kymograph interface
if runQuantitativeInterface
    DATA.startFrame = startFrame;
    DATA.finalFrame = finalFrame;
    DATA.backupFolderPath = 'toto';
    DATA.segmentationPath = pathFolderRES;
    DATA.rawFolderPath = pathFolderRaw;
    DATA.junctionTrackPath = pathFolderJNK;
    DATA.rootFilename = filenameRaw;
    DATA.segmFilename = filename;
    DATA.digitsFormat = digitsFormat;
    DATA.rawImageFormat = imageFormatRaw;
    DATA.imageFormat = imageFormat;
    
    KYMO.ponderation = [0.5 1 0.5 ; 1 2 1 ; 0.5 1 0.5];
	KYMO.filter = [ floor(size(KYMO.ponderation,1)./2) floor(size(KYMO.ponderation,2)./2)];
    KYMO.crops = true;

    QuantitativeInterface(DATA, KYMO);
end

%% Kymograph interface
if runExtractKymographs

    KymographExtraction
    
end




%% Global time benchmark
fprintf('-----------------------------------------------------------------------\n');
gEnd = toc(gStart);
fprintf('Total process done in ................\t')
fprintf('%d minutes and %f seconds\n', floor(gEnd/60), rem(gEnd,60));

