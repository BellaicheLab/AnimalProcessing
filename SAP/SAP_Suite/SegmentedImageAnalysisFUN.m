function SegmentedImageAnalysisFUN(AIAbackupPath)
%
% Performs static analysis of segmented image at levels of single cells (cell areas, perimeters...) and sides (side
% intensities, chord lengths...).
% NB: as of 2.6+, REMOVED CORRECTION OF 4-PIXEL BLOCKS: ALL SEGMENTED IMAGES MUST GO THROUGH "FourPixelBlocksFilter"
%     AS LAST STEP OF THE SEGMENTATION PROCESS.
%
version = '3.4';
% Boris Guirao

%% Loading AIA_parameters %%

load(AIAbackupPath);


%% Overriding parameter values according to "noDisplay" and "noStatistics" values (2.2) %%

if noDisplay == 1
    % Cells:
    displayRNsAndVs = 0;
    displayArea = 0;                
    displayAnisotropy = 0;        
    displayNeighbor = 0;             
    displayChordDisorder = 0;
    displayPolarityMode = 0;
    % Sides:
    displayChordLength = 0;
    displayIntensity = 0;
    displaySideIntensityDisorder = 0;
end

if noStatistics == 1
    % xls files:
    cellStatistics = 0;
    sideStatistics = 0;
    vertexStatistics = 0;
    % histograms
    chordHistograms = 0;                                                                                                         
    neighborHistograms = 0;
end


%% Creation of Directories 

% pathFolderSIAfull = [pathFolderSIA SIAboxTag];          % 2.20
% filenameSIAfull = [filenameSIA SIAboxTag];              % 3.4

if ~exist(pathFolderSIAfull,'dir')
    
    mkdir(pathFolderSIAfull);                          % 2.20
end

%%% Backup folder:
backupFolder = [pathFolderSIAfull filesep 'Backups']; 
mkdir(backupFolder)                                  % creates a directory named as 'Backups' in pathSaveFolder

%%% "Vertex" Folder:
anyStatistics = 0;
if vertexStatistics == 1
    anyStatistics = 1;
    VertexFolder = [pathFolderSIAfull filesep 'Vertices'];
    mkdir(VertexFolder)                             % creates a directory named as 'Sides' in pathSaveFolder
end

% Initialize:
anyDisplay = 0;

%%% "Frames" and subfolders for cells (mod 2.16, 2.19, 3.0):
%--------------------------------------------------------------------------------------
% Default frame folders (used when when nFrames =1)
frameFolder = [pathFolderSIAfull filesep 'Frames']; % only one frame folder for cells and sides (3.0)

% Default folders:
frameFolderRNsAndRVs = frameFolder;
frameFolderAreas = frameFolder;
frameFolderAnisotropies = frameFolder;
frameFolderNeighbors = frameFolder;
frameFolderChordDisorders = frameFolder;
frameFolderSideIntensityDisorders = frameFolder;
frameFolderPolarityModes = frameFolder;

frameFolderChordLengths = frameFolder;
frameFolderIntensities = frameFolder;

intensityFolder = frameFolder;

mkdir(frameFolder); % always create it (3.0)

if nFrames >= nFrameMin2CreateFolders && ~allImagesInSameFoler % (3.0)
    
    frameFolderRNsAndRVs = [frameFolder filesep 'RNs&Vs'];
    frameFolderAreas = [frameFolder filesep 'Areas'];
    frameFolderAnisotropies = [frameFolder filesep 'Anisotropies'];
    frameFolderNeighbors = [frameFolder filesep 'Neighbors'];
    frameFolderChordDisorders = [frameFolder filesep 'ChordDisorders'];
    frameFolderSideIntensityDisorders = [frameFolder filesep 'SideIntensityDisorders'];
    frameFolderPolarityModes = [frameFolder filesep 'PolarityModes'];
    
    frameFolderChordLengths = [frameFolder filesep 'ChordLengths'];
    frameFolderIntensities = [frameFolder filesep 'Intensities'];
    
    intensityFolder = [frameFolder filesep 'SideIntensity'];
    mkdir(intensityFolder)
end
        
% Creates requested subfolders (mod 3.0)
if displayRNsAndVs == 1 || displayArea==1 || displayAnisotropy ==1 || displayNeighbor==1 || ...
        displayChordDisorder  == 1 || displaySideIntensityDisorder || displayPolarityMode == 1 || ...
        displayChordLength  == 1 || displayIntensity  == 1  % 3.0

    anyDisplay = 1;     % 1 or more dipslay selected:

    if nFrames >= nFrameMin2CreateFolders && ~allImagesInSameFoler % (3.0)
        
        if displayRNsAndVs == 1           
            mkdir(frameFolderRNsAndRVs)
        end
        if displayArea == 1           
            mkdir(frameFolderAreas);
        end
        if displayAnisotropy == 1           
            mkdir(frameFolderAnisotropies);
        end
        if displayNeighbor == 1            
            mkdir(frameFolderNeighbors)
        end
        if displayChordDisorder == 1           
            mkdir(frameFolderChordDisorders)
        end
        if displaySideIntensityDisorder == 1            
            mkdir(frameFolderSideIntensityDisorders)
        end
        if displayPolarityMode == 1
            mkdir(frameFolderPolarityModes)
        end
        if displayChordLength  == 1
            mkdir(frameFolderChordLengths)
        end       
        if displayIntensity  == 1
            mkdir(frameFolderIntensities)
        end
    end
end
%--------------------------------------------------------------------------------------


%%% Statistics folders on Cells:
%--------------------------------------------------------------------------------------
if cellStatistics == 1
    anyStatistics = 1;
    %%% "Cells" Folder (2.15):
    cellStatisticsFolder = [pathFolderSIAfull filesep  'CellStatistics'];
    mkdir(cellStatisticsFolder)    
    
    if nFrames >= nFrameMin2CreateFolders   
        
        % Single cell data folder:
        cellDataFolder = [cellStatisticsFolder filesep 'CellData'];
        mkdir(cellDataFolder);

        %%%% Histogram:
        if neighborHistograms == 1
            histNeighborsFolder = [cellStatisticsFolder filesep 'HistNeighbors'];
            mkdir(histNeighborsFolder);
        end
    else
        cellDataFolder = cellStatisticsFolder; 
        histNeighborsFolder = cellStatisticsFolder;
    end   
end
%--------------------------------------------------------------------------------------

%%% Statistics folders on Sides:
%--------------------------------------------------------------------------------------
if sideStatistics == 1
    
    anyStatistics = 1;
    
    %%% "Sides" Folder (2.15):
    sideStatisticsFolder = [pathFolderSIAfull filesep 'SideStatistics'];
    mkdir(sideStatisticsFolder);
    
    if nFrames >= nFrameMin2CreateFolders 
        
        % Single cell data folder:
        sideDataFolder = [sideStatisticsFolder filesep 'SideData'];
        mkdir(sideDataFolder);
        
        %%%% Histograms (mod 2.15):
        if chordHistograms  == 1
            histChordLengthsFolder = [sideStatisticsFolder filesep 'HistChordLengths'];
            mkdir(histChordLengthsFolder)
        end
    else
        sideDataFolder = sideStatisticsFolder;
        histChordLengthsFolder = sideStatisticsFolder;
        histSideLengthsFolder = sideStatisticsFolder;
    end
end
%--------------------------------------------------------------------------------------

% Date:
today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style. Look up date for details
todayFull = datestr(now);

%%% Saving txt file to specify program version and parameters (mod 3.1)
%--------------------------------------------------------------------------------------
txtFilename = [today '_SIA_' version '.txt'];

% Writing main parameters in txt file
parameterCell = {
    'Main Parameters:',[];
    [],[];
    'SIAboxMode = ', SIAboxMode;                                    
    'allImagesInSameFoler = ', allImagesInSameFoler;  
    'skelDilatation = ' skelDilatation;
    'skelDilatationBG = ', skelDilatationBG;
    [],[];
    'BOX Parameters:',[];
    [],[];
    'reloadBox = ', reloadBox;
    'predefinedBoxData = ', predefinedBoxData;
    'oneCellFrontier = ', oneCellFrontier};

dlmcell([pathFolderSIAfull filesep txtFilename], parameterCell,' ');
%--------------------------------------------------------------------------------------

%% Initializations %%

scale2D = scale1D^2;      % square value for area scaling calculated from above value
q = 0;                      % counter initialization new
iterationIndex = 0;        % initialize iteration index

% Number of raw images TO PROCESS FOR POLARITY ANALYSIS (mod 2.15):
filenameRawMod = cell(nRawImages,1);
for r = 1:nRawImages
    filenameRawMod{r} = FormatFilename(filenameRaw{r}); % first removes last '_', then crops it to its first 15 characters.
end

% Cells:
if cellStatistics == 1
    nColCellStats = 35 + 3* nRawImages;                                 % 3 per raw image: cell side length disorder: mean + std + ratio
    globalCellStatisticsCC = zeros(nFrames, nColCellStats);           % will store each frame overall statistics
    globalCellStatisticsFLC = zeros(nFrames, nColCellStats);
    globalCellStatisticsNBC = zeros(nFrames, nColCellStats);
    globalnNeighborsCC = zeros(nFrames, nNeighborsMax);
end

% Sides:
if sideStatistics == 1
    nColSideStats = 6 + 5 * nRawImages;                                % 5 per raw image: chord angles: mean + std + R, intensity: mean + std.
    globalSideStatisticsCS = zeros(nFrames, nColSideStats);
    globalSideStatisticsCFLS = zeros(nFrames, nColSideStats);
    globalSideStatisticsACS = zeros(nFrames, nColSideStats);
    globalSideStatisticsFLS = zeros(nFrames, nColSideStats);       
    globalSideStatisticsBFLS = zeros(nFrames, nColSideStats);      
    globalSideStatisticsAFLS = zeros(nFrames, nColSideStats);        
    globalSideStatisticsBS = zeros(nFrames, nColSideStats);        
    globalSideStatisticsABS = zeros(nFrames, nColSideStats);         
    globalSideStatisticsNBS = zeros(nFrames, nColSideStats);
    globalSideStatisticsANBS = zeros(nFrames, nColSideStats);    
end

% Vertices:
if vertexStatistics == 1
    nColVertexStats = 5;
    globalVertexStatisticsCV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsCFLV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsNCV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsFLV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsBFLV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsBV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsACV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsANCV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsAFLV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsABV = zeros(nFrames, nColVertexStats);
    globalVertexStatisticsABulkV = zeros(nFrames, nColVertexStats);
end

% Area and neighbor disorder (Phi):
allPhiAreas = zeros(nFrames, 1);
allPhinNeighbors = zeros(nFrames, 1);

% Progress bars initialization (mod 3.4):
if nFrames > 1 && SIAboxMode == 0                  % only display progress when nFrames > 1
    progressDisplay = 1;
    progressbar(['SIA iteration over ' Animal ' frames...']); % specifying animal (2.14)
else
    progressDisplay = 0;                                                  % progress won't be displayed
end

% Initialization of "path2SelectedImage" and quantities stored in BOX (mod 3.1):
path2SelectedImage = '';
if SIAboxMode % checks if box use (2.4.5)
    BOX.XYs = [];
    BOX.Choice = [];
    BOX.MatrixIn = [];
    BOX.MatrixOut = [];
end
% NB: will be overwritten if reload_box = 1


%%  ITERATION OVER FRAME NUMBERS


for n = frames2process                                          % use of "frames2process" (2.15)
    
    
    When = datestr(now,15);                                             % specifies the date and time. 15 new in 1.5
    iterationIndex = iterationIndex +1;                                 % increment of iteration index. 1.8b
    fn = num2str(n,digitsFormat);   
    fnBackupFile = [backupFolder filesep filenameSIAfull '_' fn '.mat'];   % defines future backup file name (2.20), use "filenameSIAfull" (3.4)
  
    %% REPLOT vs NOT REPLOT %%
    
    if ~exist(fnBackupFile,'file') % checks NON-existence of backup about to be generated BEFORE actual execution (2.14)
        
        
        %% Loading of nth segmented image %%
        
        %%% Display info regarding frame being processed:
        disp(' '); disp(' ');
        disp([SIAmode ' ' version  ': processing "' Animal '" frame # ' fn ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);
        disp('---------------------------------------------------------------------------------');                                                                
        
        %%% All images now assumed to be in same folder, white cells-black membranes (formerly "Fanny-like" images) and binary:
        segFilename = [pathFolder filesep filename num2str(n,digitsFormat) '.' imageFormat];
        if exist(segFilename,'file')                                       % check for existence of file
            segImage = imread(segFilename);                                   % loads the segmented images
            imageSize = size(segImage);                                        % updating image size in case not a real movie (Martial images) (2.19)
        else
            disp(['Segmented image "' segFilename '" not found.'])
            disp('Stopped SIA execution.')
            return                                                          % exit if not found
        end
        
        %%% Numbering of image regions (Relative Numbers RN) (2.4.0, moved here 3.4):
        imageLabels = bwlabel(segImage,4);                                % Assigns a unique number in each frame to each region
        
        
        
        %% USE OF BOX MODE OR NOT %%
        
        if SIAboxMode == 0                                                    
            
            %% Loads raw fluorescence imageS (mod 2.15):
            for r = 1:nRawImages
                rawImage = imread([pathFolderRaw  filesep filenameRaw{r} num2str(n,digitsFormat) '.' imageFormatRaw]); 
                assignin('base',['rawImage_' filenameRawMod{r}], rawImage);
            end
            
            
            %% Building "Skeleton" matrix (2.3.1) AND image labeling (2.4.0) (mod 2.9,2.12) %%
            
            skeletonPixelsListPath = [pathFolderRaw filesep 'Output_Mtracking' filesep 'skeletonPixelsList_' num2str(n) '.txt'];  % 2.12
            
            if exist(skeletonPixelsListPath,'file') % 2.12
                
                %%% Building "Skeleton" from "skeletonPixelsList_n.txt" (2.3.0)
                %-------------------------------------------------------------------------------------------------------
                tic
                % Loading "skeletonPixelsList_n.txt" file:
                disp(['Building "Skeleton" matrix from "skeletonPixelsList_' num2str(n) '.txt" file...']);
                try
                    SkeletonC = dlmread(skeletonPixelsListPath);
                catch err
                    disp(['Could not find file at location: ' '"' skeletonPixelsListPath '"']);
                    disp('Please respect folder organization set in segmentation phase.');
                    disp('Stopping program...')
                    return
                end
                % adding 1 to whole first column (because Matlab starts @ pixel 1, C++ @ pixel 0):
                SkeletonC(:,1) = SkeletonC(:,1) + 1;
                % determining n_neighbors
                pixNeighborsTF = ~ismember(SkeletonC,0);                                                                  % finds non-zero locations
                nPixNeighbors = sum(pixNeighborsTF,2)-1;                                                                % -1 because of first column
                % replaces zero locations with NaNs:
                SkeletonC(~pixNeighborsTF) = NaN;
                % Finalize Skeleton:
                SkeletonC = [SkeletonC  nPixNeighbors];                                                                   %#ok<AGROW>
                % Dropping the C (2.9):
                Skeleton = SkeletonC;
                toc
                clear SkeletonC skelIndicesC; % 3.1
                %-------------------------------------------------------------------------------------------------------
                
            else                               
                
                %%% Direct determination of "Skeleton" matrix %%
                %-------------------------------------------------------------------------------------------------------
                %%% Getting linear indices of pixels making up image skeleton (ind_skel):
                imageSkeleton = ~segImage;                                                  % take image negative: borders == 1
                skelIndicesM = sort(find(imageSkeleton));                                    % indices of pixels making up skeleton
                
                %%% Determining linear indices of pixels neighboring each
                %%% skeleton pixels AND corresponding cell numbers:
                [indPixSkel, indPixNeighbors] = ixneighbors(segImage, imageSkeleton);     % gets indiceS and neighboring indices of skeleton
                indPixSkelAndNeighbors = [indPixSkel indPixNeighbors];             % makes a 2 col matrix
                indPixSkelAndNeighborsSorted = sortrows(indPixSkelAndNeighbors,1);  % sort elements according to ascending pixel index
                indPixSkel = indPixSkelAndNeighborsSorted(:,1);                       % updates
                indPixNeighbors = indPixSkelAndNeighborsSorted(:,2);
                neighbors = imageLabels(indPixNeighbors);                                % get cell numbers correponding to neighboring indices
                
                
                %%% LOOP USING PARALLEL COMPUTING:
                %--------------------------------------------------------------
                % matlabpool must have been opened previously
                disp(['Parallel determination of "Skeleton" matrix using ' num2str(nLabs) ' labs... ']);  
                pixNeighborsNaN = NaN(1,4);
                tic
                spmd
                    CDindSkel = codistributed(skelIndicesM, codistributor1d(1));             % codistributes "ind_skel": slices it to spread it evenly on the "nlabs" labs
                    LindSkel = getLocalPart(CDindSkel);                                % part of "ind_skel" on this lab L
                    LnPixSkel = length(LindSkel);                                     % gets corresponding length
                    LSkeleton = NaN(LnPixSkel, 6);                                     % create local part of Skeleton
                    for p = 1:LnPixSkel
                        pix = LindSkel(p);                                               % gets index of pth pixel in image
                        LocInindPixSkel = find(indPixSkel == pix);                   % gets indiceS of pixel pix in "ind_pix_skel"
                        pixNeighbors = unique(neighbors(LocInindPixSkel));            % only keeps one occurence of each number
                        pixNeighbors = pixNeighbors(2:end);                              % removes 0 from the list
                        nPixNeighbors = length(pixNeighbors);
                        pixNeighborsMod = pixNeighborsNaN;
                        pixNeighborsMod(1:nPixNeighbors) = pixNeighbors;              % version of "pix_neighbors" with NaNs completing columns
                        LSkeletonPthRow = [pix  pixNeighborsMod  nPixNeighbors];     % builds line p
                        LSkeleton(p,:) = LSkeletonPthRow;                               % fills up Skeleton line p
                        
                        % No progress bar in parallel computing
                    end
                end
                % Merging all parts from all labs to make up full "Skeleton":
                SkeletonM = [];
                for lab = 1:nLabs
                    SkeletonM = [SkeletonM ; LSkeleton{lab}];                        %#ok<AGROW>
                end
                % Dropping the M (2.9):
                Skeleton = SkeletonM;
                toc
                clear SkeletonM skelIndicesM; % 3.1
                %-------------------------------------------------------------------------------------------------------
            end
            
            % Breaking down "Skeleton" columns (3.1)
            skelPixIndices = Skeleton(:,1);             % list of pixel indices making up skeleton
            skelPixNeighborInfo = Skeleton(:,2:5);      % columns 2-5 contain all info on neighboring pixels for each skel pixel
            skelPixnNeighbors = Skeleton(:,6);          % number of neighboring pixels with a region number assigned (if =2, belongs to a side; =3 to a vertex...)
            
            clear Skeleton nPixNeighbors;
            
            %% Dertermination of Border cells %%
            
            %%% creates a border frame matrix M_border (1s on borders, 0s elswhere):
            borderMat = MakeBorderFrame(segImage);
            borderMatIndices = find(borderMat);                                                                              % 2.3.1
            
            %%% Determination of border cells
            borderRNs = unique(imageLabels(borderMatIndices)); % 3.0
            borderRNs = RemoveZeros(borderRNs);
             
            clear borderMat; % 3.1
            
            %% Completion of 3 cell populations: First layer and Core cells %%
            
            % NB: determination carried out without calling vertices, ie based on real neighbors sharing at least one pixel
            
            %%% First layer cells (FL_cells) (mod 3.0):
            borderRNsFoundTF = ismember(skelPixNeighborInfo, borderRNs);               % in this array, replaces cell number with 1 if cell is a BC, 0 otherwise
            rowsWithBorderRNsTF = any(borderRNsFoundTF,2);                          % crops previous array into a vector with 1 if a 1 lays in the row, 0 otherwise
            nonCoreRNs = unique(skelPixNeighborInfo(rowsWithBorderRNsTF,:));           % gets all numbers of all cells laying in lines where a BCell was found (=> non core cells)
            nonCoreRNs = RemoveNaNs(nonCoreRNs);                                    % removes NaNs from the list (3.0)
            FLRNs = setdiff(nonCoreRNs, borderRNs);                                 % building list of First layer cells
            
            %%% Core cells (Core_cells):
            allRNs = unique(imageLabels);                                       % all cell numbers
            allRNs = allRNs(find(allRNs));                                %#ok<FNDSB> % removes 0 from the list
            coreRNs = setdiff(allRNs, nonCoreRNs);
            
            %%% Non border cells:
            nonBorderRNs = sort(setdiff(allRNs, borderRNs));
            
            %%% Total number of cells:
            nCells = max(allRNs);
                      
            %%% Buils structure "cell_CATEGORIES":
            cellCATEGORIES.coreRNs = coreRNs;
            cellCATEGORIES.FLRNs = FLRNs;
            cellCATEGORIES.borderRNs = borderRNs;
            cellCATEGORIES.nonBorderRNs = nonBorderRNs;
            
          
            %% Filling up "Vertices" %%
            
            %%% finding all vertices (mod 3.1):
            SkeletonVertexLoc = find(skelPixnNeighbors >= 3);
            SkeletonThreeVertexLoc = find(skelPixnNeighbors == 3);
            SkeletonFourVertexLoc = find(skelPixnNeighbors == 4);

            %%% Vertex numbers:
            nVertices = length(SkeletonVertexLoc);
            vertexNumbers = (1:nVertices)';
            
            %%% Vertex indices:
            vertexIndices = skelPixIndices(SkeletonVertexLoc); % use of skelIndices (3.1)
            
            %%% Vertex types:
            vertexnCells = skelPixnNeighbors(SkeletonVertexLoc); % 3.1
            threeVertexLoc = find(vertexnCells == 3);
            fourVertexLoc = find(vertexnCells == 4);
            
            %%% Vertex cells:
            vertexCellsMat = skelPixNeighborInfo(SkeletonVertexLoc,:);         % keeps the NaNs when only 3 neighbors
            
            %%% Lists of 3 and 4vertex numbers:
            threeVertices = vertexNumbers(threeVertexLoc);
            fourVertices = vertexNumbers(fourVertexLoc);
            
         
            %% Filling up "edgeVertices" %%
            
            %%% indices of cell sides without vertices:
            SkeletonSideLoc = find(skelPixnNeighbors == 2);     % does not get sides made by real vertices (that have 3+ cell numbers as neighbors then) (mod 3.1)
            allSideIndices = skelPixIndices(SkeletonSideLoc);        % INDICES IN IMAGE OF ALL PIXELS MAKING UP SIDES **WITHOUT VERTICES** % use of skelIndices (3.1)
            
            %%% Edge vertices:
            skeletonEdgeIndices = intersect(skelPixIndices, borderMatIndices);                                                  % finds indices of ALL skeleton pixels on the edge of image (2.3.1)
            edgeVertexIndices = intersect(skeletonEdgeIndices, allSideIndices);                % only keeps indices of pixels of cell borders meeting image edge
            % NB: DO NOT CONTAIN REGULAR 3-VERTICES ON THE EDGE, NOR SERIES OF PIXELS ALINED ALONG EDGE
            [~,edgeVertexIndicesLocInSkeleton] = ismember(edgeVertexIndices, skelPixIndices); % gets index of edge vertices in "Skeleton", mod 3.1
            
            %%% Edge Vertex numbers:
            nEdgeVertices = length(edgeVertexIndices);
            edgeVertexNumbers = (nVertices + 1:nVertices + nEdgeVertices)';
                    
            %%% Vertex cells (removed "Border_cell_check"):
            edgeVertexVellsMat = skelPixNeighborInfo(edgeVertexIndicesLocInSkeleton,:);   % keeps all columns (and the NaNs)
            
            clear skelPixnNeighbors; % 3.1
            
            %% Building "allVertices" and structure "VERTICES" (mod 3.0) %%
            
            %%% Reformatting vertex quantities for all vertices:
            allVertexNumbers = [vertexNumbers ; edgeVertexNumbers];
            allVertexIndices = [vertexIndices ; edgeVertexIndices];
            allVertexCells = [vertexCellsMat ; edgeVertexVellsMat];
            % getting number of cells meeting at each vertex (replacing "allVertexTypes") (3.0)
            allVertexnCells = sum(~isnan(allVertexCells),2);
            % XY coordinates:
            [allVertexYsPixels, allVertexXsPixels] = ind2sub(imageSize, allVertexIndices);          % all_vertex_Ys  = Row I, all_vertex_Xs = Col J
            allVertexXYs = [allVertexXsPixels allVertexYsPixels] * scale1D;                        % rescaling
            
            %%% Start building vertex_CATEGORIES:
            allVertexCATEGORIES.bulkVertices = vertexNumbers;              % all vertices that are not edge vertices
            allVertexCATEGORIES.edgeVertices = edgeVertexNumbers;
            allVertexCATEGORIES.threeVertices = threeVertices;
            allVertexCATEGORIES.fourVertices = fourVertices;
            
            %%% Defining STRUCTURE "VERTICES":
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            VERTICES.Numbers = allVertexNumbers;                                 % vector
            VERTICES.Indices = allVertexIndices;                                 % vector
            VERTICES.Cells = allVertexCells;                             % matrix (N_all_vertices x 4)
            VERTICES.nCells = allVertexnCells;                                     % vector (3.0)
            VERTICES.XYs = allVertexXYs;                                         % matrix (X Y at scale)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
       
            %% DETERMINATION OF CELL AND SIDE PROPERTIES %%
            
            % NB: Major improvement % <2.0: use of regionprops only once !!
                        
            %%% Use of "regionprops" ONLY ONCE AND IN CONNECTIVITY 4:
            imageCC = bwconncomp(segImage,4);
            statAllRegions = regionprops(imageCC,'Area', 'Centroid','MajorAxisLength','MinorAxisLength','Orientation', 'PixelIdxList', 'Perimeter');  % WARNING: ORDERING OF MATLAB OUTPUT
            statAllRegionsCellArray = (struct2cell(statAllRegions))';                                                                                    % conversion to a cell of 7 columns
            
            %%% Cell numbers:
            cellNumbers = allRNs;
            %%% Cell Areas AT SCALE:
            cellAreas = cell2mat(statAllRegionsCellArray(:,1)) * scale2D;
            %%% Cell Centroids AT SCALE:
            cellXYs = cell2mat(statAllRegionsCellArray(:,2)) * scale1D;
            %%% Cell 'MajorAxisLength','MinorAxisLength','Orientation':
            cellMjorAxisLengths = cell2mat(statAllRegionsCellArray(:,3)) * scale1D;
            cellMinorAxisLengths = cell2mat(statAllRegionsCellArray(:,4)) * scale1D;
            cellOrientations = cell2mat(statAllRegionsCellArray(:,5));
            cellAnisotropies = ones(nCells,1) - cellMinorAxisLengths./cellMjorAxisLengths;
            %%% Cell indices making up regions:
            cellIndices = statAllRegionsCellArray(:,6);
            %%%  Cell Perimeters AT SCALE:
            cellPerimeters = cell2mat(statAllRegionsCellArray(:,7)) * scale1D;
            
            clear imageCC statAllRegions statAllRegionsCellArray; % 3.1
            
            %%% Iteration over cells (regions):
            % Initialization of "cell" quantities:
            cellNeighbors = cell(nCells,1);
            cellnNeighbors = zeros(nCells,1);
            cellVertices = cell(nCells,1);
            cellnVertices = zeros(nCells,1);
            cellContourIndices = cell(nCells,1);
            cellDilatedContourIndices = cell(nCells,1);
            cellContourChordLengths = zeros(nCells,1);
            cellSides = cell(nCells,1);
            cellnSides = zeros(nCells,1);
            cellChordDisorders = zeros(nCells,1);
            cellMs = zeros(nCells,4);                                      
            cellnLinks = zeros(nCells,1);                                   
            cellIs = NaN(nCells,4);                                          
            cellIanisotropies = NaN(nCells,1);                              
            cellIorientations = NaN(nCells,1);                               
            cellVs = NaN(nCells,4);                                          
            cellVpolarities = NaN(nCells,1);                                
            cellVorientations = NaN(nCells,1);                               
            for r = 1:nRawImages
                assignin('base', ['cellSideIntensityDisorders' signalName{r}], []); % use of "signalName" (3.0), no "_" (3.3)
                assignin('base', ['cellBGintensities' signalName{r}], []); 
                assignin('base', ['cellPolarityModes' signalName{r}], []);  
            end
            
            % Initialization of "Sides" quantities:
            nSides = 0;
            nSidesMax = 4*nCells;                           % overestimates number of sides to pre-build arrays (2.4.0)
            sideCells = NaN(nSidesMax,2);           % will store couple of cell RNs corresponding to this side
            sideVertices = NaN(nSidesMax,2);
            sideVertexIndices = NaN(nSidesMax,2);
            sideIndices = cell(nSidesMax,1);
            sideDilatedIndices = cell(nSidesMax,1); % dilated sides remain the same regardless of raw image
            for r = 1:nRawImages
                assignin('base',['sideIntensities' signalName{r}],[]); % use of "signalName" (3.0)
            end
                        
                %% REGULAR LOOP OVER CELLS: DETERMINING SIDES (mod 3.0) %%
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            tic
            disp('Determining sides... ');
            for i = 1:nCells
                
                %%%% Get pixel indices of cell i contour (mod 3.0):
                ithCellFoundTF = ismember(skelPixNeighborInfo, i);   % in this array, puts 1s where cell i was found in "Neighborhood_info", 0s elsewhere
                ithCellFoundRowsTF = any(ithCellFoundTF,2);                % puts 1s in rows where 1 was found
                ithCellCountourIndices = skelPixIndices(ithCellFoundRowsTF);   % indices of cell i contour pixels IN IMAGE, use of skelIndices (3.1)
                
                %%%% Getting cell i neighbors (mod 3.0):
                ithCellNeighbors = unique(skelPixNeighborInfo(ithCellFoundRowsTF,:));
                ithCellNeighbors = RemoveNaNs(ithCellNeighbors);
                ithCellNeighbors = setdiff(ithCellNeighbors, i);                   % removes cell i from the neighbor list
                ithCellnNeighbors = length(ithCellNeighbors);
                % NB: NEIGHBORS DETERMINED WITHOUT INVOLVING VERTICES!!
                
                %%%% Vertex numbers belonging to cell i:
                ithCellVertexIndices = intersect(ithCellCountourIndices, allVertexIndices);
                [~, ithCellVertices] = ismember(ithCellVertexIndices, allVertexIndices); % get cell i vertex numbers. NB: index location in "All_vertices" is equivalent to the vertex number
                ithCellnVertices = length(ithCellVertices);
                
                %%%% Determination of Cell i Sides:
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Crops quantities to ith Cell (mod 3.0):
                ithCellNeighborhoodInfo = skelPixNeighborInfo(ithCellFoundRowsTF,:);                  % Only keeps columns 1 (pix index) and 6 (number of neighboring cells)              
                
                % get neighbor with higher numbers (to avoid repetitions):
                higherNeighbors = ithCellNeighbors(ithCellNeighbors > i);         % iteration over higher neighbor number so as not to iterate the same side twice
                nHigherNeighbors = length(higherNeighbors);
                if nHigherNeighbors ~= 0
                    for j = 1:nHigherNeighbors
                        
                        jthNeighbor = higherNeighbors(j);
                        jthNeighborLocTF = ismember(ithCellNeighborhoodInfo, jthNeighbor);     % in "Neighborhood_info_cell_i", puts 1s where neighbor_j was found, 0s elsewhere
                        % WARNING: PUTING Skeleton_cell_i INTRODUCES ERRORS SINCE SOME NUMBERS COULD BE FOUND IN COLUMNS 1 AND 6
                        jthNeighborRowsTF = any(jthNeighborLocTF, 2);
                        ijSideIndices = ithCellCountourIndices(jthNeighborRowsTF);                % *** IMPORTANT: indices of ALL pixels making up side i-j ***
                        
                        % Checks indices and numbers of vertices involved in this side:
                        [ijSideVertexIndices, ~, ijSideVertexIndicesLoc] = intersect(ijSideIndices, ithCellVertexIndices);
                        verticesInvolved = ithCellVertices(ijSideVertexIndicesLoc);                                        % get numbers of all vertices involved
                        nVerticesInvolved = length(verticesInvolved);
                        
                        if nVerticesInvolved <= 2 % (REGULAR CASE nVerticesInvolved = 2)
                            
                            nSides = nSides + 1;
                            sideCells(nSides,:) = [i jthNeighbor];
                            sideIndices{nSides} = ijSideIndices';
                            
                            % Dilatating sides and calculating side mean intensity (mod 2.15):
                            ijSideDilatedIndices = SideDilator(imageSize, ijSideIndices, skelDilatation);
                            sideDilatedIndices{nSides} = ijSideDilatedIndices';
                            for r = 1:nRawImages
                                % Name this image variables:
                                rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);
                                sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % use of "signalName" (3.0)
                                % Calculate mean intensity:
                                ijSideMeanIntensity = mean(rawImage(ijSideDilatedIndices));
                                sideIntensities = [sideIntensities ; ijSideMeanIntensity];                   %#ok<AGROW>
                                % Update variables:
                                assignin('base',['sideIntensities' signalName{r}],sideIntensities)
                            end
                            
                            if nVerticesInvolved == 1                            % 4-vertex OR REGULAR 3-VERTICES ON IMAGE EDGES OR Circle cell with one 3-vertex
                                if length(ijSideIndices) > 1                         % Pseudo-circle cell: circle cell connected by a single pixel
                                    disp(['Case "pseudo-circle" cell ("nVerticesInvolved = 1") encountered for side # ' num2str(nSides)  ', cell # ' num2str(i) ', and neighbor # ' num2str(jthNeighbor)])
                                end
                                sideVertices(nSides,:) = [verticesInvolved verticesInvolved];                           % WILL BE ONLY ONE NUMBER REPEATED TWICE !!
                                sideVertexIndices(nSides,:) = [ijSideVertexIndices ijSideVertexIndices];               % WILL BE ONLY ONE NUMBER REPEATED TWICE !!
                                
                            elseif nVerticesInvolved == 0                        % Circle cell without vertex
                                disp(['Case "circle" cell ("nVerticesInvolved = 0") encountered for side # ' num2str(nSides)  ', cell # ' num2str(i) ', and neighbor # ' num2str(jthNeighbor)])
                                sideVertices(nSides,:) = [NaN NaN]; 
                                sideVertexIndices(nSides,:) = [NaN NaN]; 
                                
                            else                                                   % NORMAL CASE: nVerticesInvolved = 2
                                sideVertices(nSides,:) = verticesInvolved';
                                sideVertexIndices(nSides,:) = ijSideVertexIndices';
                            end
                            
                            %%%% 2 neighbors sharing side containing > 2 vertices: SIDE MADE UP BY MULTIPLE PARTS:
                        elseif nVerticesInvolved > 2
                            
                            disp(['Case "nVerticesInvolved > 2" encountered for cell # ' num2str(i) ', neighbor # ' num2str(jthNeighbor) ' and vertices # ' num2str(verticesInvolved')])
                            ijSideImage = MakeMatrix(imageSize, ijSideIndices, 1);
                            ijCC = bwconncomp(ijSideImage,8);                   % gets connected components in connectivity 8
                            nPartsijSide = ijCC.NumObjects;                    % gets n parts of this side
                            ijSideIndicesAllParts = ijCC.PixelIdxList;            % gets indices of each parts (cell)
                            
                            % Iteration over each part found (could be just one single part):
                            for p = 1:nPartsijSide
                                
                                pthPARTijSideIndices = ijSideIndicesAllParts{p}; % indices of this part
                                nPixPthPART = length(pthPARTijSideIndices);
                                
                                % Checks indices and numbers of vertices involved IN THIS PART p OF SIDE IJ:
                                [pthPARTijSideVertexIndices, ~, pthPARTijSideVertexIndicesLoc] = intersect(pthPARTijSideIndices, ithCellVertexIndices);
                                pthPARTverticesInvolved = ithCellVertices(pthPARTijSideVertexIndicesLoc);                                            % get numbers of all vertices involved
                                nPthPARTVerticesInvolved = length(pthPARTverticesInvolved);
                                
                                %%% CASE 1: side part made up by a single pixel(vertex):
                                if nPthPARTVerticesInvolved == 1
                                    
                                    if nPixPthPART == 1                           % checks this part is indeed made up by a single pixel
                                        nSides = nSides + 1;
                                        disp(['     Side part # ' num2str(p) '/' num2str(nPartsijSide) ', case "nPthPARTVerticesInvolved == 1" encountered for side # ' num2str(nSides)...
                                            ', cell # '  num2str(i) ', neighbor # ' num2str(jthNeighbor) ' and vertices # ' num2str(pthPARTverticesInvolved')])
                                        sideCells(nSides,:) = [i jthNeighbor];
                                        sideIndices{nSides} = pthPARTijSideIndices';
                                        
                                        % Dilatating sides and calculating side mean intensity (mod 2.15):
                                        pthPARTijSideDilatedIndices = SideDilator(imageSize, pthPARTijSideIndices, skelDilatation);
                                        sideDilatedIndices{nSides} = pthPARTijSideDilatedIndices';
                                        for r = 1:nRawImages
                                            % Name this image variables:
                                            rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);
                                            sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % use of signalName (3.0)
                                            % Calculate mean intensity:
                                            pthPARTijSideMeanIntensity = mean(rawImage(pthPARTijSideDilatedIndices));
                                            sideIntensities = [sideIntensities ; pthPARTijSideMeanIntensity];                   %#ok<AGROW>
                                            % Update variables:
                                            assignin('base',['sideIntensities' signalName{r}], sideIntensities)
                                        end
                                        sideVertices(nSides,:) = [pthPARTverticesInvolved pthPARTverticesInvolved];                             % WILL BE ONLY ONE NUMBER REPEATED TWICE !!
                                        sideVertexIndices(nSides,:) = [pthPARTijSideVertexIndices pthPARTijSideVertexIndices];                 % WILL BE ONLY ONE NUMBER REPEATED TWICE !!
                                    else
                                        disp('Warning 01: nPixPthPART > 1')
                                    end
                                    
                                %%% CASE 2: side part containing only 2 vertices (REGULAR CASE):
                                elseif nPthPARTVerticesInvolved == 2
                                    
                                    nSides = nSides + 1;
                                    disp(['     Side part # ' num2str(p) '/' num2str(nPartsijSide) ', case "nPthPARTVerticesInvolved == 2" encountered for side # ' num2str(nSides)...
                                        ', cell # ' num2str(i) ', neighbor # ' num2str(jthNeighbor) ' and vertices # ' num2str(pthPARTverticesInvolved')])
                                    sideCells(nSides,:) = [i jthNeighbor];
                                    sideIndices{nSides} = pthPARTijSideIndices';
                                    
                                    % Dilatating sides and calculating side mean intensity:
                                    pthPARTijSideDilatedIndices = SideDilator(imageSize, pthPARTijSideIndices, skelDilatation);
                                    sideDilatedIndices{nSides} = pthPARTijSideDilatedIndices';
                                    for r = 1:nRawImages
                                        % Name this image variables:
                                        rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]); 
                                        sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % use of signalName (3.0)
                                        % Calculate mean intensity:
                                        pthPARTijSideMeanIntensity = mean(rawImage(pthPARTijSideDilatedIndices));
                                        sideIntensities = [sideIntensities ; pthPARTijSideMeanIntensity];                   %#ok<AGROW>
                                        % Update variables:
                                        assignin('base',['sideIntensities' signalName{r}],sideIntensities); % use of signalName (3.0)
                                    end
                                    sideVertices(nSides,:) = pthPARTverticesInvolved';
                                    sideVertexIndices(nSides,:) = pthPARTijSideVertexIndices';              % NOW STORE LINEAR INDICES RATHER THAN XY COORDINATES
                                 
                                    
                                %%% CASE 3: side part containing > 2 vertices: UNSEPARATED PARTS OF SIDE IJ:
                                % NB: 4like vertex or 2 neighboring 3vertices in a side part (case c and e notbook #3)
                                elseif nPthPARTVerticesInvolved > 2
                                    
                                    disp(['     Side part # ' num2str(p) '/' num2str(nPartsijSide) ', case "nPthPARTVerticesInvolved > 2" encountered for cell # '...
                                        num2str(i) ', neighbor # ' num2str(jthNeighbor) ' and vertices # ' num2str(pthPARTverticesInvolved')])
                                    % Rebuilding ONLY this part of side ij:
                                    pthPARTijSideImage = MakeMatrix(imageSize, pthPARTijSideIndices, 1);
                                    % get endpoint vertices of this side:
                                    pthPARTendpointVertexImage = bwmorph(pthPARTijSideImage,'endpoints');  % image with the 2 endpoint vertices
                                    pthPARTendpointVertexIndices = find(pthPARTendpointVertexImage);       % indices of endpoint vertices
                                    
                                    % SUBCASE of 2-part side meeting at BOTH ends => NO endpoint vertices!!! (3.2)
                                    % Fixing "pthPARTendpointVertexIndices" by finding two endpoint vertices differently
                                    if isempty(pthPARTendpointVertexIndices)
                                        disp('          Special case: 2-part side making a closed contour');
                                        
                                        % removes ONE vertex (first listed) => opens CLOSED contour
                                        firstVertexIndex = allVertexIndices(pthPARTverticesInvolved(1));  
                                        otherVertexIndices = allVertexIndices(pthPARTverticesInvolved(2:end));
                                        pthPARTijSideIndicesMod = setdiff(pthPARTijSideIndices, firstVertexIndex); 
                                        
                                        % Getting 2 NEW endpoints: one of them is wrong due to vertex removal.
                                        pthPARTijSideImageMod = MakeMatrix(imageSize, pthPARTijSideIndicesMod, 1);
                                        pthPARTendpointVertexImageMod = bwmorph(pthPARTijSideImageMod,'endpoints');
                                        pthPARTendpointVertexIndicesMod = find(pthPARTendpointVertexImageMod);
                                        
                                        % replacing index of wrong endpoint found due to vertex removal by index of removed vertex:
                                        vertex2replaceTF = ~ismember(pthPARTendpointVertexIndicesMod, otherVertexIndices); % replace the one that is NOT an actual vertex index
                                        pthPARTendpointVertexIndicesMod(vertex2replaceTF) = firstVertexIndex; % putting it back
                                        
                                        pthPARTendpointVertexIndices = pthPARTendpointVertexIndicesMod;
                                    end
                                    
                                    % get indices of vertices remaining in the side (COMMENTED 3.2 since unused):
%                                     pthPARTremainingVertexIndices = setdiff(pthPARTijSideVertexIndices, pthPARTendpointVertexIndices);  % indices of vertices remaining in PART p of side ij
                                    
                                    % Numbering 8-connected pixels making up this part of side ij starting with 1st vertex in endpoint_vertices:
                                    firstVertexIndex = pthPARTendpointVertexIndices(1);
                                    lastVertexIndex = pthPARTendpointVertexIndices(2);
                                    % gets first vertex number:
                                    [~, firstVertexLoc] = ismember(firstVertexIndex, ithCellVertexIndices);
                                    firstVertexNumber = ithCellVertices(firstVertexLoc);
                                    
                                    % List of side part p indices in ascending pixel arclength using function "Arclength":
                                    [~, pthPARTindicesAscendingArclength, closedCountour] = Arclength(imageSize, pthPARTijSideIndices, firstVertexIndex, scale1D);
                                    % NB: arclength SCALED with scale1D
                                    
                                    % If "firstVertexIndex" is listed as last in "pthPARTindicesAscendingArclength", which can happen in closed contours, 
                                    % then flipping table to list it first (3.2)
                                    if firstVertexIndex == pthPARTindicesAscendingArclength(end) && closedCountour
                                        pthPARTindicesAscendingArclength = flipud(pthPARTindicesAscendingArclength);
                                    end
                                    
                                    % Sort vertices according to ascending pixel arclength:
                                    [~, pthPARTijSideVertexIndicesLoc] = ismember(pthPARTijSideVertexIndices, pthPARTindicesAscendingArclength);
                                    pthPARTijSideVertexIndicesLoc = sort(pthPARTijSideVertexIndicesLoc);                 % SORTED locations of vertices in "pthPARTijSideVertexIndicesLoc"
                                    vertexIndicesSorted = pthPARTindicesAscendingArclength(pthPARTijSideVertexIndicesLoc);        % indices of vertices
                                    
                                    % Subdivision of part p of side ij:
                                    nNextVertex = 1;                             % Initializations
                                    nextVertexIndex = firstVertexIndex;
                                    nextVertexLoc = 1;                           % locations of vertices in "ind_PART_p_ascending_arclength"
                                    nextVertex = firstVertexNumber;
                                    nSubpart = 0;
                                    
                                    while nNextVertex < nPthPARTVerticesInvolved
                                        % Current vertex:
                                        nVertex = nNextVertex;
                                        vertexIndex = nextVertexIndex;
                                        vertexLoc = nextVertexLoc;
                                        vertex = nextVertex;
                                        % Next vertex:
                                        nNextVertex = nVertex + 1;
                                        nextVertexIndex = vertexIndicesSorted(nNextVertex);                                         % takes index of next vertex
                                        nextVertexLoc = pthPARTijSideVertexIndicesLoc(nNextVertex);                       % takes location of next vertex in "ind_PART_p_ascending_arclength"
                                        [~, nextVertexInithCellVerticesLoc] = ismember(nextVertexIndex, ithCellVertexIndices); % get next vertex number
                                        nextVertex = ithCellVertices(nextVertexInithCellVerticesLoc);
                                        % pixel distance between the 2:
                                        deltaLoc = nextVertexLoc - vertexLoc;  % calculates difference between these 2 vertex locations in "ind_PART_p_ascending_arclength"
                                        if deltaLoc > 1 || (deltaLoc == 1 && vertexIndex == firstVertexIndex) || (deltaLoc == 1 && nextVertexIndex == lastVertexIndex)
                                            % if next vertex IS NOT neighbor of the previous one
                                            % OR if neighbor, one of the 2 vertices making up side is one of Part p endpoints
                                            
                                            % Get pixels making up this subpart and vertex indices and numbers ending it:
                                            pthSUBPARTijSideIndices = pthPARTindicesAscendingArclength(vertexLoc:nextVertexLoc);
                                            pthSUBPARTinvolvedVertexIndices = [vertexIndex ; nextVertexIndex];
                                            pthSUBPARTinvolvedVertices = [vertex ; nextVertex];
                                            
                                            % Create a new side:
                                            nSides = nSides + 1;
                                            nSubpart = nSubpart + 1;
                                            disp(['           ' '- SUBpart # ' num2str(nSubpart) ' corresponds to side # ' num2str(nSides)...
                                                ' and involves vertices # ' num2str(pthSUBPARTinvolvedVertices')])
                                            % Special warning:
                                            if (deltaLoc == 1 && vertexIndex == firstVertexIndex) || (deltaLoc == 1 && nextVertexIndex == lastVertexIndex)
                                                disp(['           ' '  2 pixel SUBpart: vertex neighboring an endpoint vertex'])
                                            end
                                            sideCells(nSides,:) = [i jthNeighbor];
                                            sideIndices{nSides} = pthSUBPARTijSideIndices';
                                            
                                            % Dilatating sides and calculating side mean intensity :
                                            pthSUBPARTijSideDilatedIndices = SideDilator(imageSize, pthSUBPARTijSideIndices, skelDilatation);
                                            sideDilatedIndices{nSides} = pthSUBPARTijSideDilatedIndices';
                                            for r = 1:nRawImages
                                                % Name this image variables:
                                                rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);
                                                sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % using signalName (3.0)
                                                % Calculate mean intensity:
                                                pthSUBPARTijSideMeanIntensity = mean(rawImage(pthSUBPARTijSideDilatedIndices));
                                                sideIntensities = [sideIntensities ; pthSUBPARTijSideMeanIntensity];                   %#ok<AGROW>
                                                % Update variables:
                                                assignin('base',['sideIntensities' signalName{r}],sideIntensities); % using signalName (3.0)
                                            end
                                            sideVertices(nSides,:) = pthSUBPARTinvolvedVertices';
                                            sideVertexIndices(nSides,:) = pthSUBPARTinvolvedVertexIndices';
                                        else
                                            disp(['           ' '- No additional SUBpart: neighboring vertices found within this side part: '  num2str([vertex nextVertex])])
                                        end
                                    end
%                                     if jthNeighbor == 344
%                                     return
%                                     end
                                end
                            end
                        end
                    end
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
                %%%% Global storage for all cells:
                cellNeighbors{i} = ithCellNeighbors';
                cellnNeighbors(i) = ithCellnNeighbors;
                cellVertices{i} = ithCellVertices';
                cellnVertices(i) = ithCellnVertices;
                cellContourIndices{i} = ithCellCountourIndices;         
            end
            
            clear skelPixIndices skelPixNeighborInfo; % 3.1
            
            %%% Finalizing side related cell arrays (2.4.0)
            sideNumbers = (1:nSides)';
            % Cropping side arrays to their minimal size:
            sideCells = sideCells(1:nSides,:);
            sideVertices = sideVertices(1:nSides,:);
            sideVertexIndices = sideVertexIndices(1:nSides,:);
            sideIndices = sideIndices(1:nSides);
            sideDilatedIndices = sideDilatedIndices(1:nSides);
            toc
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
                %% PARALLEL LOOP OVER SIDES %%
            
            %%% Saves dilated skeleton for intensity computation:
            
            Sides = (1:nSides)';                                        % vector of side numbers
            skelDilatationBGeff = skelDilatationBG - skelDilatation;    %  will load DILATED side indices => using a smaller dilation values (3.1)
            
            for r = 1:nRawImages
                
                disp(['Parallel removal of background intensity on sides in ' signalName{r} ' images using ' num2str(nLabs) ' labs... ']); % 3.1
                
                %%%% Side Intensity image:
                rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);                           % Name this image variables:
                
                % Creates image made up by dilated sides and intensity:
                sideDilatedIndicesMerged = (unique(cell2mat(sideDilatedIndices')))';                % merges all indices of dilated sides into a single column-vector
                intensitySkeleton = uint8(zeros(imageSize));                                        % conversion to uint8
                intensitySkeleton(sideDilatedIndicesMerged) = rawImage(sideDilatedIndicesMerged);
                % saves image:
                imwrite(intensitySkeleton, [intensityFolder filesep Animal '_SideIntensity' signalName{r} '_' num2str(n,digitsFormat) '.' imageFormat],  imageFormat); % using "signalName" (3.0)
                clear intensitySkeleton; % 3.1
                
                %%% Removing Background Intensity from side intensity (mod 2.15)
                tic  
                BGrawImage = rawImage;
                if islogical(BGrawImage) % 2.16
                    BGrawImage = double(BGrawImage);
                end
                BGrawImage(sideDilatedIndicesMerged) = NaN;                     % puts NaNs where intensity was calculated so as NOT to include them in background (2.4.3)
                                                              
                spmd
                    CD_Sides = codistributed(Sides, codistributor1d(1));             % codistributes "Sides": slices it to spread it evenly on the "nlabs" labs
                    LabSides = getLocalPart(CD_Sides);                                % part of "Sides" on this Lab L
                    LabnSides = length(LabSides);                                     % gets corresponding length
                    LabSideBGintensities = zeros(LabnSides,1);                                % initializes side background intensity
                    LabBGindices = [];                                               % initializes indices in image around sides used to determine background intensity
                    
                    %%% LOOP OVER EACH LAB "LabnSides":
                    for s = 1:LabnSides
                        
                        sthSideNumber = LabSides(s);                                  % gets the number (in FULL IMAGE) of sth side to process in L_Sides
                        sthSideIndices = sideDilatedIndices{sthSideNumber};           % loads this side DILATED indices (3.1)
%                         sthSideIndices = sideIndices{sthSideNumber};                % loads this side indices
                        sthSideIndices = sthSideIndices';                             % making it column vector
                        
                        % TIME LIMITING STEP:
                        sthSideDilatedBGindices = SideDilator(imageSize, sthSideIndices, skelDilatationBGeff); % using "skelDilatationBGeff" as now using dilated sides (3.1)
%                         sthSideDilatedBGindices = sideDilatedIndices{sthSideNumber}; % TESTS
%                         sthSideDilatedBGindices = sthSideDilatedIndices';             % TESTS
                        
                        sthSideBGPixelIntensity = BGrawImage(sthSideDilatedBGindices);                          % gets all pixel intensities on BG_raw_image
                        sthSideMeanBGIntensity = nanmean(sthSideBGPixelIntensity);                            % compute average over local background around side s(2.4.3)
%                         noNaN_pix_I_side_s = sthSideBGPixelIntensity(~isnan(sthSideBGPixelIntensity));       % only keeps non-NaN intensity pixels (2.4.3)
%                         sthSideMeanBGIntensity = mean(noNaN_pix_I_side_s);                                        % compute average over local background around side s(2.4.3)
                        % NB: will yield NaN if "sthSideBGPixelIntensity" is empty OR only contains NaNs!!!
                        LabSideBGintensities(s) = sthSideMeanBGIntensity;                                                  % stores value
                        LabBGindices = [LabBGindices ; sthSideDilatedBGindices];                              %#ok<AGROW>
                    end
                end
                % Merging of all lab parts:
                sideBGintensities = [];
                BGindices = [];
                for lab = 1:nLabs
                    sideBGintensities = [sideBGintensities ; LabSideBGintensities{lab}];              %#ok<AGROW>
                    BGindices = [BGindices ; LabBGindices{lab}];                              %#ok<AGROW>
                end
                BGindices = unique(BGindices);
                % Checks whether no NaN were found due to a too small value of "skelDilatationBG" (2.4.2):
                nanInsideBGintensitiesInd = find(isnan(sideBGintensities));
                if ~isempty(nanInsideBGintensitiesInd)
                    disp('Error in determination of background intensity for sides #:')
                    disp(num2str(nanInsideBGintensitiesInd'))
                    disp(['Increase parameter "skelDilatationBG" to (3+)*"skelDilatation" (current values: '...
                        num2str(skelDilatationBG) ' vs ' num2str(skelDilatation) ')'])
                    return
                end
                
                % REMOVAL OF BACKGROUND VALUES FROM SIDE INTENSITIES:
                sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % use of "signalName" (3.0)
                sideIntensities = sideIntensities - sideBGintensities;
                % Updates "sideIntensities" and save "sideBGintensities" for each image "r":
                assignin('base',['sideIntensities' signalName{r}],sideIntensities)
                assignin('base',['sideBGintensities' signalName{r}],sideBGintensities)
                % Creates image of BG kept pixels:
                sideBGimage = uint8(zeros(imageSize));
                sideBGimage(BGindices) = BGrawImage(BGindices);
                imwrite(sideBGimage, [intensityFolder filesep Animal '_SideBGIntensity' signalName{r} '_' num2str(n,digitsFormat) '.' imageFormat],  imageFormat); % using "signalName" (3.0)
                clear sideBGimage; % 3.1
                % Duration display
                disp(['Duration: ' num2str(toc) 's']);
            end
            clear BGrawImage BGindices sideDilatedIndicesMerged; % 3.1
            
            %%% Completing calculations on sides: chord lengths and chord angles:
            sideChordLengths = ChordGeometry(imageSize, sideVertexIndices, scale1D); % stopped calling "side_chord_angles" (3.0)
            
            %%% Determining side types:
            sideCATEGORIES = SortSides(sideNumbers, sideCells, cellCATEGORIES);
            
                %% Determining "sideParts" for multiple sides (mod 3.0) %%
            
            % Initializations:
            sideParts = ones(nSides,1);                                                 % initialization to 1 (default number of parts for all sides)
            % Determination of cell couples making up multipart sides:
            [sideCellsUnique, sideCellsLoc] = unique(sideCells, 'rows');                % sideCellsUnique = sideCells(sideCellsLoc)
            sideNumbersUnique = sideNumbers(sideCellsLoc);                              % get side numbers selected
            multipleSideNumbersTemp = setdiff(sideNumbers, sideNumbersUnique);          % get numbers of non selected parts of mutliple sides
            multiplePartSideCells = sideCells(multipleSideNumbersTemp, :);              % get pairs of cell numbers of these sides
            multiplePartSideCells = unique(multiplePartSideCells, 'rows');              % keeps only one occurrence of repeated cell couples
            nMultiplePartSides = size(multiplePartSideCells,1);                         % number of pairs repeated >1 times
            
            % Getting corresponding side numbers and updating "sideParts" with number of parts making up full side:
            for k = 1:nMultiplePartSides
                
                kthCellCouple = multiplePartSideCells(k,:);                             % gets cell couple characterizing this multiple side
                kthCellCoupleTF = ismember(sideCells, kthCellCouple, 'rows');           % gets locations of "kthCellCouple" in table "sideCells" (fix 3.0)
%                 kthCellCoupleTF = ismember(sideCells, multiplePartSideCells, 'rows');  % gets locations of this couple in table "sideCells"
                nPartsKthMultiplePartSide = sum(kthCellCoupleTF);                           % sums number of occurrences of this couple
                kthMultiplePartSideNumbers = sideNumbers(kthCellCoupleTF);                  % gets all side numbers corresponding to this couple
                sideParts(kthMultiplePartSideNumbers) = nPartsKthMultiplePartSide;          % in "side_n_parts", replaces 1 by number of parts making up this side
            end
         
                %% REGULAR LOOP OVER CELLS: compute side related quantities AND texture M %%
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            disp('Calculating texture M, inertia I, side related quantities and polarity for cells...')
            
            tic
            for i = 1:nCells
                
                %%% storing side,chord and contour lengths:
                ithCellLocsTF = ismember(sideCells, i);                % in this array, puts 1s where cell i was found in "Neighborhood_info", 0s elsewhere
                ithCellRowsTF = any(ithCellLocsTF,2);                  % puts 1s in rows where 1 was found
                ithCellSides = find(ithCellRowsTF);                    % DIRECTLY yields side numbers in Sides or side_numbers
                ithCellnSides = length(ithCellSides);                  % number of side (including side subparts)
                ithCellChordLength = sideChordLengths(ithCellSides);
                ithCellContourChordLength = sum(ithCellChordLength);   % cell contour based on chord lengths
                ithCellDilatedContourIndices = (unique(cell2mat((sideDilatedIndices(ithCellSides))')))';    % merge all indices of all dilated sides of cell i

                %%% side and chord disorders: std/mean(side/chord_lengths)
                ithCellChordDisorder = std(ithCellChordLength)/mean(ithCellChordLength);   % = 0 for a regular hexagon. Now uses mean(chord_lengths) instead of sqrt(area)
  
                %%% cell roundness:
                ithCellArea = cellAreas(i);                                    % moved here
                             
                %%% Texture calculation:
                [Mi, ithCellnLinks] = CalculateTexture(i, cellCATEGORIES, cellNeighbors, cellVertices, cellXYs, fourVertices);
                
                %%% Recalculation of inertia I, Ianisotropies, Iorientations from cell indices (2.5.0):
                [ithCellI, ithCellIanisotropy, ithCellIorienation] = CalculateInertia(cellIndices{i},cellXYs(i,:),scale1D,imageSize);
                
                %%% Calculation of vertex tensor and related quantities (2.5.1)
                ithCellVertices = cellVertices{i};                                                                 % cell i vertex numbers
                ithCellVertexXYs = VERTICES.XYs(ithCellVertices,:);                                                % cell i vertex coordinates IN ?m
                [ithCellV, ithCellVpolarity, ithCellVorientation] = VertexTensor(ithCellVertexXYs, cellXYs(i,:));  % => V_cell_i IN ?m^2
               
                %%% Filling up cell_sides, cell_n_sides, cell_contour_lengths...:
                cellSides{i} = ithCellSides;
                cellnSides(i) = ithCellnSides;
                cellContourChordLengths(i) = ithCellContourChordLength;
                cellChordDisorders(i) = ithCellChordDisorder;
                cellMs(i,:) = Mi;         
                cellnLinks(i) = ithCellnLinks;                                 
                cellDilatedContourIndices{i} = ithCellDilatedContourIndices;  
                % cell Inertia:
                cellIs(i,:) = ithCellI;                                          
                cellIanisotropies(i) = ithCellIanisotropy;                        
                cellIorientations(i) = ithCellIorienation;                
                % cell Vertex tensor:
                cellVs(i,:) = ithCellV;                                        
                cellVpolarities(i) = ithCellVpolarity;                 
                cellVorientations(i) = ithCellVorientation;                  
                
                %%% Side intensity disorders AND cell polarity for each raw image:
                ithCellXYsPixels = cellXYs(i,:)/scale1D;      % conversion of ?m in pixels
                for r = 1:nRawImages
                    
                    %%%% Side intensity disorders:
                    % "sideIntensities" and "cellSideIntensityDisorders" of THIS raw image:
                    sideIntensities = evalin('caller',['sideIntensities' signalName{r}]); % use of "signalName" (3.0)
                    cellSideIntensityDisorders = evalin('caller',['cellSideIntensityDisorders' signalName{r}]);
                    % calculate cell side intensity disorder for cell i:
                    ithCellSideIntensities = sideIntensities(ithCellSides);                                               % cell i side intensities
                    ithCellSideIntensityDisorder = std(ithCellSideIntensities)/mean(ithCellSideIntensities);
                    cellSideIntensityDisorders = [cellSideIntensityDisorders ; ithCellSideIntensityDisorder];       %#ok<AGROW> % add this value to the list
                    % updates "cell_side_intensity_disorders_r" in workspace for each image:
                    assignin('base', ['cellSideIntensityDisorders' signalName{r}], cellSideIntensityDisorders);  
                    
                    %%%% Cell Polarity (mod 2.15):
                    cellPolarityModes = evalin('caller',['cellPolarityModes' signalName{r}]); % use of "signalName" (3.0)
                    rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);
                    % Removal of cell mean background intensity "A0_BG" (calculated over cell i sides):
                    % Loading:
                    sideBGintensities = evalin('caller',['sideBGintensities' signalName{r}]); % use of "signalName" (3.0)
                    cellBGintensities = evalin('caller',['cellBGintensities' signalName{r}]);
                    % Computing cell i mean background intensity over sides:
                    ithCellSideBGintensity = sideBGintensities(ithCellSides);
                    A0_BG = mean(ithCellSideBGintensity);
                    cellBGintensities = [cellBGintensities ; A0_BG];            %#ok<AGROW>
                    % Update:
                    assignin('base', ['cellBGintensities' signalName{r}],cellBGintensities); % use of signalName (3.0)
                        
                    if ismember(i,nonBorderRNs)
                        % Getting intensity Fourier coefficients:
                        [A0, A1, B1, A2, B2] = PCPmodes(rawImage, ithCellDilatedContourIndices, 'dilated', ithCellXYsPixels, skelDilatation, imageSize);
                        A0 = A0 - A0_BG;                                      % withdraws background mean value from A0
                        ithCellPolarityModes = [A0 A1 B1 A2 B2];
                    else
                        ithCellPolarityModes = NaN(1,5);
                    end
                    cellPolarityModes = [cellPolarityModes ; ithCellPolarityModes];                %#ok<AGROW>
                    assignin('base', ['cellPolarityModes' signalName{r}], cellPolarityModes);     % Updates variable % use of signalName (3.0)
                end
            end
            toc
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
                        
            %% Filling up "CELLS", "SIDES" and "VERTICES" %%
            
            disp('Filling up "CELLS", "SIDES" and "VERTICES" structures...')
            
            %%% Defining STRUCTURE "SIDES":
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            SIDES.Numbers = sideNumbers;                                      % vector
            SIDES.Cells = sideCells;                                          % matrix (N_sides x 2)
            SIDES.Vertices = sideVertices;                                    % matrix (N_sides x 2)
            SIDES.VertexIndices = sideVertexIndices;                        % matrix (N_sides x 2)
            SIDES.ChordLengths = sideChordLengths;                          % vector
            SIDES.Indices = sideIndices;                                      % cell
            SIDES.DilatedIndices = sideDilatedIndices;                      % cell
            SIDES.Parts = sideParts;                                          % vector
            % Stores "side_intensities" for each raw image and "side_BG_intensities":
            for r = 1:nRawImages
                sideIntensities = evalin('caller',['sideIntensities' signalName{r}]);            % use of "signalName" (3.0)
                SIDES.(['Intensities' signalName{r}]) = sideIntensities;                       % vector
                sideBGintensities = evalin('caller',['sideBGintensities' signalName{r}]);      % inverted these 2 lines
                SIDES.(['BGintensities' signalName{r}]) = sideBGintensities;                   % vector
            end

            clear sideIndices sideDilatedIndices; % 3.1
            
            %%%% DIFFERENT NUMBER OF LINES THAN N_sides:
            SIDES.CATEGORIES = sideCATEGORIES;                                % STRUCTURE
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Statistics Computation OVER SIDES. NB: NOT STORED IN "SIDES":
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            sideSTATISTICS = SideStatistics(SIDES, signalName);             % 2.1e
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                       
            %%% Overwriting some border cells Inertia related quantities with NaNs (2.5.0):
            cellIs(borderRNs,:) = NaN;
            cellIanisotropies(borderRNs) = NaN;
            cellIorientations(borderRNs) = NaN;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            %%% Overwriting some border cells Vertex related quantities with NaNs (2.5.1):
            cellVs(borderRNs,:) = NaN;
            cellVpolarities(borderRNs) = NaN;
            cellVorientations(borderRNs) = NaN;
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            
            %%% Defining STRUCTURE "CELLS":
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            CELLS.Numbers = cellNumbers;                                                                 % vector
            CELLS.Indices = cellIndices;                                                                 % cell
            CELLS.Areas = cellAreas;                                                                     % vector
            CELLS.Perimeters = cellPerimeters;                                                           % vector
            CELLS.Anisotropies = cellAnisotropies;                                                       % vector 
            CELLS.Orientations = cellOrientations;                                                       % vector 
            CELLS.XYs = cellXYs;                                                             % matrix (X Y)
            CELLS.Vertices = cellVertices;                                                               % cell
            CELLS.nVertices = cellnVertices;                                                           % vector
            CELLS.Neighbors = cellNeighbors;                                                             % cell
            CELLS.nNeighbors = cellnNeighbors;                                                         % vector
            CELLS.ContourIndices = cellContourIndices;                                                 % cell
            CELLS.DilatedContourIndices = cellDilatedContourIndices;                                 % cell
            CELLS.ContourChordLengths = cellContourChordLengths;                                     % vector
            CELLS.Sides = cellSides;                                                                     % cell
            CELLS.nSides = cellnSides;                                                                 % vector
            CELLS.ChordDisorders = cellChordDisorders;                                                 % vector
            CELLS.Ms = cellMs;                                                                           % matrix [Mxx Mxy Myy
            CELLS.nLinks = cellnLinks;                                                                 % vector
            CELLS.Is = cellIs;                                                                           % matrix [Ixx Ixy Iyx Iyy]
            CELLS.Ianisotropies = cellIanisotropies;                                                      % vector
            CELLS.Iorientations = cellIorientations;                                                     % vector
            CELLS.Vs = cellVs;                                                                           % matrix [Vxx Vxy Vyx Vyy]
            CELLS.Vpolarities = cellVpolarities;                                                         % vector
            CELLS.Vorientations = cellVorientations;                                                     % vector
            % Stores "cellSideIntensityDisorders" for each raw image:
            for r = 1:nRawImages
                
                cellSideIntensityDisorders = evalin('caller',['cellSideIntensityDisorders' signalName{r}]);       % vector
                CELLS.(['SideIntensityDisorders' signalName{r}]) = cellSideIntensityDisorders;
                cellBGintensities = evalin('caller',['cellBGintensities' signalName{r}]);                      
                CELLS.(['BGintensities' signalName{r}]) = cellBGintensities;                                   % vector
                cellPolarityModes = evalin('caller',['cellPolarityModes' signalName{r}]);                       % vector
                CELLS.(['PolarityModes' signalName{r}]) = cellPolarityModes;
            end
            
            clear cellIndices cellContourIndices cellDilatedContourIndices; % 3.1
            
            %%%% DIFFERENT NUMBER OF LINES THAN nCells:
            CELLS.CATEGORIES = cellCATEGORIES;                                                           % STRUCTURE
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            %%% Additional computation OVER CELLS. NB: NOT STORED IN "CELLS":
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            cellSTATISTICS = CellStatistics(CELLS, signalName);                                     % 2.1e
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            
            %%% Extraction of cell and side statistics %%
            ExtractData(cellSTATISTICS);
            ExtractData(sideSTATISTICS);
            
  
            %% Determination of Vertex CATEGORIES from SIDES + completion of VERTICES %%
            
            % Reminder: ALREADY STORED in all_vertex_CATEGORIES: All_vertices, Bulk_vertices, Edge_vertices, Three_vertices, Four_vertices
            % NB: need to remove possible NaN values from list for sides without vertices (circle cells)
            
            % Resume filling up "all_vertex_CATEGORIES":
            allVertexCATEGORIES = SortVertices(allVertexCATEGORIES, sideVertices, sideCATEGORIES); 
            
            %%% Storage into VERTICES:
            VERTICES.CATEGORIES = allVertexCATEGORIES;
                               
            %%% Extraction of side and all_vertex CATEGORIES %%          
            ExtractData(sideCATEGORIES);                                   
            ExtractData(allVertexCATEGORIES);                             
            
 
        else 
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % USE OF SIA_BOX
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            %% Get main parameter values entered in AIA %%
            
            scale1D_AIA = scale1D;           
            
            
            %% Loading of SIA backup of current frame %%
            
            %%% Worspace message:
            disp(['Loading backup file "SIA_' Animal  '_' fn '"...'])
            
            %%% Loading SIA Backup file (loads CELLS, SIDES, VERTICES):
            load([pathFolderSIA filesep 'Backups'  filesep 'SIA_' Animal  '_' fn '.mat']); % 3.1
            
            %%% Extraction of ALL cell quantities:
            ExtractData(CELLS,'cell');                      % mod 3.0
            cellCATEGORIES = CELLS.CATEGORIES;                            % WILL BE UDATED (AND SAVED) WITH BOX CATEGORIES FURTHER DOWN
            ExtractData(cellCATEGORIES);                               % extract Core_cells, FL_cells... gotten from full image
            
                           
            %% Dialog Box: compare main parameter values with the one in SIA backup files %%

            %%% scale1D values:
            deltaScale1D = abs(scale1D_AIA - scale1D);
            if isempty(scale1D_AIA)
                warndlg('No value has been entered for the scale factor ("scale1D") ! Please enter the appropriate value.', 'Warning!');
                return
            elseif deltaScale1D ~= 0
                warndlg({['Value saved in backup file (' num2str(scale1D) ' {\mu}m/pixel) differs from value entered in AIA (' num2str(scale1D_AIA) ' {\mu}m/pixel).'];'';
                    'Please either correct value entered in AIA if it is wrong, or fully re-run SIA with the proper value.'}, '"scale1D" value mismatch!!');
                return
            end
            

            %% Loads raw fluorescence imageS (mod 2.15) %%
            
            % Overrides "Side_Intensity" value in AIA (if it was set to 0) by the one just loaded from backups (mod 2.15):
            filenameRawMod = cell(nRawImages,1);
            for r = 1:nRawImages
                filenameRawMod{r} = FormatFilename(filenameRaw{r}); % first removes last '_', then crops it to its first 15 characters.
            end

            if displayPolarityMode == 1
                for r = 1:nRawImages
                    rawImage = imread([pathFolderRaw  filesep filenameRaw{r} num2str(n,digitsFormat) '.' imageFormatRaw]);
                    assignin('base',['rawImage_' filenameRawMod{r}], rawImage);
                end
            end
            
            
            %% Drawing of Box & Determination of the 3 cell categories from box %%
                      
            %%% Reload box previously drawn (2.4.5):
            if reloadBox
                SIAboxBackupPath = [backupFolder filesep  filenameSIAfull '_' fn '.mat']; % path to should-be-existing box backup (if reload_box=1), use "filenameSIAfull" (3.4)
%                 SIAboxBackupPath = [backupFolder filesep  'SIA_' Animal SIAboxTag '_' fn '.mat']; % path to should-be-existing box backup (if reload_box=1)
                try
                    boxBackup = load(SIAboxBackupPath);
                    if isfield(boxBackup,'BOX')
                        BOX = boxBackup.BOX;
                    end
                    % NB: no need to remove BOX from FRAME since this latter will be overwritten below in the new backup
                catch err
                    disp(['Warning: file ' SIAboxBackupPath ' could not be found!!!'])
                    choice = questdlg('No backup file containing "BOX" data could be found! Do you want to draw a new box?','"BOX" not found!!!','Yes','No','Yes');
                    switch choice
                        case 'No'
                            return
                        case 'Yes'              % 3.1
                            reloadBox = false;  % back on regular tracks if calculated box cannot be found and user want to draw a new box
                    end
                end
            end
                
            
            %%% Use of "StaticBox":
            [cellCATEGORIES, BOX, proceed] = StaticBox(segImage,CELLS, oneCellFrontier, path2SelectedImage, pathFolderRaw, predefinedBoxData, gridLineWidth, BOX, reloadBox);
             

            %%%% UPDATE OF "cellCATEGORIES" IN "CELLS":
            CELLS.CATEGORIES = cellCATEGORIES;
            
            %%% UPDATE OF all cell categories in workspace:
            ExtractData(cellCATEGORIES,'','base');
            ExtractData(BOX,'box','base');
                       
            %%% Checking BOX before continuing (2.1)
            if isempty(boxChoice) || boxChoice== 0 || ~proceed
            % if isnan(boxChoice)|| boxChoice== 0 || ~proceed
                disp('Please choose a proper image and box. Stopping SIA...')
                return
            end
            

           %%  Update of Side quantities and categories %%
           
            %%% Worspace message:
            disp('Update of side and vertex categories corresponding to box...')
            
            ExtractData(SIDES,'side');                                 % extracts all quantities stored in SIDES and add prefix 'side'
            
            %%% Determining side types and categories:
            sideCATEGORIES = SortSides(sideNumbers, sideCells, cellCATEGORIES);
            
            %%% Updates side CATEGORIES in SIDES + Extraction:       
            ExtractData(sideCATEGORIES);    
            SIDES.CATEGORIES = sideCATEGORIES;
            
            
            %% Update and Extraction of cell and side Statistics %%
            
            %%% Statistics Computation OVER SIDES. NB: NOT STORED IN "SIDES":
            sideSTATISTICS = SideStatistics(SIDES, signalName); % use of signalName (3.1)
            ExtractData(sideSTATISTICS);

            %%% Additional computation OVER CELLS. NB: NOT STORED IN "CELLS":
            cellSTATISTICS = CellStatistics(CELLS, signalName); % use of signalName (3.1)
            ExtractData(cellSTATISTICS);         

            
            %% Update of Vertex CATEGORIES from SIDES + Update of VERTICES %%
            
            ExtractData(VERTICES, 'allVertex'); 
            ExtractData(allVertexCATEGORIES);                         
            
            % Reminder: ALREADY STORED in all_vertex_CATEGORIES: All_vertices, Bulk_vertices, Edge_vertices, Three_vertices, Four_vertices
            % NB: need to remove possible NaN values from list for sides without vertices (circle cells)
            
            % Resume filling up "all_vertex_CATEGORIES":
            allVertexCATEGORIES = SortVertices(allVertexCATEGORIES, sideVertices, sideCATEGORIES); 
            
            %%% Extraction and Storage into VERTICES:
            ExtractData(allVertexCATEGORIES);   
            VERTICES.CATEGORIES = allVertexCATEGORIES;
            
        end
               
        
        %% Saving backup file (mod 2.4.5)%%
        
        disp(['Saving Backup file # ' fn]);
        if ~SIAboxMode
            save(fnBackupFile,'CELLS','VERTICES','SIDES'); % use of "fnBackupFile" defined right at beginning  (2.14)
        else
            save(fnBackupFile,'CELLS','VERTICES','SIDES','BOX') % added BOX saving outside FRAME (2.4.5), mod 2.14
        end
        % NB: if SIAboxMode == 1, "Backup_folder" and "Program" are different than SIA folders to store generated data in a separate folder
                   
        
        %% Saving XLS files for Cells %%
        
        
        if cellStatistics == 1
            
            %%% Display message:
            disp('Saving data over single cells in .xlsx file...')
            
            %%% Excel file path and initialization:
            this_Excel_file = [cellDataFolder filesep SIAmode  '_' Animal  '_Cell_Data_' fn  '.xlsx'];
            [Excel,  ExcelWorkbook] = xlswrite2007Intro(this_Excel_file);
            
            %%% Non Border cells (NBC):
            % Single cell data:
            cell_table_NBC = Cell_Data_Table(nonBorderRNs, CELLS);
            xlswrite2007(this_Excel_file, cell_table_NBC, 'Non-Border cells');                                                   % Saving in a xlsx file sheet:
            % Overall statistics:
            globalCellStatisticsNBC = Global_Cell_Statistics(globalCellStatisticsNBC, nonBorderRNs, 'NBC', cellSTATISTICS, n, iterationIndex, filenameRawMod);
            
            %%% FL cells (FLC):
            % Single cell data:
            cell_table_FLC = Cell_Data_Table(FLRNs, CELLS);
            xlswrite2007(this_Excel_file, cell_table_FLC, 'First Layer cells');                                                   % Saving in a xlsx file sheet:
            % Overall statistics:
            globalCellStatisticsFLC = Global_Cell_Statistics(globalCellStatisticsFLC, FLRNs, 'FLC', cellSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            %%% Core cells (CC):
            % Single cell data:
            cell_table_CC = Cell_Data_Table(coreRNs, CELLS);
            xlswrite2007(this_Excel_file, cell_table_CC, 'Core cells');                                                         % Saving in a xlsx file sheet:
            % Overall statistics:
            globalCellStatisticsCC = Global_Cell_Statistics(globalCellStatisticsCC, coreRNs, 'CC', cellSTATISTICS, n, iterationIndex, filenameRawMod);

            %%% xlswrite2007Outro
            xlswrite2007Outro;
            pause(0.1)
        end
        
        
        %% Saving XLS files for Sides %%
        
        
        if sideStatistics == 1
            
            %%% Display message:
            disp('Saving data over single sides in .xlsx file...')
            
            %%% Excel file path and initialization:
            this_Excel_file = [sideDataFolder filesep SIAmode  '_' Animal  '_Side_Data_' fn  '.xlsx'];
            [Excel,  ExcelWorkbook] = xlswrite2007Intro(this_Excel_file);
            
            %%% All_Non_Border_sides (ANBS = NBS U BFLS):
            side_table_ANBS = Side_Data_Table(All_Non_Border_sides, SIDES, filenameRawMod);
            xlswrite2007(this_Excel_file, side_table_ANBS, 'All Non Border Sides');
            % Overall statistics:
            globalSideStatisticsANBS = Global_Side_Statistics(globalSideStatisticsANBS, All_Non_Border_sides, 'ANBS', sideSTATISTICS, n, iterationIndex, filenameRawMod);
            
            %%% Non-Border sides (NBS = ACS U FLS):
            side_table_NBS = Side_Data_Table(Non_Border_sides, SIDES, filenameRawMod);
            xlswrite2007(this_Excel_file, side_table_NBS, 'Non-Border Sides');
            % Overall statistics:
            globalSideStatisticsNBS = Global_Side_Statistics(globalSideStatisticsNBS, Non_Border_sides, 'NBS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            %%% All_Border_sides (ABS = BS U BFLS):
            side_table_ABS = Side_Data_Table(All_Border_sides, SIDES, filenameRawMod);
            xlswrite2007(this_Excel_file, side_table_ABS, 'All Border Sides');
            % Overall statistics:
            globalSideStatisticsABS = Global_Side_Statistics(globalSideStatisticsABS, All_Border_sides, 'ABS', sideSTATISTICS, n, iterationIndex, filenameRawMod);
            
            %%% Border_sides (BS):
            side_table_BS = Side_Data_Table(Border_sides, SIDES, filenameRawMod);  
            xlswrite2007(this_Excel_file, side_table_BS, 'Border Sides');
            % Overall statistics:
            globalSideStatisticsBS = Global_Side_Statistics(globalSideStatisticsBS, Border_sides, 'BS', sideSTATISTICS, n, iterationIndex, filenameRawMod);
            
            %%% All_FL_sides(AFLS = CFLS U FLS U BFLS):
            side_table_AFLS = Side_Data_Table(All_FL_sides, SIDES, filenameRawMod); 
            xlswrite2007(this_Excel_file, side_table_AFLS, 'All FL Sides');
            % Overall statistics:
            globalSideStatisticsAFLS = Global_Side_Statistics(globalSideStatisticsAFLS, All_FL_sides, 'AFLS', sideSTATISTICS, n, iterationIndex, filenameRawMod);
            
            %%% Border_FL_sides (BFLS):
            side_table_BFLS = Side_Data_Table(Border_FL_sides, SIDES, filenameRawMod);   
            xlswrite2007(this_Excel_file, side_table_BFLS, 'Border-FL Sides');
            % Overall statistics:
            globalSideStatisticsBFLS = Global_Side_Statistics(globalSideStatisticsBFLS, Border_FL_sides, 'BFLS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            %%% FL_sides (FLS):
            side_table_FLS = Side_Data_Table(FL_sides, SIDES, filenameRawMod);   
            xlswrite2007(this_Excel_file, side_table_FLS, 'FL Sides');
            % Overall statistics:
            globalSideStatisticsFLS = Global_Side_Statistics(globalSideStatisticsFLS, FL_sides, 'FLS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
                        
            %%% All Core Sides (ACS = CS U CFLS):
            side_table_ACS = Side_Data_Table(All_Core_sides, SIDES, filenameRawMod); 
            xlswrite2007(this_Excel_file, side_table_ACS, 'All Core Sides');
            % Overall statistics:
            globalSideStatisticsACS = Global_Side_Statistics(globalSideStatisticsACS, All_Core_sides, 'ACS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            %%% Core-FL_sides (CFLS):
            side_table_CFLS = Side_Data_Table(Core_FL_sides, SIDES, filenameRawMod);                     
            xlswrite2007(this_Excel_file, side_table_CFLS, 'Core-FL Sides');
            % Overall statistics:
            globalSideStatisticsCFLS = Global_Side_Statistics(globalSideStatisticsCFLS, Core_FL_sides, 'CFLS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            %%% Core Sides (CS):
            side_table_CS = Side_Data_Table(Core_sides, SIDES, filenameRawMod);                       
            xlswrite2007(this_Excel_file, side_table_CS, 'Core Sides');
            % Overall statistics:
            globalSideStatisticsCS = Global_Side_Statistics(globalSideStatisticsCS, Core_sides, 'CS', sideSTATISTICS, n, iterationIndex, filenameRawMod); 
            
            % code for xlswrite2007:
            xlswrite2007Outro;
            pause(0.1)
            
        end
        
        
        %% Computing vertex global statistics %%
        
        if vertexStatistics == 1
            
            % OVERLAPPING SUBSETS:
            %%% All Bulk = Non Edge vertices (ABulkV):
            globalVertexStatisticsABulkV = Global_Vertex_Statistics(globalVertexStatisticsABulkV, Bulk_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% All Border vertices (ABV):
            globalVertexStatisticsABV = Global_Vertex_Statistics(globalVertexStatisticsABV, All_Border_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% All FL vertices (AFLV):
            globalVertexStatisticsAFLV = Global_Vertex_Statistics(globalVertexStatisticsAFLV, All_FL_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% All Non Core vertices (ANCV):
            globalVertexStatisticsANCV = Global_Vertex_Statistics(globalVertexStatisticsANCV, All_Non_Core_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% All Core vertices (ACV):
            globalVertexStatisticsACV = Global_Vertex_Statistics(globalVertexStatisticsACV, All_Core_vertices, threeVertices, fourVertices, n, iterationIndex); 
            
            % PARTITION:
            %%% Border vertices (BV):
            globalVertexStatisticsBV = Global_Vertex_Statistics(globalVertexStatisticsBV, Border_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% Border-FL vertices (BFLV):
            globalVertexStatisticsBFLV = Global_Vertex_Statistics(globalVertexStatisticsBFLV, Border_FL_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% FL vertices (FLV):
            globalVertexStatisticsFLV = Global_Vertex_Statistics(globalVertexStatisticsFLV, FL_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% Non Core vertices (NCV):
            globalVertexStatisticsNCV = Global_Vertex_Statistics(globalVertexStatisticsNCV, Non_Core_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% Core-FL vertices (CFLV):
            globalVertexStatisticsCFLV = Global_Vertex_Statistics(globalVertexStatisticsCFLV, Core_FL_vertices, threeVertices, fourVertices, n, iterationIndex);
            %%% Core Sides (CV):
            globalVertexStatisticsCV = Global_Vertex_Statistics(globalVertexStatisticsCV, Core_vertices, threeVertices, fourVertices, n, iterationIndex);
            
        end
        
    else
        
        %% CASE: Simple graphics replot %%
        
        % Added case where replot mode was NOT asked but backup already exists (2.14)
        if noDisplay && exist(fnBackupFile,'file') % case of NON-replot mode BUT backup already exists (2.14)
            
            disp(' '); disp(' ');
            disp([SIAmode ' ' version  ': processing "' Animal '" frame # ' fn ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);
            disp('---------------------------------------------------------------------------------');
            
            disp(['WARNING: backup "' fnBackupFile '" was found!'])
            disp('          => SIA execution was skipped and switched to "replot" mode for this frame.')
            
        else % REPLOT MODE
            disp(' '); disp(' ');
            disp([SIAmode ' ' version  ': FIGURE REPLOT MODE: Processing "' Animal '" frame # ' fn ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);   
            disp('---------------------------------------------------------------------------------');                               
  
            disp(['Loading backup file ' SIAmode  '_' Animal  '_' fn '... ']); % 3.2
        end
        
        %%%% Loading of Backup file:
        load(fnBackupFile); % use of "fnBackupFile" defined right at beginning  (2.14)
        % NB: now only loads structures CELLS, SIDES, STATISTICS and VERTICES in workspace, and BOX if any

        % Get value entered in AIA and prevents accidental overwritting when extracting parameters from structures
        scale1D_AIA = scale1D;      

        %%% ALWAYS loads segmented image (2.19)
        fprintf('Loading segmented image and determining region labels...')
        segImage = imread([pathFolder filesep filename num2str(n,digitsFormat) '.' imageFormat]);     % loads the segmented images
        imageCC = bwconncomp(segImage,4);
        imageLabels = labelmatrix(imageCC); % REcreates the image labelled uint8 or uint16 according to the number of regions 
        clear imageCC; % 3.1
        fprintf('Done!\n')
        
        %%%% Loading of raw images if Side_Intensity = 1:
        for r = 1:nRawImages
            rawImage = imread([pathFolderRaw  filesep filenameRaw{r} num2str(n,digitsFormat) '.' imageFormatRaw]);
            assignin('base',['rawImage_' filenameRawMod{r}], rawImage);
        end
        
        %%%% Extraction of data from saved structures into workspace with "ExtractData":
        ExtractData(CELLS, 'cell');
        ExtractData(SIDES, 'side');
        ExtractData(VERTICES, 'allVertex');
        % Extraction of cell and side CATEGORIES :
        ExtractData(cellCATEGORIES);
        ExtractData(sideCATEGORIES);
        ExtractData(allVertexCATEGORIES);         
        % Recalculation of Statistics:
        cellSTATISTICS = CellStatistics(CELLS, signalName);  % use of "signalName" (3.0)
        sideSTATISTICS = SideStatistics(SIDES, signalName); 
        % Extracting variables from structures cell/side_STATISTICS
        ExtractData(cellSTATISTICS);
        ExtractData(sideSTATISTICS);
        % Extracting quantities stored in BOX :
        if SIAboxMode == 1
            ExtractData(BOX,'box');
        end
        % NB: BOX is directly loaded (new backups)
        
        %%%% Dialog box: checks saved value of "scale1D" and "Side_lengths" with the ones in AIA
        %---------------------------------------------------------------------------------------------------
        %%% scale1D values:
        deltaScale1D = abs(scale1D_AIA - scale1D);
        if isempty(scale1D_AIA)
            warndlg('No value has been entered for the scale factor ("scale1D") ! Please enter the appropriate value.', 'Warning!');
            return
        elseif deltaScale1D ~= 0
            warndlg({['Value saved in backup file (' num2str(scale1D) ' {\mu}m/pixel) differs from value entered in AIA (' num2str(scale1D_AIA) ' {\mu}m/pixel).'];'';
                'Please either correct value entered in AIA if it is wrong, or fully re-run SIA with the proper value.'}, '"scale1D" value mismatch!!');
            return
        end
        %---------------------------------------------------------------------------------------------------
       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    end
    
    
    %% CELL RELATED PLOTS %%
    
    if anyDisplay == 1        
        disp('Displaying and saving cell and side maps... ')
    end
   
    %%% Filling structure "PLOT" (2.10, 2.21)
    time = frame2time(n, timeRef, frameRef, dt,'str'); % mod 2.13
    PLOT.time = time;
    PLOT.n = n;
       
        %% Relative Numbers (RNs) and Vertices (Vs) %%
    
    shortFileName = [ Animal '_RNs&Vs_' fn '.' imageFormatOutput];
    thisFileName = [frameFolderRNsAndRVs filesep shortFileName];

    if displayRNsAndVs == 1 && ~exist(thisFileName,'file')
        
        cellXsPixels = cellXYs(:,1)/scale1D;
        cellYsPixels = cellXYs(:,2)/scale1D;
        
        figure('PaperPositionMode','auto')
        imshow(segImage,'Border', 'tight')
        hold all
        
        % Plotting cell RNs according to cell categories (mod 3.0)
        text(cellXsPixels(borderRNs),cellYsPixels(borderRNs), num2str(borderRNs), 'FontSize', fontSizeCellNumbers, 'HorizontalAlignment','center','Color','red','FontWeight', 'bold')
        text(cellXsPixels(FLRNs),cellYsPixels(FLRNs), num2str(FLRNs), 'FontSize', fontSizeCellNumbers, 'HorizontalAlignment','center','Color','green','FontWeight', 'bold')
        text(cellXsPixels(coreRNs),cellYsPixels(coreRNs), num2str(coreRNs), 'FontSize', fontSizeCellNumbers, 'HorizontalAlignment','center','Color','blue','FontWeight', 'bold')
        
        % Plot circles around vertices (overhaul 3.0):
        vertexColors = [yellow ; grey ; turquoise ; red];
        for k = 1:4 % always 4 vertex types at most (3.0)
            
            kthTypeVertexTF = allVertexnCells == k;           
            [kthTypeVertexYs, kthTypeVertexXs] = ind2sub(imageSize,allVertexIndices(kthTypeVertexTF));
            scatter(kthTypeVertexXs,kthTypeVertexYs,circleSize,'LineWidth', circleWidth, 'MarkerEdgeColor', vertexColors(k,:));     % scatter(X,Y,S,C) displays colored circles at the locations specified by the vectors X and Y (must be same size)
        end

        % Plotting info (quantity plotted, time hAPF, animal and scalebar) (2.15):
        %-------------------------------------------------------------------------------
        textAnimal = '';
        textQuantity = '';
        if ~minimalInfoDisplay
            textAnimal = [Animal ' # ' num2str(n)];
            textQuantity = 'Regions & Vertices';
        end
        PlotInfo(textQuantity, '',0, colorInfo, '{\mu}m', textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
        %-------------------------------------------------------------------------------
        
        % Box plot:
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end
 
        % Saves image:
        print (printFormat,printResolution,thisFileName)
        close
        
   elseif displayRNsAndVs == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
       
        %% Areas %%
    
    % Determining rata range used in plot to name file (2.17)
    rangeAreaPlot = rangeArea; % default
    if isempty(rangeArea)
        rangeAreaPlot = FindValueRange(CELLS,'areas');
    end

    shortFileName =  [Animal  '_Areas_'  '[' num2str(rangeAreaPlot(1)) '_' num2str(rangeAreaPlot(2)) ']_'  fn '.' imageFormatOutput];
    thisFileName = [frameFolderAreas filesep shortFileName];
                        
    if displayArea == 1 && ~exist(thisFileName,'file')
        
        % Display image using "CellDisplay" (2.10):
        areaMap = CellDisplay(imageLabels, CELLS, 'Areas', rangeArea, PLOT);

        % Box plot:
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end
        
        % Saves image (mod 2.10):
        print(printFormat, printResolution, thisFileName)
%         imwrite(areaMap,thisFileName) % to save image at native resolution
%         saveas(gcf,thisFileName2)
        close
        
    elseif displayArea == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
      
        %% Anisotropies NEW (2.16) %%
    
    % Determining rata range used in plot to name file (2.17)
    rangeAnisotropyPlot = rangeAnisotropy; % default
    if isempty(rangeAnisotropy)
        rangeAnisotropyPlot = FindValueRange(CELLS,'Anisotropies');
    end
    
    shortFileName = [Animal  '_Anisotropies_'  '[' num2str(rangeAnisotropyPlot(1)) '_' num2str(rangeAnisotropyPlot(2)) ']_' fn '.' imageFormatOutput];
    thisFileName = [frameFolderAnisotropies filesep shortFileName];
    
    if displayAnisotropy == 1 && ~exist(thisFileName,'file')
        
        % Building image (mod 2.17):
        %----------------------------------------------------------------------------------------
        nCells = length(cellNumbers);
        cmap = winter(91);
        imageR = zeros(imageSize(1),imageSize(2));
        imageG = imageR;
        imageB = imageR;  
        for r = 1:nCells
            rPixels = CELLS.Indices{r}; % 3.1
            rAngle = round(cellOrientations(r));
            rColorAngle = cmap(1+abs(rAngle),:); 
            rAnisotropy = cellAnisotropies(r);
            rAnisoThresh = max(rangeAnisotropyPlot(1), rAnisotropy); % applies threshold on lowest value
            rAnisoThresh = min(rangeAnisotropyPlot(2), rAnisoThresh); % applies threshold on highest value
            rAnisoUsed = (rAnisoThresh - rangeAnisotropyPlot(1))/(rangeAnisotropyPlot(2) - rangeAnisotropyPlot(1)); % between 0 and 1
            rColor = FadeColor(rColorAngle, (1-rAnisoUsed)); % fading according to anisotropy
            imageR(rPixels) = rColor(1);
            imageG(rPixels) = rColor(2);
            imageB(rPixels) = rColor(3);
        end
        imageRGB = cat(3,imageR, imageG, imageB);
        
        % Overriding ALL BC colors (not just #1) with "colorBorderCells" by using Paint instead of Blend
        BCpixels = cell2mat(CELLS.Indices(borderRNs)); % 3.1
%         BCpixels = cell2mat(cellIndices(borderRNs));
        imageRGB = Paint(imageRGB, BCpixels, colorBorderCells);
        
        figure('PaperPositionMode','auto')
        imshow(imageRGB,'Border', 'tight')

        % Plotting colorbar (2.19)
        colorMap = makeColorMap(custom_white, blue, 32);
        PlotColorBar('anisotropy', colorBarXYWH, [rangeAnisotropyPlot(1) rangeAnisotropyPlot(2)], fontSizeInfo, colorInfo, colorMap);
        
        % Attempt to add another colorbar (DOESN'T WORK!)
%         angleColorBarXYWH = colorBarXYWH;
%         angleColorBarXYWH(1) = 0.6; 
%         PlotColorBar('angle', angleColorBarXYWH, [0 90], fontSizeInfo, cmap);
        
        % Plotting info (quantity plotted, time hAPF, animal and scalebar) (2.15):
        %-------------------------------------------------------------------------------
        textAnimal = '';
        textQuantity = '';
        if ~minimalInfoDisplay
            textAnimal = [Animal ' # ' num2str(n)];
            textQuantity = 'anisotropies';
        end
        PlotInfo(textQuantity, '',0, colorInfo, '{\mu}m', textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth);
        %-------------------------------------------------------------------------------
        
        % Box plot
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end
 
        % Saves image:
        print (printFormat, printResolution, thisFileName)
        close       
        
    elseif displayAnisotropy == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
       
        %% Neighbors %%
    
    shortFileName = [Animal  '_Neighbors_'   fn '.' imageFormatOutput];
    thisFileName = [frameFolderNeighbors filesep shortFileName];

    if displayNeighbor == 1 && ~exist(thisFileName,'file')
        % Display image using "CellDisplay":
        CellDisplay(imageLabels, CELLS, 'nNeighbors', [], PLOT);

        % Box plot
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end
  
        % Save image:
        print (printFormat,printResolution, thisFileName)
        close
        
    elseif displayNeighbor == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
          
        %% Chord disorders
    
    % Determining data range used in plot to name file (2.19)
    rangeChordDisorderPlot = rangeChordDisorder; % default
    if isempty(rangeChordDisorder)
        rangeChordDisorderPlot = FindValueRange(CELLS,'chord_disorders');
    end
    
    shortFileName = [Animal  '_ChordDisorders_'  '[' num2str(rangeChordDisorderPlot(1)) '_' num2str(rangeChordDisorderPlot(2)) ']_' , fn '.' imageFormatOutput];
    thisFileName = [frameFolderChordDisorders filesep shortFileName];

    if displayChordDisorder == 1 && ~exist(thisFileName,'file')
        
        % Display image using "CellDisplay"
        CellDisplay(imageLabels, CELLS, 'ChordDisorders', rangeChordDisorder, PLOT);      

        % Box plot
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end
        
        % Saves image:
        print (printFormat,printResolution,thisFileName)
        close
        
    elseif displayChordDisorder == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
 
        %% Side Intensity Disorders %% 

    for r = 1:nRawImages
        
        % Determining data range used in plot to name file (2.19)
        rangeSideIntensityDisorderPlot = rangeSideIntensityDisorder; % default
        if isempty(rangeSideIntensityDisorder)
            rangeSideIntensityDisorderPlot = FindValueRange(CELLS,['SideIntensityDisorders' signalName{r}]); % using "signalName" (3.0)
        end
        
        shortFileName = [Animal  '_SideIntensityDisorders' signalName{r} '_' ... % 3.0
            '[' num2str(rangeSideIntensityDisorderPlot(1)) '_' num2str(rangeSideIntensityDisorderPlot(2)) ']_' fn '.' imageFormatOutput];
        thisFileName = [frameFolderSideIntensityDisorders filesep shortFileName];
        
        if displaySideIntensityDisorder == 1 && ~exist(thisFileName,'file')
        
            % Display image using "CellDisplay":
            CellDisplay(imageLabels, CELLS, ['SideIntensityDisorders' signalName{r}], rangeSideIntensityDisorder,  PLOT); % using "signalName" (3.0)
            
            % Box plot
            if SIAboxMode == 1
                hold on
                if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                    rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
                elseif boxChoice == 3
                    plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
                end
            end
            % Averages of raw image r:
            min_value = evalin('caller',['min_cellSideIntensityDisorders' signalName{r} '_NBC']); % use of "signalName" (3.0)
            max_value = evalin('caller',['max_cellSideIntensityDisorders' signalName{r} '_NBC']);
            mean_value = evalin('caller',['mean_cellSideIntensityDisorders' signalName{r} '_NBC']);
            std_value = evalin('caller',['std_cellSideIntensityDisorders' signalName{r} '_NBC']);
            
            % Saves image:
            print (printFormat,printResolution,thisFileName)
            close
            
        elseif displaySideIntensityDisorder == 1 && exist(thisFileName,'file')
            
            disp(['File "' shortFileName '" already exists => skipped!'])
        end
    end
   
        %% cell Polarity 

    for r = 1:nRawImages
            
            %%% Setting PmodeTag (3.0)
            PmodeTag = '';
            if displayCellMode0
                PmodeTag = [PmodeTag '0']; %#ok<AGROW> % 2.4.6
            end
            if displayCellMode1
                PmodeTag = [PmodeTag '1']; %#ok<AGROW> % 2.4.6
            end
            if displayCellMode2
                PmodeTag = [PmodeTag '2']; %#ok<AGROW> % 2.4.6
            end
            
            shortFileName = [Animal  '_PolarityModes'  signalName{r} '_' PmodeTag '_' fn '.' imageFormatOutput]; % use of "signalName" (3.0), without "_" (3.0)
            thisFileName = [frameFolderPolarityModes filesep shortFileName];
            
        if displayPolarityMode == 1 && ~exist(thisFileName,'file')
            
            %%%% Loading:
            rawImage = evalin('caller',['rawImage_' filenameRawMod{r}]);
            As = evalin('caller',['cellPolarityModes' signalName{r}]); % using signalName (3.0), without "_" (3.0)
            XYsPixels = cellXYs/scale1D;
            plottedCells = nonBorderRNs;

            %%% Cropping quantities to Plotted_cells:
            XYsPixels = XYsPixels(plottedCells,:);
            As = As(plottedCells,:);
            A0s = As(:,1); A1s = As(:,2); B1s = As(:,3); A2s = As(:,4); B2s = As(:,5);
            Is = As2Is(As);
            I0s = Is(:,1); I1s = Is(:,2); Phi1s = Is(:,3); I2s = Is(:,4); Phi2s = Is(:,5);
            theta_star1s = - Phi1s;                                % NB: for angles in TRIGONOMETRIC CONVENTION, one should use theta_stars1s_CC = -theta_star1s = +Phi1s!!!!
            theta_star2s = - Phi2s/2;                              % NB: for angles in TRIGONOMETRIC CONVENTION, one should use theta_stars2s_CC = -theta_star2s = +Phi2s/2!!!!
            
            %%%% Display of modes: ellipse = 0th + 2nd, arrow = 1st:
            figure('PaperPositionMode','auto');
            imshow(rawImage,'Border', 'tight');
            hold on
            % Box plot (2.1c):
            if SIAboxMode == 1
                hold on
                if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                    rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
                elseif boxChoice == 3
                    plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
                end
            end
            %%%%% Mode 0+2 (2.1, 2.4.4):
            if displayCellMode0
                nPlottedCells = length(plottedCells);
                for k = 1:nPlottedCells
                    cell_k_polarity_eig1 = I0s(k) + I2s(k);                     % largest eigenvalue of 0th-2nd modes of intensity
                    cell_k_polarity_eig2 = I0s(k) - I2s(k);                     % smallest eigenvalue
                    Ellipse(1/2*modeScale*cell_k_polarity_eig1, 1/2*modeScale*cell_k_polarity_eig2, XYsPixels(k,1), XYsPixels(k,2),theta_star2s(k), mode2Color, polarityLineWidth)
                    % NB: careful of convention in image: y increases as going down in image, and therefore positive angles are displayed CLOCKWISE with respect to x axis.
                end
            end
            
            %%%%% Mode 1:
            if displayCellMode1
                quiver(XYsPixels(:,1), XYsPixels(:,2), modeScale*cos(deg2rad(theta_star1s)).*I1s, modeScale*sin(deg2rad(theta_star1s)).*I1s, 0, mode1Color,'MaxHeadSize',0.1);
                % NB: drawn after mode 2 so that arrows are above ellipses
            end
            
            %%%%% Mode 2:
            if displayCellMode2
                quiver(XYsPixels(:,1), XYsPixels(:,2), modeScale*1/2*cos(deg2rad(theta_star2s)).*I2s, modeScale*1/2*sin(deg2rad(theta_star2s)).*I2s, 0, mode2Color,'MaxHeadSize',0.001,'LineWidth',polarityLineWidth);
                quiver(XYsPixels(:,1), XYsPixels(:,2), -modeScale*1/2*cos(deg2rad(theta_star2s)).*I2s, -modeScale*1/2*sin(deg2rad(theta_star2s)).*I2s, 0, mode2Color,'MaxHeadSize',0.001,'LineWidth',polarityLineWidth);
                % NB: plot (I0+I2s) instead of I2s alone to check that ellipses are drawn at the right scale
                % Ellipse(30, 10, 100, 100, +30, 'r',line_width)                %  used to test sign of angles: this +30 angle ellipse points DOWNWARD ('ij' axis convention)!
            end
            
            % Plotting info (quantity plotted, time hAPF, animal and scalebar) (2.11):
            %-------------------------------------------------------------------------------
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(n)];
                textQuantity = ['PolarityModes ' signalName{r}];
            end
            PlotInfo(textQuantity, '',0, custom_white, 'I.U.', textAnimal, time, custom_white, polarityScaleBarLength, 1/modeScale, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
            %-------------------------------------------------------------------------------

            %%%%% Saves image:
            print (printFormat,printResolution,thisFileName)
            % NB: saving at very high resolution instead of "print_resolution_Maps" to get clean ellipses and arrows.
            close
            
        elseif displayPolarityMode == 1 && exist(thisFileName,'file')
            
            disp(['File "' shortFileName '" already exists => skipped!'])
        end
    end
   
    %% SIDE RELATED PLOTS %%
    
    clear imageLabels; % 3.1
          
        %% Chord lengths %%
    
    % Saving name:
    shortFileName = [Animal '_ChordLengths_'  fn '.' imageFormatOutput];
    thisFileName = [frameFolderChordLengths filesep shortFileName];
    
    if displayChordLength == 1 && ~exist(thisFileName,'file')
        
        % SPECIFIC TO pten STUDY:
        %---------------------------------------------------------------------------------------------------------------
        these_patch_cells = [];
        SideDisplay(imageSize,SIDES, VERTICES, 'ChordLengths', rangeChordLength);
        %---------------------------------------------------------------------------------------------------------------

        % Plotting info (quantity plotted, time hAPF, animal and scalebar) (2.15):
        %-------------------------------------------------------------------------------
        textAnimal = '';
        textQuantity = '';
        if ~minimalInfoDisplay
            textAnimal = [Animal ' # ' num2str(n)];
            textQuantity = 'Chord length';
        end
        PlotInfo(textQuantity, '',0, colorInfo, '{\mu}m', textAnimal, time, custom_white, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
        %-------------------------------------------------------------------------------

        % Box plot
        if SIAboxMode == 1
            hold on
            if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
            elseif boxChoice == 3
                plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
            end
        end

        % Saves image:
        print (printFormat, printResolution, thisFileName)
        close
        
    elseif displayChordLength == 1 && exist(thisFileName,'file')
        
        disp(['File "' shortFileName '" already exists => skipped!'])
    end
  
        %% Side Intensity %%

    for r = 1:nRawImages
        
        shortFileName = [Animal  '_SideIntensityMap' signalName{r} '_' fn '.' imageFormatOutput]; % use of signalName (3.0), without "_" (3.0)
        thisFileName = [frameFolderIntensities filesep shortFileName];
        
        if displayIntensity == 1 && ~exist(thisFileName,'file')
        
            SideDisplay(imageSize, SIDES, VERTICES, ['Intensities' signalName{r}], rangeIntensity);  % using "signalName" (3.0)
                        
            % Plotting info (quantity plotted, time hAPF, animal and scalebar) (2.15):
            %-------------------------------------------------------------------------------
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(n)];
                textQuantity = 'Side intensity';
            end
            PlotInfo(textQuantity, '',0, mode2Color, 'I.U.', textAnimal, time, custom_white, polarityScaleBarLength, 1/modeScale, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
            %-------------------------------------------------------------------------------

            % Box plot
            if SIAboxMode == 1
                hold on
                if boxChoice == 1 || boxChoice == 2 || boxChoice == 4
                    rectangle('Position',boxXYs,'Curvature',[0,0],'LineWidth',gridLineWidth,'EdgeColor','r');
                elseif boxChoice == 3
                    plot(boxXYs(:,1),boxXYs(:,2),'LineStyle','-','Color','r','linewidth',gridLineWidth);
                end
            end
            % Averages of raw image r:
            min_value = evalin('caller',['min_sideIntensities' signalName{r} '_NBS']); % using signalName (3.0)
            max_value = evalin('caller',['max_sideIntensities' signalName{r} '_NBS']);
            mean_value = evalin('caller',['mean_sideIntensities' signalName{r} '_NBS']);
            std_value = evalin('caller',['std_sideIntensities' signalName{r} '_NBS']);
            
            % Saves image:
            print (printFormat,printResolution,thisFileName)
            close
            
        elseif displayIntensity == 1 && exist(thisFileName,'file')
            
            disp(['File "' shortFileName '" already exists => skipped!'])
        end
    end
     
    %% HISTOGRAM PLOTS %%
    
    %%% HISTOGRAM OF NEIGHBORS:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if neighborHistograms == 1
        savingName = '_Histogram_Neighbors_';
        % choice of category:
        selected_cell_areas = cell_areas_CC;
        selected_cell_n_neighbors = cell_n_neighbors_CC;
        max_selected_cell_n_neighbors = max_cell_n_neighbors_CC;
        n_selected_cells = length(coreRNs);
        name_selected_cells = 'Core cells';
        
        % Plot:
        load('Boris_Colormaps', 'cmap_neighbors');
        fig = figure('PaperPositionMode','auto');
        set(fig, 'color', 'white');
         
        p_neighbors_CC = zeros(nNeighborsMax,1);                                          % will store values of ratio n_neighbors/n_selected_cells FOR CORE CELLS
        X_neighbors = 1:1:nNeighborsMax;                                                  % +1 to fully see the last histogram bar (2.0GMf). removed the +1
        % X_neighbors = 1:1:max_selected_cell_n_neighbors + 1;
        for n_neighbors = 1:nNeighborsMax
            % Restricts cell areas to the one having n_neighbors:
            this_n_cell_areas = selected_cell_areas(selected_cell_n_neighbors == n_neighbors);
            this_n_cell_n_neighbors = selected_cell_n_neighbors(selected_cell_n_neighbors == n_neighbors);
            mean_this_n_cell_areas = mean(this_n_cell_areas);
            n_values = hist(this_n_cell_n_neighbors, X_neighbors);                 % return n_values = 1x(n_neighbors_max+1) giving distrib of "this_n_cell_n_neighbors" along values listed in "X_neighbors"
            p_neighbors_CC(n_neighbors) = n_values(n_neighbors)/n_selected_cells;  % stores this value in p_neighbors_CC
            this_color = Neighbor_Color_Generator(cmap_neighbors, n_neighbors);
            this_bar = bar(X_neighbors, n_values/n_selected_cells);
            set(this_bar,'FaceColor', this_color)
            hold on
            if ~isnan(mean_this_n_cell_areas)
                text(n_neighbors, 0.85, [num2str(mean_this_n_cell_areas, '%0.1f') ' {\mu}m^2'],'Rotation', 90, 'FontSize', 8);
            end
        end
        % Title and info:
        axis([0 nNeighborsMax+1 0 1]);                                    % Uses "n_neighbors_max". Starts at 0 
        % axis([1 max_selected_cell_n_neighbors+1 0 1]);
        xlabel( 'Number of neighbors n', 'FontSize', fontSizeInfo );
        ylabel( 'P(n)', 'FontSize', fontSizeInfo, 'Rotation', 90 );
        title(['Number of neighbors (' num2str(n_selected_cells) ' ' name_selected_cells ')     ' Animal '    Frame: ' num2str(n,digitsFormat)...
            '    '   SIAmode ' ' version '     ' today '   ' When,'   '],'FontSize', fontSizeInfo)
        print (printFormat,printResolution,[histNeighborsFolder filesep SIAmode  '_' Animal  savingName , fn '.' imageFormatOutput])
        close
        
        %%% P(n_neighbors) of Core cells:
        % NB: "p_neighbors" MUST HAVE BEEN CALCULATED ON CORE CELLS (cf Histogram of neighbors)
        globalnNeighborsCC(iterationIndex,:) = p_neighbors_CC';
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %%% HISTOGRAM OF CHORD LENGTHS:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if chordHistograms == 1
        % choice of category of chords to display:
        quantity_display = side_chord_lengths_NBS;                         % NBS: Core_sides + Core-FL_sides + FL_sides (does not contain Border-FL_sides)
        quantity_range = rangeChordLength;
        quantity_bin = 0.5;
        n_selected_cells = length(nonBorderRNs);
        name_selected_cells = 'NB cells';
        savingName = '_Histogram_Chords_';
        
        % sorting and plot:
        load('Boris_Colormaps', 'cmap_sides');
        n_display = Hist_Side_Display(quantity_display, quantity_range, quantity_bin, cmap_sides);
        
        % Title and info:
        xlabel( 'Chord Length l ({\mu}m) ', 'FontSize', fontSizeInfo );
        ylabel( 'P(l) ', 'FontSize', fontSizeInfo, 'Rotation', 90 );
        title(['Chord lengths (' num2str(n_selected_cells) ' ' name_selected_cells ', ' num2str(n_display) ' chords, range [' num2str(rangeChordLength) '] {\mu}m)    ' ...
            Animal '    Frame: ' num2str(n,digitsFormat) '    ' SIAmode ' ' version '     ' today '   ' When,'   '],'FontSize', fontSizeInfo)
        print (printFormat,printResolution,[histChordLengthsFolder filesep SIAmode  '_' Animal  savingName , fn '.' imageFormatOutput])
        close
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    %%% Progress display:
    if progressDisplay == 1
        progressbar(iterationIndex/nFrames)
    end
    
    clear CELLS SIDES VERTICES % 3.0
    disp('---------------------------------------------------------------------------------'); 
    
end


%% Saving Global Cell & Side Statistics over ALL FRAMES %%


if anyStatistics == 1                
    
    disp(' ');
    disp('*********************************************************************************');
    disp(' ');
    disp([SIAmode ' ' version  ': saving GLOBAL STATISTICS over all frames for "' Animal '"']); 
    disp('---------------------------------------------------------------------------------');  
    
    if anyStatistics == 1
        if nFrames > 1
            frame_range = [num2str(startFrame,digitsFormat) '-' num2str(finalFrame,digitsFormat)];
        else
            frame_range = num2str(n,digitsFormat);
        end
    end
    
    %% Cells:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if cellStatistics == 1
        
        disp('Saving global cell statistics in .xlsx file... ');
        
        %%% Builds a cell table to save as a xlsx file:
        % Adaptation to >1 raw images:
        global_cell_headings_partI = {        'Frame #'                         'n' ...
            'Mean areas (?m^2)'                'Std areas (?m^2)'         'Std/Mean areas' ...
            'Mean contours (?m)'              'Std contours (?m)'       'Std/Mean contours' ...
            'Mean roundnesses (?m)'           'Std roundnesses (?m)'    'Std/Mean roundnesses' ...
            'Mean n neighbors'                'Std n neighbors'         'Std/Mean n neighbors' ...
            'Mean anisotropies'               'Std anisotropies'        'Std/Mean anisotropies' ...
            'Mean orientations (?)'           'Std orientations'        'R orientations'  ...
            'Mean side disorders'             'Std side disorders'      'Std/Mean side disorders' ...
            'Mean chord disorders'            'Std chord disorders'     'Std/Mean chord disorders' ...
            'Mean RSP sides'                  'Std RSP sides'           'Std/Mean RSP sides' ...
            'Mean RSP chords'                 'Std RSP chords'          'Std/Mean RSP chords' ...
            'eta_<M>'                         's_<M> (?m^2)'             'theta_<M> (?)'     };
        
        global_cell_headings_partII = [];
        for r = 1:nRawImages
            global_cell_headings_addon =  {['Mean side I disorders "' filenameRawMod{r} '"']     ['Std side I disorders "' filenameRawMod{r} '"']     ['Std/Mean side I disorders "' filenameRawMod{r} '"']}; 
        
            global_cell_headings_partII = [global_cell_headings_partII global_cell_headings_addon];                  %#ok<AGROW>
        end
        % Merging  parts:
        global_cell_headings = [global_cell_headings_partI global_cell_headings_partII];
        
        % Excel file path and initialization:
        this_Excel_file = [cellStatisticsFolder filesep SIAmode  '_' Animal  '_Global_Cell_Statistics_' frame_range  '.xlsx'];
        [Excel,  ExcelWorkbook] = xlswrite2007Intro(this_Excel_file);
        
        % Writing in xlsx file:
        global_cell_table_NBC = [global_cell_headings ; num2cell(globalCellStatisticsNBC)];
        xlswrite2007(this_Excel_file, global_cell_table_NBC, 'Non-Border cells');
        
        global_cell_table_FLC = [global_cell_headings ; num2cell(globalCellStatisticsFLC)];
        xlswrite2007(this_Excel_file, global_cell_table_FLC, 'First Layer cells');
        
        % Adding Phi_areas and Phi_n_neighbors for core cells
        %------------------------------------------------------------------
        globalCellHeadingsCC_ext = [global_cell_headings  'Phi Areas'  'Phi Neighbors' ];
        globalCellStatisticsCC_ext = [globalCellStatisticsCC  allPhiAreas  allPhinNeighbors];
        global_cell_table_CC = [globalCellHeadingsCC_ext ; num2cell(globalCellStatisticsCC_ext)];
        xlswrite2007(this_Excel_file, global_cell_table_CC, 'Core cells');
        %------------------------------------------------------------------
        
        % Additional Excel sheet for P(n_neighbors) for Core cells:
        if neighborHistograms == 1
            global_p_neighbors_CC_headings = cell(1,nNeighborsMax);
            for p = 1:nNeighborsMax
                global_p_neighbors_CC_headings{p} = ['P(' num2str(p) ')'];
            end
            global_p_neighbors_CC_table = [global_p_neighbors_CC_headings; num2cell(globalnNeighborsCC)];
            xlswrite2007(this_Excel_file, global_p_neighbors_CC_table, 'P(n) Core cells');
        end
        
        % code for xlswrite2007:
        xlswrite2007Outro;
        pause(0.1)
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %% Sides:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if sideStatistics == 1
        
        disp('Saving global side statistics in .xlsx file... ');
        
        %%% Builds a cell table to save as a xlsx file:
        % Adaptation to >1 raw images:
        global_side_headings_partI = {       'Frame #'                         'n' ...
                                             'Mean chord lengths (?m^2)'        'Std chord lengths (?m^2)'                           ...
                                             'Mean side lengths (?m)'          'Std side lengths (?m)'                             };
        
        global_side_headings_partII = [];
        for r = 1:nRawImages
            global_side_headings_addon =  {['Mean chord orientations "' filenameRawMod{r} '"']         ['Std chord orientations "' filenameRawMod{r} '"']...
                ['R chord orientations "' filenameRawMod{r} '"']         ['Mean side I "' filenameRawMod{r} '"']           ['Std side I "' filenameRawMod{r} '"']}; 
        
            global_side_headings_partII = [global_side_headings_partII global_side_headings_addon];                  %#ok<AGROW>
        end
        % Merging  parts:
        global_side_headings = [global_side_headings_partI global_side_headings_partII];
        
        % Excel file path and initialization:
        this_Excel_file = [sideStatisticsFolder filesep SIAmode  '_' Animal  '_Global_Side_Statistics_' frame_range  '.xlsx'];
        [Excel,  ExcelWorkbook] = xlswrite2007Intro(this_Excel_file);
        
        % Writing in xlsx file:
        global_side_table_ANBS = [global_side_headings ; num2cell(globalSideStatisticsANBS)]; 
        xlswrite2007(this_Excel_file, global_side_table_ANBS, 'All Non Border Sides');
        
        global_side_table_NBS = [global_side_headings ; num2cell(globalSideStatisticsNBS)];
        xlswrite2007(this_Excel_file, global_side_table_NBS, 'Non-Border Sides');
        
        global_side_table_ABS = [global_side_headings ; num2cell(globalSideStatisticsABS)]; 
        xlswrite2007(this_Excel_file, global_side_table_ABS, 'All Border Sides');
        
        global_side_table_BS = [global_side_headings ; num2cell(globalSideStatisticsBS)];
        xlswrite2007(this_Excel_file, global_side_table_BS, 'Border Sides');
        
        global_side_table_AFLS = [global_side_headings ; num2cell(globalSideStatisticsAFLS)];
        xlswrite2007(this_Excel_file, global_side_table_AFLS, 'All FL Sides');
        
        global_side_table_BFLS = [global_side_headings ; num2cell(globalSideStatisticsBFLS)]; 
        xlswrite2007(this_Excel_file, global_side_table_BFLS, 'Border-FL Sides');
        
        global_side_table_FLS = [global_side_headings ; num2cell(globalSideStatisticsFLS)];  
        xlswrite2007(this_Excel_file, global_side_table_FLS, 'FL Sides');
        
        global_side_table_ACS = [global_side_headings ; num2cell(globalSideStatisticsACS)];
        xlswrite2007(this_Excel_file, global_side_table_ACS, 'All Core Sides');
        
        global_side_table_CFLS = [global_side_headings ; num2cell(globalSideStatisticsCFLS)];
        xlswrite2007(this_Excel_file, global_side_table_CFLS, 'Core-FL Sides');
        
        global_side_table_CS = [global_side_headings ; num2cell(globalSideStatisticsCS)];
        xlswrite2007(this_Excel_file, global_side_table_CS, 'Core sides');
        
        % code for xlswrite2007:
        xlswrite2007Outro;
        pause(0.1)
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %% Vertices:
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if vertexStatistics == 1
        
        disp('Saving global vertex statistics in .xlsx file... ');
        
        %%% Common Table headings:
        global_vertex_headings =  {'Frame #'            'n vertices'                 'n 3-vertices'               'n 4-vertices'              '% 4-vertices' };
        
        % Excel file path and initialization:
        this_Excel_file = [VertexFolder filesep SIAmode  '_' Animal  '_Global_Vertex_Statistics_' frame_range  '.xlsx'];
        [Excel,  ExcelWorkbook] = xlswrite2007Intro(this_Excel_file);    

        % Overlapping subsets:
        global_vertex_table_ABulkV = [global_vertex_headings ; num2cell(globalVertexStatisticsABulkV)];
        xlswrite2007(this_Excel_file, global_vertex_table_ABulkV, 'All Bulk (Non-Edge)');
        
        global_vertex_table_ABV = [global_vertex_headings ; num2cell(globalVertexStatisticsABV)];
        xlswrite2007(this_Excel_file, global_vertex_table_ABV, 'All Border');
        
        global_vertex_table_AFLV = [global_vertex_headings ; num2cell(globalVertexStatisticsAFLV)];
        xlswrite2007(this_Excel_file, global_vertex_table_AFLV, 'All FL');
        
        global_vertex_table_ANCV = [global_vertex_headings ; num2cell(globalVertexStatisticsANCV)];
        xlswrite2007(this_Excel_file, global_vertex_table_ANCV, 'All Non-Core');
 
        global_vertex_table_ACV = [global_vertex_headings ; num2cell(globalVertexStatisticsACV)];
        xlswrite2007(this_Excel_file, global_vertex_table_ACV, 'All Core');
        
        
        % Bulk Partition:
        global_vertex_table_BV = [global_vertex_headings ; num2cell(globalVertexStatisticsBV)];
        xlswrite2007(this_Excel_file, global_vertex_table_BV, 'Border');
        
        global_vertex_table_BFLV = [global_vertex_headings ; num2cell(globalVertexStatisticsBFLV)];
        xlswrite2007(this_Excel_file, global_vertex_table_BFLV, 'Border-FL');
        
        global_vertex_table_FLV = [global_vertex_headings ; num2cell(globalVertexStatisticsFLV)];
        xlswrite2007(this_Excel_file, global_vertex_table_FLV, 'FL');
        
        global_vertex_table_NCV = [global_vertex_headings ; num2cell(globalVertexStatisticsNCV)];
        xlswrite2007(this_Excel_file, global_vertex_table_NCV, 'Non-Core');
        
        global_vertex_table_CFLV = [global_vertex_headings ; num2cell(globalVertexStatisticsCFLV)];
        xlswrite2007(this_Excel_file, global_vertex_table_CFLV, 'Core-FL');

        global_vertex_table_CV = [global_vertex_headings ; num2cell(globalVertexStatisticsCV)];
        xlswrite2007(this_Excel_file, global_vertex_table_CV, 'Core');        

        %%% code for use of xlswrite2007:
        xlswrite2007Outro
    end
    
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% History %%

% KNOWN BUGS:
% - the "Box" mode has rapidly been updated and may contain some bugs
% - the "cellStatistics" part has NOT been updated for a very long time

% FUTURE IMPROVEMENTS:
%--------------------------------------------------------------------------
% - possibility to draw several boxes at once
% - possibility to run it without generating SIDES, VERTICES and NOT
% calculate quantities on intensity?
% - fully fix box mode (oneCellFrontier = 0) crashes
% - fix histograms and statistics part
%--------------------------------------------------------------------------

% 13/02/2018: created function "SegmentedImageAnalysisFUN" from SIA 3.4
% - added path to "AIAparameters.mat" as unique argument 
% - turned every "evalin('base',...)" into "evalin('caller',...)"
% - updated "CellStatistics" and "SideStatistics" by replacing
% "evalin('caller',...)" by "eval(...)"

% 09/02/2018: 3.4
% - removed structure "FRAME" from everywhere
% - removed all warnings involved in testing varialbe "noWarning" that has
% been set to 0 for ages.
% - removed variable "replotSIA": now backups are ever recalculated anyway
% when they exist, and plot will only occur if "noDisplay" is set to false
% AND when the image doesn't already exists
% - "program" became "SIAmode"
% - removed varialbes "programName" and "programTag"
% - removed all history before version 2.2
% - took "imageLabels = bwlabel(segImage,4);" out of "if SIAboxMode" choice
% since was also required for box processing

% 25/01/2018: 3.3
% - removing "_" before all signal names (that now must have an upper case)
% replaced everywhere "_' signalName" by "' signalName"

% 24/01/2018: 3.2
% - fixed bug when a multiple-part side was forming a closed contour
% (encountered on a histoblast image)
% - removed last occurences of support of older backups

% 23/01/2018: 3.1
% - now saves main parameter values in the txt file
% - now erasing the biggest (memory wise) matrices during main execution
% - during background intensity removal, now loads DILATED version of sides
% to skip an iteration of dilation => faster execution!
% - decreased value of "skelDilatationBG" to 4 pixels => faster execution!
% - "intDilatation" became "skelDilatation" (and it BG version)
% - broke down "Skeleton" into 3 relevant matrices
% - updated BOX processing part
% - "boxSideThickness" became "gridLineWidth"

% 17-22/01/2018: 3.0
% - Core_cells, FL_cells, Border_cells... became coreRNs, FLRNs, borderRNs
% - removed "cell_rsp_chords", "side_chord_angles", "cell_types",
% "side_types"
% - removed "displayChordAngle", "displayRSPchord"
% - changes to make it work with all AIA routines new names
% - properly skips ALL images already existing
% - removed "nameAddonInt" and replaced it by 'NoBG_' since was always used
% - stopped defining and storing redundant cell arrays "allVertices",
% "Vertices", "edgeVertices"
% - in VERTICES, removed redundancy between cell array "Cells" and matrix
% "CellsMat" to only keep the latter (renamed "Cells")
% - replaced "allVertexTypes" by "allVertexnCells"
% - overhaul of "RNs&Vs" plot
% - "cellCentroids" became "cellXYs"
% - removed output "Ianisotropy2" that is just Ianisotropy2 = 1 - (1-Ianisotropy)^2
% - stopped calculating area and neighbor disorders
% - fixed issue in determining number of subparts of sides
% - update of "SideDilator" => faster execution!

%
% 12/01/2018: 2.21
% - moved out filling of "PLOT" structure to AIA_parameters
%
% 19/09/2017: 2.20
% - WHEN THEY EXIST, renaming of old backups "SIA_Animal_Backup_000X.mat" into "SIA_Animal_000X.mat"
% - minor adjustments and changes of variables and folder names (Numbers and Vertices became RNsAndVs...)
%
% 23/06/2017: 2.19
% - display of color bar on every generated image with "PlotColorBar"
% - stopped generating images for "rsp_chords" and "chord_angles"
% - finally using "SideDilator" instead of "Side_Dilatator"
% - reUpdates "imageSize" to treat series of images of different size

% 19/05/2017: 2.18
% - look for 2.18 in the text
%
% 15/02/2017: 2.17
% - look for 2.17 in the text
%
% 06/07/2016: 2.16
% - new display of cell anisotropies that both uses cell anisotropy AND orientation
% - removed parameter "displayOrientation"
% - accordingly removed old cell anisotropy and orientation plots
% - further simplified cell plots (since CellDisplay contains PlotInfo)
%
% 05/07/2016: 2.15
% - use interation over "frames" defined in AIA rather than startFrame:finalFrame
% - removed MIA execution = > removed parameters useMIA, MIA
% - defintion of "nRawImages" now done in AIA (6.5) for ALL declared raw images
% - completely removed parameter "polarityRawImages": now SIA intensity related quantities are ALWAYS calculated WITH REMOVAL of background intensity
% - removed MANY parameters in AIA for SIA execution and here:
% sideLengths, Side_lengths_AIA, displayRSPside, displayLength, sideHistograms, displaySideDisorder, sideIntensity, Side_Intensity_AIA,
% polarityRawImages, polarityModes, backgroundRemoval, Background_removal_AIA, originalResolution 
% - updated names of variables saved in structure FRAME => may cause some bugs in other programs

% 23/05/2016: 2.14
% - now checks the existence of backup before actually recalculating it and skips it when found
% - display of animal being treated in progressbar
%
% 28/04/2016: 2.13
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage
%
% 08/04/2016: 2.12
% - now checks the existence of "SkeletonPixelsList_n.txt" file for each frame and uses it if found, otherwise does
% without it.

% 27/05/2015: 2.11 became "SegmentedImageAnalysis"
% - changed many parameter names to match AIA 6.0
% - stopped diplaying polarity mode images when noDisplay = 1

% 22/05/2015: 2.10
% - updated "CellDisplay" for full wing processing (Kaoru)

% 15/04/2015: 2.9
% - fixed bug when not using "skeletonPixelList" txt file from C++ tracking
% - rechecked equality of Skeleton matrixces coming from C++ or directly calculated.

% 13/04/2015: 2.8
% - commented parts defining "Phi_areas" because of bug involving "mean_cell_areas_CC" not defined

% 21/07/2014: 2.7
% - extensive use of 'filesep' for mac compatibility
% - replaced ?m by 

% 25/02/2014: 2.6
% - REMOVED CORRECTION OF 4-PIXEL BLOCKS: ALL SEGMENTED IMAGES MUST GO THROUGH "Four_Pixel_Blocks_Filter" AS LAST STEP OF THE SEGMENTATION PROCESS.
% - chages to make program run with new Scalebar_Plotter (1.3)

% 18/02/2014: 2.5.2
% - moved out parameters to plot circles around vertices "circle_size" and "circle_width" into AIA_parameters

% 29/10/2013: 2.5.1
% - now computes and stores vertex tensor matrices (Vs), vertex polarity (Vpolarities) and vertex orientation (Vorientations)

% 03/07/2013: 2.5.0
% - now computes and stores inertia matrices (Is), inertia anisotropies (Ianisotropies) and inertia orientation (Iorientations)  

% 19/02/2013: 2.4.7
% - added a scalebar for mode polarity

% 12/02/2013: 2.4.6
% - specifies which polarity modes were plotted in filename

% 5/02/2013: 2.4.5
% - added support of "reload_box" option
% - fixed BOX issue: an empty box was saved in backups when using SIA in normal mode, causing problems when using box.

% 3/12/2012: 2.4.3
% - changed the BG intensity is calculated (the way pixels with BG intensity are found using NaNs instead of 0s)
% - now uses "Resolution" to display PCP maps

% 30/11/2012: 2.4.2
% - display error message and stop program execution when "BG_int_dil_value" is too small and generate NaN values in
% "side_BG_intensities"

% 10/07/2012: 2.4.1
% - adjustments to display of chord lengths to match Fig. 1 of pten paper (black bg, green long chords, magenta short
% chords...). For this purpose use of function "SideDisplayPten" modified from "Side_Display".

% 15/05/2012: 2.4.0
% - pre-allocation of side related arrays (side_vertices, side_indices...) to make program run faster (required for Full
% Thorax processing)
% - stopped removing 4-pixel vertices when using Cpp skeleton (otherwise mismatch between SIA backup and Skeleton)

% 04/05/2012: 2.3.2
% - adjustments to Cpp tracking update 3.2.6: now "skeletonPixelsList_n.txt" stored in "Output_results"

% 13/04/2012: 2.3.1
% - VALIDATED THE NEW WAY OF DETERMINATION OF "Skeleton" matrix BY PROCESSING THE 193 FRAMES OF the small scutellum
% - added option to determine "Skeleton" matrix according to value of parameter "skeletonPixelsList_use"

% 12/04/2012: 2.3.0
% - started implementation of building matrix "Skeleton" straight from "skeletonPixelsList_n.txt"

% 11/04/2012: 2.2
% - now overrides parameters according to values of "noDisplay/_statistics" here instead of AIA
% - only creates folders "Cells" and "Sides" if something will be stored in it



