% MatlabShujiMatcher (MSM)
%
% This program will match Shuji and Matlab relative numbers of vertices (Vs), cells (Cs) and edges (Es). The
% program starts by matching vertex numbers based on their exact XY coordinates, then matches cell numbers based on
% their exact vertex list first, then rescue the unfound ones by allowing a match if 2 cells share at least
% "min_n_vertices". Finally, it matches edges based on vertex numbers previously matched.
% The output is a mat file "Animal_XXX_MS_match.mat" that contains 2 column matrices:
% Matlab-Shuji match: Vs_MS_match, Cs_MS_match, Es_MS_match.
% Shuji-Matlab match: Vs_SM_match, Cs_SM_match, Es_SM_match.
% if "check_MS_match" = 1 in "STP_Estimate_runner", an image displayig Matlab and Shuji cell numbers at cell exact
% centroid (Matlab) and at average vertex positions (Shuji) will be saved. Unmatched vertices, cells and edges are
% displayed in red. Rescued cells are displayed in green.
%
% NB: Runs through "STP_Estimate_runner" where parameters should be specified in the "MSM" section.
% NB: STP backups (run in "fast/sparse" mode) are required to run this script.
% NB: LISTS OF CELLS AND VERTICES ARE ALWAYS LONGER IN MATLAB SINCE THEY CONTAIN ALL SEGMENTED CELLS
% NB: It is a complete overhaul of Anaelle Pierre preliminary program (restarted from scratch).
%
% Boris Guirao
version = '2.15';


%% Creating directories (2.7) %%

tic
if fn == frames2process(1)
        
    % Defines and create directories
    mkdir(pathFolderMSM);
    MSMbackupFolder = [pathFolderMSM filesep 'Backups'];
    mkdir(MSMbackupFolder);
    if displayMSM
        MSMframeFolder = [pathFolderMSM filesep 'Frames'];
        mkdir(MSMframeFolder);
    end
end


%% Loading STP and SIA backups %%

% Defining path to STPE backup files (2.7, 2.11):
filename_fn = [rootFilename num2str(fn,digitsFormat)];
STPEbackupShort_fn = [filenameSTPE '_' num2str(fn,digitsFormat) '.mat'];        % 2.14
STPEbackup_fn = [pathFolderSTPE filesep 'Backups' filesep STPEbackupShort_fn];  % 2.14

% Defining path to SIA backup files:
SIAbackup_fn = [pathFolderSIA filesep 'Backups' filesep filenameSIA '_' num2str(fn,digitsFormat) '.mat']; % 2.12

% displays version running and image being processed:
disp(' '); disp(' ');
disp(['Running "MatlabShujiMatcher" version ' version ' on "' filename_fn '"...']);
disp('---------------------------------------------------------------------------------');

% Defining backup "MSMbackup_fn" (moved up here in 2.13)
MSMbackupFilname = ['MSM_' rootFilename num2str(fn,digitsFormat) '.mat'];
MSMbackup_fn = [MSMbackupFolder filesep MSMbackupFilname];

if ~exist(MSMbackup_fn,'file') % 2.13
    
    % Loading of current STPE backups, if not found look for older backup (2.7):
    if exist(STPEbackup_fn,'file')
        disp(['Loading STPE backup "' STPEbackup_fn '"!'])
        load(STPEbackup_fn, 'Js','Es','Cs'); % only loads what's needed (1.1)
        disp('Done.')
    else
        disp(['WARNING: STPE backup file "' STPEbackup_fn '" was not found!']);
        disp('This frame was skipped.');
        return
    end
    
    % Loading of SIA backups:
    if exist(SIAbackup_fn,'file')
        load(SIAbackup_fn); % loads all SIA structures (2.3)
    else
        disp(['WARNING: SIA backup file "' SIAbackup_fn '" was not found and was skipped!!']);
        return
    end
    
    
    
    %% Matching vertices %%
    
    disp('Matching vertex numbers by comparing Matlab & Shuji vertex coordinates...');
    
    % Matlab:
    Vs_M = VERTICES.Numbers; % WITH C++SIA, NO LONGER CORRESPONDS TO VERTEX ROWS!! (2.15)
    nVs_M = length(Vs_M);
    VXYs_M = VERTICES.XYs;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    VXYs_M = round(VXYs_M/scale1D); % putting coordinates back in PIXELS
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Shuji:
    VXYs_S = [Js.JXs -Js.JYs] + 1; % Shifting coordinates by (+1,+1) to match Matlab ones.
    nVs_S = length(Js.JXs);
    Vs_S = (1:nVs_S)';
    
    % Building matrix of correspondence for VERTICES: Matlab - Shuji "Vs_MS_match":
    % NB: in Matlab vertex list, looks for EXACT SAME XY coordinates of Shuji's vertex XY list
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [VXYs_M_TF, VXYs_M_loc] = ismember(VXYs_M, VXYs_S, 'rows');
    Vs_MS_match = [Vs_M VXYs_M_loc];                                % matrix of vertex correspondence Matlab - Shuji
    % NB: Shuji vertex numbers being listed in order from 1 to nVs_S, the index at which matlab vertex XY was found in
    % VXYs_S hence also corresponds to Shuji vertex number.
    % NB:   left column: all Matlab vertex numbers (not image border "fake" vertices though)
    %       right column: Shuji vertex numbers when matched, 0 otherwise
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Shuji vertices NOT FOUND in Matlab list:
    %------------------------------------------------------------------------------------------------------------------
    nVs_M_in_S = sum(VXYs_M_TF);            % number of Matlab vertices that found a match with a Shuji vertex
    nVs_S_missing = nVs_S - nVs_M_in_S;     % number of Shuji vertex not matched with a Matlab vertex
    % NB: ALL UNMATCHED SHUJI VERTICES SHOULD BE "Ext" VERTICES IF SEGMENTED IMAGES WENT THROUGH "Four_Pixel_Blocks_Filter" BEFORE BEING PROCESSED BY GETVERTEX!!
    if nVs_S_missing > 0
        Vs_S_missing = setdiff(Vs_S,VXYs_M_loc);
        disp(['WARNING: ' num2str(nVs_S_missing) ' (# ' num2str(Vs_S_missing') ') of Shuji vertices were not matched in Matlab!!'])
    else
        Vs_S_missing = [];
        disp('All of Shuji vertices were matched in Matlab vertex list!');
    end
    %------------------------------------------------------------------------------------------------------------------
    
    
    % Building matrix of inverted correspondence for VERTICES: Shuji-Matlab "Vs_SM_match" (2.4)
    %------------------------------------------------------------------------------------------------------------------
    % mod 2.15: in C++SIA, Matlab vertex numbers NO LONGER corresponds to their rows!!
    [Vs_S_TF, Vs_S_loc] = ismember(Vs_S, Vs_MS_match(:,2)); 
    Vs_S_locFound = Vs_S_loc(Vs_S_TF);                      % removes zeros to only keep found ones
    
    Vs_SM_match = [Vs_S false(nVs_S,1)];                    % initialization
    Vs_SM_match(Vs_S_TF,2) = Vs_MS_match(Vs_S_locFound,1);  % replacing 0s with MATLAB vertex numbers
    
    % OLD
%     [~, Vs_S_loc] = ismember(Vs_S, Vs_MS_match(:,2));
%     Vs_SM_match = [Vs_S Vs_S_loc];
    % NB: Matlab vertex numbers being listed in order from 1 to nVs_M, the index at which Shuji vertex was found in
    % column 2 of "Vs_MS_match", hence also corresponds to Matlab vertex number.
    % NB:   left column: all Shuji vertex numbers
    %       right column: Matlab vertex numbers when matched, 0 otherwise
    %------------------------------------------------------------------------------------------------------------------
    
    
    %% Matching cells %%
    
    fprintf('\n')
    disp('Matching cell numbers by comparing their Matlab & Shuji vertex numbers...');
    
    % Matlab:
    %--------------------------------------------------------------------------------------------------
    CRNs_M = CELLS.Numbers;     % cell relative numbers in Matlab
    CVs_M = CELLS.Vertices;     % CELL ARRAY containing the list of Matlab vertex numbers for each cell (row)
    CnVs_M = CELLS.nVertices;  % number of vertices for each cell
    nCs_M = length(CnVs_M);     % number of cells
    max_nVs_M = max(CnVs_M);
    
    % Converting "CVs_M" array into matrix "CVs_M2S" where Matlab vertex numbers are replaced by their matching Shuji numbers using "Vs_MS_match":
    CVs_M2S = zeros(nCs_M,max_nVs_M);
    for c = 1:nCs_M 
        [~,CVs_M_loc] = ismember(CVs_M{c},Vs_M);            % finding rows for those vertex numbers (2.15)
        CVs_M2S(c,1:CnVs_M(c)) = Vs_MS_match(CVs_M_loc,2);   % for each cell (row), *NEW* Matlab vertex numbers (from C++SIA) TRANSLATED into Shuji number with "Vs_MS_match" (mod 2.15)
%         CVs_M2S(c,1:CnVs_M(c)) = Vs_MS_match(CVs_M{c},2);   % for each cell (row), Matlab vertex numbers TRANSLATED into Shuji number with "Vs_MS_match"
    end
    CVs_M2S = sort(CVs_M2S,2,'descend');                    % IN EVERY ROW, sorts vertex numbers in DESCENDING order, putting 0s at the end
    %--------------------------------------------------------------------------------------------------
    
    % Shuji:
    %--------------------------------------------------------------------------------------------------
    CVs_S_nan = Cs.CJs;                     % matrix containing the list of Shuji vertex numbers for each cell (row), filled up with NaNs
    CnVs_S= Cs.CnJs;                    % number of vertices for each cell
    nCs_S = length(CnVs_S);             % number of cells
    CRNs_S = (1:nCs_S)';                % cell relative numbers in Shuji
    max_nVs_S = max(CnVs_S);
    
    % Sorting vertex numbers in DESCENDING order for every cell (row):
    CVs_S = CVs_S_nan;
    CVs_S(isnan(CVs_S_nan)) = 0;            % replaces NaNs by 0s so "ismember" can be used
    CVs_S = sort(CVs_S,2,'descend');    % IN EVERY LINE, sorts vertex numbers in DESCENDING order, putting 0s at the end
    %--------------------------------------------------------------------------------------------------
    
    % Compares largest number of vertices found in Matlab and Shuji and crops matrices to smallest number:
    max_nVs = min(max_nVs_M, max_nVs_S);
    CVs_M2S = CVs_M2S(:,1:max_nVs);
    CVs_S = CVs_S(:,1:max_nVs);
    
    % Building matrix of correspondence for CELLS : Matlab-Shuji "Cs_SM_match" (2.4)
    % NB: in matrix of Matlab vertices translated into Shuji numbers "CVs_M2S", looks for rows that can be found in Shuji's matrix of cell vertex numbers "CVs_S":
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [CVs_M2S_TF, CVs_M2S_loc] = ismember(CVs_M2S, CVs_S, 'rows');
    Cs_MS_match = [CRNs_M CVs_M2S_loc];                                 % temporary matrix of cell number correspondance Matlab - Shuji
    % NB: Shuji cell numbers being listed in order from 1 to nCs_S, the row at which Matlab set of vertices was found in
    % CVs_S hence also corresponds to Shuji cell number.
    % NB:   left column: Matlab cell numbers
    %       right column: Shuji cell numbers when matched, 0 otherwise
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    % Shuji cell numbers NOT MATCHED in Matlab list: RESCUING SOME OF THEM by looking at their specific vertex list
    %---------------------------------------------------------------------------------------------------
    % NB:   some cells could not be found because their vertex list is incomplete.
    %       In this rescue round, matching will be based on the largest number of vertices shared by these remaining cells in Matlab and Shuji.
    nCs_M_in_S = sum(CVs_M2S_TF);
    nCs_S_missing = nCs_S - nCs_M_in_S;
    if nCs_S_missing > 0
        Cs_S_missing = setdiff(CRNs_S,CVs_M2S_loc);                                                     % gets Shuji's cell numbers not matched
        Cs_S_solved = NaN(nCs_S_missing,1);         % 2.15
        disp(['WARNING: ' num2str(nCs_S_missing) ' (# ' num2str(Cs_S_missing') ') of Shuji cells were not matched in Matlab!!'])
        disp('Attempting rescue of cells whose Shuji number was not matched in Matlab list...')
        for c = 1:nCs_S_missing
       % for mc = Cs_S_missing'
            mc = Cs_S_missing(c); % 2.15
            mcVs_S = CVs_S(mc,:);                               % gets missing cell vertex list
            mcVs_S = mcVs_S(mcVs_S > 0);                        % removes 0s
            CVs_M2S_tf = ismember(CVs_M2S, mcVs_S);             % looks where each vertex is found in "CVs_M2S"
            [mc_M2S_nVs, mc_M2S_loc] = max(sum(CVs_M2S_tf,2));  % gives max number of vertices found and ON WHICH ROW (= Matlab cell#) in CVs_M2S
            if mc_M2S_nVs >= nVerticesMin
                Cs_MS_match(mc_M2S_loc,:) = [mc_M2S_loc mc];    % match is done if criterion satisfied
                disp(['Rescued Shuji cell # ' num2str(mc) ' matched to Matlab #' num2str(mc_M2S_loc) ' (' num2str(mc_M2S_nVs) ' vertices used)'])
                
                Cs_S_solved(c) = mc; % 2.15
            else
                disp(['Did not rescue cell # ' num2str(mc) ': only ' num2str(mc_M2S_nVs) ' vertices were found.'])
            end
        end
        % defines "Cs_S_missing_AR" (2.15)
        Cs_S_missing_AR = setdiff(Cs_S_missing, Cs_S_solved);
        
    else                        % added 2.3
        Cs_S_missing = [];
        Cs_S_missing_AR = []; % 2.15
        disp('All of Shuji cell numbers were direclty matched in Matlab cell numbers list!');
    end

    %---------------------------------------------------------------------------------------------------
    
    % Shuji cell numbers STILL NOT MATCHED in Matlab list: FINAL LIST (mod 2.15)
    %---------------------------------------------------------------------------------------------------
    if ~isempty(Cs_S_missing)
        if ~isempty(Cs_S_missing_AR)  
            nCs_S_missing_AR = length(Cs_S_missing_AR);
            if nCs_S_missing_AR > 0
                disp(['WARNING: ' num2str(nCs_S_missing_AR) ' (# ' num2str(Cs_S_missing_AR') ') of Shuji cells were still not matched in Matlab!!'])
            end
        else
            disp('All of Shuji cell numbers were matched after a rescue round in Matlab cell numbers list!');
        end
    end
    %---------------------------------------------------------------------------------------------------
    
    % Shuji cell numbers STILL NOT MATCHED in Matlab list: FINAL LIST
    %---------------------------------------------------------------------------------------------------
%     if ~isempty(Cs_S_missing)                                      % 2.3
%         nCs_M_in_S_AR = sum(Cs_MS_match(:,2) > 0);                 % updates number of Matlab cells found in Shuji's list
%         nCs_S_missing_AR = nCs_S - nCs_M_in_S_AR;                  % AR= After Rescue
%         if nCs_S_missing_AR > 0
%             Cs_S_missing_AR = setdiff(CRNs_S,Cs_MS_match(:,2));    % updates list of unmatched Shuji cell numbers
%             disp(['WARNING: ' num2str(nCs_S_missing_AR) ' (# ' num2str(Cs_S_missing_AR') ') of Shuji cells were still not matched in Matlab!!'])
%         else
%             Cs_S_missing_AR = [];
%             disp('All of Shuji cell numbers were matched after a rescue round in Matlab cell numbers list!');
%         end
%     else % 2.14
%         Cs_S_missing_AR = [];
%         disp('All of Shuji cell numbers were matched after a rescue round in Matlab cell numbers list!');
%     end
    %---------------------------------------------------------------------------------------------------
    
    % Building matrix of inverted correspondence for CELLS : Shuji-Matlab "Cs_SM_match" (2.4)
    %------------------------------------------------------------------------------------------------------------------
    [~, CRNs_S_loc] = ismember(CRNs_S, Cs_MS_match(:,2));
    Cs_SM_match = [CRNs_S CRNs_S_loc];
    % NB: Matlab cell numbers being listed in order from 1 to nCs_M, the index at which Shuji cells were found in
    % column 2 of "Cs_MS_match", hence also corresponds to Matlab cell number.
    % NB:   left column: Shuji cell numbers
    %       right column: Matlab cell numbers when matched, 0 otherwise
    %------------------------------------------------------------------------------------------------------------------
    
    
    %% Matching edges (2.4) %%
    
    fprintf('\n')
    disp('Matching edge numbers by comparing their Matlab & Shuji pair of vertex numbers...');
    
    % Matlab:
    %-----------------------------------------------------------------------------------------------------------------
    Es_M = SIDES.Numbers;       % side numbers. WITH C++SIA, NO LONGER CORRESPONDS TO SIDE ROWS!! (2.15)
    EVs_M = SIDES.Vertices;     % pairs of edge vertex numbers
    EVs_M = sort(EVs_M,2);      % puts smaller Matlab numbers in 1st column
    nEs_M = length(Es_M);       % number of edges
    %-----------------------------------------------------------------------------------------------------------------
    
    % Shuji:
    %-----------------------------------------------------------------------------------------------------------------
    EV1s_S = Es.EJ1s;
    EV2s_S = Es.EJ2s;
    EVs_S = [EV1s_S EV2s_S];
    nEs_S = length(EV1s_S);
    Es_S = (1:nEs_S)';
    %-----------------------------------------------------------------------------------------------------------------
    
    % translating Shuji vertex numbers into Matlab numbers:
    EV1s_S2M = Vs_SM_match(EV1s_S,2);
    EV2s_S2M = Vs_SM_match(EV2s_S,2);
    EVs_S2M = [EV1s_S2M EV2s_S2M];
    EVs_S2M = sort(EVs_S2M,2);              % puts smaller Matlab numbers in 1st column
    
    
    % Building matrix of correspondence for EDGES: Matlab-Shuji "Es_MS_match" (2.4)
    % NB: in Matlab edge vertex pair list, looks for same vertex pair of Shuji's edge vertex pair list
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [~, EVs_M_loc] = ismember(EVs_M, EVs_S2M,'rows');
    Es_MS_match = [Es_M EVs_M_loc];
    % NB: Shuji edge numbers being listed in order from 1 to nEs_S, the row at which Matlab pair of vertices was found in
    % EVs_S2M hence also corresponds to Shuji edge number.
    % NB:   left column: all Matlab edge numbers
    %       right column: Shuji edge numbers when matched, 0 otherwise
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Shuji edges NOT FOUND in Matlab list:
    %------------------------------------------------------------------------------------------------------------------
    Es_S_missing = setdiff(Es_S, EVs_M_loc);    % 2.8
    nEs_S_missing = length(Es_S_missing);       % 2.8
    % OLD:
    % nEs_M_in_S = sum(Es_MS_match(:,2) > 0); % number of Matlab edges that found a match with a Shuji edge
    % nEs_S_missing = nEs_S - nEs_M_in_S;     % number of Shuji edges not matched with a Matlab vertex
    % NB: ALL UNMATCHED SHUJI VERTICES SHOULD BE "Ext" VERTICES IF SEGMENTED IMAGES WENT THROUGH "Four_Pixel_Blocks_Filter" BEFORE BEING PROCESSED BY GETVERTEX!!
    if nEs_S_missing > 0
        %Es_S_missing = setdiff(Es_S, EVs_M_loc);
        disp(['WARNING: ' num2str(nEs_S_missing) ' (# ' num2str(Es_S_missing') ') of Shuji edges were not matched in Matlab!!'])
        disp('Corresponding pair of Shuji vertex #:')
        disp(num2str(EVs_S(Es_S_missing,:)));
    else
        Es_S_missing = [];
        disp('All of Shuji edges were matched in Matlab edge list!');
    end
    %------------------------------------------------------------------------------------------------------------------
    
    % Building matrix of inverted correspondence for EDGES: Shuji-Matlab "Es_SM_match" (2.4)
    %------------------------------------------------------------------------------------------------------------------
    % mod 2.15: in C++SIA, Matlab edge numbers NO LONGER corresponds to their rows!!
    [Es_S_TF, Es_S_loc] = ismember(Es_S, Es_MS_match(:,2));
    Es_S_locFound = Es_S_loc(Es_S_TF);
    
    Es_SM_match = [Es_S false(nEs_S,1)];                    % initialization
    Es_SM_match(Es_S_TF,2) = Es_MS_match(Es_S_locFound,1);  % replacing 0s with MATLAB edge numbers
    
    % OLD
%     [~, Es_S_loc] = ismember(Es_S, Es_MS_match(:,2));
%     Es_SM_match = [Es_S Es_S_loc];
    % NB:   left column: all Shuji edge numbers
    %       right column: Matlab edge numbers when matched, 0 otherwise
    %------------------------------------------------------------------------------------------------------------------
    
    
    %% Display %%
    
    % display of segmented image and chord image overlayed, scattering of unmatched vertices
    
    if displayMSM
        
        disp(' ');
        disp('Making image for checking Matlab-Shuji match...');

        imageSegPath = [pathFolderRES filesep filename num2str(fn,digitsFormat) '.png']; % 2.15
%         imageSegPath = [pathFolderRaw filesep 'Output_results' filesep 'Unionseg_' rootFilename num2str(fn,digitsFormat) '.png']; % 2.7
        imageSeg = imread(imageSegPath);
        
        % extracting edge data
        ExtractData(Es,'');
        nEs = length(EX1s);
        es = (1:nEs)';              % includes "Ext" edges
        EX1s = EX1s + 1; EX2s = EX2s + 1;
        EY1s = -EY1s + 1; EY2s = -EY2s + 1;
        
        % image display (mod 2.15);
        h1 = figure;
        imshow(imageSeg,[],'border','tight');
        set(h1,'Position', positionFullScreen);
%         figure('PaperPositionMode','auto'); % display not as good with these parameters
%         imshow(imageSeg,'Border','tight')
        hold on
        
        % Display of edges:
        line([EX1s(es)';EX2s(es)'],[EY1s(es)';EY2s(es)'],'linewidth',edgeWidthT,'color','g');
        
        % Overdrawing UNMATCHED edges in thicker and in red (2.4,2.8):
        line([EX1s(Es_S_missing)';EX2s(Es_S_missing)'],[EY1s(Es_S_missing)';EY2s(Es_S_missing)'],'linewidth',edgeWidthT*2,'color','r'); % 2.8
        
        % Displays unmatched Shuji vertices:
        scatter(VXYs_S(Vs_S_missing,1), VXYs_S(Vs_S_missing,2),circleSize,'MarkerEdgeColor','r');
        
        
        % Plots ALL Matlab numbers at Matlab CoMs in black:
        %--------------------------------------------------------------------------------------------------------------
        if size(highlightMRNs,2) > size(highlightMRNs,1)
            highlightMRNs = highlightMRNs'; % makes it a column vector: MANDATORY (2.8)
        end
        CCoMs_M = (CELLS.XYs)/scale1D;       % in pixels
        rCRNS_M = setdiff(CRNs_M,highlightMRNs); % "r" stands for regular (2.8)
        rCXs_M = CCoMs_M(rCRNS_M,1);
        rCYs_M = CCoMs_M(rCRNS_M,2);
        rCRNs_Mstr = num2str(rCRNS_M);
        rCRNs_Mstr = cellstr(rCRNs_Mstr);
        text(rCXs_M,rCYs_M,rCRNs_Mstr,'VerticalAlignment','top','HorizontalAlignment','center','color','k','FontSize',fontSizeCellNumbers);
        % Highlighted cell numbers (2.8)
        hCXs_M = CCoMs_M(highlightMRNs,1);
        hCYs_M = CCoMs_M(highlightMRNs,2);
        hCRNs_Mstr = num2str(highlightMRNs);
        hCRNs_Mstr = cellstr(hCRNs_Mstr);
        text(hCXs_M,hCYs_M,hCRNs_Mstr,'VerticalAlignment','top','HorizontalAlignment','center','color','m','FontSize',fontSizeCellNumbers*2,'Fontweight','bold');
        %--------------------------------------------------------------------------------------------------------------
        
        
        % Plots ALL Shuji numbers translated into Matlab at Shuji approximate CoMs in blue (direct match),
        % green (match after rescue), red (no match):
        %--------------------------------------------------------------------------------------------------------------
        % Estimate Shuji cells CoMs from their vertex positions:
        disp('Estimating Shuji cell CoMs from vertex positions...')
        CXs_S = NaN(nCs_S,1);
        CYs_S = NaN(nCs_S,1);
        for c = 1:nCs_S
            cellVs = RemoveNaNs(CVs_S_nan(c,:)); % list of cell c vertices
            cellVXs = VXYs_S(cellVs,1);
            cellVYs = VXYs_S(cellVs,2);
            CXs_S(c) = mean(cellVXs);
            CYs_S(c) = mean(cellVYs);
        end
        
        % Splitting Shuji cell numbers into 3 categories:
        if size(highlightSRNs,2) > size(highlightSRNs,1)
            highlightSRNs = highlightSRNs'; % makes it a column vector: MANDATORY (2.8)
        end
        CRNs_S_matched_BR = setdiff(Cs_MS_match(:,2),unique([0;Cs_S_missing;Cs_S_missing_AR])); % Shuji numbers that were matched BEFORE RESCUE
        CRNs_S_matched_BR = setdiff(CRNs_S_matched_BR, highlightSRNs);                         % highlight overrides regular display (2.8)
        CRNs_S_matched_AR = setdiff(Cs_S_missing, Cs_S_missing_AR);                             % Shuji numbers that were matched AFTER RESCUE
        CRNs_S_matched_AR = setdiff(CRNs_S_matched_AR, highlightSRNs);                         % highlight overrides "after-rescue" display (2.8)
        CRNs_S_unmatched = sort(Cs_S_missing_AR);                                               % Shuji numbers that were NOT MATCHED
        CRNs_S_highlighted = setdiff(highlightSRNs,CRNs_S_unmatched);                          % BUT unmatching overrides highlight (2.8)
        
        CRNs_S_plot = {'CRNs_S_matched_BR' ; 'CRNs_S_matched_AR' ; 'CRNs_S_highlighted'; 'CRNs_S_unmatched' };  % 2.8
        CRNs_S_colors = {'b' ; 'g' ; 'm' ; 'r' };                                                               % 2.8
        CRNs_S_fw = {'normal'; 'bold' ; 'bold'; 'bold'};                                                        % 2.8
        CRNs_S_fs = [fontSizeCellNumbers ; 2*fontSizeCellNumbers ; 2*fontSizeCellNumbers; 2*fontSizeCellNumbers];                       % 2.8
        
        for np = 1:4
            eval(['these_CRNs_S = ' CRNs_S_plot{np} ';']);
            CXs_S_matched = CXs_S(these_CRNs_S);
            CYs_S_matched = CYs_S(these_CRNs_S );
            if np < 4
                [~, these_CRNs_S_loc] = ismember(these_CRNs_S, Cs_MS_match(:,2));
                CRNs_S2M = Cs_MS_match(these_CRNs_S_loc,1);
                CRNs_S2Mstr = num2str(CRNs_S2M);
                CRNs_S2Mstr = cellstr(CRNs_S2Mstr);
            else % if there are unmatched Shuji numbers, they will be found in "Cs_MS_match(:,2)" as 0s
                CRNs_S2M = CRNs_S_unmatched;        % in that case, directly putting the unmatched SHUJI numbers in "CRNs_S2M"
                CRNs_S2Mstr = num2str(CRNs_S2M);
                % adding "S_" in front of Shuji numbers to notify it is NOT a Matlab number that will be displayed:
                n_unmatched = length(CRNs_S_unmatched);
                CRNs_S2Mstr = [repmat('S.',n_unmatched,1) CRNs_S2Mstr];  %#ok<AGROW>
                CRNs_S2Mstr = cellstr(CRNs_S2Mstr);
            end
            % displays matching Matlab numbers AT estimated Shuji CoM
            text(CXs_S_matched, CYs_S_matched, CRNs_S2Mstr,'VerticalAlignment','bottom','HorizontalAlignment','center',...
                'color',CRNs_S_colors{np},'FontSize',CRNs_S_fs(np), 'FontWeight',CRNs_S_fw{np});
        end
        %--------------------------------------------------------------------------------------------------------------
        
        filenameOut = ['MSM_' rootFilename num2str(fn,digitsFormat) '.' imageFormatOutput]; % 2.9
        disp(['Saving image ' filenameOut '...']);
        filenameOutFull = [MSMframeFolder filesep filenameOut];
        
        print(printFormat, printResolution, filenameOutFull); % 2.9
        close
    end
    
    
    %% Saving correspondence matrices %%
    
    disp(' ');
    fprintf('Saving results...');
    save(MSMbackup_fn, 'Vs_MS_match', 'Vs_SM_match','Cs_MS_match','Cs_SM_match','Es_MS_match','Es_SM_match'); % 2.7
    fprintf('Done.\n')
    toc
    
else
    disp(['Warning: MSM backup "' MSMbackupFilname '" was found => skipping this frame!'])
end
disp('---------------------------------------------------------------------------------');

%% History %%

% Possible improvements:
%------------------------------------------------------------------------------------------------------------------
% - vertex rescue based on cell identity that should be done after having determined "Cs_MS/SM_match" ?
% - edge rescue based on cell identity ? caution though because unmatched edges involve a wrong vertex that belong
% to the neighboring cell: not sure this can work
%------------------------------------------------------------------------------------------------------------------
% NB: as of v2.4, unmatched vertices and edges are rare and should only involve external ("Ext") ones

% 02/05/2018: 2.15
% - changes to adapt to new C++SIA: now vertex and side numbers NO LONGER
% CORRESPOND TO THEIR ROW NUMBERS!!
% - using "positionFullScreen" to display figure bigger on screen.
% - fixed the update of solved cell Shuji's numbers after recovery
% - removed several commented parts

% 27/02/2018: 2.14
% - update to match with new variables and function names
% - does NOT support the loading of older STPE backups
% - display of MSM images also works

% 12/10/2017: 2.13
% - do NOT recalculates backups when they already exist

% 10/10/2017: 2.12
% - minor adjustments to match new names of SIA backups

% 15/02/2017
% - using "filename_fn" rather than "filename" that used to overwrite the one from AIA_info

% 15/09/2016: 2.11
% - adjusments to support the loading of new STPE backups from STPE v3.0+ and older ones from STPE 2.11+ (BUT NOT before)

% 10/09/2015: 2.10
% - now directly looking for existence of "scale_1D" in FRAME to detect old backups (instead of "image_size")

% 28/05/2015: 2.9
% - changed many parameter names to match AIA 6.0

% 16/10/2014: 2.8
% - decreased thickness of unmatched edges from 3x to 2x regular thickness
% - possibility to enter a list of Matlab and Shuji cell numbers to highlight in magenta
% - solved mismatch between the displayed and actual number of umatched edges

% 08/10/2014: 2.7: adjustments for integration into AIA workflow
% - creation of specific MSM folder and subfolders for Backups and Frames
% - changed naming of figures and backup files ('MSM_animal_frame.mat/png")
% - support of old STPE backups (STPE 2.10-)

% 23/07/2014: 2.6
% - use of filesep for mac compatibility

% 06/03/2014: 2.5
% - fixed bug to display in red an umatched cell: now displaying "S.XXX" on the map, XXX being this cell Shuji number

% 05/03/2014: 2.4 WORKS
% - implemented edge match based on vertex numbers, obviously using Vs_MS/SM_match
% - made reverse match for vertices, cells and edges: saves "Shuji-Matlab" matrices in addition to  "Matlab-Shuji" matrices
% - display of unmatched edges in thick red
% - removed commented part implementing vertex rescue that was based on tolerance in the difference of XY
% coordinates (see below)

% 04/03/2014: 2.3 WORKS
%------------------------------------------------------------------------------------------------------------------
% NB: the origin of the issue mentionned below (unmatched vertices) was due to the fact that getVertex was modifying the segmented image
% before processing it using "sunnyremover", "Four_Pixel_Vertex_Removal". Hence the difference in vertex
% coordinates: some core vertices were just NOT the same.
% Now, the segmented image is no longer changed in getVertex: before it should had gone through "Four_Pixel_Block_Filter"
% that now removes ALL of these 4pixels blocks!!
%------------------------------------------------------------------------------------------------------------------
% - removed rescue round for vertices (see above)
% - finalized the cell identity check (when parameter "check_MS_match" = 1) and the associated image "..._MS_match.png"
% - check for existence of SIA and STP backup files before pursuing: files with missing backups are skipped
% - fixed bug where "Cs_S_missing" was not set to [] when all cells were matched right away
% - improved messages displayed in command window

% 19/02/2014: 2.2
% - implemented a rescue for unmatched vertices but found out that they were never found because eligible vertices
% have always been already matched!

% 18/02/2014: 2.1
% - finalized Matlab-Shuji matching of vertex AND cell numbers
% - now finds a match for nearly every vertex and cell number listed by Shuji (not leaving out "Ext" cells)
% - drastically improved speed (BIGwt2 #9 used to take 183s = 3 min, now only takes 4.5s!!!)
% - removing parts commented in 2.0

% 17/02/2014: 2.0 restarting from scratch

% 17/02/2014: 1.2
% - simlifying and removing useless lines of code and loops
% - major overhaul to take advantage of the way data and backup are structured

% 17/02/2014: 1.1 (changed name to "Matlab_Shuji_Matcher") RUNS
% - adjustments to make it run from STP_Estimate_runner

% 19/09/2013: changed name to "Matlab_Shuji_match" from "correspondance_matlab_block"

% 15/03/2013: creation

