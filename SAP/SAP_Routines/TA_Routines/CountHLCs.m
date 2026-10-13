function nHLC = CountHLCs(allHLCs)
%
% nHLC = CountHLCs(allHLCs)
%
% Determines structure "nHLC" that recategorizes each HL in "all_HLCs" into Special categories "Clist" (see below)
% based on Half-Link (HL) Category.
%
% NB: Clist is different than MCatList defined in TensorCalculator:
% Clist = {'C';'R';'D';'A';'J';'N';'F';'Jb'}
% MCatList = {'G';'S';'R';'Ds';'D';'A';'N';'F';'J';'Jb';'DM'};
%
% Inputs:
% - all_HLC: nHL array containing one of the category listed in "HLCplotstyle".
%
% Output:
% structure "nHLC" that contains:
% - all_SpecHLCs: n array containing HL tagged after Special category
% - nP: number of LINKS associated to process P = C,D,N,A,F,J,Jb, as well as nSum, the sum of all nP, and nTot, the
% number of LINKS that are not tagged 'n/a' in all_SpecHLCs.
%
% NB: nP can be HALF-INTEGERS
%
% NB: all_HLC:      contains 'n/a' for all cells that are Non-Core in CURRENT FRAME
%     all_HLC_old:  contains 'n/a' for all cells that are Non-Core in OLD FRAME
%     Note that some Core_old will become Non-Core in current, and conversely, some Core in current were Non-Core in old frame,
%     these will be contributing to Jout and Jin, respectively (unless they're involved in fusion, division...)
%
% NB: all_cat = {'B';'B/R+';'B/R-';'R+;'R-';'Ds';'Dn';'Dm';'A';'N';'J+';'J-';'TD+';'TD-';'TA';'TN';'F';'Jb+';'Jb-';'n/a'};
%
% Version 1.2 (after "HLC2RC")
% Boris Guirao


%% Overriding regular HL categories with SPECIAL ONES %%

% NB: Except for category "C" that merges conserved HL and those making T1s, all other special categories must match
% what's done in TensorCalculator to define Main categories.

all_SpecHLCs = allHLCs; % initialization with regular all_HLCs array

% Fusion (nothing to be done)
%-----------------------------------------------------------------------------------------------------------------------
% Fij_TF = strcmp(all_HLCs,'F');
% all_RCs(Fij_TF) = {'F'};
%-----------------------------------------------------------------------------------------------------------------------

% Boundary flux:
%-----------------------------------------------------------------------------------------------------------------------
Jij_TF = [strcmp(allHLCs,'J-') strcmp(allHLCs,'J+')];
Jij_TF = any(Jij_TF,2); 
all_SpecHLCs(Jij_TF) = {'J'};
% NB: if input is "all_HLC_old", J is a Jout; if "all_HLC", J is a Jin
%-----------------------------------------------------------------------------------------------------------------------

% Conserved HL: involves only Geometric changes (1.1):
%-----------------------------------------------------------------------------------------------------------------------
Cij_TF = strcmp(allHLCs,'G'); % 1.1, B became G (1.2)
% Cij_TF = [strcmp(all_HLCs,'R-')  strcmp(all_HLCs,'B/R-') strcmp(all_HLCs,'B') strcmp(all_HLCs,'B/R+') strcmp(all_HLCs,'R+')]; 
Cij_TF = any(Cij_TF,2); 
all_SpecHLCs(Cij_TF) = {'C'};
%-----------------------------------------------------------------------------------------------------------------------

% SEMI-CONSERVED LINKS (1.1):
%-----------------------------------------------------------------------------------------------------------------------
CRij_TF = [strcmp(allHLCs,'G/R-') strcmp(allHLCs,'G/R+')]; % 1.1, B became G (1.2)
CRij_TF = any(CRij_TF,2); 
all_SpecHLCs(CRij_TF) = {'CR'};
%-----------------------------------------------------------------------------------------------------------------------

% Rearrangements (1.1):
%-----------------------------------------------------------------------------------------------------------------------
Rij_TF = [strcmp(allHLCs,'R-') strcmp(allHLCs,'R+')];
Rij_TF = any(Rij_TF,2); 
all_SpecHLCs(Rij_TF) = {'R'};
%-----------------------------------------------------------------------------------------------------------------------

% Box flux (when using Grid)
%-----------------------------------------------------------------------------------------------------------------------
Jbij_TF = [strcmp(allHLCs,'Jb-') strcmp(allHLCs,'Jb+')];
Jbij_TF = any(Jbij_TF,2); 
all_SpecHLCs(Jbij_TF) = {'Jb'};
% NB: if input is "all_HLC_old", Jb is a Jbout; if "all_HLC", Jb is a Jbin
%-----------------------------------------------------------------------------------------------------------------------

% Nucleation:
%-----------------------------------------------------------------------------------------------------------------------
Nij_TF = [strcmp(allHLCs,'N+') strcmp(allHLCs,'N-') strcmp(allHLCs,'TN+')]; % N,TN became N+,TN+, added N- (1.2)
Nij_TF = any(Nij_TF, 2);    % 1.1
all_SpecHLCs(Nij_TF) = {'N'};
%-----------------------------------------------------------------------------------------------------------------------

% Division:
%-----------------------------------------------------------------------------------------------------------------------
Dij_TF = [strcmp(allHLCs,'Dm') strcmp(allHLCs,'Ds') strcmp(allHLCs,'Dn') strcmp(allHLCs,'TD-') strcmp(allHLCs,'TD+')];
Dij_TF = any(Dij_TF,2);                                 
all_SpecHLCs(Dij_TF) = {'D'};
%-----------------------------------------------------------------------------------------------------------------------

% Apoptosis:
%-----------------------------------------------------------------------------------------------------------------------
Aij_TF = [strcmp(allHLCs,'A+') strcmp(allHLCs,'A-') strcmp(allHLCs,'TA-')]; % A,TA became A-,TA-, added A+ (1.2)
Aij_TF = any(Aij_TF, 2);    % 1.1
all_SpecHLCs(Aij_TF) = {'A'};
%-----------------------------------------------------------------------------------------------------------------------


% Storage in nHLC:
nHLC.all_SpecHLCs = all_SpecHLCs;


%% Getting number of LINKS for each SPECIAL category %%

Clist = {'C';'R';'D';'A';'J';'N';'F';'Jb'}; % added R (1.1)
nHLC.Clist = Clist;

% special case for CR (1.1):
CR_TF = strcmp(all_SpecHLCs, 'CR');
nCR = sum(CR_TF);   % getting number of HALF-links that are SEMI-conserved

for p = Clist'
    pTF = strcmp(all_SpecHLCs, p);
    np = sum(pTF);
    
    % Splitting nCR equally between C and R (1.1)
    if strcmp(p,'C') || strcmp(p,'R')
        np = np + nCR/2;                %#ok<NASGU>
    end
    % storage in nHLC:
    eval(['n' p{1} '= np;']);
    eval(['nHLC.n' p{1} '= np;']);
end

% Total number of RNs to consider for the balance
% NB: this should exactly yield the Core_cells or corresponding image sice DM = Mf_core - Mi_core
Tot_TF = ~strcmp(all_SpecHLCs,'n/a');
nTot = sum(Tot_TF);                  % removed 1/2 factor (1.1)
nHLC.nTot = nTot;

nSum = nC + nR + nJ + nJb + nD + nA + nN + nF; % added nR (1.1)
nHLC.nSum = nSum;

% Check nSum and nTot are the same:
if nSum ~= nTot
    disp(['HLCCounter WARNING: nSum = ' num2str(nSum) ' is different from nTot = ' num2str(nTot) '!'])
end


%% History %%

% 27/03/2015: 1.2
% - introduction of G, A+/-, N+/-, TA- and TN+

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTRODUCTION OF A+/-, N+/-, TA- and TN+ (TA 2.1+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 17/03/2015: 1.1
% - fixed wrong tagging of "conserved" for links undergoing T1s that are NOT conserved => introduced category 'R' in Clist and splitting
% semi-conserved HL equally between R and C. This should fix the observed unbalance of links number when running BIG.
% - removed 1/2 factor before link numbers: now counting HALF-links
% - fixed mistake when tagging with A and N

% 06/03/2015: created after HLC2RC


