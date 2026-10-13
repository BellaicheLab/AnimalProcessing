% CalculationOverQuantities (COQ) 
%
% Loads AOA backup (single or avg animal) and make simple operations between two list of quantities listed in AOA backups and appends the
% newly calculated ones to the backup.
% NB: ONLY WORKS with AOA backups (not sure it was working with other ones before)
%
% version 1.3
% Stephane Rigaud
% Boris Guirao
%

%% number of operations (1.2) %%

nQnameA = length(QnameA);
nQnameB = length(QnameB);

if nQnameA ~= nQnameB
    disp('COQ ERROR: number of quantities listed in "QnameA" and "QnameB" must be the same!')
    return
end

% Repeats
nCalculType = length(CalculType);
if nCalculType == 1
    CalculType = repmat(CalculType, nQnameA,1);
    nCalculType = length(CalculType);
elseif nCalculType ~= nQnameA
    disp('COQ ERROR: number of quantities listed in "CalculType" must either be 1 or match QnameA/B!')
    return
end

%% Process (mod 1.2) %%

for q = 1:nQnameA
    if strcmp(CalculType{q},'minus')
        Operation = '-';
    elseif strcmp(CalculType{q},'plus')
        Operation = '+';
    end
    
    disp(['Processing : ' QnameA{q} Operation QnameB{q}]);
    eval(['BACKUP.' QnameA{q} CalculType{q} QnameB{q} ' = BACKUP.' QnameA{q}  Operation ' BACKUP.' QnameB{q} ';']);
    if ~singleAnimal
        eval(['BACKUP.' QnameA{q} CalculType{q} QnameB{q} '_Smap = or(BACKUP.' QnameA{q} '_Smap, BACKUP.' QnameB{q} '_Smap);']);
    end
end

%%% Save AOA mean structure
disp('Appending structure ...')
Previous = load([OutputPath filesep backupName]);
eval([backupName ' = catstruct(Previous,BACKUP);']);                    % 1.3
save([OutputPath filesep backupName], '-struct', backupName, '-append'); % 1.3
% eval([backupName ' = catstruct(Previous,BACKUP);']);
% save([OutputPath filesep backupPathName], '-struct', backupName, '-append');


%% Plot %%

if PLOT.plot
    
    disp('Starting Plot ...')
    
    %%% initialisation of plot
    BACKUP = load([OutputPath filesep backupName]);
    Lt = size(BACKUP.FrameArray,1);

    %%% Loading plot parameters
    if ~singleAnimal % 1.3
        % Extracting FULL or REG data for plot (1.2)
        TYPE = BACKUP.REG;
        if PLOT.makeItFull
            TYPE = BACKUP.FULL;
        end
        BACKUP.xywh = TYPE.xywh;
        BACKUP.centroids = TYPE.centroids;
        BACKUP.sizeImageX = TYPE.sizeImageX;
        BACKUP.sizeImageY = TYPE.sizeImageY;
        
        DISPLAY.yMid = TYPE.yMid;
        DISPLAY.macrocaetes = TYPE.macrocaetes;
    else % single animal case (1.3)
        BACKUP.xywh = RAW.xywh;
        BACKUP.centroids = RAW.centroids;
        BACKUP.sizeImageX = RAW.imageSize(2);   
        BACKUP.sizeImageY = RAW.imageSize(1);   
        BACKUP.finalFrame = RAW.finalFrame;     
        
        DISPLAY.yMid = RAW.yMid;                 
    end
    
    Qimage = ones(BACKUP.sizeImageY, BACKUP.sizeImageX);
       
    %%% plot process
    for t = 1:Lt
        
        % Sets the time and n variable (mod 1.1)
        timeStart = Time_str2dec(BACKUP.TimeArray{t,1}) + timeShift;                % turns time string into decimal and adds timeShift
        timeEnd = Time_str2dec(BACKUP.TimeArray{t,2}) + timeShift;
        timeStart = Time_dec2str(timeStart);                                      % switches back to string
        timeEnd = Time_dec2str(timeEnd);
        DISPLAY.time = [timeStart ' - ' timeEnd];
        DISPLAY.n = round( ( BACKUP.FrameArray(t,1) + BACKUP.FrameArray(t,2) ) / 2 );
        
        if Lt > 1
            DISPLAY.step = t;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % singleAnimal processing: loading LGrid info from TA backups (mod 1.3)
        if singleAnimal
            framePlot = min(BACKUP.FrameArray(t,2), BACKUP.finalFrame); % 1.3
            % framePlot = BACKUP.FrameArray(t,2);
            if strcmp(gridType,'L')
                pathbackup = [RAW.gridAnimalFolder filesep 'Backups' filesep 'TA' '_LGrid_' Animal '_' num2str(framePlot,RAW.digitsFormat) '.mat'];
                % pathbackup = [RAW.gridAnimalFolder filesep 'Backups' filesep Pname '_LGrid_' Animal '_' num2str(framePlot,['%0' num2str(RAW.nDigits) 'd']) '.mat'];
                BU = load(pathbackup);
                iGRID = BU.GRID_TA;             % 1.3
                % iGRID = BU.(['GRID_' Pname]);
                DISPLAY.Lcentroids = iGRID.Lcentroids;
                DISPLAY.contour_indices = iGRID.contour_indices;
            end
            Qimage = imread([RAW.rawPathFolder filesep 'Output_results' filesep RAW.filename num2str(framePlot, RAW.digitsFormat) '.' RAW.imageFormat]);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        
        for q = 1:nQnameA % 1.2
            
            PlotQname = [QnameA{q} CalculType{q} QnameB{q}]; % 1.2

            [Pname,idx] = GetPname(QnameA{q});
            Qsr       = eval(['sr_' Pname '{idx}']);
            Qscalebar = eval(['srbar_' Pname '(idx)']);
            Qunits    = eval(['allUnits_' Pname '{idx}']);
            Qcolor    = eval(['allColors_' Pname '{idx}']);
            QKillTr   = eval(['killtrace_' Pname '(idx)']);
            
            % Overwritting by the one in AIA_MultiOperation (1.3)
            if ~isempty(QsrCOQ); Qsr = QsrCOQ(q); end
            if ~isempty(QsbCOQ); Qscalebar = QsbCOQ(q); end
            if ~isempty(QunitsCOQ); Qunits = QunitsCOQ{q}; end
            if ~isempty(QcolorsCOQ); Qcolor = QcolorsCOQ{q}; end
            
            KillTrTag = '';
            if QKillTr
                KillTrTag = '_Tr=0';
            end

            %%% Significance
            if PLOT.significance
                temp_sign_map = eval(['BACKUP.' PlotQname '_Smap']);
                DISPLAY.significant_map = temp_sign_map(:,:,:,t);
            end
            
            PlotField(PlotQname,QKillTr,Qcolor,Qunits,Qsr,Qscalebar,BACKUP,Qimage,DISPLAY);
            
            %%% print (mod 1.2)
            if PLOT.print
                frameOutputFolder = [OutputPath filesep 'COQ_' QplotType fullTag]; % 1.2
                thisFilename = [AOAtag PlotQname '_' timeStart 'to' timeEnd fullTag KillTrTag '_sr=' num2str(Qsr) imageExtension]; % 1.2
                mkdir(frameOutputFolder);
                if strcmp(imageExtension,'.svg')
                    plot2svg([frameOutputFolder filesep thisFilename],figure(1),'png');
                else
                    print(printFormat, printResolution, [frameOutputFolder filesep thisFilename]);
                end
            end
            close
        end
    end
end

%% History %%

% 06/02/2017: 1.3 (Boris)
% - adjustments for single movie processing
% - now saving newly calculated quantities in AOA backups EVEN when single animal processing!
% - removed parameter "OnameCOQ"
% - using values defined in AIA_MultiOperation for QsrCOQ, QsbCOQ, QunitsCOQ, QcolorsCOQ

% 02/02/2017: 1.2 (Boris)
% - adjustments to make it work with AOA v2.7
% - now process several operations A+/-B at the same time

% 05/01/2016: 1.1 (Boris)
% - replaced Oname by OnameCOQ
% - now uses "timeShift" to correct displayed time range of averaging

