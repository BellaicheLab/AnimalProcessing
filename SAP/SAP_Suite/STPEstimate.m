% STPEstimate
%
version = '3.8';
% Shuji Ishihara
% Boris Guirao (versions 1.1+)
%
% default input filename : dat.txt
%         output filename: out.dat, tmpP.png, tmpT.png
%


%% Initialization %%

% name = [Animal ' # ' num2str(fn)];                                      % "Animal" defined in STP_runner (2.10, moved 2.11)
if init   
    
    %%% defining tags to name outputs (mod 2.11, 3.0):
    tag = ABICminMethod;
    if ~strcmp(ABICminMethod,'forced')
        nametag = ['(\Delta\mu < ' num2str(muAccuracy) ',  ' tag ')']; % muAccuracy only relevant for "fminbnd" and "manual" ABIC methods
    else
        nametag = ['(' tag ')'];
%         tag = [tag '_mu=' num2str(muForced)];
    end
    
    %%% Creates directories (2.11, mod 3.5)
    folderBackup = [pathFolderSTPE filesep 'Backups']; 
    folderFrame = [pathFolderSTPE filesep 'Frames'];
    
    if ~exist(pathFolderSTPE,'dir')
        mkdir(pathFolderSTPE);
    end
    if ~exist(folderBackup,'dir')
    mkdir(folderBackup);
    end
    if ~exist(folderFrame,'dir') && (makePimage || makeTimage) % only created if some plots required (3.5)
        mkdir(folderFrame);
    end
    
    %%% Saving txt file indicating date and version used in "saveFolder" (3.5)
    %--------------------------------------------------------------------------
    today = datestr(now,29);                        % format 29 displays date yyyy-mm-dd style
    txtFilename = [today '_STPE_' version '.txt'];
    
    % Writing main parameters in txt file
    parameterCell = {   'Main Parameters:',[];
        [],[];
        'ABICminMethod = ', ABICminMethod;
        'muAccuracy = ', muAccuracy;
        'muForced = ', muForced;
        'sMshift = ', sMshift;
        'qrMethod = ',qrMethod;
        'scaleFactorSTPE = ', scaleFactorSTPE};
    
    dlmcell([pathFolderSTPE filesep txtFilename], parameterCell,' ');
    %--------------------------------------------------------------------------
    
    init = false; % initialization was just done (2.11)
end

filenameBackupShort = [filenameSTPE '_' num2str(fn,digitsFormat)];          % 3.5
filenameBackup = [folderBackup filesep filenameBackupShort '.mat'];         % mod 3.5
filenameTxtBackup = [folderBackup filesep filenameBackupShort '.txt'];      % mod 3.5
% filenameBackup = [folderBackup filesep 'STPE_' filename_fn];    % added STPE prefix in backups
% filenameBackup = [filenameBackup  '.mat'];                  % removed "'_out' tag"

skippedSTPE = false;    % variable to determine whether GV produced a proper "dat.txt" file for this frame OR NOT (2.13)
replotSTPE = false;     % variable to determine if  backup already exists and (3.5)
    
if ~exist(filenameBackup,'file')
    %% Loading data from dat.txt file %%
    
    fprintf(1,'##\n##  inpufile= %s\n##\n',fullFilenameData_fn);
    disp(' ');
    
    disp('Running "FastGetData"...');
    tic
    [Js,Es,Cs,Rnd,CELL_NUMBER,E_NUM,V_NUM,INV_NUM,R_NUM] = FastGetData(fullFilenameData_fn);                                 % 2.0
    toc
    
    %%% Checking dat file was NOT empty (3.3)
    if isempty(Js)
        disp('Empty "dat.txt" file => DELETING "dat.txt" file and SKIPPING STPEstimate for this frame!');
        delete(fullFilenameData_fn);
        skippedSTPE = true;
        return
    end
    
    ExtractData(Js,'','caller');
    ExtractData(Es,'','caller');
    ExtractData(Cs,'','caller');
    
    
    % =====================================
    %       Get Matrix to Solve MM
    % =====================================
    %%% Creates sparse matrix SMM (1.5):
    disp(' ');disp('Running "SparseGetMatrix_ForceEstimation"...');
    tic
    ERR_MAX = 1.0e-12;
    [SMM, C_NUM, X_NUM] = SparseGetMatrix_ForceEstimation(Js,Es,Cs,E_NUM,CELL_NUMBER,R_NUM,INV_NUM,ERR_MAX);
    %     [SMM, C_NUM, X_NUM] = SparseGetMatrix_ForceEstimation( x, y, edge, cell, E_NUM, CELL_NUMBER, R_NUM, INV_NUM, Rnd, 1.0e-12);
    toc
    
    %%% Creates sparse matrices SB, SG and SV (1.5):
    % sparse B:
    Bis = (1:E_NUM)';
    Bjs = (1:E_NUM)';
    Bss = ones(E_NUM,1);
    mB = E_NUM + CELL_NUMBER;
    nB = mB;
    SB = sparse(Bis,Bjs,Bss,mB,nB);
    % sparse G:
    Gis = (1:E_NUM)';
    Gjs = ones(E_NUM,1);
    Gss = ones(E_NUM,1);
    mG = E_NUM + CELL_NUMBER;
    nG = 1;
    SG = sparse(Gis,Gjs,Gss,mG,nG);
    % sparse V:
    %         SV = sparse([],[],[],size(SMM,1),1); % velocity zero (commented 2.5)

    
    fprintf('## constraint      :  C_NUM= %d   [ 2x(%d) ] \n',C_NUM,INV_NUM);
    fprintf('## unknown factors :  X_NUM= %d   [ E_NUM+CELL_NUMBER= %d + %d ] \n',X_NUM,E_NUM,CELL_NUMBER);
    fprintf('## rounding cells  :  R_NUM= %d   \n',R_NUM);
    
    
    %% Detecting and solving vertex mistakes (3.0)
    
    fprintf('\nChecking for mistakes in vertex ordering...\n')
    
    HParameter_Number = 2;
    sM = [ 1.0e-8 0.5 1.0 1.5 2.0 ];        % Will ONLY be used in the "manual" case
    
    % Special treatement of first mu value to check for vertex mistakes in Cs (2.5):
    [ABICsM1, vertexMistake] = SparseGetABIC_PT(SMM,SB,SG,sM(1),HParameter_Number,E_NUM,qrMethod); % removed SV from arguments (2.3)

    if vertexMistake
        fprintf('\nTP_Estimate WARNING: mistake in vertex ordering found in Cs!!\n');
        fprintf('\nFixing Cs with "Vertex_Fixer"...\n)');
        tic
        [Cs, vertexFixLog] = FixVertices(Cs,Es,Js);
        toc
        ExtractData(Cs,'','caller');
        disp('RE-Running "SparseGetMatrix_ForceEstimation to update matrix SMM with proper Cs"...');
        SMM = SparseGetMatrix_ForceEstimation(Js,Es,Cs,E_NUM,CELL_NUMBER,R_NUM,INV_NUM,ERR_MAX);
        vertexText = 'Vertex Fix';     % will display 'Vertex Fix' above TP scalebars
    else
        fprintf('\nNo mistake in vertex ordering found.\n');
        vertexFixLog = [];
        vertexText = '';
    end

   
    %% ABIC Minimization (mod 3.0) %%
    % =============================================================================================================
    
    fprintf('\n####################################################\n#\n');
    fprintf('#  Start determination of ABIC minimum... \n');
    fprintf('#\n####################################################\n');
    
    if strcmp(ABICminMethod,'fminbnd')
        
        % ==================================================================================================
        fprintf('using Matlab function "fminbnd" (NEW way)...\n')
 
        % finding ABIC minimum
        tic_global = tic;
        opts = optimset('Display','iter','TolX', muAccuracy);
        
        [mu, ABIC, exitflag] = fminbnd(@(Mu) SparseGetABIC_PTforMu(Mu,SMM,SB,SG,HParameter_Number,E_NUM,qrMethod), 0., 1.5, opts);
        
        % terminates loop if fminbnd did NOT converge to a solution
        if exitflag ~= 1
            disp('Function "fminbnd" did NOT converge to a solution. Skipping... ')
            return
        end
        disp(['### Result: ABIC(' num2str(mu) ') = ' num2str(ABIC)]);
        disp(['### Total ABIC minimization time = ' num2str(toc(tic_global))]);
        % ==================================================================================================
        
    elseif strcmp(ABICminMethod,'manual')
        
        % ==================================================================================================
        fprintf('using manual iterations (OLD way)...\n')

        tri_num=1;
        tABIC=[];
        
        % defining mu accuracy (1.1):
        disp(['mu accuracy = ' num2str(muAccuracy)]);
        
        tic_global = tic;
        ABIC = NaN(1,length(sM));   % 1.6
        
        % 3.0
        if vertexMistake
            istart = 1;                     % will recalculate ABIC of first mu value with fixed vertex ordering in Cs
        else
            ABIC(1) = ABICsM1;  % putting value already calculated
            istart = 2;         % resuming at second mu value since 1st was fine
        end
 
        % Resuming iteration at istart:
        for i = istart:length(sM)
            ABIC(i) = SparseGetABIC_PT(SMM,SB,SG,sM(i),HParameter_Number,E_NUM,qrMethod); % removed SV from arguments (2.3)
        end
        [pabic, mid] = min(ABIC);
        mu_ABICs = [sM' ABIC'];                                     % initializes "mu_ABICs" that will store all couples (?,ABIC) (2.6)
        fprintf('\n### %2d  % 10f  % 10f\n',tri_num,sM(mid),pabic);
        
        
        %% Starting "while" loop %%
        
        while sM(5)-sM(1)> muAccuracy
            [c,I] = min(ABIC);
            tABIC = [tABIC c]; %#ok<AGROW>
            delta_mu = abs(sM(5)-sM(1));
            disp(['delta mu = ' num2str(delta_mu) ' > ' num2str(muAccuracy)]);
            if I==1
                dsm = (sM(2)-sM(1))/4.0;
                sM = [sM(1) sM(1)+dsm sM(1)+2*dsm sM(2)+3*dsm sM(2)];
                ABIC(5) = ABIC(2);
                cind = 2:4;
            elseif I==2
                dsm = (sM(3)-sM(2))/2.0;
                sM = [sM(1) sM(1)+dsm sM(2) sM(2)+dsm sM(3)];
                ABIC(5) = ABIC(3);
                ABIC(3) = ABIC(2);
                cind = [2 4];
            elseif I==3
                dsm = (sM(3)-sM(2))/2.0;
                sM = [sM(2) sM(2)+dsm sM(3) sM(3)+3*dsm sM(4)];
                ABIC(2) = ABIC(1);
                ABIC(5) = ABIC(4);
                cind = [2 4];
            elseif I==4
                dsm = (sM(5)-sM(4))/2.0;
                sM = [sM(3) sM(3)+dsm sM(4) sM(4)+dsm sM(5)];
                ABIC(1) = ABIC(3);
                ABIC(3) = ABIC(4);
                cind = [2 4];
                % sMshift option (2.2)
                %---------------------------------------------------------------------------------------------------------------
            elseif I==5 && ~sMshift                                                                                        % correspond to Shuji's original code
                dsm = (sM(5)-sM(4))/4.0;
                sM = [sM(4) sM(4)+dsm sM(4)+2*dsm sM(4)+3*dsm sM(5)];
                ABIC(1) = ABIC(4);
                cind = 2:4;
            elseif I==5 && sMshift
                disp('ABIC(sM(5)) is minimal => Shifting sM values outside initial domain...')
                dsm = sM(5)-sM(4);
                sM = [sM(3) sM(4) sM(5) sM(5)+dsm sM(5)+2*dsm];                                                             % shift of sM OUTSIDE the initial domain
                ABIC(1) = ABIC(3);
                ABIC(2) = ABIC(4);
                ABIC(3) = ABIC(5);
                cind = 4:5;
                %---------------------------------------------------------------------------------------------------------------
            end
            
            for i=cind
                ABIC(i)  = SparseGetABIC_PT(SMM,SB,SG,sM(i),HParameter_Number,E_NUM,qrMethod); % removed SV from arguments (2.3)
                mu_ABICs = [mu_ABICs ; [sM(i) ABIC(i)]];                                    %#ok<AGROW> % adding new calculated values (2.6)
            end
            
            tri_num=tri_num+1;
            [mabic, mid] = min(ABIC);
            fprintf('\n### %2d  % 10f  % 10f\n\n',tri_num,sM(mid),mabic);
        end
        mu_ABICs = sortrows(mu_ABICs);                  % sorting rows according to ascending mu values (2.6)
        
        % display delta_mu value at exit of while loop (1.1)
        delta_mu = sM(5)-sM(1);
        disp(['delta mu = ' num2str(delta_mu) ' <= ' num2str(muAccuracy)]);

        [ABIC,I] = min(ABIC);
        mu = sM(I);
        disp(['### Result: ABIC(' num2str(mu) ') = ' num2str(ABIC)]);
        disp(['### Total ABIC minimization time = ' num2str(toc(tic_global))]);
        % ==================================================================================================
    
    elseif strcmp(ABICminMethod,'forced')  % 3.0
        
       fprintf(['forcing mu value to ' num2str(muForced) '...\n'])
       
        % Looking for Vertex mistakes
        vertexFixLog = [];
        vertexText = '';
       
       mu = muForced;
       ABIC = SparseGetABIC_PT(SMM,SB,SG,mu,HParameter_Number,E_NUM,qrMethod);
       disp(['### Result: ABIC(' num2str(mu) ') = ' num2str(ABIC)]);
    end
    % =============================================================================================================
    
    
    %% Maximal A Posteriori (MAP) estimation %%
    
    disp('MAP estimation...')
    smu = sqrt(mu);
    K=1;              % number of zero-eigen values of A
    
    UN = E_NUM;
    % UN = sum(any(B));  % = E_NUM !!!!
    % UN = rank(B'*B)
    
    M0 = X_NUM-UN;    % Number of zero-eigen values of B
    NKM = C_NUM+K-M0;
    
    
    S0 = sparse(zeros(C_NUM,1));
    SS = [SMM S0; smu*SB smu*SG]; %#ok<NASGU>
    clear SMM S0 SB SG SV
    
    % Determining SR (QR factorization):
    cmd = ['SR = ' qrMethod '(SS);'];
    fprintf(['\nQR decomposition of S using SPARSE MATRICES [' cmd ']...'])
    tic
    eval(cmd);
    fprintf('done\n');
    clear SS;
    toc
    
    % Building sparse H and F (1.6):
    SH = SR(1:X_NUM-1,1:X_NUM); %#ok<NASGU>
    Sh = SR(1:X_NUM-1,end);     %#ok<NASGU>
    clear SR
    
    cmd = 'Sep = spqr_solve(SH,Sh);';
    fprintf(['\nInverting H and computing "ep" using SPARSE MATRICES [' cmd ']...'])
    tic
    % Determining Sep with "spqr_solve" (1.7):
    %------------------------------------------------
    eval(cmd);
    % Removal of mean pressure (only required for):
    Ptemp = Sep(E_NUM+1:X_NUM);
    Ptemp = Ptemp - mean(Ptemp);
    Sep(E_NUM+1:X_NUM) = Ptemp;
    %------------------------------------------------
    
    % Best alternative to "sqr_solve":
    % Sep = inverse(SH)*Sh;
    
    fprintf('done\n')
    toc
    clear SH Sh Ptemp
    fprintf('\nBuilding full "ep"...')
    fprintf('done\n')
    tic
    ep = full(Sep);
    toc
    clear Sep
    
    %%%% normalize as mean(T) = 1.0;
    norm = mean(ep(1:E_NUM));
    ep = ep/norm;

else % When fullFilenameBackup was found (2.13, 3.7)
    
    disp(['Backup file ' filenameBackupShort ' was found => STPEstimate was skipped for this frame!']); % 2.13, mod 3.5
    
    %%% Loading .mat backups (2.1, mod 2.7, 2.11, move here 3.5)
    %---------------------------------------------------------------------------------------------------------------------------
    replotSTPE = true;          % backup was found => this is just a replot (3.5)
    
    if makePimage || makeTimage % Only loads backup if at least one plot will be performed (3.5)
        
        % remove display parameters from backup before loading it to prevent overwritting (2.7, updated names in 2.14);
        load(filenameBackup);
        % Further extracting (3.7)
        ExtractData(Js,'','caller');
        ExtractData(Es,'','caller');
        ExtractData(Cs,'','caller');

        if ~exist('vertexText','var') % old backups compatibility (3.1)
            vertexText = '';
        end
    end
    %---------------------------------------------------------------------------------------------------------------------------
end


%% Output Figures (mod 3.5) %%
   
if ~replotSTPE || makePimage || makeTimage % 3.8
    
    T = ep(1:E_NUM);
    P = ep(E_NUM+1:X_NUM)/scaleFactorSTPE;
    
    nTones = 128;
    maxP = max(P);
    minP = min(P);
    maxT = max(T);
    minT = min(T);
end
    
if makePimage || makeTimage % 3.5
    
    displayText = ['\mu = ' num2str(mu,'%.3f') '   ' nametag '   ABIC = ' num2str(ABIC,'%.0f')  '   ' vertexText]; % moved, added vertext_text
    leeway = 1;                 % introduces space (in pixels) between the now drawn image frame and resolution info (?, ABIC...) (2.7)
    
    % defines specific tags when P/T_range is set (2.8.1):
    P_range_tag = [];
    T_range_tag = [];
    if ~isempty(rangeP)
        P_range_tag = ['_[' num2str(rangeP(1)) ' ' num2str(rangeP(2)) ']'];
    end
    if ~isempty(rangeT)
        T_range_tag = ['_[' num2str(rangeT(1)) ' ' num2str(rangeT(2)) ']'];
    end
    
    % creating image backgrounds (3.5)
    imageBG = ones(imageSize);                   % makes image with minValEff as background value
    imageBG = repmat(imageBG, [1 1 3]);           % making it RGB otherwise get B&W colormap with Matlab 2017!
    
    %% Cell Pressures (overhaul 3.1,3.2,3.5) %%
    
    if makePimage
        
        thisFilenameShort = ['P_' filename_fn P_range_tag '.png'];
        thisFilename = [folderFrame filesep thisFilenameShort];
        
        if ~exist(thisFilename, 'file')
            
            fprintf(['\nPlotting cell PRESSURES and saving image "' thisFilenameShort '"...\n']);
            fprintf('minP = %f ; maxP = %f\n', minP, maxP);
            
            %%% Determines rangePplot and dP:
            Pplot = P;
            minPplot = minP;
            maxPplot = maxP;
            if ~isempty(rangeP)
                minPplot = rangeP(1);
                maxPplot = rangeP(2);
                Pplot(P < minPplot) = minPplot;
                Pplot(P > maxPplot) = maxPplot;
            end
            
            %%% Initializing image, applying colormap and building colorbar (3.2, 3.5)         
            figure('PaperPositionMode','auto')
            imshow(imageBG,'Border', 'tight');
            hold on
            
            cmap = cool(nTones);
            [hc, valVector]= PlotColorBar('cell pressure', colorBarXYWH, [minPplot maxPplot], fontSizeInfo, colorInfo, cmap);
            
            caxis([minPplot maxPplot]);     % colormap will cover this range of values
            set(hc, 'XTick', valVector);    % specifies the values to display on colorbar
                       
            for i=1:CELL_NUMBER
                if i > R_NUM
                    iCJs = CJs(i,:);
                    iCJs_TF = ~isnan(iCJs);
                    ijs = iCJs(iCJs_TF);
                    pgx = JXs(ijs);
                    pgy = - JYs(ijs);                           % now taking minus sign becaue switched to image convention in 3.1
                    fill(pgx,pgy,Pplot(i),'linewidth',edgeWidthP); % use of Pplot
                end
            end
            
            %%% Plots border edges WITHOUT LOOP (2.6):
            line([EX1s(Rnd)';EX2s(Rnd)'],[-EY1s(Rnd)';-EY2s(Rnd)'],'linewidth',edgeWidthP,'color','b'); % minus sign (3.1)
            
            %%% Plotting info (time hAPF, animal and scalebar)
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(fn)  ' (mu* = ' num2str(mu,2) ')']; % 3.3
                textQuantity = 'Cell Pressure';
            end
            time = frame2time(fn, timeRef, frameRef, dt,'str');
            PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
            
            % Saving image
            print(printFormat, printResolution, thisFilename); % 3.1
            close
            pause(1); % pause to give time to close figures (1.3)
            
        else
            disp(['Image "' thisFilenameShort '" was found and was skipped.']) % 3.5
        end
    end
    
    %% Edge tensions (overhaul 3.1,3.2) %%
    
    if makeTimage
        
        % Defining "Atag" right away (3.5);
        Atag = '';                              % default Apoptotic Tag
        if displayApoptoticCells && exist(allDelaminatingANsFile,'file')
            Atag = ['Adisplay_' num2str(tSwitch) 'h_'];
            
            % Loading "allDelaminatingCells" CTD backup (3.5)
            allDelaminatingCellsFile = [pathFolderCTD filesep 'allDelaminatingCells.mat'];
            load(allDelaminatingCellsFile);
        end
        
        thisFilenameShort = ['T_' Atag filename_fn T_range_tag '.png']; % removed "tag", moved T at beginning (2.11), added Atag (2.14)
        thisFilename = [folderFrame filesep thisFilenameShort];           
        
        if ~exist(thisFilename, 'file')
            
            fprintf(['\nPlotting edge TENSIONS and saving image "' thisFilenameShort '"...\n']);
            fprintf('minT = %f ; maxT = %f\n\n', minT, maxT);
            
            %%% Determining rangeTplot and dT:
            Tplot = T;              % Tplot is solely used for Tension plot purposes (2.6)
            maxTplot = max(T);
            minTplot = min(T);
            if ~isempty(rangeT)
                maxTplot = rangeT(2);
                minTplot = rangeT(1);
                % ceil/floor T values at plot thresholds:
                Tplot(T > maxTplot) = maxTplot;
                Tplot(T < minTplot) = minTplot;
            end
            
            %%% Initializing image, applying colormap and building colorbar (3.2, 3.5)
            figure('PaperPositionMode','auto')
            imshow(imageBG,'Border', 'tight');
            hold on
            
            cmap = jet(nTones);
            [hc, valVector]= PlotColorBar('edge tension', colorBarXYWH, [minTplot maxTplot], fontSizeInfo, colorInfo, cmap);
            
            caxis([minTplot maxTplot]);     % colormap will cover this range of values
            set(hc, 'XTick', valVector);    % specifies the values to display on colorbar
            
            
            % display of Apoptotic cells (as soon as they appear) (2.14)
            %----------------------------------------------------------------------
            if displayApoptoticCells && exist(allDelaminatingANsFile,'file')
                
                nSwitch = tSwitch*60/dt;        % number of frame
                baseACellColor = grey;          % cell color if cRatio could reach0
                lastACellColor = black;         % cell color when cRatio = 1
                
                nCol = size(allDelaminatingANs,2) + 1; % +1 to put the RNs in first column
                % NB: list of A/D cells ANS "allDelaminatingANs" has been loaded in AIA (ONLY once)
                
                % Loading and expanding "Correspondence" (mod 3.5)
                CorrespondenceRaw = dlmread([trackingFolder filesep 'correspondence_' num2str(fn) '.txt']);
                Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal);
                clear CorrespondenceRaw;
                
                % Getting A/D cell Matlab RNs that exist in image:
                [AcellMRNsTF, AcellLoc] = ismember(Correspondence(:,2:end),allDelaminatingANs,'rows');
                AcellMRNsRaw = Correspondence(AcellMRNsTF,1);
                
                % gets corresponding last frames
                AcellLoc = AcellLoc(AcellLoc > 0); % removes 0s that cannot be indexes
                AcellLastFramesRaw = allLastFramesDel(AcellLoc); % mod 3.5
  %             AcellANsRaw = allDelaminatingANs(AcellLoc,:);
                
                % Shuji-Matlab correspondance file must be loaded FOR EACH frame
                MSMfile = [pathFolderMSM filesep 'Backups' filesep filenameMSM '_' num2str(fn,digitsFormat) '.mat'];
                load(MSMfile,'Cs_MS_match');
                
                % get A/D cells SHUJI RNs that exist in image:
                AcellSRNsRaw = Cs_MS_match(AcellMRNsRaw,2);
                % removing 0s (for cells NOT found) and cropping other matrices so they match:
                AcellSRNs = AcellSRNsRaw(AcellSRNsRaw > 0);
                AcellMRNs = AcellMRNsRaw(AcellSRNsRaw > 0);
                %             AcellANs = AcellANsRaw(AcellSRNsRaw > 0,:);
                AcellLastFrames = AcellLastFramesRaw(AcellSRNsRaw > 0); % updates "AcellsLastFrames" accordingly
                nAcells = length(AcellSRNs);
                
                % only iterates over A/D cells
                hold on
                for c = 1:nAcells
                    iA = AcellSRNs(c);         % get this Shuji RN
                    %                 cAN = AcellANs(c,1); % only displays first AN (no div tags)
                    cLF = AcellLastFrames(c);
                    cColor = baseACellColor;
                    if cLF-fn <= nSwitch
                        cColor = lastACellColor;
                    end
                    %                 cRatio = fn/cLF; % 0 < cRatio <= 1 when the cell is in its last frame
                    %                 cColor = Color_Mixer(lastFrameColor, baseFrameColor,cRatio); % = lastFrameColor when cRatio = 1
                    if iA > R_NUM
                        iCJs = CJs(iA,:);
                        iCJs_TF = ~isnan(iCJs);
                        ijs = iCJs(iCJs_TF);
                        pgx = JXs(ijs);
                        pgy = - JYs(ijs); % taking minus becaue switched to image convention in 3.1
                        fill(pgx, pgy, cColor,'linewidth',edgeWidthP);
                    end
                end
                
            end
            %----------------------------------------------------------------------
            
            % Plots border edges WITHOUT LOOP (2.6):
            es = 1:E_NUM;
            dT = (maxTplot - minTplot)/(nTones-1);      % distance between 2 tones (3.5)
            ds = (Tplot(es)-minTplot)/dT;
            ds = int16(ds)+1;                          % defines position in colormap for each edge. Removed one "+1" in 3.5 since removed background tone.
            % NB: +1 so that minTplot (ds =0) corresponds to first tone in cmap => edges must start at tone #1
            
            % FIRST sets the color that will be assigned to each edge by imposing color order in which edges will be drawn:
            set(gca,'ColorOrder',cmap(ds,:));                                           % replaces default color order by tones corresponding to each edge tension
            
            line([EX1s(es)';EX2s(es)'],[-EY1s(es)';-EY2s(es)'],'linewidth',edgeWidthT); % minus sign (3.1)
            % NB: edges are plotted in the same order as their corresponding tones in "ds"
            
            % Plotting info (time hAPF, animal and scalebar)
            textAnimal = '';
            textQuantity = '';
            if ~minimalInfoDisplay
                textAnimal = [Animal ' # ' num2str(fn) ' (mu* = ' num2str(mu,2) ')']; % 3.3
                textQuantity = 'Edge Tension';
            end
            time = frame2time(fn, timeRef, frameRef, dt,'str');
            PlotInfo(textQuantity, '',0, colorInfo, ['\mu' 'm'], textAnimal, time, colorInfo, scaleBarLength, scale1D, fontSizeInfo, xyOffset, scaleBarWidth); % 1.5
            
            % Saving image
            print(printFormat, printResolution, thisFilename); % 3.1
            close
            pause(1); % pause to give time to close figures (1.3)
        else        
            disp(['Image "' thisFilenameShort '" was found and was skipped.']); % 3.5
        end
    end
    
end


%% Saving Workspace in .mat and .txt files %%

if ~replotSTPE  % 3.5

    fprintf(['Saving "' filenameBackupShort '" backup...'])
    %%% .mat file:
    save(filenameBackup,'ABIC','mu','Js','Es','Cs','Rnd','CELL_NUMBER',...
        'E_NUM','V_NUM','INV_NUM','R_NUM','X_NUM','ep'); % saving minimal backup (3.7)
%     save(filenameBackup);
    
    %%% .txt file:
    oFid = fopen(filenameTxtBackup, 'w' );               % 2.11, 3.5
    fprintf( oFid, '### ABIC= %e \n', ABIC );
    fprintf( oFid, '### mu=   %e \n', mu   );
    for e=1:E_NUM
        fprintf(oFid,'%3d   %e - -    (%f %f) (%f %f) \n',e-1,ep(e),EX1s(e),EY1s(e), EX2s(e),EY2s(e));
    end
    fprintf(oFid,'\n');
    for i=E_NUM+1:length(ep)
        fprintf(oFid,'- - %3d   %e\n',i-E_NUM-1,ep(i));
    end
    fclose(oFid);
    
    fprintf('Done.\n')    
end


%% History %%

% IMPROVEMENTS:
% - parallelize the processing of frames?

% 21/05/2019: 3.8
% - restored use of "skippedSTPE" to fix bug
% - fixed bug when not plotting anything + rerunning on already processed
% frames

% 15/03/2018: 3.7
% - only saves required quantities in backups to avoid huge backup files
% (especially when other programs have run before)

% 02/03/2018: 3.6
% - small adjustments to match GV 2.0

% 27/02/2018: 3.5
% - removed AIA parameter "replotSTPE" to define it internally here when
% STPE backup is found
% - removed variable "skippedSTPE" as existence of "dat.txt" file is
% checked in AIA_parameters and when it exists and is empty, using "return"
% here to skip iteration
% - now skipping the making of figure when it already exists
% - stopped adding tags to "Backups" and "Frames" folders. Now saving a txt
% file with parameters used like for other programs.
% - fixed display of P and T images due to change in the way Matlab 2017
% handles graphics.

% 26/02/2018: 3.4
% - adjustments to make it work with new function and variable names

% 29/06/2017: 3.3
% - Fixed crash when empty dat.txt file encoutered: now checking "dat" file is not empty and skipping execution if it is.
% - put back mu* star value next to image number

% 22/06/2017: 3.2
% - finalized the use of "InitiateColorMapImage" and "PlotColorBar" 

% 23/05/2017: 3.2 BETA
% - started using "PlotColorBar"

% 19/05/2017: 3.1
% - overhaul of P,T image generation
% - now saves images of P and T similar to all other AIA programs (same size, resolution...)
% - new parameters "makePimage" and "makeTimage" in "AIA_parameters"
% - fixed bug when "vertexText" was not defined in backups
%
% 13/02/2017
% - small adjustments to match AIA_parameter update 6.9: using "filename_fn" rather than "filename" that used to
% overwrite the one from AIA_info

% 07/09/2016: 3.0
% - implemented research of ABIC minimum with Matlab function "fminbnd"
% - accordingly added parameter "ABICminMethod" that can be "manual", "fminbnd", and "forced"
% - ONLY using code with sparse matrices now => removed parameter "code2run"
% - removed support of old backups with old folder names

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 02/09/2016: 2.14
% - option to display apoptotic cells in junction tension maps
% - added "Adisplay" in names of Tension images
% - fixed replot mode

% 26/04/2016: 2.13
% - now checks existence of backup of frame about to be processed and skips it if already exists => easier to run it on many computers

% 11/06/2015:
% - reintroduced a specific resolution to save images "printResolution_STPE"

% 28/05/2015: 2.12 became "STPEstimate"
% - changed many paramter names to match AIA 6.0

% 08/10/2014: 2.11: minor adjustments for integration into AIA workflow
% - changed code2run mode to 'sparse' from 'fast'
% - changed names of backup/frame folders and file to improve compatibility with mac that cannot read files with the "mu" character
% - now specifying this in folder names and NOT in filenames anymore
% - now directly using "mu" instead of mu symbol
% - supports replot of older backups (not original Shuji backup though)
% - figure filenames start with quantity plotted now

% 12/09/2014: 2.10
% - now creates classic tree view with folder STPE_animal, and subfolder Backups and Frames

% 23/07/2014: 2.9
% - user of filesep for mac compatibility

% 07/05/2014: 2.8.1
% - when T/P_range is specified in "STP_Estimate_runner", adds it to saved figure filenames.

% 13/02/2014: 2.8
% - fixed display bug with edge tension and frame location in "regular" mode
% - removed definition and use of mx = mean([edge.x1]), my = mean([edge.y1])
% - added axis option "tight" to limit colorbar width to image width
% - removed many commented parts in section %% Output Figures %%

% 12/02/2014: changed name to "STP_Estimate" from "TP_Estimate" for consistency with Shuji's naming

% 12/11/2013: 2.7
% - redrawing raw image frame around cells in T,P images (to make overlay easy)
% - simplified replot part using "rmfield" instead of definition of new variables to prevent overwritting of display parameters
% - added some leeway around the newly drawn frame because some edges were missing

% 24/09/2013: 2.6
% - saving of all couples (?,ABIC) into "mu_ABICs" computed during minimization in backup file
% - removed all occurences of "DHosei_Y" (Plot part) that was set to 0 and added to Y components (useless)
% - diplay of P and T colors according to parameters P_range and T_range
% - plot of edges is now done without "for" loops (and stopped using mx, my)

% 20/09/2013: 2.5
% - use of "Vertex_Fixer" to fix erroneous vertex ordering in CJs (in Cs) (ONLY FOR SPARSE VERSION OF CODE)
% - accordingly displays "Vertex Fix" above TP scalebars in TP images
% - commented creation of SV and V matrices since not used anymore

% 19/09/2013: 2.4 changed name to "TP_Estimate" from "Force_Estimate_PT" v2.3
% - removed the commented parts to compare sparse and full matrices for M,B,V,G...

% 03/09/2013: 2.3 (modified from version 2.2, separately of Anaelle's version)
% - removed SV and V from arguments of SparseGetABIC_PT and Get_ABIC_PT, respectively to make it compatible with latest
% version of these two routines (2.2 and 1.2, respectively)

% 30/12/2012:
% - fixed bug in replot mode where some display paramaters were erased after 1st iteration

% 12/11/2012: 2.2
% - changes to include parameter "sMshift" to avoid being stuck on border of initial sM domain when ABIC(sM(5)) is
% minimal

% 12/11/2012: 2.1
% - implemented replot mode from backups
% - not saving plot parameters anymore to avoid overwritting when loading badckups for replot
% - accordingly moved saving of workspace to the end
% - compatibility with "old" backups using parameter "use_sparse" and not "code2run"

% 11/11/2012: 2.0
% - changes to make it compatible with "FastGetData"
% - added display of delta ? accuracy in filename and title
% - changed name of saved files so they contain "code2run" and "? accuracy" info

% 08/11/2012: 1.7
% - use of "spqr_solve" to determine Sep instead of "pinv" (doesn't support sparse matrices) or even "inverse" (=factorize)
% - split edge_with into ..._T and ..._P
% - fixed mistake of first ABIC computation (for i=3 instead of i=1:length(sM))

% 31/10/2012: 1.6
% - added option "use_sparse" to use new faster code thoroughly using sparse matrices OR use (almost) original Shuji's code
% - use of "pseudoinverse" instead of "pinv" when sparse matrices are used
% - improved display with titles and resolution

% 30/10/2012: 1.5
% - adjustments for compatibility with "GetMatrix_ForceEstimation" 1.1 that returns sparse matrix SMM instead of MM
% - now uses sparse versions of B,G and V matrices (SB,SG,SV) that are used in GetABIC

% 01/10/2012: 1.4
% - clearing biggest matrices right after their last use => significant decrease of backup size!!

% 28/09/2012: 1.3
% - stopped calculating UN = rank(B'*B) here and in "Get_ABIC_PT" (not needed): UN = sum(any(B));

% 27/09/2012: 1.2
% - now runs through "run_Force_Estimation_PT"
% - changed filenames and paths so that everything is loaded
% - changed filenames of saved files
% - added many timings and workspace display

% 26/09/2012: 1.1
% - added parameter "mu_accuracy = 1e-2";                                                                                                     % 1e-2 = 0.01

