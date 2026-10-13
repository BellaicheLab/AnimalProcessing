% ProjectionOverAnimals

Version = 4.1;
% Stephane Rigaud
% Boris Guirao

%% Building common grid (4.1) %%

% NB: loading backups of process to project (AOA or DBA) and of unitary
% tensor (AOA) to build commond grid

% Updating RAW macro coordinates in new common image with average:
macro1cRaw = LoadedBackupsPOA{1}.REG.MacrocaetesRaw;
macro2cRaw = LoadedBackupsPOA{2}.REG.MacrocaetesRaw;
% NB: MacrocaetesRaw are macro positions in MICRON using ANIMAL
% ORIGIN (ususally macro barycenter)
meanMacrocaetesRaw = 0.5*(macro1cRaw + macro2cRaw); % taking average

% Updating RAW midline coordinates in new common image:
yMid1cRaw = LoadedBackupsPOA{1}.REG.yMidRaw;
yMid2cRaw = LoadedBackupsPOA{2}.REG.yMidRaw;
meanDeltaYmidRaw = 0.5*(yMid1cRaw + yMid2cRaw); % taking average

poaAnimalList = {poaAnimal; ['u' uAnimal]};
[GRID, LOCxy] =  BuildCommonGrid(poaAnimalList, poaAnimalList, LoadedBackupsPOA, meanMacrocaetesRaw, meanDeltaYmidRaw, gridOverlap, halfNotum, cloneTracking, DISPLAY);

LtotX = GRID.Size(2);
LtotY = GRID.Size(1);


%% Placing backup 1 quantities into common grid into POAbackup structure (4.1) %%

fields2skip = {'Coordinates', 'ULCs', 'Color','FrameArray','TimeArray','LineWidth','Size','fullImage','originBoxIJ','Overlap','REG','FULL','filteringTag'};

fieldList = fieldnames(LoadedBackupsPOA{1}); % Get the list of field to process from one of the backup

for f = 1:length(fieldList)
    
    fthFieldIn1 = LoadedBackupsPOA{1}.(fieldList{f});
    
    if ~ismember(fieldList{f},fields2skip) && ~isstruct(fthFieldIn1) && ~strcmp(fieldList{f},'AreaRatios') && isempty(strfind(fieldList{f},'_Smap'))
        
        fthFieldOut1 = NaN(LtotY,LtotX, size(fthFieldIn1,3), size(fthFieldIn1,4));
        fthFieldOut1(LOCxy.startLocY(1):LOCxy.endLocY(1), LOCxy.startLocX(1):LOCxy.endLocX(1),:,:) = fthFieldIn1(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
        
        % STORAGE in Q2PROJECT:
        Q2PROJECT.(fieldList{f}) = fthFieldOut1;      

    elseif ~ismember(fieldList{f},fields2skip) && ~isstruct(fthFieldIn1)

        % For AreaRatios, initializes new matrices with ZEROS:
        fthFieldOut1 = zeros(LtotY,LtotX, size(fthFieldIn1,3), size(fthFieldIn1,4)); 
        fthFieldOut1(LOCxy.startLocY(1):LOCxy.endLocY(1), LOCxy.startLocX(1):LOCxy.endLocX(1),:,:) = fthFieldIn1(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
        
        % Loading also backup 2
        fthFieldIn2 = LoadedBackupsPOA{2}.AreaRatios;
        fthFieldOut2 = zeros(LtotY, LtotX, size(fthFieldIn2,3), size(fthFieldIn2,4));
        fthFieldOut2(LOCxy.startLocY(2):LOCxy.endLocY(2), LOCxy.startLocX(2):LOCxy.endLocX(2),:,:) = fthFieldIn2(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
        
        if strcmp(fieldList{f},'AreaRatios') % min(A.ar, B.ar)
            disp(['min : ' fieldList{f}]);
            ARfield = min(fthFieldOut1, fthFieldOut2);
            POAbackup.(fieldList{f}) = ARfield;
            
        elseif ~isempty(strfind(fieldList{f},'_Smap')) % if Significance map, logical AND(A.map, B.map)
            disp(['logical OR : ' fieldList{f}]);
            fthFieldSmap = or(fthFieldOut1, fthFieldOut2);
            POAbackup.(fieldList{f}) = fthFieldSmap;
        end 
    else
        POAbackup.(fieldList{f}) = fthFieldIn1; % copy FIRST value of fields2skip as it is
    end
end

%% Overwritting with common grid values (4.1) %%

%common size:
POAbackup.Size = GRID.Size;
% originBoxIJ
POAbackup.originBoxIJ = GRID.originBoxIJ;
% ULCs, Coordinates
POAbackup.Coordinates = GRID.Coordinates;
POAbackup.ULCs = GRID.ULCs;
% REG & FULL structures:
POAbackup.REG = GRID.REG;
POAbackup.FULL = GRID.FULL;


%% Initialization of the unitary tensor %%

% retrieving quantity to project onto AND placing it in common grid:
QprojRaw = LoadedBackupsPOA{2}.(uQname);
% Qproj = eval(['bBackup.' uQname ';']);
Qproj = NaN(LtotY, LtotX, size(QprojRaw,3), size(QprojRaw,4));
Qproj(LOCxy.startLocY(2):LOCxy.endLocY(2), LOCxy.startLocX(2):LOCxy.endLocX(2),:,:) = QprojRaw(:,:,:,:,1);

[by, bx, bz, bt, ba] = size(Qproj);

thetaB = GetAngleMap(Qproj); % return the angle map in rad
sigma0 = repmat(reshape([1 0 ; 0  1], [1 1 4 1 1]), [by bx 1 bt ba]);
sigma1 = repmat(reshape([0 1 ; 1  0], [1 1 4 1 1]), [by bx 1 bt ba]);
sigma3 = repmat(reshape([1 0 ; 0 -1], [1 1 4 1 1]), [by bx 1 bt ba]);

sigmaIso  = sigma0;
sigmaDev  = repmat( cos(thetaB.*2), [1 1 4 1 1]) .* sigma3 + repmat(sin(thetaB.*2), [1 1 4 1 1]) .* sigma1;
sigmaDevO = repmat(-sin(thetaB.*2), [1 1 4 1 1]) .* sigma3 + repmat(cos(thetaB.*2), [1 1 4 1 1]) .* sigma1;

unitaryTensorList = {sigmaIso ; sigmaDev ; sigmaDevO};
tagUnitaryTensor  = {   'i'   ;    'd'   ;   'do'   };


%% Projection of quantities over uProjTensor %%

for i = 1:nQname
    for t = 1:length(tagUnitaryTensor)
        
        fprintf(['\tComputing ' Qname{i} '.' tagUnitaryTensor{t} '(' uQname ') ...']);
        
        if isfield(Q2PROJECT, Qname{i})
            
            currentQ = Q2PROJECT.(Qname{i}); % 4.1
            uProjTensor = unitaryTensorList{t};
            
            if size(currentQ, 3) == 4
                
                %%% managing quantities size
                if size(currentQ, 4) > size(uProjTensor, 4)
                    uProjTensor = repmat(uProjTensor, [1 1 1 size(currentQ, 4) 1]);
                elseif size(currentQ, 4) < size(uProjTensor, 4)
                    currentQ = repmat(currentQ, [1 1 1 size(uProjTensor, 4) 1]);
                end
                
                %%% compute projection
                AdotB = ScalarProductFunction(currentQ, uProjTensor);
                
                %%% manage significance map
                POAbackup.([Qname{i} 'dot' uQname '_' tagUnitaryTensor{t}]) = AdotB; % mod 4.1
                if ~singleAnimal % 3.7
                    if strcmp(tagUnitaryTensor{t},'d') || strcmp(tagUnitaryTensor{t},'do')                       
                        temp_map = POAbackup.([uQname '_Smap'])(:,:,2,:,:); % mod 4.1
                    elseif strcmp(tagUnitaryTensor{t},'i')                        
                        temp_map = POAbackup.([uQname '_Smap'])(:,:,1,:,:); % mod 4.1
                    end
                    B_Smap = cat(3, temp_map, temp_map);
                    POAbackup.([Qname{i} 'dot' uQname '_' tagUnitaryTensor{t} '_Smap']) = B_Smap; % mod 4.1
                end
                fprintf(' Done\n');
            else
                fprintf(' Skipped\n');
            end
        else
            fprintf(' Skipped\n');
        end
    end
end

%%% save, or update if already existing, the new backup
if ~exist(OutputPathName,'dir')
    mkdir(OutputPathName);
end

thisFilename = [OutputPathName filesep 'POA_u' uQname '_' uAnimal '_' tagProjectionTime '.mat'];% mod 4.1
% thisFilename = [OutputPathName filesep 'POA_' uAnimal '_' tagProjectionTime '.mat'];

if ~exist(thisFilename,'file')
    disp('Saving new structure ...')
    save(thisFilename,'-struct', 'POAbackup');
else
    disp('Appending structure ...')
    save(thisFilename,'-struct', 'POAbackup', '-append');
end



%% Plot %%

if ~isempty(Qname) && PLOT.plot && ~skipPOAplots
    fprintf('Plotting projected quantities ...\n')
    
    %%% Load backup
    BACKUP = load([OutputPathName filesep 'POA_u' uQname '_' uAnimal '_' tagProjectionTime]); % added fullTag (2.6) % mod 4.1
%     BACKUP = load([OutputPathName filesep 'POA_' uAnimal '_' tagProjectionTime]); % added fullTag (2.6)
    
    Lt = size(BACKUP.FrameArray,1);
    
    %%% Loading plot parameters (mod 2.9)
    % Extracting FULL or REG data for plot (2.7)
    TYPE = BACKUP.REG;
    if DISPLAY.makeItFull
        TYPE = BACKUP.FULL;
    end
    BACKUP.xywh = TYPE.xywh;
    BACKUP.Centroids = TYPE.Centroids;
    BACKUP.SizeImageX = TYPE.SizeImageX;
    BACKUP.SizeImageY = TYPE.SizeImageY;
    DISPLAY.yMid = TYPE.yMid;
    DISPLAY.macrocaetes = TYPE.Macrocaetes;
    
    Qimage = ones(BACKUP.SizeImageY, BACKUP.SizeImageX);
    
    
    %%% plot process
    for t = 1:Lt
        
        % Correcting time display: ONLY relevant when TA quantities were added LAST in AOT backup(2.5)
        fixDtH = 0;
        timeShift = 0;
        % fixDtH = delta_t/60; % uncomment if 12h05 is displayed instead of 12h00 for instance
        
        % Set the time and n variable (mod 2.2)
        tmpTimeStart = TimeStr2Dec(BACKUP.TimeArray{t,1}) + timeShift - fixDtH;      % turns time string into decimal and adds timeShift, added fixDtH (2.5)
        tmpTimeEnd = TimeStr2Dec(BACKUP.TimeArray{t,2}) + timeShift;
        tmpTimeStart = TimeDec2Str(tmpTimeStart);                                            % switches back to string
        tmpTimeEnd = TimeDec2Str(tmpTimeEnd);
        DISPLAY.time = [tmpTimeStart ' - ' tmpTimeEnd];
        DISPLAY.n = round( ( BACKUP.FrameArray(t,1) + BACKUP.FrameArray(t,2) ) / 2 );
        
%         if Lt > 1 % (1.2)
            DISPLAY.step = t;
%         end
        
        %%% For each Display to be plot
        for j = 1:nQname
            
            for p = 1:length(tagProjPlot)
                
                PlotQname = [Qname{j} 'dot' uQname '_' tagProjPlot{p}];
                
                if isfield(BACKUP,PlotQname)
                    
                    POAname = ['POA_' Qname{j} '.' uQname '_' tagProjPlot{p} '_'  uAnimal  '_' tagProjectionTime];
                    DISPLAY.Animal = POAname;
                    
                    % Get the Qcolor, Qunits, Qsr, etc. corresponding to the Display
                    [Pname,idx] = GetPname(Qname{j}); % now gets Pname (2.3)
                    Qunits    = eval(['allUnits' Pname '{idx}']);
                    Qcolor    = eval(['allColors' Pname '{idx}']);
                    Qscalebar = eval(['scaleBarLength' Pname ]);
                    QKillTr   = eval(['killMeanTrace' Pname ]);
                    Qsr       = eval(['scaleRatio' Pname ]);
                    Qsr = GetPlotScaleParameter(Qsr, idx).* scaleRatioFactorPOA; %  multiplication by .* scaleRatioFactorPOA
                    Qscalebar = GetPlotScaleParameter(Qscalebar, idx);
                    QKillTr = GetPlotScaleParameter(QKillTr, idx);

                    % tag indicating mean Tr = 0 for naming files
                    KillTrTag = '';
                    if QKillTr
                        KillTrTag = '_Tr=0';
                    end

                    % COMMENTED 4.1
%                     La = size(eval(['BACKUP.' PlotQname]),5);
%                     if La > 1 % (1.2) KEEP OR LEAVE?
%                         DISPLAY.animalIdx = t;
%                     end
                    
                    %%% Significance
                    if PLOT.significance
                        DISPLAY.SignificanceMap = BACKUP.([PlotQname '_Smap'])(:,:,:,t); % mod 4.1
                    end
                    
                    % COMMENTED 4.1
%                     %%% Plot value as a surface instead of radius
%                     S = sign( eval(['BACKUP.' PlotQname ';']) );
%                     V = sqrt( abs( eval(['BACKUP.' PlotQname ';']) ) );
%                     eval(['BACKUP.' PlotQname ' = S .* V;']);
                    
                    PlotField(PlotQname, QKillTr, Qcolor, Qunits, Qsr, Qscalebar, BACKUP, Qimage, DISPLAY);
                    
                    % Plot print (removed "Frames_" prefix and added fullTag in filenames)(2.6)
                    plotFolder = [OutputPathName filesep 'POA_u' uQname '_' uAnimal '_' tagProjectionTime '_' plotType fullTag BACKUP.filteringTag]; % mod 4.1
%                     plotFolder = [OutputPathName filesep 'POA_' plotType fullTag BACKUP.filteringTag];
                    thisFilename = ['POA_' PlotQname '_' tmpTimeStart 'to' tmpTimeEnd KillTrTag fullTag '_sr=' num2str(Qsr(1)) imageExtension]; % 1.7, added fullTag (2.5), use timeStart/End (2.7)

                    if ~exist(plotFolder, 'dir')
                        mkdir(plotFolder);
                    end
                    if strcmp(imageExtension,'.svg')
                        plot2svg([plotFolder filesep thisFilename], figure(1), 'png');
                    else
                        print(printFormat, printResolution, [plotFolder filesep thisFilename]);
                    end
                    close
                end
            end
        end 
    end
end


%% History %%

% 04/10/2024: 4.1 Major update (Boris)
% - now possible to project outputs from DBA (only AOA before)
% - use of "BuildCommonGrid" to build a common grid between quantities to project
% - stopped using "eval" when unnecessary
% - removed the S.*V part that was leading to completely wrong plots (when serveral timepoints were involved)
% - added "filteringTag" to image folder name
% - added "uAnimal '_' tagProjectionTime" in POA folder name to make it
% match with corresponding backup .mat file. Otherwise images corresponding
% to different projection could overwrite previously generated ones.
% - now using "scaleRatioFactorPOA" to tune display scale
% - added "uQname" (namely EG, I,...) in the plotFolder and backup names in
% order to better separate the different types of projections.

% 13/06/2018: 4.0 (Stephane)
% - update for new SAP and MAP script
% - add a fifth dimension to compute projection on average animal (A1) and per animal (A2 to An)
% - remove single animal processing (single animal only done in SAP now)

% 06/02/2017: 3.7 (Boris)
% - adjustments to process single animals
% - now directly compares first 2 characters of A to the list of scalar quantities to skip A projection
% - STOPPED saving non-tensor quantities for LTA plots: now LTA loads AOA or DOA AND POA backups simultaneously
% - changed filenames of POA images being saved

% 02/02/2017: 3.6 (Boris)
% - look for "3.6" to see changes

% 27/01/2017: 3.5 (Boris)
% - now still runs when quantities listed in Qname are not available (or are non-tensors cf 3.4)
% - now saving non-tensor quantities (such as dnA) and their Smap UNTOUCHED in POA backups for convenience in LTA plot

% 26/01/2017: 3.4 (Boris)
% - now runs even when non-tensor quantites are listed in Qname in AIA_MultiOperation (they're just skipped)
% - now takes into account "timeShift" when naming files being saved

% 23/01/2017: 3.3 (Boris)
% - adjustments for compatibility with AOA v2.7 and the use of unique backups for regular or full case (makeItFull = true)
% - accordingly loads structures REG and FULL stored in AOA backups

% 20/01/2017: 3.2 (Boris)
% - ONLY using AOT backups now!!
% - moved most filling of DISPLAY to AOA_MultiOperation

% 04/01/2017: 3.1 (Boris)
% - use of "OnamePOA" instead of "Oname"
% - now uses "timeShift" to correct displayed time range of averaging
% - Qunits, Qsr, Qsb became QunitsPOA, QsrPOA, QsbPOA

% 07/08/2015: v3
% - projection on unitary tensor sigma0 sigmaDev sigmaOrtho
% - use of the new TensorData

% 21/07/2015: v2.5
% - remove normalisation
% - add global or instant contraction

% 19/03/2015: v2.0
% - Major modification of the code