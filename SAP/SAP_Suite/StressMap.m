% StressMap
%
% Will determine junctional elastic stress S (SP: pressure part, ST: tension part) from single cell pressures and single
% edge tensions computed by "STPEstimate".
%
% NB: in getVertex, all (X,Y) coordinates have been determined with "xy" axis convention (default) leading to Xs all >0 
% and Ys all <0 for all cells, vertices and edges. Here, to match tensor analysis and image "ij" convention, the stress 
% is calculated in "ij" convention (THEREFORE USING -YS INSTEAD), namely its corresponding major axis will point down if
% the angle with the x axis is POSITIVE.
% 
% NB: Comments about stress units and renormalization by scale1D in the "renormalization by scale1D" section (3.4)
%
% NB: programs does NOT recalculate backups when they're found; if "makePlots_SM = false" AND last backup is found,
% directly skips the whole execution; if "makePlotsSM = true", will replot images even if they exist
%
 version = '4.3';
% Boris Guirao
% Shuji Ishihara

%% Additional parameters & defs %%

% upper bound on allowed number of edges per cell (4.2)
nEdgesMax = 20;               

% Defines ALL POSSIBLE quantities to plot (3.9):
AllQsColorsUnits;
allQs =  allQsSM;
allColors = allColorsSM;
allUnits = allUnitsSM; 
allScaleRatios = scaleRatioSM;   
allScaleBarLengths = scaleBarLengthSM;
allKillMeanTraces = killMeanTraceSM;

% duplicating "allScaleRatios" when only one specified (3.17)
nAllQs = length(allQs);
if length(scaleRatioSM) == 1
    allScaleRatios = repmat(scaleRatioSM,nAllQs,1);
    allScaleBarLengths = repmat(scaleBarLengthSM,nAllQs,1);
end

time = frame2time(fn, timeRef, frameRef, dt,'str');     % determines time hAPF (mod 3.15)
filenameRaw_fn = [rootFilename num2str(fn, digitsFormat)];
filenameSTPE_fn = [filenameSTPE '_' num2str(fn, digitsFormat)];   % 3.10
filenameSM_fn = [filenameSM '_' num2str(fn, digitsFormat)];       % 3.10


%%% Displays workspace info (4.0)
disp(' '); disp(' ');
disp(['Running "StressMap" version ' version ' with ' gridType 'Grid on "' filenameRaw_fn '"...']);% 3.12
disp('---------------------------------------------------------------------------------');


%% 1st frame INITIALIZATION: Grid Loading, Checking existence of last SM backup, creating folders (4.0)  %%

if fn == frames2process(1) 
    
    %%% LOADING Grid to be used from CPT backup(4.0) %%
    GRID_DEF = load(pathGridDefFile);
    nx = GRID_DEF.Size(2);
    ny = GRID_DEF.Size(1);
    nBoxes = nx*ny;
    
    if ~cloneTracking
        xywh = GRID_DEF.xywh;
        BoxArea = xywh(3)*xywh(4);
    end
    
    %%% Defining directory paths:
    saveFolder = [pathFolderSM filesep gridSpecs];     % Grid specific subfolder:
    backupFolder = [saveFolder filesep 'Backups'];
    frameFolder = [saveFolder filesep plotType ]; 

    %%% Checking Existence of last backup before running ONLY if makePlotsSM = false (3.14, 4.0) %%
    if ~makePlotsSM
        thisFilename = [filenameSM '_' num2str(finalFrame, digitsFormat) '.mat'];
        lastBackup = [backupFolder filesep thisFilename];
        if exist(lastBackup,'file')
            fprintf('\nSM WARNING: LAST backup already exists. Skipping SM execution...\n');
            close; % closes grid figure
            disp('---------------------------------------------------------------------------------');
            return % 4.1
        end
    end  
    
    %%% Creating directories (3.9) %%
    mkdir(pathFolderSM);                                      % parent directory
    mkdir(saveFolder)
    mkdir(backupFolder)
    
    % Saving txt file indicating date and version used in "saveFolder" (3.14)
    today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style. Look up date for details
    txtFilename = [today '_SM_' version '.txt'];
    dlmwrite([saveFolder filesep txtFilename], 'SM only involves display parameters!', 'delimiter', '', 'newline','pc')
    
    % Starting progressbar (3.14)
    progressbar(['SM iteration over ' Animal ' frames...'])
    % NB: the progressbar update is done i AIA_parameters
    
end


%% ITERATION OVER GRID COMPARTMENTS TO DETERMINE S, SP, ST %%

SM_backup = [backupFolder filesep filenameSM_fn '.mat'];                        % 3.10

if ~exist(SM_backup, 'file') % 4.0    
    
    %% Loading STPE backup and Extracting data %%
    
    STPEbackup_fn = [pathFolderSTPE filesep 'Backups' filesep filenameSTPE_fn '.mat']; % 4.1
    
%     STPEbackup_fn = [pathFolderSTPE filesep 'Backups_' STPEtag filesep filenameSTPE_fn '.mat' ]; % 3.10, 3.17
%     oldSTPEbackup_fn = [pathFolderSTPE filesep 'Backups_' oldSTPEtag filesep filenameSTPE_fn '.mat' ]; % 3.6,3.9, 3.17
    
    STPEbackupFound = false;
    if exist(STPEbackup_fn, 'file')
        STPEbackupFound = true;
        fprintf(['Loading backup "' filenameSTPE_fn '"...']) % just using "filenameSTPE_fn" (4.0)
        load(STPEbackup_fn,'Js','Es','Cs','ep');
        fprintf('Done.\n')
    else
        disp(['Backup "' filenameSTPE_fn '.mat" was not found and was skipped!']); % mod 4.1
    end
    
    
    %% Iteration: determination of S,SM,SP... %%
    
    if STPEbackupFound
        
        ExtractData(Js,'','caller');
        ExtractData(Es,'','caller');
        ExtractData(Cs,'','caller');
        
        E_NUM = length(EDs);     % nb de bords
        C_NUM = length(CnJs);    % nb de cellules
        X_NUM = length(ep);      % nb d'inconnues T,P
        
        Ens = (1:E_NUM)';       % list of Edge numbers                                                                                                      % edge identities
        Cns = (1:C_NUM)';       % list of Cell numbers
        CExts = Cs.CExts;       % list of "External" cells as listed by Shuji (3.7)
        
        Ts = ep(1:E_NUM);
        Ps = ep(E_NUM+1:X_NUM); % /scale1D; NOT RESCALING P THAT IS EXPRESSED IN 1/PIXEL? AND THAT GET MULTIPLICATED BY AREAS IN PIXEL?
        
        
        %% Determining Cell Areas, Cell-Edge relation & Cell vertex-based center %%
        
        fprintf('Determining polygonal area, edge numbers and vertex-based centroid for each cells...')
        CAs = NaN(C_NUM,1);
        CXYs = NaN(C_NUM,2);                                  % will store each cell XY (3.1)
        CEs = NaN(size(CJs,1),min(nEdgesMax, size(CJs,2)+1));   % CEs: cell edges. NB: a cell should have as many edges as vertices !
%         CEs = NaN(size(CJs));
        for c = Cns'
            % This cell vertices without NaNs:
            cCJs = RemoveNaNs(CJs(c,:));           % gets cell c vertices
            
            % Polygonal areas (3.1):
            CAs(c) = PolygonArea(cCJs,JXs,JYs);     % cell c area
            
            % Edge numbers belonging to cell c:
            inEJ1s_TF = ismember(EJ1s,cCJs);  % les segments qui touchent la cellule c par un bout                              % looks for locations of edges whose j1s are in cCJs
            inEJ2s_TF = ismember(EJ2s,cCJs);  % les segments qui touchent la cellule c par l'autre bout                         % same for j2s
            inBoth_TF = all([inEJ1s_TF inEJ2s_TF],2); % les segments qui entourent la cellule c
            cCEs = Ens(inBoth_TF);           % nos des segments qui entourent la cellule c                                     % list edges for which BOTH j1 AND j2 were found in cCJs
            ncCEs = length(cCEs);             % nb de bords de la cellule c
            ncCEs = min(nEdgesMax, ncCEs);      % cutting number of edges at "nEdgesMax" (4.2)
            CEs(c,1:ncCEs) = cCEs(1:ncCEs);     % matrice des bords de la cellule c % SHOULD IT BE STORED IN Cs???
            
            % Cell XYs IN PIXELS (3.1):
            cX = mean(JXs(cCJs));
            cY = mean(JYs(cCJs));
            % CHANGE OF AXIS CONVENTION:
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            CXYs(c,:) = [cX -cY]; % - SIGN FOR Y
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
        end
        fprintf('Done.\n')
        
        
        %% Determination of ST,SP,S in every grid compartments %%
        
        ShujiRNs = cell(ny,nx);            % will store Shuji RNs in each box compartment (4.0)
        nShujiRNs = zeros(ny,nx);
        % NB: "Core" are Shuji's cells that are NOT "Ext" cells

        % Initialization of 1D and 3D matrices for ST,SP,S (3.14):
        P = NaN(ny,nx); % 3.10
        SP = NaN(ny,nx);
        ST = NaN(ny,nx,4); 
        S = NaN(ny,nx,4);

        % % CHANGE OF AXIS CONVENTION:
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        EdYs = -EdYs;
        % NB: EdXs = EX1s-EX2s;   EdYs = EY1s-EY2s, X1/2,Y1/2 being the coordinates of vertices J1/2 making up edges Es.
        % convention: Xs all >0 BUT Ys all <0, hence taking here -EdYs to switch from "xy" to "ij" convention
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        %% Loading CPT & MSM backups (E or L grids) (4.0) %%

        %%% CPT backups
        fprintf(['Loading CPT backup "' filenameCPT '_' num2str(fn, digitsFormat) '.mat"...'])
        fileCPT = [pathCPTbackupFiles '_' num2str(fn, digitsFormat) '.mat'];
        buCPT = load(fileCPT);
        
        gridCoreRNs = buCPT.CoreRNs; % may contain some FL cells
        gridMaskTF = buCPT.MaskTF;      
        gridContourIndices = buCPT.ContourIndices;
        gridnCoreRNs = buCPT.nCoreRNs;
        gridAreaRatios = buCPT.AreaRatios;
       
        if strcmp(gridType,'L')
            gridLcentroids = buCPT.Lcentroids;           
        end
        fprintf('Done.\n')
        
        %%% MSM backups
        fprintf(['Loading MSM backup "' filenameMSM '_' num2str(fn,digitsFormat) '.mat"...'])
        fileMSM = [pathFolderMSM  filesep 'Backups' filesep filenameMSM '_' num2str(fn,digitsFormat) '.mat'];
        buMSM = load(fileMSM);
        CsMSmatch = buMSM.Cs_MS_match;
        fprintf('Done.\n')
  
        
        %% ITERATION over grid compartments %%
        
        fprintf('Determining ST, SP and S for each grid compartment...')
        for b = 1:nBoxes
            
            [ky,kx] = ind2sub([ny nx],b);                           % turns linear index b into (i,j) grid coordinate (3.17)
                        
            %% Determining Shuji RNs in this grid compartment "boxCns" (4.0) %%
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            boxCoreRNs = gridCoreRNs{ky,kx};                % retrieving list OF MATLAB CORE RNs loaded from CPT
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            boxShujiRNs = CsMSmatch(boxCoreRNs,2);          % corresponding cell Shuji RNs
            boxShujiRNs = boxShujiRNs(boxShujiRNs > 0);     % removes unmatched cells tagged with number 0
    
            
            if ~isempty(boxShujiRNs)
                
                %%  Determination of corresponding edges "boxEns" %%
                
                boxEns = CEs(boxShujiRNs,:);                % selects all lines of edges corresponding to cells in this box
                boxEns = RemoveNaNs(unique(boxEns));        % turns it into an ordered vector without NaN
                % NB: ALL edges of cells whose centroids have been found in the box are kept, even edges lying at the outer bounds
                
                
                %% Determination of  boxCellArea (4.0) %%
                
                boxCellArea = sum(CAs(boxShujiRNs));         % total area of CELLS in the box (not just the polygon making up the box) (moved here 3.7)
                
                
                %% Determination of Pressure part of Stress tensor: SP (mod 3.10)%%
                
                % uses scalar product to calculate sum(Pi*Ai) over cells i in the box, then renormalizes by total cell area
                SPbox = - Ps(boxShujiRNs)'*CAs(boxShujiRNs)/boxCellArea; % renormalization by Acells_box instead of Abox (3.7), became scalar (3.10)
                
                
                %% Determination of Tension part of Stress tensor: ST %%
                
                % NB: EdYs sign has been changed before loop on grid compartments (3.2)
                ST_xx = sum( Ts(boxEns).*EdXs(boxEns).*EdXs(boxEns)./EDs(boxEns) )/boxCellArea; % renormalization by Acells_box instead of Abox (3.7)
                ST_xy = sum( Ts(boxEns).*EdXs(boxEns).*EdYs(boxEns)./EDs(boxEns) )/boxCellArea; % renormalization by Acells_box instead of Abox (3.7)
                ST_yy = sum( Ts(boxEns).*EdYs(boxEns).*EdYs(boxEns)./EDs(boxEns) )/boxCellArea; % renormalization by Acells_box instead of Abox (3.7)
                
                STbox = [ST_xx ST_xy ST_xy ST_yy];
                
                
                %% Determination of mean Pressure: P (3.2)%%
                
                Pbox = mean(Ps(boxShujiRNs));           % mean cell pressure in box (3.10)
                
                % NB: Pbox differs from SPbox because it is NOT weighted by cell areas, and accordingly, is NOT
                % directly related to stress
                
                
                %% Renormalization by "scale1D" and Global Stress S = SP + ST %%
                
                % NB: Energy in N.m => Tij = dE/dLij in Newtons (N) => T'ij determined in Shuji: T'ij = Tij/f, f unknown scaling factor in N
                % => Pi = d?E/dAi in N/m => Pi = f*P'i + Po => P'i = (Pi-Po)/f in m-1, BUT calculated with all lengths in PIXELS
                %        |----------------------------------------------|
                % =>     | P'i in pixels-1 right out of Shuji's program |
                %        |----------------------------------------------|
                % stress S has same units as P, namely N/m => *** S' ultimately in m-1 as well ***, but so far used lengths in PIXELS
                % => S'(pixels-1) so far, scale1D in ?m/pixel -> S'/scale1D now in ?m-1
                % THEREFORE, EVEN THOUGH THE STRESS AMPLITUDE IS NOT KNOWN (f FACTOR IN NEWTONS UNKNOWN), IT RESCALES WITH IMAGE RESOLUTION "scale1D"
                
                SPbox = SPbox/scale1D;
                STbox = STbox/scale1D;
                Sbox = SPbox*[1 0 0 1] + STbox; % 3.10
                %Sbox = SPbox + STbox;          % Commented in 3.10
                
                Pbox = Pbox/scale1D; % 3.10
                
                
                %% Storage in (ky,kx) grid compartment %%
                
                % Shuji RNs in each box comparment
                ShujiRNs{ky,kx} = boxShujiRNs;
                nShujiRNs(ky,kx) = length(boxShujiRNs);
                
                % pressure part of stress (3.10):
                SP(ky,kx) = SPbox;
                
                % tension part of stress (3.14):
                ST(ky,kx,:) = STbox;
                
                % stress (3.14):
                S(ky,kx,:) = Sbox;
                
                % mean pressure (3.2, 3.10):
                P(ky,kx) = Pbox;

            end
            
        end
        fprintf('Done.\n')          
        
        
        %% Storage of nCells,AreaRatios,S,ST,SP in GRID_SM & saving backup file %%
        
        fprintf('Storing quantities in GRID_SM and saving backup file...')
        
        GRID_SM.SP = SP;                        % 3.10, 3.14
        GRID_SM.P = P;                          % 3.10, 3.14
        GRID_SM.ST = ST;                        % 3.14
        GRID_SM.S = S;                          % 3.14
        GRID_SM.ShujiRNs = ShujiRNs;            % 4.0
        GRID_SM.nShujiRNs = nShujiRNs;          % 4.0
        GRID_SM.AreaRatios = gridAreaRatios;    % 4.0
 
        %%% Saving backup file
        save([backupFolder filesep filenameSM_fn '.mat'], 'CAs','CEs','CXYs');              % 3.6, 3.10
        save([backupFolder filesep filenameSM_fn '.mat'], '-struct', 'GRID_SM','-append');  % storing what's inside GRID_SM structure (4.0)
        fprintf('Done.\n');
        
    end
    
else
    %% SM backup alread exists (4.0) %%
    
    STPEbackupFound = true;
    
    fprintf(['Backup "' filenameSM_fn '.mat" was found and will be loaded...'])
    load(SM_backup);  
    fprintf('Done.\n');
    
    %%% Loading fn CPT backup
    fprintf(['Loading CPT backup "' filenameCPT '_' num2str(fn, digitsFormat) '.mat"...'])
    fileCPT = [pathCPTbackupFiles '_' num2str(fn, digitsFormat) '.mat'];
    buCPT = load(fileCPT);
    gridContourIndices = buCPT.ContourIndices;  
    gridAreaRatios = buCPT.AreaRatios;
    % Not needed:
%     gridCoreRNs = buCPT.CoreRNs; % may contain some FL cells
%     gridMaskTF = buCPT.MaskTF;
%     gridnCoreRNs = buCPT.nCoreRNs;
 
    if strcmp(gridType,'L')
        gridLcentroids = buCPT.Lcentroids;
    end
    fprintf('Done.\n')
    
end


%% Display of Maps %%

% Checks backup file existence (STPE or SM, depending on replot mode) before plot (3.2)
if makePlotsSM && STPEbackupFound && ~isempty(plotTensorsSM) && ~strcmp(plotTensorsSM{1},'none') % replaced "replotSM" by "makePlotsSM" (3.17)   
    
    if ~exist(frameFolder,'dir') % 4.0
        mkdir(frameFolder)
    end
    
    % Building GRIDall for plot (4.0)
    GRIDall = GRID_DEF;
    GRIDall.AreaRatios = gridAreaRatios; 
    GRIDall.SP = SP;  
    GRIDall.P = P;   
    GRIDall.ST = ST;   
    GRIDall.S = S;  
    
    % Loading current segmented image (mod 4.3):
    segFilename = [filename num2str(n,digitsFormat) '.' imageFormat];
    segPath = [pathFolder filesep segFilename];
    image = imread(segPath);
    
    % determining macroRNs in image (4.0)
    %-------------------------------------------------------------------------------------------
    % Loading macroANs from CTD backup ONLY in first frame:
    if fn == startFrame    
        macroANs = FindMacroANs(pathFolderCTD);
    end
    
    % Getting macroRNs in this frame
    macroRNs = FindMacroRNs(trackingFolder, nColTotal, macroANs, fn);
    %-------------------------------------------------------------------------------------------
    
    %  Determines contributions to plot from "displaySM":
    if strcmp(plotTensorsSM,'all')
        plotQsTF = ismember(allQs, allQs);
    else
        plotQsTF = ismember(allQs, plotTensorsSM);
    end
    plotQs = allQs(plotQsTF);
    plotColors = allColors(plotQsTF);
    nPlotQs = sum(plotQsTF);
    plotUnits = allUnits(plotQsTF);
    plotScaleRatios = allScaleRatios(plotQsTF);   
    plotScaleBarLengths = allScaleBarLengths(plotQsTF); 
    plotKillMeanTraces = allKillMeanTraces(plotQsTF);
    
    % Filling DISPLAY structure (3.9)
    DISPLAY.Animal = Animal;
    DISPLAY.scaleBarWidth = scaleBarWidth;
    DISPLAY.fontSizeInfo = fontSizeInfo;
    DISPLAY.plotType = plotType;
    DISPLAY.EVstyles = EVstyles;
    DISPLAY.signOpacities = signOpacities;
    DISPLAY.lineWidth = lineWidth;
    DISPLAY.gridDisplay = gridDisplay;
    DISPLAY.imageFading = imageFading;
    DISPLAY.n = fn;
    DISPLAY.time = time;                                            
    DISPLAY.minimalInfoDisplay = minimalInfoDisplay;    % 3.13
    DISPLAY.xyOffset = xyOffset;                        % 3.13
    DISPLAY.cloneTracking = cloneTracking;              % 4.0
    DISPLAY.macroRNs = macroRNs;                        % 4.0
    DISPLAY.colorMacrochaetes = colorMacrochaetes;      % 4.0
    
    if strcmp(gridType,'L')
        DISPLAY.Lcentroids = gridLcentroids;            % 4.0
        DISPLAY.ContourIndices = gridContourIndices;    % 4.0, 4.1
    end
    
    for q = 1:nPlotQs
        
        qQ = plotQs{q};
        qColor = plotColors{q};
        qUnits = plotUnits{q};
        qScaleRatio = plotScaleRatios{q};                 
        qScaleBar = plotScaleBarLengths(q); 
        qKillMeanTrace = plotKillMeanTraces(q);         % 3.9

        % tag indicating mean Tr = 0 for naming files (3.9):
        KillTrTag = '';
        if qKillMeanTrace
            KillTrTag = '_Tr=0';
        end
        % Defining "qScaleRatioTag" (3.14)
        qScaleRatioTag = num2str(qScaleRatio(1),2); % default
        if length(qScaleRatio)==2 && qScaleRatio(1) ~= qScaleRatio(2)
            qScaleRatioTag = [num2str(qScaleRatio(1),2) '-' num2str(qScaleRatio(2),2)];
        end
        
        thisFilenameShort = [qQ '_' filenameRaw_fn KillTrTag '_sr=' num2str(qScaleRatioTag) '.' imageFormatOutput];
        thisFilename = [frameFolder filesep thisFilenameShort];               % 3.14
        
        if ~exist(thisFilename,'file') % 4.1
            
            fprintf(['Plotting and saving image "' thisFilenameShort '"...']); % 3.2
            
            % Plots with "PlotField" (3.9):
            PlotField(qQ, qKillMeanTrace, qColor, qUnits, qScaleRatio, qScaleBar, GRIDall, image, DISPLAY); % use of GRIDall (4.0)
            
            % NB: rescaling by "scale1D" because the stress is expressed in micron-1: its value is therefore now independent of image resolution.
            % Now, if resolution is x10 (ie scale1D divided by 10), images are x10 bigger, the scalebar for stress
            % must therefore be x10 in new image as well, ie the value of 1 pixel of scalebar "scale" (= scale1D/q_sr here) must be divided
            % by 10, which is indeed the case here when scale1D -> scale1D/10.
            
            %%% Saving image:
            print (printFormat, printResolution, thisFilename);              % 3.6
            close
            fprintf('Done.\n');
        else
            disp(['Image "' thisFilenameShort '" already exists and was skipped.'])
        end
    end
    
elseif makePlotsSM && (isempty(plotTensorsSM) || strcmp(plotTensorsSM{1},'none') )                              % checks there is sth to plot (3.8)
    disp('WARNING: no tensor was selected for plot in "displaySM"! Please select at least one among "all", "S", "SP", "ST", "mP".')
    disp('---------------------------------------------------------------------------------');
    return % 4.1
end
disp('---------------------------------------------------------------------------------');


%% History %%

% - MUST CHECK CELLS SELECTED IN GRID COMPARTMENTS

% KNOWN BUGS:
%--------------------------------------------------------------------------------------------------------------------------------------------
% - Remove the part making plots (for coherence with AOS)??
% - bug on frame 165 of TRBL8 for unknown reason:
%             Subscript indices must either be real positive integers or logicals.
%             Error in StressMap (line 288)
%                                 ST_xx = sum( T(Ens_box).*EdXs(Ens_box).*EdXs(Ens_box)./EDs(Ens_box) )/Acells_box; % renormalization by
%                                 Acells_box instead of Abox (3.7)
% Checked that Ens_box starts with 0
% ATTEMPTED FIX in 3.11:
% Ens_box = Ens_box(Ens_box > 0);         % removes possible 0s remaining (3.11)
% NB: the only case encountered with a 0 listed in "Ens_box" came from TRBL8 #165 where there is a round cell with only 2
% vertices!! For an unclear reason, this lead one of the neighboring cell having a list of edges going beyond nJmax that
% normally sets the width of the CEs matrix, adding a whole new column of 0s in CEs (after all the NaNs normally
% completing the matrix). Then, where removing NaNs, those 0s remain in Ens_box.
%--------------------------------------------------------------------------------------------------------------------------------------------

% 25/04/2019: 4.3
% - updated path to segmented image for display within SM

% 21/05/2019: 4.2
% - defined upper bound on allowed number of edges per cell "nEdgesMax" = 20 to
% fix a bug (on animal "pnrg4_white_1") where a cell had 60 edges (which is
% already non-sense) and only 59 vertices (unknown reason)!
% - added +1 to number of columns as a quick fix for the bug adding a
% column of 0s in CEs because sometimes, one cell has a larger number of
% juctions than size(CJs,2) for an unknown reason.
       
% 28/02/2018: 4.1
% - changes to adapt to Matlab 2017 and new varialbe and function names
% - changes to get STPE backups from their new folders (stopped trying to
% load older versions of backups)
% - updated display of maps (skipping image already exists)

% 10/10/2017: 4.0 **NOW USING CPT BACKUPS FOR LAGRANGIAN GRIDS**
% - removed grid validation step that is now in AIA_parameters
% - improved similarity between "E" or "L" grid treatements
% - in BOTH "L" & "E" grid modes, cells in each box compartments are now determined before in CPT (and no longer by TA)
% - "Lcentroids" and "contourIndices" are no longer saved here but are now saved by CPT
% - stopped saving backups in a sub-backup "GRID_SM" but directly in the .m file
% - stopped creating "frameFolder" when no images saved
% - removed parameter "replotSM": either found OR calculates SM backup and plot if "makePlotsSM = true"
% - determining macroRNs in each image to color them in PlotField

% 13/01/2017: 3.18
% - use of "gridFrame" to plot corresponding image for grid validation
% - added gridTag specifying gridTime in gridSpecs folder name

% 15/09/2016: 3.17
% - adjusments to support the loading of new STPE backups from STPE v3.0+ and older ones from STPE 2.11+ (BUT NOT before)
% - plots now support of unique "uniqueScaleRatioSM" and "uniqueScaleBarLengthSM" specified in AIA_info
% - in the "Map display" section replaced "replotSM" by "makePlotsSM" to avoid having to rerun SM for plots
% - linear iteration on grid compartments using nBoxes
% - better support of "fullImage" mode
% - fixed bug printing a piece of the progressbar (instead of the grid) and NOT closing the grid figure

% 09/06/2016: 3.16
% - display of FIRST image with lagrangian (to see which patch was selected initially) grid and LAST with Eulerian (to see how empty some
% compartments will get)

% 28/04/2016: 3.15
% - removed argument "temperature" in "frame2time/time2frame" since "dt" is now corrected at "AIA_parameter" stage

% 01/06/2015: 3.14
% - additional changes in parameter names
% - initializing "AreaRatios" and "nShujiCells" with zeros rather than NaNs
% - now using 3D matrices to save ST,S
% - saving txt file indicating which version of SM was used
% - skipping execution when last SM backup is found
% - added initiation of progressbar (updated in AIA parameters)

% 29/05/2015: 3.13
% - changed many parameter names to match AIA 6.0
% - using parameter "normalizeMethod" in "Normalizer" defined in AIA parameters

% 08/04/2015: 3.12 LAGRANGIAN GRID SUPPORT
% - support of Lagrangian grid: loading TA backups and MSM backups
% - using "Normalizer" to normalize AreaRatios in EGrid mode
% - removed parts commented in 3.10

% 16/10/2014: 3.11
% - attempted to fix the TRBL8#165 bug (see right above), but realized the problem was even bigger in STPE where mu=0 is found for this frame.

% 14/10/2014: 3.10
% - turned "P" and "SP" into scalars, as it should be
% - use of "filenameSM"

% 08/10/2014: 3.9: adjustments for integration into AIA workflow
% - use of "AllQsColorsUnits" and "PlotField" to plot stress maps which simplified the code
% - support older STPE backups (STPE 2.10-), BUT saves everything in new SM format
% - "BU_found" became "BackupFound"
% - Frame filenames now start with quantity plotted

% 18/09/2014: 3.8
% - introduced parameter "killMeanTraceSM" to plot tensors by removing
% the weighted average over all compartments of their trace since their
% isotropic part is only known up to an additive constant.
% - use of newly created functions "TraceMatrix" and "WeightedMean" to do so.

% 15/09/2014: 3.7
% - now saves "Ncells" and "AreaRatios" in backups (required for Anais
% correlation plots and to weight border boxes)
% - stopped renormalizing stress by Abox, but by Acells_box, sum of areas
% of cells in the box
% - now only consider non-Ext cells in boxes

% 12/09/2014: 3.6
% - now creates classic tree view with folder SM_EGrid_animal, subfolder with
% Grid specs, and subfolders Backups and Frames_split+,_dev+ according to "plot_typeSM"

% 23/07/2014: 3.5
% - use of filesep for mac compatibility

% 09/05/2014: 3.4
% - added "grid_overlap" in GridMaker
% - added plot of midline with "Midline_Plotter([], yMid)"
% - use of "Tensor_Plotter" 1.7 with "sign_opacitiesSM"
% - use of "Info_Plotter"
% - added many comments in the "renormalization by scale1D" section
% - added "StressMap" at beginning of subfolder name
% - added number of compartments nx,ny and value of overlap at the end of subfolder name

% 12/11/2013: 3.3
% - directly closes grid image after validation if in replot mode

% 14/10/2013: 3.2
% - normalization of stress by box compartment area Abox = w*h instead of sum(cell areas)
% - changed EdYs sign globally before stress computation to be consistent with "ij" axis convention used in image AND in tensor analysis.
% - added mean pressure P in GRID_SM
% - implemented replot mode
% - display of quantity plotted, animal and frame #

% 26/09/2013: 3.1: STARTING MAJOR OVERHAUL OF THE CODE
% - removed all parts involving time averaging
% - thoroughly rewrote parts caculating stress, removing all loops except the one over compartment grids

%----------------------------------------------------------------------------------------------------------------
% 19/09/2013: renaming to "StressMap" from "FastStressMap"

% 15/05/2013: 3.0 and renaming to "FastStressMap" from "FastGlobalStress_Run_Force_Estimate_PT_time_averaging" (!!)

% 22/03/2013:
% - Calculates and saves "DensiteMoy"
% - Calculates and saves "EllipsesPnp"

% 18/03/2013:
% - Saves the calculation results in "image name".mat
% - Replot mode, runs plot_PT_ellipses

% 25/02/2013: changed name to "FastGlobalStress_Run_Force_Estimate_PT_time_averaging"
% - averaging on time. Run by "run_Force_Estimate_PT_time_averaging".

% 12/11/2012: 2.0
% - initiated changes for compatibility with "FastGetData" outputs

% 26/09/2012: 1.1
% - changed inputs: GlobalStress(T,P,cell,edge,x,y) to GlobalStress(ep,cell,edge,x,y,scale) so that one just needs to
% load out.m file to run
% - added plot
