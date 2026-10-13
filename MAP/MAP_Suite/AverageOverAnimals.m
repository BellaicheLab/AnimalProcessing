
Version = 4.1;
% Stephane Rigaud
% Anais Bailles
% Boris Guirao


%% Building of global common grid %%

% Merge all the GRID information loaded from the different annimals into
% the union of all the grids.

fprintf('\tBuilds global common grid ...')

% Load grids to define crop and translation
% clear GRID;
[GRID, LOCxy] =  BuildCommonGrid(avgAnimals, allAnimals, AnimalGridList, meanMacrocaetesRaw, meanDeltaYmidRaw, gridOverlap, halfNotum, cloneTracking, DISPLAY);

%% Initialization %%

% set up and test all variable for the averaging process
% NB: specific case if averaging AOS process for managing multichannel

fprintf('\tUniformizing data format ...')

% Get all unique field names across all animals
allFields = {};
for m = 1:nAvgAnimals
    allFields = union(allFields, fieldnames(AnimalAOTList{m}));
end

% Remove fields in the reject list
allFields = setdiff(allFields, rejectList);

% Initialize a matrix to store presence/absence of fields
fieldPresence = zeros(nAvgAnimals, length(allFields));

% Check presence of fields for each animal
for m = 1:nAvgAnimals
    animalFields = fieldnames(AnimalAOTList{m});
    fieldPresence(m, :) = ismember(allFields, animalFields);
end

% Find common fields across all animals
commonFields = allFields(all(fieldPresence, 1));

% Print summary header
fprintf('\n===== Summary of Quantity Presence Across Animals =====\n')
fprintf('Total unique quantities: %d\n', length(allFields))
fprintf('Common quantities across all animals: %d\n\n', length(commonFields))

% Print detailed summary for each animal
fprintf('Detailed summary for each animal:\n')
for m = 1:nAvgAnimals
    % Convert logical array to numeric indices
    presentIndices = find(fieldPresence(m, :));
    missingIndices = find(~fieldPresence(m, :));
    
    presentFields = allFields(presentIndices);
    missingFields = allFields(missingIndices);
    
    fprintf('\nAnimal: %s\n', avgAnimals{m})
    fprintf('  Present quantities: %d\n', length(presentFields))
    fprintf('  Missing quantities: %d\n', length(missingFields))
    
    if ~isempty(missingFields)
        fprintf('  List of missing quantities:\n')
        for i = 1:length(missingFields)
            fprintf('    - %s\n', missingFields{i})
        end
    end
end

temporary = AnimalAOTList{1}; % 2.3
list = fieldnames(temporary);
for m = 2:nAvgAnimals
    temporary = AnimalAOTList{m}; % 2.3
    list = intersect(list, fieldnames(temporary));
end
list = setdiff(list, rejectList);
nList = length(list); % 2.3

% dimension test
nbFrame = size(AnimalAOTList{1}.FrameArray, 1);% 2.3
testDim = 4;
if nbFrame == 1, testDim = 3; end

%%% Turning all 3D matrix (X,Y,Time) into 4D matrix (X,Y,1,Time)
for n = 1:nList
    for m = 1:nAvgAnimals
        eval( ['temporary = AnimalAOTList{m}.' list{n} ';' ] ); % 2.3
        
        if size(temporary,testDim) == 1
            new = reshape( temporary, size(temporary,1), size(temporary,2) ,1, size(temporary,3) );
            eval( ['AnimalAOTList{m}.' list{n} ' = new ;' ] ); % 2.3
        end
    end
end
fprintf(' Done\n')


%% Calculating averages over animals %%
 
% AOA backup initialisation
% We try to mimic the structure of single animal backup
BACKUP = GRID;
stdMAP = GRID;
fullBackup = GRID;
 
% finds the number of time points by loading quantity listed first:
LtotX = GRID.Size(2);
LtotY = GRID.Size(1);
[Lt] = size( eval(['AnimalAOTList{1}.' list{1}]) , 4 ); % 2.3
 
%%% Stackin up quantities
% for each quantities, including AreaRatios and Rcons, we create a 5D-matrix (X,Y,Z,Time,Animal)
% wherw X and Y are defined by the new GRID, Z the dimension of the quantity values (1 scalar, 2 vector, or 4 tensor), Time the number of time point and Animal the number of animal
fprintf('\tStacking up data ...')
cQTFall = false(LtotY, LtotX, nList, Lt, size(avgAnimals, 1)); % initialization of filtering matrix (4.0)
filteringTag = '';                                              % empty default tag (4.0)
 
for m = 1:nList
    
    [~,~,Lz,~] = size( eval(['AnimalAOTList{1}.' list{m}]) ); % get the dimensions of the quantity (2.3)
    eval(['total' list{m} '= NaN(LtotY, LtotX, Lz, Lt, nAvgAnimals);']); % create a 5D matrix
    
    % Specific case for AreaRatios (2.3)
    if strcmp(list{m},'AreaRatios')
        totalAreaRatios = zeros(LtotY, LtotX, Lz, Lt, size(avgAnimals, 1)); % NB: RConds already included in AreaRatios for TA
    end
    
    for a = 1:nAvgAnimals
        
        if ~cloneTracking
            eval(['total' list{m} '(LOCxy.startLocY(a):LOCxy.endLocY(a), LOCxy.startLocX(a):LOCxy.endLocX(a),:,:,a) = AnimalAOTList{a}.' list{m} ';']); % 2.3
%             eval(['total' list{m} '(startLocYwt(a):endLocYwt(a), startLocXwt(a):endLocXwt(a),:,:,a) = AnimalAOTList{a}.' list{m} ';']); % 2.3
        %else
        %    eval(['total' list{m} '(startLocYwt(a)+1:endLocYwt(a)+1, startLocXwt(a)+1:endLocXwt(a)+1,:,:,a) = AnimalAOTList{a}.' list{m} ';']); % 3.2
        %    eval(['total' list{m} '(2, 2,:,:,a) = AnimalAOTList{a}.' list{m} ';']); % ONLY fills compartment in the center, other compartments created just for display (3.1)
        end
        
        % Filtering data beyond "AOAvalidityThreshold" (4.0)
        if ismember(list{m}, QnameFilter) % Check if the quantity belongs to QnameFilter
            
            % Gets current quantity
            currentQuantity  = eval(['total' list{m}]);
            
            % Get the absolute value of the current quantity
            cQabs = abs(currentQuantity(:,:,:,:,a));
            
            % Identify the elements where the maximum value along the 3rd dimension exceeds the threshold (seuil)
            cQTF = cQabs > AOAvalidityThreshold;
            exceededSeuilMask = any(cQTF,3); % any tensor component beyond threshold will discard the whole tensor
            
            % Staacks this quantity mask into cQTFall with all the other quantity masks:
            cQTFall(:,:,m,:,a) = exceededSeuilMask;
            
            % creates tag when filtering was performed:
            filteringTag = ['_filt' num2str(AOAvalidityThreshold)];
        end
    end
end
fprintf(' Done\n')
 
 
%%% Calculating weights
fprintf('\tCalculating weights ...')
% Data filtering (4.0)
% any quantity having one component beyond threshold will discard the box measurements for ALL quantities:
cQTFall = any(cQTFall, 3);
% Setting those AreaRatios to 0 so those animal boxes do not contribute to the average:
totalAreaRatios(cQTFall) = 0;
 
totalWeight = totalAreaRatios .^ 2;
% NB: RConds have been integrated to "total_AreaRatios" at "AIA_MultiOperation" stage
fprintf(' Done\n')


%%% Averaging values using weights when needed
fprintf('\tAveraging quantities ...\n')
for m = 1:nList
    fprintf(['\t\tProcessing ' list{m} ' ...'])
    
    if strcmp(list{m},'AreaRatios')
        meanTotalAreaRatios = mean(totalAreaRatios, 5);
        BACKUP.AreaRatios = meanTotalAreaRatios;
        stdMAP.AreaRatios = meanTotalAreaRatios;
        
        mergeBackup = cat(5, meanTotalAreaRatios, totalAreaRatios);
        eval(['fullBackup.' list{m} ' = mergeBackup;'])
    else
        
        currentTotalQuantity = eval(['total' list{m}]);
        % repeat weight matrix to fit the quantity structure (scalar, vector, or tensor)
        [Tz] = size(currentTotalQuantity, 3);
        R_TotalWeight = repmat(totalWeight, [1 1 Tz 1 1]);
        % calculate the weighted average of the quantity
        meanCurrentTotalQuantity = currentTotalQuantity .* R_TotalWeight;
        meanCurrentTotalQuantity = nansum( meanCurrentTotalQuantity, 5) ./ sum( R_TotalWeight, 5 );
        % calculate the significance map (binary) and std of the quantity
        [SignificanceMap, meanMap, stdMap] = MakeSignificanceMap( currentTotalQuantity, meanCurrentTotalQuantity, R_TotalWeight );
        if ~isempty(PLOT.SignOpacityMap)
            % calculate significance opacity value based on weights
            SignOpacityMap_iso = max(SignificanceMap(:,:,1,:) , abs(SignificanceMap(:,:,1,:) - 1) .* PLOT.SignOpacityMap(1) );
            SignOpacityMap_dev = max(SignificanceMap(:,:,2,:) , abs(SignificanceMap(:,:,2,:) - 1) .* PLOT.SignOpacityMap(2) );
            SignificanceMap = cat(3, SignificanceMap, SignOpacityMap_iso, SignOpacityMap_dev);
        end
        % store mean in new AOA backup
        eval(['BACKUP.' list{m} ' = meanCurrentTotalQuantity;']);
        eval(['BACKUP.' list{m} '_Smap = SignificanceMap;']);
        eval(['stdMAP.' list{m} '_std = meanMap;']);  % (v2) in progress add-on for biological variability estimation
        eval(['stdMAP.' list{m} ' = meanCurrentTotalQuantity;']);   % (v2) in progress add-on for biological variability estimation
        
        mergeBackup = cat(5, meanCurrentTotalQuantity, currentTotalQuantity);
        eval(['fullBackup.' list{m} ' = mergeBackup;'])
        eval(['fullBackup.' list{m} '_Smap = SignificanceMap;']);
    end
    fprintf(' Done\n')
end % end for each quantities


%%% Add the rest to the backup (mod 2.3)
BACKUP.TimeArray  = AnimalAOTList{1}.TimeArray;
BACKUP.FrameArray = AnimalAOTList{1}.FrameArray;
stdMAP.TimeArray  = AnimalAOTList{1}.TimeArray;  % (v2) in progress add-on for biological variability estimation
stdMAP.FrameArray = AnimalAOTList{1}.FrameArray; % (v2) in progress add-on for biological variability estimation

fullBackup.TimeArray = AnimalAOTList{1}.TimeArray;
fullBackup.FrameArray = AnimalAOTList{1}.FrameArray;

fullBackup.filteringTag = filteringTag; %4.1

%%% Save AOA mean backup
if ~exist(OutputPathName,'dir')
    mkdir(OutputPathName);
end

BACKUP = fullBackup;

%%% Save main backup
thisFilename = [OutputPathName filesep 'AOA_backup' '.mat']; % added fullTag (2.6)
if ~exist(thisFilename,'file')
    fprintf('\tSaving new backup ...')
    save(thisFilename, '-struct', 'BACKUP');
else
    fprintf('\tAppending backup ...')
    Previous = load(thisFilename);
    BACKUP = catstruct(Previous, BACKUP);
    save(thisFilename, '-struct', 'BACKUP', '-append');
end
fprintf(' Done\n')

%% Plot %%

if ~isempty(Qname) && PLOT.plot && ~skipAOAplots
    fprintf('Plotting averaged quantities ...\n')
    
    BACKUP = load([OutputPathName filesep 'AOA_backup']); % added fullTag (2.6)
    % BACKUP = load([OutputPathName filesep 'AOA_backup_MOD']);
    % NB: "MOD" backups were made to symmetrize tensors ONLY in the row right next to the midline,
    % to mimick the calculation done in BIGwt2 where a big box including
    % both sides of the midline can be drawn.
    
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
%     DISPLAY.gridOnlyBulk = gridOnlyBulk; %3.8
    
    Qimage = ones(BACKUP.SizeImageY, BACKUP.SizeImageX);
    
    %%% For each time point
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
        
        %if Lt > 1 % (1.2)
        DISPLAY.step = t; %4.0
        %end
        
        
        %%% For each Display to be plot
        for j = 1:nQname
            
            if isfield(BACKUP,Qname{j}) % 2.3
                
                % Get the Qcolor, Qunits, Qsr, etc. corresponding to the Display
                [Pname,idx] = GetPname(Qname{j}); % now gets Pname (2.3)
                Qunits    = eval(['allUnits' Pname '{idx}']);
                Qcolor    = eval(['allColors' Pname '{idx}']);
                Qscalebar = eval(['scaleBarLength' Pname ]);
                QKillTr   = eval(['killMeanTrace' Pname ]);
                Qsr       = eval(['scaleRatio' Pname ]);
                Qsr = GetPlotScaleParameter(Qsr, idx);
                Qscalebar = GetPlotScaleParameter(Qscalebar, idx);
                QKillTr = GetPlotScaleParameter(QKillTr, idx);
                
                % tag indicating mean Tr = 0 for naming files
                KillTrTag = '';
                if QKillTr
                    KillTrTag = '_Tr=0';
                end
                
                % Load significance map
                if PLOT.significance && ~singleAnimal
                    DISPLAY.SignificanceMap = BACKUP.([Qname{j} '_Smap'])(:,:,:,t); % 4.1
                end
                
                % Plot image
                PlotField(Qname{j}, QKillTr, Qcolor , Qunits , Qsr, Qscalebar, BACKUP, Qimage, DISPLAY);
                
                % Plot print (removed "Frames_" prefix and added fullTag in filenames)(2.6)
                thisFilename = ['AOA_' Qname{j} '_' tmpTimeStart 'to' tmpTimeEnd KillTrTag fullTag '_sr=' num2str(Qsr(1)) imageExtension]; % 1.7, added fullTag (2.5), use timeStart/End (2.7)
                plotFolder = [OutputPathName filesep 'AOA_' plotType filteringTag fullTag]; % 4.0
                if ~exist(plotFolder, 'dir')
                    mkdir(plotFolder);
                end
                if strcmp(imageExtension,'.svg')
                    plot2svg([plotFolder filesep thisFilename],figure(1),'png');
                else
                    print(printFormat, printResolution, [plotFolder filesep thisFilename]);
                end
                close
                
            else % 2.3
                disp(['AOA WARNING: quantity "' Qname{j} '" was not found in "BACKUP"!']);
                disp('Please make sure that it is the name assigned to this quantity AND that it was averaged over time and stored in each animal AOT backups.')
            end
        end % end for each quantities
    end % end for each time point
elseif ~isempty(Qname) && PLOT.plot && skipAOAplots
    disp('WARNING: skipping AOA plots ("skipAOAplots" set to 1)!')
end % end if plot


%% History %%

% 30/09/2024: 4.1 (Boris)
% - adjustments to use function "BuildCommonGrid"
% - in "BuildCommonGrid", fixed yMid used that was strangely always used
% with a minus sign, which was not consistent with the treatment of macrocaetes coordinates.

% 17/09/2024: 4.0 (Boris & Mehdi)
% - now always defines "step" in DISPLAY (not just when Lt > 1 (one timepoint)
% - fixed spelling mistake in REG: REG.MacrocatesRaw -> REG.MacrocaetesRaw
% - Filtering of data beyond threshold with new MAP parameters
% "AOAvalidityThreshold" and "QnameFilter" (list of quantities whose components
% will be compared to threshold)
% NB: if a single quantity component is beyond threshold in a grid box, all
% quantities will be discarded in that box

% 09/11/23 3.9 (Adrien & Boris)
% - Fixed issue with macrochaete positioning (newOxMCU and newOyMCU should
% not be scaled by the overlap)

% 13/01/2023: 3.8 (Boris)
% - fixed issue where some macrochaetes were not displayed because the were
% not included in the grid. Now the MAP images are determined by checking
% that both all grid compartments AND all macrochaetes can fit in image.
% - now only adds 1/2 box as leeway (instead of 1 before)

% 01/09/2021: 3.7 (Boris)
% - fixed issue in MacrocaetesMCU coordinates when "gridOverlap" > 0

% 29/09/2020: 3.6 (Boris)
% - Saves macro & midline positions in MICRON with macrocaetes BARYCENTER AS ORIGIN!
% Saved in REG substructure (REG.MacrocatesRaw, REG.yMidRaw).

% 09/07/2020: 3.5 (Boris)
% - added the calculation (and storage in REG structure) of MacrocaetesMCU,
% xywhMCU and yMidMCU, coordinates of the corresponding quantities in MCU
% (matrix compartement units).

% 02/06/2020: 3.4 (Boris)
% - call to " SignificanceMap" rather than "SignificantMap"

% 20/04/2020: 3.3 (Boris)
% - call to " SignificanceMap" rather than "SignificavityMap"

% 06/07/2018: 3.2 (Boris)
% - BETA: alternative averaging of clone that assumes that clone tracking
% has been done with "matchingWTclone" = 2, only case that gathers all
% clone parts together in the average.

% 02/07/2018: 3.1 (Boris)
% - supports clone averaging (without WT counterpart) and display.

% 13/06/2018: 3.0 (Stephane)
% - update for new SAP and MAP script
% - add a fifth dimension to compute average animal (A1) and to keep Qs for each animal (A2 to An)
% - remove single animal processing (single animal only done in SAP now)

% 08/02/2017: 2.9 (Boris)
% - Adjustments for single movie processing
% - added "skipAOAplots"

% 03/02/2017: 2.8 (Boris)
% - do NOT try to build full grid when processing animals tha are halfNotum = 'b'

% 23-26/01/2017: 2.7 (Boris)
% - now will save both regular and full versions of xywh, yMid, sizeImageX/Y, macrochaetes in stuctures REG and FULL within GRID that get
% extracted only right before plot => back to ONLY saving one backup for AOA
% - fixed the issue of mismatch between grid size and actual matrix size by defining gridSize right from LtotX/Y
% - fixed all formulas wrongly setting origins and sizes due to wrong handling of the overlap between boxes.
% - impose a minimum distance of either one full box everywhere around data or 5%/2 of image size (whichever is smallest)
% - now takes into account "timeShift" when naming files being saved

% 20/01/2017: 2.6 (Boris)
% - added a 5% leeway in sizeImageX to start drawing tensors further from left border
% - added fullTag to folders and backup names to make follwing programs compatible
% - took "fullTag" definition to AIA_MultiOperation
% - moved most filling of DISPLAY to AOA_MultiOperation

% 18/01/2017: 2.5 (Boris)
% - made plot of FULL mean animal out of a HALF mean animal possible
% - removed leeway along Y to define "sizeImageY" (issue before was due to something else)
% - removed plot of miline that is now done in PlotField

% 18/01/2017: 2.4 (Boris)
% - same as 2.3 but removed most of the many old commented parts
% - decreased leeway along Y to define "sizeImageY" to 5% (from 10%)

% 12/01/2017: 2.3 (Boris)
% - ONLY using AOT backups now!! (=> removed "PnameAOA")
% - added leeway of 10% along Y to define "sizeImageY"

% 05/01/2016: 2.2 (Boris)
% - now uses "timeShift" to correct displayed time range of averaging
% - "All_Animals" became "allAnimals"
% - "Animals" became "avgAnimals"
% - "genericName" became "Animal"
% - "Pname" became "PnameAOA"

% 26/05/2016: 2.1
% - RConds are now mean using nanmean to avoid them impacting weight when they are not calculated
%   This follow the AOT modification to allow time windows average regardless of the movie length
% - Verification after the weight calculation to switch NaN to 0, because weight shoudl alway be between {0;1}

% 25/03/2015: 2.0
% - reshape of the mean process for better clarity and efficiency. It now in two times:
%   1 - create for each quantities a 5D matrix X,Y,Z,Time,Animal
%   2 - apply mean on the 5th dimension of each matrix
% - include of RConds variable in TA process

% 21/01/2015: 1.2
% - fixed bug when nb time point data == 1

% 13/11/2014 v1.1 :
% - add the new plot_field procedure that allow to plot iso and aniso value at different scale
% - start of integration of VMM process. TC,SO,DRP are not tested
% - modification of the code to better fit AIA_parameters from Boris

% 22/10/2014 v1 :
% - simplified rip-off of Animal_Averager of Anais adapted to Boris framework