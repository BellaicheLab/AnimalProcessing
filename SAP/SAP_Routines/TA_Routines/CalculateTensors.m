function [TENSORS, ERROR] = CalculateTensors(LINKS, iioMatch, HLCat, Dt, renormM)
%
% [TENSORS, ERROR] = CalculateTensors(LINKS, iioMatch, HLCat, Dt, renormType, renormM)
%
% NB: Dt determines the unit of the tensor rates. If given in min or h, then EQ will be min^(-1) or h^(-1)
%
% As of 3.0, only uses renormalization corresponding to renormType = 2.
%
% BEFORE 3.0:
% renormType = 0; => no renomarlization by initial conserved texture Mc: all tensors have dimensions (NO LONGER USED)
% renormType = 1; => renormalized by Mc and symmetrization => dimensionless tensors (NO LONGER USED)
% renormType = 2; => same as 1 with additional subtraction of rotation term (PSI). USED FOR eLife ARTICLE
%
% Version 3.5
% Boris Guirao


%% Initialization %%

% Building cell array "MCatList":
%-----------------------------------------------------------------------------------------------------------------------
% Defining Main Categories:
MCatList =   { 'G' ; 'S' ; 'R' ; 'Ds' ; 'D' ; 'A' ; 'N' ; 'F' ; 'J' ; 'Jb' ; 'DM'}; % removed U from Main category list
% Additional MCatList for quantities built separately
addMCatList = {'' ; 'eig' };                                        % 3.4: set back "geo" quantities as default because = most accurate so far
% addMCatList = {'geo' ; '' };                                      % 3.3: removed "chol" calculation because yields very BAD results
% addMCatList = {'geo' ; 'chol'; '' };                              % 3.3 BETA
% addMCatList = {'geo' ; '' };                                      % 3.2 list
% addMCatList = { 'mid' ; 'geo' ; 'chol' };                         % 3.1 list
extMCatList = [MCatList ; addMCatList];                             % merging the two into an EXTENDED list (2.3.2)
                                                                    % NB: "PhiU" will be added to the "EQ" list at the very end.
nMCat = length(MCatList);                                           % number of MAIN contributions
nAddMCat = length(addMCatList);
nExtMCat = length(extMCatList);                                     % 2.3.2
% NB: 'Sum' removed in 2.0.5, added 'U' in 2.3.0 then removed 2.3.2, created addMCatList (2.3.2)
% NB: 'DM' and 'U' ALWAYS MUST OCCUPY THE 2nd TO LAST AND LAST POSITIONS, RESPECTIVELY!!
%-----------------------------------------------------------------------------------------------------------------------

% Intitializing main contributions Total_Q to 0:
%-----------------------------------------------------------------------------------------------------------------------
TENSORS = [];                                       % 2.0.4
for c = 1:nMCat
    eval([MCatList{c} '= zeros(1,4);']); % 2.3.1
end
MoC = zeros(1,4);                                   % Initializes texture of conserved links (2.0.4)
moC = zeros(1,4);       % DEBUG
MC = NaN(1,4);          % DEBUG
dMoldC = zeros(1,4);    % DEBUG
%-----------------------------------------------------------------------------------------------------------------------


%% Calculation of Tensor Contributions and RENORMALIZATIONS (2.0) %%

if ~isempty(LINKS)          % 2.0.2
    
    % Extracting data from LINKS (2.0.2,only grid 2.0.3):
    % Current frame
    all_ijMatch = LINKS.box_ijMatch;
    all_Lijs = LINKS.box_Lijs;                  % 2.0.4
    all_Wijs = LINKS.box_Wijs;
    all_HLC = LINKS.box_HLC;

    % Old frame
    all_iokoMatch = LINKS.box_rokoMatch;
    all_Liokos = LINKS.box_Lrokos;              % 2.0.4
    all_Wiokos = LINKS.box_Wrokos;
    all_HLCold = LINKS.box_HLCold;
    
    % Caculating "all_Mijs" and "all_Miokos" with "MakeMijs" (2.0.4):
    all_Mijs = MakeMijs(all_Lijs);
    all_Miokos = MakeMijs(all_Liokos);
    
    % Caculating "all_Uijs" and "all_mWijs" with "UijMaker" (2.3.0, 2.3.3, 2.3.5, 2.3.6):
    alpha = 1/2;
    [all_UIJs, all_MCIJs, all_mWijs]= MakeUijAlpha(all_Lijs, all_Wijs, all_HLC, all_ijMatch, all_Liokos, all_Wiokos, all_HLCold, all_iokoMatch, iioMatch, alpha);
    all_Uijs = all_UIJs.UijsAlpha;      % 2.3.6
    all_MCijsMid = all_MCIJs.MCijsAlpha;   % 2.3.6 
    % NB: suffix "mid" assumes "alpha = 1/2"
    % NB: in general, "all_Uijs" and "all_MCijs" values depend on alpha value.   
    
    % For Ugeo (2.3.6, mod 3.0)
%     all_U0ijs = all_UIJs.Uijs0;
%     all_U1ijs = all_UIJs.Uijs1;
    all_MCijs = all_MCIJs.MCijs0;
    all_NCijs = all_MCIJs.MCijs1;  
    all_mCijs = all_MCIJs.mCijs; % 3.0

    % REFormatting "all_Wijs/Wiokos" to match "all_Mijs/Miokos" dimensions (done BEFORE CROPPING as of 1.4):
    all_WijsRep = repmat(all_Wijs,1,4);
    all_WiokosRep = repmat(all_Wiokos,1,4);
    % same for U quantities (2.3.0):
    all_mWijsRep = repmat(all_mWijs,1,4);
    
    % Current:
    HL_TF = ~strcmp(all_HLC,'n/a');
    all_HLC_crop = all_HLC(HL_TF);
    all_WijsRep_crop = all_WijsRep(HL_TF,:);                                                                          % 1.4
    all_Mijs_crop = all_Mijs(HL_TF,:);
    % specific to Umid (2.3.0):
    all_Uijs_crop = all_Uijs(HL_TF,:);              % 2.3.0 
    all_mWijsRep_crop = all_mWijsRep(HL_TF,:);      % 2.3.0
    all_MCijsMid_crop = all_MCijsMid(HL_TF,:);            % 2.3.3
    % for Ugeo, Uchol (2.3.6, 3.0)
%     all_U0ijs_crop = all_U0ijs(HL_TF,:);
%     all_U1ijs_crop = all_U1ijs(HL_TF,:);
    all_MCijs_crop = all_MCijs(HL_TF,:);    
    all_NCijs_crop = all_NCijs(HL_TF,:);  
    all_mCijs_crop = all_mCijs(HL_TF,:);  % 3.0
    
    % Old:
    HLold_TF = ~strcmp(all_HLCold,'n/a');
    all_HLCold_crop = all_HLCold(HLold_TF);
    all_WiokosRep_crop = all_WiokosRep(HLold_TF,:);                                                                  % 1.4
    all_Miokos_crop = all_Miokos(HLold_TF,:);
    % NB: no OLD equivalent for U since a conserved link cannot become or have been 'n/a'
    
    % Checking existence of CONSERVED links before proceeding
    % NB: this is required so that inv(MoC) and EG are not ill defined
    consHL_TF = strcmp(all_HLC_crop, 'G'); % 2.0.4, G (2.1.0)
    
    if any(consHL_TF)
        
        % Calculating DM = M - Mold over ALL "non-n/a" links:
        M = 1/2*sum((all_WijsRep_crop.*all_Mijs_crop),1);
        Mo = 1/2*sum((all_WiokosRep_crop.*all_Miokos_crop),1);
        DM = M - Mo;                                                %#ok<*NASGU>
        
        % Further cropping "Uijs" and "mWijs" to "all_Uijs_crop" rows that are non-NaN (2.3.0):
        nanRows_TF = any(isnan(all_Uijs_crop),2);
        all_Uijs_crop = all_Uijs_crop(~nanRows_TF,:);
        all_mWijsRep_crop = all_mWijsRep_crop(~nanRows_TF,:);
        all_MCijsMid_crop = all_MCijsMid_crop(~nanRows_TF,:); % 2.3.3
        % Calculating Umid over ALL "non-n/a" links and "non-NaN rows" (2.3.0, com 3.2):
%         Umid = 2*1/2*sum((all_mWijsRep_crop.*all_Uijs_crop),1);    % additional factor 2 in the def so that grad(u) = Ubar = U/(2MoC)
%         MCmid = 1/2*sum((all_mWijsRep_crop.*all_MCijsMid_crop),1);     % 2.3.3
        
        % for Ugeo, Uchol (2.3.6)
%         all_U0ijs_crop = all_U0ijs_crop(~nanRows_TF,:);
%         all_U1ijs_crop = all_U1ijs_crop(~nanRows_TF,:);
        all_MCijs_crop = all_MCijs_crop(~nanRows_TF,:);
        all_NCijs_crop = all_NCijs_crop(~nanRows_TF,:);
        all_mCijs_crop = all_mCijs_crop(~nanRows_TF,:);
%         U0 = 2*1/2*sum((all_mWijsRep_crop.*all_U0ijs_crop),1);
%         U1 = 2*1/2*sum((all_mWijsRep_crop.*all_U1ijs_crop),1);
        MC = 1/2*sum((all_mWijsRep_crop.*all_MCijs_crop),1);    % INITIAL texture MC = sum(wc L*(L^t)) computed on CONSERVED links from MakeUijAlpha
        NC = 1/2*sum((all_mWijsRep_crop.*all_NCijs_crop),1);    % MIXED non-symmetric matrix NC = sum(wc L*(l^t)) on CONSERVED links computed from MakeUijAlpha
        mC = 1/2*sum((all_mWijsRep_crop.*all_mCijs_crop),1);    % FINAL texture mC = sum(wc l*(l^t)) computed on CONSERVED links from MakeUijAlpha (3.0)
        % NB: for conserved links, one should have Wc = wc and link weights doing 1->1/2 and 1/2->1 should all be
        % changed to 1/2->1/2, the other 1/2 being counted in R+ or R- in the balance
        
        %% CALCULATING TENSOR CONTRIBUTION FOR EACH CATEGORY %%
        
        nCat = length(HLCat);                          % gets number of ALL contributions listed in "HLCat" ('B'...) (mod 2.0.3)
        for c = 1:nCat-1                               % -1 because last category in HLCat is 'n/a'
            
            %%% Calculating Wijs*Mijs for OLD AND CURRENT:
            %---------------------------------------------------------------------------------------------------------------
            % Retrieving this category plotstyle from "HLC_plotstyle":
            cth_HL_cat = HLCat{c}; % 2.0.3
            
            % Finding lines corresponding to this category in "all_HLC_crop" and "all_HLCold_crop":
            HL_cat_TF = strcmp(all_HLC_crop, cth_HL_cat);
            HL_catOld_TF = strcmp(all_HLCold_crop, cth_HL_cat);
            
            % Get matrix of CURRENT contributions:
            Mijs_cat = all_Mijs_crop(HL_cat_TF,:);
            Wijs_rep_cat = all_WijsRep_crop(HL_cat_TF,:);                                                                  % 1.4
            Tcat_mat = Wijs_rep_cat.*Mijs_cat;
            
            % Get matrix of CURRENT contributions:
            Miokos_cat = all_Miokos_crop(HL_catOld_TF,:);
            Wiokos_rep_cat = all_WiokosRep_crop(HL_catOld_TF,:);                                                          % 1.4
            Tcat_matOld = Wiokos_rep_cat.*Miokos_cat;
            %---------------------------------------------------------------------------------------------------------------
            
            
            %%% CALCULATION FOR ALL DEFINED CONTRIBUTIONS (B,BR+,J+...):
            %---------------------------------------------------------------------------------------------------------------
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Tcat = 1/2*(sum(Tcat_mat,1) - sum(Tcat_matOld,1));
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %---------------------------------------------------------------------------------------------------------------
            
            
            %%% Merging ALL tensor contributions into MAIN contributions (1.1,2.0.2):
            %---------------------------------------------------------------------------------------------------------------
            % NB: G = MC-MoC => for consistency and balance, one needs to include BR+/- HL counted in G into MC (not defined) and MoC
            % definitions, adding the "old" HL to MoC and the "current" HL to MC, with the right coefficients.
            if strcmp(cth_HL_cat,'G')                                           % introduced G (2.1.0)
                G = G + Tcat;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                MoC = MoC + 1/2 * sum(Tcat_matOld,1);                          % MoC = Initial texture of CONSERVED LINKS (2.0.2)
                moC = moC + 1/2 * sum(Tcat_mat,1); % DEBUG
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif strcmp(cth_HL_cat,'G/R+')                                    % Weights: 1/2 -> 1 => in G: 1/2 -> 1/2 ; in R: 0 -> 1/2; introduced G/R+ (2.1.0)
                G_part = 1/2*(1/2*sum(Tcat_mat,1) - sum(Tcat_matOld,1));
                R_part = 1/2*(1/2*sum(Tcat_mat,1) -            0        );      % Note that T_cat = G_part + R_part;
                G = G + G_part;
                R = R + R_part;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                MoC = MoC + 1/2 * sum(Tcat_matOld,1);                         % updating MoC: global weight = 1/2 * 1/2(old weight in Tcat_matOld) = 1/4
                moC = moC + 1/4 * sum(Tcat_mat,1); % DEBUG
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif strcmp(cth_HL_cat,'G/R-')                                   % Weights: 1 -> 1/2 => in G: 1/2 -> 1/2 ; in R: 1/2 -> 0; introduced G/R- (2.1.0)
                G_part = 1/2*(sum(Tcat_mat,1) - 1/2*sum(Tcat_matOld,1));
                R_part = 1/2*(      0         - 1/2*sum(Tcat_matOld,1));      % Note that T_cat = G_part + R_part;
                G = G + G_part;
                R = R + R_part;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                MoC = MoC + 1/4 * sum(Tcat_matOld,1);                          % updating MoC: global weight = 1/4 * 1(old weight in Tcat_matOld) = 1/4
                moC = moC + 1/2 * sum(Tcat_mat,1); % DEBUG
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elseif strcmp(cth_HL_cat,'R+') || strcmp(cth_HL_cat,'R-')           % R = R+ + R-
                R = R + Tcat;
            elseif strcmp(cth_HL_cat,'Ds')                                      % D = Ds + Dns
                Ds = Tcat;                                                      
                D = D + Tcat;
            elseif strcmp(cth_HL_cat,'Dn') || strcmp(cth_HL_cat,'TD+') || strcmp(cth_HL_cat,'Dm') || strcmp(cth_HL_cat,'TD-')      
                D = D + Tcat;                                       % Dns = (Dn + TD+ + Dm + TD-)(Non Sister contribution)
            elseif strcmp(cth_HL_cat,'A+') || strcmp(cth_HL_cat,'A-') || strcmp(cth_HL_cat,'TA-') % introduced A-,TA- (2.1.0)
                A = A + Tcat;
            elseif strcmp(cth_HL_cat,'N+') || strcmp(cth_HL_cat,'N-') || strcmp(cth_HL_cat,'TN+') % introduced N+,N-,TN+ (2.1.0)
                N = N + Tcat;
            elseif strcmp(cth_HL_cat,'J+') || strcmp(cth_HL_cat,'J-')           % J = J+ + J-
                J = J + Tcat;
            elseif strcmp(cth_HL_cat,'F')
                F = F + Tcat;                   % F+ had been forgotten so far (shouldn't change anything) (2.3.1)
            elseif strcmp(cth_HL_cat,'Jb+') || strcmp(cth_HL_cat,'Jb-')         % Jb = Jb+ + Jb- (1.3)
                Jb = Jb + Tcat;
            end
            %---------------------------------------------------------------------------------------------------------------
        end
        
        
        % Putting MoC it in 2x2 format (2.0.2, moved 2.0.4)
        MoC = Vec2Mat(MoC);  
        moC = Vec2Mat(moC); % DEBUG
        % Determination or RCond to asses accuracy of inversion (2.0.5):
        RCond = rcond(MoC);                 % Matrix reciprocal condition number estimate
        ERROR.RCond = RCond;                % storage or RCond
        

        %% Applying RENORMALIZATIONs by MoC and nLinks or nCells (2.0) %%
          
        
        % Applying "renormM" (2.0.9):
        if strcmp(renormM,'nLinks')
            
            % Using number of LINKS for M renormalization:
            RC = CountHLCs(all_HLC);                       % REcategorizes each HLs into Cell categories
            RCo = CountHLCs(all_HLCold);
            
        elseif strcmp(renormM,'nCells')
            
            % Using number of CELLS for M renormalization:
            RC = HLC2RC(all_ijMatch, all_HLC);             % getting Region categories from HL categories
            RCo = HLC2RC(all_iokoMatch, all_HLCold);
            
        else
            disp('"TensorCalculator" ERROR: parameter "renormM" must either be "nLinks" or "nCells"!!')
            TENSORS = []; % default outputs
            ERROR = [];
        end
        nT = RC.nTot;
        nTo = RCo.nTot;
        Ccat_list = RC.Clist;    % gets list of contributions defined for cells. Clist = {'C';'D';'A';'J';'N';'F';'Jb'}
        
        % DEBUG: checks if nCo = nC
        nCo = RCo.nC;
        nC = RC.nC;
        if nCo ~= nC
            disp(['"TensorCalculator" WARNING: nCo = ' num2str(nCo) ' is different from nC = ' num2str(nC) '!']); % 2.0.8
        end
        % NB: differences should not occur as conserved link should be found both in current and old frames.
        %
        % OBSOLETE AS OF TA 2.0.13 and Jb new tagging:
        % However, when nP are cell numbers (renormM = 'nCells'),since Jb tagging ONLY overrides B,B/R+,B/R- in TA, is that a conserved cell is
        % surrounded by neighbors undergoing division, apoptosis, nucleation and have their HL tagged TD,TA,TN, respectively. Therefore,
        % when the cell is exiting the box, if all its HL are TD,TA,TN, namely none of them are Jb, and cell will appear as conserved!!
        % => required to override all HL of a cell exiting a box with Jb, as done for a cell exiting the frame with J!!
        
        % Special defintion for S:
        S = nTo/nT*M - Mo;         
        
        % Iteration on contributions other than G,S,DM,Sum
        for p = 3:nMCat-1                                      % starts @ R ends @ Jb;
            pMcat = MCatList{p};                               % gets letter of pth category in Mcat_list
            P = eval(pMcat);
            
            DnP = 0;                                            % default value that will be applied for R & Ds
            if ismember(pMcat,Ccat_list)
                nP = RC.(['n' pMcat]);
                nPo = RCo.(['n' pMcat]);
                DnP = nP - nPo;
                eval(['Dn' pMcat '= DnP;']);                    % creates DnP for each P (2.0.5)
            elseif strcmp(pMcat,'Ds')                           % special case for Ds that is kept RAW (2.1.1)
                P = - P;                            % NB: DnP = 0 for Ds
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            P = DnP/nT*M - P;                      
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            eval([ pMcat ' = P;']);                % Overwrites process P contribution
        end
        % NB:
        % Mcat_list = {'G';'S';'R';'Ds';'D';'A';'J';'N';'F';'Jb';'DM'};
        % Ccat_list = {'C';'R';'D';'A';'J';'N';'F';'Jb'}
        
        
        % Final renormalization by 1/2*MoC^(-1) (initial texture only including CONSERVED links) AND Symmetrization:
        for p = 1:nMCat
            pMcat = MCatList{p};                                           % gets letter of pth category in Mcat_list
            P = eval(pMcat);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            P = Vec2Mat(P);         % put in 2x2 matrix form
            P = P/MoC*1/2;          % renorm by right *inv(MoC)/2
            % Taking symmetric part
            EP = 1/2*(P + P');
            EP = Mat2Vec(EP);         % put it back in Vector format
            EP = EP/Dt;               % defining rate (2.0.3)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            eval(['E' pMcat ' = EP;']);
        end
        
        
        %% Defining Umid, Ugeo, Uchol and associated PSImid, PSIgeo, PSIchol (2.0, 3.0) %%
        
        % NB: M = Vec2Mat(V) will turn vector V = [Mxx Mxy Myx Myy] into 2x2 matrix M = [Mxx Mxy ; Myx Myy].
        
        %%% Quantities independant of mid,geo,chol renormalizations
        %-----------------------------------------------------------------------------------------------------------
        MC = Vec2Mat(MC);   % INITIAL conserved texture (from MakeUijAlpha, issue with 4vertex weights)
        NC = Vec2Mat(NC);
        mC = Vec2Mat(mC);   % FINAL conserved texture (from MakeUijAlpha, issue with 4vertex weights)
        
        
%         MC = MoC; % DEBUG
%         mC = moC; % DEBUG
        
%         dMC = mC - MC;
        %-----------------------------------------------------------------------------------------------------------
        
        
        %%% Umid: based on Lmid = (L+l)/2 (assumes Alpha = 1/2) com 3.2
        %-----------------------------------------------------------------------------------------------------------
%         Umid = Vec2Mat(Umid);
%         MCmid = Vec2Mat(MCmid);                       % 2.3.3
%         Umid = Umid/MCmid*1/2;                       % *inv(MC)/2 => U IS NOW THE **DISPLACMENT** GRADIENT TENSOR grad(u)!! ***USING MC*** (and not MoC) (2.3.3)
%         Fmid = eye(2) + Umid;                     % F IS THE **DEFORMATION** GRADIENT TENSOR
%         PSImid = Fmid*Commutator(MoC,Fmid')/MoC*1/2;     % PSI function to renormalize EG and ES in Renorm#2 (2.3.1)
%         
%         
%         mCmid = Fmid*MC*Fmid'; % 3.1
%         dMCmid = mCmid - MC;  
%         mCmid = Mat2Vec(mCmid);
%         dMCmid = Mat2Vec(dMCmid);
%         
%         
%         % Bulding symmetric and antisymmetric parts:
%         Emid = 1/2*(Fmid*Fmid' - eye(2));   % exact strain
% %       Emid = 1/2*(Umid + Umid');        % approximate strain
%         EPSImid = 1/2*(PSImid + PSImid');
%         Phimid = 1/2*(Umid - Umid');
%         
%         % putting back in vector (scalar for PhiU) format AND turning into rates:
%         Emid = Mat2Vec(Emid)/Dt;                
%         EPSImid = Mat2Vec(EPSImid)/Dt;          
%         Phimid = Phimid(2,1)/Dt;                % PhiU = w*sigma_2 = w [0 -1 ; 1 0] => PhiU(2,1) = w BUT PhiU(1,2) = -w!!!(2.3.4)
        %-----------------------------------------------------------------------------------------------------------
        
        
        %%% Ugeo: based on (F0*F1)^1/2 (mod 3.0)
        %-----------------------------------------------------------------------------------------------------------
        F0 = NC'/MC;        % NB: factors 1/2*(1/(1/2)) in NC and MC naturally cancel out
        F1 = mC/NC;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~(any(isnan(F1(:))) || any(isnan(F0(:))) || any(isinf(F1(:))) || any(isinf(F0(:))))
            FgeoRaw = (F1*F0)^(1/2);
        else
            FgeoRaw = NaN(2);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        Fgeo = real(FgeoRaw); % to remove the 0.000000i terms (3.0)
        
        Ugeo = Fgeo - eye(2);
        PSIgeo = Fgeo*Commutator(MoC,Fgeo')/MoC*1/2;     % PSI function to renormalize EG and ES in Renorm#2 (2.3.1)
        
%         comF0F1 = TensorNorm(Commutator(F0,F1));
%         deltaEq47 = TensorNorm( F1 - TensorNorm(F1)/TensorNorm(F0) * F0 );
%         normUgeo = TensorNorm(Fgeo - eye(2)); % small deformation => F = Id almost always => Ugeo actual deformation
        
%         mCgeo = Fgeo*MC*Fgeo'; %#ok<*NASGU> % 3.0
%         dMCgeo = mCgeo - MC;
%         mCgeo = Mat2Vec(mCgeo);
%         dMCgeo = Mat2Vec(dMCgeo);
        
        % Bulding symmetric and antisymmetric parts:
        Egeo = 1/2*(Fgeo*Fgeo' - eye(2));   % EXACT strain
        %Egeo = 1/2*(Ugeo + Ugeo');         % approximate strain
        EPSIgeo = 1/2*(PSIgeo + PSIgeo');
        Phigeo = 1/2*(Ugeo - Ugeo');
        
        % putting back in vector (scalar for PhiU) format AND turning into rates:
        Egeo = Mat2Vec(Egeo)/Dt;      
        EPSIgeo = Mat2Vec(EPSIgeo)/Dt;          
        Phigeo = Phigeo(2,1)/Dt;    
        %-----------------------------------------------------------------------------------------------------------
        
        
        
        %%% Uchol: based on Cholesky factorization of M (3.0, com 3.3)
        %-----------------------------------------------------------------------------------------------------------
%         try
%             LC = chol(MC,'lower');     % lower triangular => MC = LC*LC'
%             lC = chol(mC,'lower');     % lower triangular => mC = lC*lC'
%             Fchol = lC/LC;              % lC = F*LC
%         catch err
%             errMC = TensorNorm(MC-MC');
%             errmC = TensorNorm(mC-mC');
%             disp(['Error on texture symmetry:  errMC = ' num2str(errMC)  '   ;   errmC = '  num2str(errmC)]);
%             Fchol = NaN(2);
%         end
%         Uchol = Fchol - eye(2);
%         PSIchol = Fchol*Commutator(MoC,Fchol')/MoC*1/2;
% %         PSIchol = Fchol*Commutator(MC,Fchol')/MC*1/2; % TESTS 3.3
%         
% %         mCchol = Fchol*MC*Fchol'; % 3.1
% %         dMCchol = mCchol - MC;
% %         mCchol = Mat2Vec(mCchol);
% %         dMCchol = Mat2Vec(dMCchol);
%         
%         % Bulding symmetric and antisymmetric parts:
%         Echol = 1/2*(Fchol*Fchol' - eye(2));   % EXACT strain
%         %Echol = 1/2*(Uchol + Uchol');         % approximate strain
%         EPSIchol = 1/2*(PSIchol + PSIchol');
%         Phichol = 1/2*(Uchol - Uchol');
%         
%         % putting back in vector (scalar for PhiU) format AND turning into rates:
%         Echol = Mat2Vec(Echol)/Dt;                  %#ok<NASGU>
%         EPSIchol = Mat2Vec(EPSIchol)/Dt;            %#ok<NASGU>
%         Phichol = Phichol(2,1)/Dt;                  %#ok<NASGU>
        %-----------------------------------------------------------------------------------------------------------
        
        
        %%% Ueig: based on eigenvalue decomposition of MC and mC (3.3)
        %-----------------------------------------------------------------------------------------------------------    
        [RC, DC] = eig(MC);    % RC^(-1) = RC' when MC symmetric
        [rC, dC] = eig(mC);    % rC^(-1) = rC' when mC symmetric
        % NB: use of Matlab "eig" rather then MatlabCentral "myEIG" because the latter introduces some 
        
        % Checking eigenvectors have been normalized (seems to always be the case)
        dRC = RC*RC' - eye(2);
        drC = rC*rC' - eye(2);
        tol = 1e-12;
        if TensorNorm(dRC)> tol || TensorNorm(drC) > tol
            fprintf('\n\nWARNING TensorCalculator: some eigenvectors were not normalized to one!\n');
        end
        
        % Checking neither Inf nor NaN in dC/DC (3.5)
        dCoverDC = dC/DC;
        NaNorInf = any(isnan(dCoverDC(:))) || any(isinf(dCoverDC(:)));
        if ~NaNorInf
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            Feig = rC*(dC/DC)^(1/2)*RC';         % Def Gradient tensor F: see notebook # 9 day 17/02/2016
            Reig = rC*RC';                       % Rotation matrix from polar decomposition F = R*P = Q*R, P,Q are right and left stretches
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        else
            Feig = NaN(2);
            Reig = NaN(2);
        end

        Ueig = Feig - eye(2);
        PSIeig = Feig*Commutator(MoC,Feig')/MoC*1/2;

        % Bulding symmetric and antisymmetric parts:
        Eeig = 1/2*(Feig*Feig' - eye(2));   % EXACT strain
        %Eeig = 1/2*(Ueig + Ueig');         % approximate strain
        EPSIeig = 1/2*(PSIeig + PSIeig');
%         Zeig = Reig(1,1) + 1i*Reig(2,1);     % cos(Phieig) + i*sin(Phieig)
%         Phieig = angle(Zeig);               % EXACT angle
        Phieig = 1/2*(Ueig - Ueig');        % approximate angle
        Phieig = Phieig(2,1);
        
        % putting back in vector (scalar for PhiU) format AND turning into rates:
        Eeig = Mat2Vec(Eeig)/Dt;
        EPSIeig = Mat2Vec(EPSIeig)/Dt; 
        Phieig = Phieig/Dt;   
        %-----------------------------------------------------------------------------------------------------------
        
        
        
        %%% Correcting EG and ES for rotation (3.1)
        %---------------------------------------------------------------------------------------------------------- 
        EGgeo = EG - EPSIgeo; %#ok<*NODEF>
        ESgeo = ES - EPSIgeo;
        
%         EGchol = EG - EPSIchol; % com 3.3
%         ESchol = ES - EPSIchol;
        
        EGeig = EG - EPSIeig; % 3.3
        ESeig = ES - EPSIeig;
        
        % Com 3.2
%         for c = 1:nAddMCat
%             eval(['EG' addMCatList{c} ' = EG - EPSI' addMCatList{c} ';']); % EGgeo = EG - EPSIgeo, EGchol = EG -...
%             eval(['ES' addMCatList{c} ' = ES - EPSI' addMCatList{c} ';']); % EGgeo = EG - EPSIgeo, EGchol = ES -...
%         end
        % NB: At this stage, EG and ES are therefore NOT corrected for rotation, unlike (EGgeo, ESgeo) and (EGchol, ESchol)
        
        % Defines default values as "geo" values (3.4) (instead of "eig" in 3.3):
        E = Egeo;
        EG = EGgeo;
        ES = ESgeo;
        EPSI = EPSIgeo;
        Phi = Phigeo;
        % NB: TO BE COMMENTED WHEN COMPARAISON BETWEEN RAW, MID, GEO AND CHOL QUANTITIES IS NEEDED
        %-----------------------------------------------------------------------------------------------------------
        
        
        %% Checking Balances (2.0.5) %%
        
        % Over cell numbers:
        %---------------------------------------------------------------------------------------------------------------
        DnP_Sum = DnD + DnR + DnA + DnN + DnF + DnJ + DnJb; % added DnR (2.0.8)
        % NB: DnR = 0 for "nCells" renorm
        DnT = nT - nTo;
        errorDnP = abs(DnP_Sum - DnT);
        ERROR.errorDnP = errorDnP;
        % Ccat_list = {'C';'D';'A';'J';'N';'F';'Jb'}
        %---------------------------------------------------------------------------------------------------------------
        
        % Over Processes:
        %---------------------------------------------------------------------------------------------------------------
        EP_Sum = ES + ER + ED + EA + EN + EF + EJ + EJb; % 2.3.1
        deltaEP = EP_Sum - EG;
        deltaEP = Vec2Mat(deltaEP);
        ERROR.errorP = TensorNorm(deltaEP);    % taking sqrt and removed threshold (2.0.6)
        % NB: Total_S is calculated totally differently than the other contributions, straight from Mf and Mi, like DM = Mf-Mi was.
        % NB: at this point in the code, Total_Q = EQ, strain-like quantities
        % NB: Total_Jb is always defined and remains zeros(1,4) if not using grid
        %---------------------------------------------------------------------------------------------------------------
        
        dMoldC = (MC-MoC)/MoC;          % DEBUG
        dMoldC = Mat2Vec(dMoldC)/Dt;    % DEBUG
        
    else
        for c = 1:nExtMCat                              % 2.3.2
            eval(['E' extMCatList{c} '= NaN(1,4);']);   % Fills up tensors with NaN when no CONSERVED link was found (2.0.4), 2.3.1, extMCatList (2.3.2)
        end
        
        % 3.0, 3.1, com 3.2
        for c = 1:nAddMCat
            eval(['EG' addMCatList{c} '= NaN(1,4);']);
            eval(['ES' addMCatList{c} '= NaN(1,4);']);
            eval(['EPSI' addMCatList{c} '= NaN(1,4);']);
            eval(['Phi' addMCatList{c} '= NaN;']);
            
%             eval(['mC' addMCatList{c} '= NaN(1,4);']);
%             eval(['dMC' addMCatList{c} '= NaN(1,4);']);
        end
        
        % 3.0, com 3.2
%         FgeoRaw = NaN(1,4);
%         F0 = NaN(1,4);
%         F1 = NaN(1,4);
%         comF0F1 = NaN;
%         deltaEq47 = NaN;
%         normUgeo = NaN; % 3.1
%         mC = NaN(1,4);
%         dMC = NaN(1,4);
        
        ERROR.RCond = 0;        % 2.0.5
        ERROR.errorDnP = NaN;   % 2.0.5
        ERROR.errorP = NaN;     % 2.0.5
        
    end
    
else
    for c = 1:nExtMCat                              % 2.3.2
        eval(['E' extMCatList{c} '= NaN(1,4);']);   % Fills up tensors with NaN when no link was found (2.0.4), 2.3.1, extMCatList (2.3.2)
    end
    
    % 3.0, 3.1, com 3.2
    for c= 1:nAddMCat
        eval(['EG' addMCatList{c} '= NaN(1,4);']);
        eval(['ES' addMCatList{c} '= NaN(1,4);']);
        eval(['EPSI' addMCatList{c} '= NaN(1,4);']);
        eval(['Phi' addMCatList{c} '= NaN;']);
        
%         eval(['mC' addMCatList{c} '= NaN(1,4);']);
%         eval(['dMC' addMCatList{c} '= NaN(1,4);']);        
    end
    
    % 3.0, com 3.2
%     FgeoRaw = NaN(1,4);
%     F0 = NaN(1,4);
%     F1 = NaN(1,4);
%     comF0F1 = NaN;
%     deltaEq47 = NaN;
%     normUgeo = NaN; % 3.1
%     mC = NaN(1,4);
%     dMC = NaN(1,4);
    
    ERROR.RCond = 0;            % 2.0.5
    ERROR.errorDnP = NaN;       % 2.0.5
    ERROR.errorP = NaN;         % 2.0.5
end


%%  Storage in TENSORS %%


% Storage of EP quantities (mod 2.3.2):
for c = 1:nExtMCat                                 % 2.3.2
    mcat = extMCatList{c};                            % get this contribution string ('B'...)("mcat" = main category); extMCatList (2.3.2)
    Emcat = eval(['E' mcat]);
    
    if any(isnan(Emcat)) || any(isinf(Emcat))
        Emcat = NaN(1,4);                        % overwrite tensor with NaN(1,4) when either NaN or Inf are found (2.0.4)
    end
    
    %%% Storage of Cartesian Coordinates in TENSORS (mod 2.3.0)
    TENSORS.(['E' mcat]) = Emcat;             % adds E to remind that quantities are (rates of) Strain-like ones (applies to all renormType 2.0.3)
end
% NB: EG and ES have just been stored in TENSORS but will be restored right below


% Storage of Phi et PSI quantities (3.0, com 3.2)
for c = 1:nAddMCat                                 % 2.3.2
    mcat = addMCatList{c};                          % get this contribution string ('B'...)("mcat" = main category); extMCatList (2.3.2)
    EGmcat = eval(['EG' mcat]);                     % 3.1
    ESmcat = eval(['ES' mcat]);                     % 3.1
    EPSImcat = eval(['EPSI' mcat]);
    Phimcat = eval(['Phi' mcat]);
    
%     mCmcat = eval(['mC' mcat]);                     % 3.1
%     dMCmcat = eval(['dMC' mcat]);                   % 3.1


    if any(isnan(EGmcat)) || any(isinf(EGmcat))
        EGmcat = NaN(1,4);                        % overwrite tensor with NaN(1,4) when either NaN or Inf are found
    end 
    
    if any(isnan(ESmcat)) || any(isinf(ESmcat))
        ESmcat = NaN(1,4);                        % overwrite tensor with NaN(1,4) when either NaN or Inf are found
    end
    
    if any(isnan(EPSImcat)) || any(isinf(EPSImcat))
        EPSImcat = NaN(1,4);
    end
       
    if isnan(Phimcat) || isinf(Phimcat)
        Phimcat = NaN;                        
    end
    
%     if any(isnan(mCmcat)) || any(isinf(mCmcat))
%         mCmcat = NaN(1,4);                        % overwrite tensor with NaN(1,4) when either NaN or Inf are found
%     end
%     
%     if any(isnan(dMCmcat)) || any(isinf(dMCmcat))
%         dMCmcat = NaN(1,4);                        % overwrite tensor with NaN(1,4) when either NaN or Inf are found
%     end
%     

    
    %%% Storage of Cartesian Coordinates in TENSORS (mod 2.3.0,, com 3.2) 
    TENSORS.(['EG' mcat]) = EGmcat; % 3.1
    TENSORS.(['ES' mcat]) = ESmcat; % 3.1
    TENSORS.(['EPSI' mcat]) = EPSImcat;
    TENSORS.(['Phi' mcat]) = Phimcat;
    
%     TENSORS.(['mC' mcat]) = mCmcat; % 3.1
%     TENSORS.(['dMC' mcat]) = dMCmcat; % 3.1
end


%%% Additional Storage (3.0,, com 3.2)
% TENSORS.FgeoRaw = Mat2Vec(FgeoRaw);
% TENSORS.F0 = Mat2Vec(F0);
% TENSORS.F1 = Mat2Vec(F1);
% 
% TENSORS.comF0F1 = comF0F1;
% TENSORS.deltaEq47 = deltaEq47;
% TENSORS.normUgeo = normUgeo; % 3.1
% 
% TENSORS.mC = Mat2Vec(mC);
% TENSORS.dMC = Mat2Vec(dMC); % 3.1

TENSORS.dMoldC = dMoldC; % DEBUG

TENSORS = orderfields(TENSORS); % 3.2



%% History %%

% IMPROVEMENTS TO IMPLEMENT:
% - do some clean up of commented parts
% - save F (and Fgeo) because one canNOT go back to it from E (rename F of fusion into C of coalescence like in eLife paper)!
% - no weight on rC and RC that can be meaningless and give inaccurate results when patches have isotropic texture for which angles are ill
% defined (3.3). Either associate weight -> 0 when M isotropic (similarly to AreaRatios and Rcond) => additional weight for rotation or find
% something more natural. Weight could be cell anistropy in the patch (in [0 1], quite natural).

% 27/07/2018:
% - added some calculations for DEBUG purposes (moC, dMoldC)

% 15&26/02/2018:
% - updated function and variable names

% 16/03/2016: 3.5
% - fixed bug when NaN or Inf found in dC/DC for Feig and Reig calculations

% 01/03/2016: 3.4
% - reset "geo" quantities as default (while saving "eig" quantities) because they are the most accurate so far (and they're the one published)

% 17/02/2016: 3.3 IMPLEMENTED Qeig CALCULATION (became default, replacing Qchol no longer calculated)
% - after noticing that Echol was highly sensitive to rotation (tested on W02 simulation) implementation of Eeig and Qeig related quantities
% based on eigenvalue decomposition. Tested on W02, gives very good results (like Qgeo quantities!). See notebook #9 date 17/02/2016 details. 
% - accordingly stopped saving Qchol quantities because they are unreliable

% 26/01/2016: 3.2 REMOVED MANY QUANTITIES SAVED IN 3.1
% - changed name tag 'chol' to '' in "addMCatList" because "chol" quantities are now default ones
% - suppressing most of the quantities temporarly saved (backups getting too large):
%       * commented: all "Qmid" quantities, dMC, mC, comF0F1, normUgeo, deltaEq47, EPSI, 
%       * removed: dMCrel
% - did a lot of cleaning comments => go to previous versions to see them

% 20/01/2016: 3.1
% - added a lot of outputs in TENSORS to check validity of equations in eLife article, especially Eq 52 with dMC, dMCgeo
% and dMCchol

% 19/01/2016: 3.0 CALCULATION OF F BY CHOLESKY FACTORIZATION OF MC AND mC
% - removed argument "renormType": now always renormalizing by MoC (or MC) AND correcting for rotation with EPSI
% - revamped computation of F based

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% USE OF CHOLESKY FACTORIZATION (TA 3.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 08/09/2015: 2.3.6: testing calculation of "Ustar"

% 22/07/2015: 2.3.5
% - now using function "MakeUijAlpha" and parameter "alpha" to run some tests.

% 02/07/2015: 2.3.4
% - now storing "PhiU" as a scalar since PhiU = w*sigma_2 = w*[0 -1 ; 1 0] => only storing w
% - accordingly PhiU = NaN instead of NaN(1,4);

% 29/06/2015: 2.3.3
% - use of MC (based on Li*(Li+Lf)/2) and 'mean' flag calculate and renormalize U. ONLY "mean" GIVES MEANINGFUL RESULTS FOR U WHEN TESTED ON
% POTTS SIMULATIONS.
% - removed "Green" from "addMCatList" because EU is almost identical to both EU and EGstar, to reduce redundency.
% - ALWAYS storing "EPSI", regardless of renorm # 1 or 2

% 26/06/2015: 2.3.2
% - removed commented parts of "Total_P" becoming "P" or "EP"
% - added "addMCatList" = { 'U' ; 'Gstar' ; 'Green'; 'PSI'}; to calculate EU, EGstar, EGreen and EPSI
% - specific storage of PhiU i TENSORS that is not a "EQ" quantity

% 25/06/2015: 2.3.1 *** INTRODUCTION of PSI ***
% - finalized U computation
% - calculation of PSI
% - implementation of Renorm #2
% - changed all "Total_Q" notations into either "P" when before symmetrization and "EP" when after

% 24/06/2015: 2.3.0 *** INTRODUCTION OF U *** 
% - added argument "iioMatch"
% - stopped calculating and storing Es and Angles

% 21/05/2015: 2.2.0 *** REMOVED "BETA" TAG ***

% 31/03/2015: 2.1.1
% - special case for Ds that is kept and will be represented RAW (without - sign)

% 26/03/2015: 2.1.0
% - introduction of G, A+/-, N+/-, TA- and TN+

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTRODUCTION OF A+/-, N+/-, TA- and TN+ (TA 2.1+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 17/03/2015: 2.0.8
% - small adjustments to adapt to existence of DnR both for nLinks and nCells renormalization (DnR=0 in latter case)

% 06/03/2015: 2.0.7
% - Mcat_list became MCatList
% - "renorm" became "renormType"
% - supports renormalization of M either using number of cells "nCells", links "nLinks"
% - added new argument "renormM" accordingly

% 03/03/2015: 2.0.6
% - removed threshold of 10^(-6) on errorP
% - now taking norm of errorP instead of norm^2 with "TensorNorm"
% - fixed iteration up to n_Mcat-1 for renorm # 0 

% 27/02/2015: 2.0.5
% - removed output "TA_plotstyle" that used to contain colors (overridden in "AllQsUnitsColors"): list of contributions
% can be obtained by fields(TENSORS) that yields {'EG', 'ES'..., 'EJb'}.
% - added output structure "ERROR" that contains:
%       * "RCond" (Matrix reciprocal condition number estimate) which gives an indication of the accuracy of the results from matrix
%       inversion of MoC and the linear equation solution.
%       * delta_P = difference between sum of contributions and EG
%       * delta_dnP = difference between sum of dnP and dnTot

% 25/02/2015: 2.0.4
% - when there are NaN or Inf in Total_Q, overwrite tensor with NaN(1,4);
% - fills tensors with NaN when LINKS is empty
% - checks for existence of CONSERVED HL in the box, fills tensors with NaN otherwise
% - fixed wrong application of 1/2 factor when renormalizing by Inv(MoC)/2 (was doing P/(MoC/2))
% - now caculating "all_Mijs" and "all_Miokos" with Mij_maker
% - included B/R- & B/R+ HL in MoC with proper weighting

% 24/02/2015: 2.0.3
% - for renormalization all tensors "Q" will have strain like notation "EQ"
% - changed arguments HLC_Plotstyle to HLCat which only contains the list of all HL categories (not line type nor color)
% - added argument "Dt": time between two frames
% - removed switches for processing of whole image
% - stopped defining separate Mcat_list for grid or full image use: now only considers grid use, the full image
% processing being a particular case of the grid.

% 22/02/2015: 2.0.2
% - implemented renormalization #1
% - removed contribution "Dns" from Mcat_list and stopped calculating it

% 17/02/2015: 2.0.1: started implementation of new framework

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NEW FRAMEWORK RENORMALIZATION (TA 2.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 13/06/2013: 1.5
% - changed colors of R, A, F, DM and Sum

% 07/02/2012: 1.4
% - fixed bug occurring when repeating empty matrix!! repmat([],1,4) = [], while a nx4 matrix M yields a 0x4 empty
% matrix when M([],:), leading to an error in .* product since dimensions do not match!! Now repeating matrices
% "all_Wijs/Wiokos" right from the start BEFORE cropping them to relevant subsets or categories.

% 12/01/2012: 1.3
% - determines if grid was used (checking out "HLC_plostyle") and defines "TA_plotstyle" accordingly
% - added "Jb" (mid_custom_magenta) to "TA_plotstyle" list of contributions

% 25/11/2011: 1.2
% - calculating eigenvalues and angles for MAIN contributions
% - added "TA_plotstyle" as output

% 25/11/2011: 1.1
% - included computation for main contributions (B,R,D...)
% - TENSORS now a structure

% 22/11/2011: creation

