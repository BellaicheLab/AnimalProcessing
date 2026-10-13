function RC = HLC2RC(all_ij_match, all_HLCs)
%
% Determines structure Region Category RC (Clist = {'C';'R';'D';'A';'J';'N';'F';'Jb'}) based on Half-Link (HL) Category.
% NB: 'R' is just to have similar structure as "HLCcounter", but here no region is tagged "R" and nR always = 0.
%
% Inputs:
% - all_ij_match: nlinks x 2 matrix containing each region RN (i) (col 1) and all its neighboring region RNs (js) (col 2).
%                 Each region RNs in col1 is repeated as many times as its neighbor number.
% - all_HLC: nlinks array containing one of the category listed in "HLC_plotstyle".
%
% Output:
% structure "RC" (for Region Category) that contains:
% - all_RNs: nregions vector
% - all_RCs: nregions array containing category of each region 
% - nP: number of cells associated to process P = C,D,N,A,F,J,Jb, as well as nSum, the sum of all nP, and nTot, the
% number of cells that are not tagged 'n/a' in all_RCs.
%
% NB: all_ij_match contains RNs ALL regions RN in the image/box, NOT JUST THE CORE REGIONS. That's "all_HLC" contains
%     the info regarding the core regions.
%     all_HLC:      contains 'n/a' for all cells that are Non-Core in CURRENT FRAME
%     all_HLC_old:  contains 'n/a' for all cells that are Non-Core in OLD FRAME
%     Note that some Core_old will become Non-Core in current, and conversely, some Core in current were Non-Core in old frame,
%     these will be contributing to Jout and Jin, respectively (unless they're involved in fusion, division...)
%
% NB: all_cat = {'B';'B/R+';'B/R-';'R+;'R-';'Ds';'Dn';'Dm';'A';'N';'J+';'J-';'TD+';'TD-';'TA';'TN';'F';'Jb+';'Jb-';'n/a'};
%
% Version 1.4
% Boris Guirao


%% Getting all_RNs %%

all_RNs = unique(all_ij_match(:,1));
RC.all_RNs = all_RNs;
nRNs = length(all_RNs); % ALL image RNs, not just the Core_cells


%% Determining all_RCs %%

all_RCs = cell(nRNs,1);
all_RCs(:) = {'n/a'};       % default filling with 'n/a'

% NB: the order in which all_RCs get filled can be important because each region has several links and each can be
% associated to a different category. However, cell biological events trump rearrangements and flux (which should be
% still visible thanks to the neighbor 1/2 links). Fusion trumps everything. Hence the ordering of categorization that
% follows:

% Fusion: MUST BE CARRIED OUT IN FIRST!
%-----------------------------------------------------------------------------------------------------------------------
Fij_TF = strcmp(all_HLCs,'F');
F_RNs = unique(all_ij_match(Fij_TF,1));
F_RNs_TF = ismember(all_RNs, F_RNs);    % finds those RNs in all_RNs list
all_RCs(F_RNs_TF) = {'F'};
% NB: put in first because trumps every contribution in all_HLCs => cell links are impacted by its coalesced neighbor
% Ex: cell i is new, all ij were assigned tag "N", except with coalesced neighbors, tag "F" => if put in last, even
% non-coalesced cell will be found as "F" if they just have a single coalesced neighbor.
% Ex: cell i is not coalesced BUT was in previous frame => tagged with F
%-----------------------------------------------------------------------------------------------------------------------


% Boundary flux (trumps box flux) (moved up in 1.2): MUST BE CARRIED OUT IN SECOND!
%-----------------------------------------------------------------------------------------------------------------------
Jij_TF = [strcmp(all_HLCs,'J-') strcmp(all_HLCs,'J+')];
Jij_TF = any(Jij_TF,2); 
J_RNs = unique(all_ij_match(Jij_TF,1));
J_RNs_TF = ismember( all_RNs, J_RNs);    % finds those RNs in all_RNs list
all_RCs(J_RNs_TF) = {'J'};
% NB: if input is "all_HLC_old", J is a Jout; if "all_HLC", J is a Jin
% NB: J tags can only come from region switching from or to Core, NOT FROM NEIGHORS.

% NB: Conserved vs Flux (updated 1.2)
% - WHEN Remove_CoreFLHLs = 0:
% Flux only comes from regions evolving from or to being "Core_cells": then ALL 1/2 links of the regions are J- or J+.
% => Regions that remained Core cannot have any HL tagged "J": conserved neighbors are "B", new ones are "R+" even if
% this new neighbor just became Core (and will have its own HL tagged "J"), or "F" if the neighbor region is coalesced.
%
% - WHEN Remove_CoreFLHLs = 1:
% The HLs of regions not directly involved in flux (core remaining core) BUT INVOLVING THEIR NEIGHBORS that go from core
% to FL have been overridend with J- => those regions have only SOME HLs tagged J-, unlike regions directly involved in
% flux => important to let the other processes override J for these cells and put J before the others.
%-----------------------------------------------------------------------------------------------------------------------

% Conserved cells: involves only geometric changes AND rearrangements, AND topological events *OF NEIGHBORS* (1.1):
%-----------------------------------------------------------------------------------------------------------------------
Cij_TF = [strcmp(all_HLCs,'R-')  strcmp(all_HLCs,'G/R-') strcmp(all_HLCs,'G') strcmp(all_HLCs,'G/R+') strcmp(all_HLCs,'R+')...
          strcmp(all_HLCs,'TD-') strcmp(all_HLCs,'TD+') strcmp(all_HLCs,'TA-') strcmp(all_HLCs,'TN+')];                        % cell events OF NEIGHBORS (1.1,1.4)
Cij_TF = any(Cij_TF,2); 
C_RNs = unique(all_ij_match(Cij_TF,1));
C_RNs_TF = ismember(all_RNs, C_RNs);    % finds those RNs in all_RNs list
all_RCs(C_RNs_TF) = {'C'};
%-----------------------------------------------------------------------------------------------------------------------

% Box flux (when using Grid)
%-----------------------------------------------------------------------------------------------------------------------
Jbij_TF = [strcmp(all_HLCs,'Jb-') strcmp(all_HLCs,'Jb+')];
Jbij_TF = any(Jbij_TF,2); 
Jb_RNs = unique(all_ij_match(Jbij_TF,1));
Jb_RNs_TF = ismember(all_RNs, Jb_RNs);    % finds those RNs in all_RNs list
all_RCs(Jb_RNs_TF) = {'Jb'};
% NB: if input is "all_HLC_old", Jb is a Jbout; if "all_HLC", Jb is a Jbin
%-----------------------------------------------------------------------------------------------------------------------

% Nucleation:
%-----------------------------------------------------------------------------------------------------------------------
Nij_TF = [strcmp(all_HLCs,'N-') strcmp(all_HLCs,'N+') ];         % N-,N+ (1.4)
Nij_TF = any(Nij_TF,2);                                          % 1.4
N_RNs = unique(all_ij_match(Nij_TF,1));
N_RNs_TF = ismember(all_RNs, N_RNs);    % finds those RNs in all_RNs list
all_RCs(N_RNs_TF) = {'N'};
%-----------------------------------------------------------------------------------------------------------------------

% Division:
%-----------------------------------------------------------------------------------------------------------------------
Dij_TF = [strcmp(all_HLCs,'Dm') strcmp(all_HLCs,'Ds') strcmp(all_HLCs,'Dn')];
Dij_TF = any(Dij_TF,2);                                 
D_RNs = unique(all_ij_match(Dij_TF,1));
D_RNs_TF = ismember(all_RNs, D_RNs);    % finds those RNs in all_RNs list
all_RCs(D_RNs_TF) = {'D'};
%-----------------------------------------------------------------------------------------------------------------------

% Apoptosis:
%-----------------------------------------------------------------------------------------------------------------------
Aij_TF = [strcmp(all_HLCs,'A-') strcmp(all_HLCs,'A+')];         % A-,A+ (1.4)
Aij_TF = any(Aij_TF,2);                                         % 1.4
A_RNs = unique(all_ij_match(Aij_TF,1));
A_RNs_TF = ismember(all_RNs, A_RNs);    % finds those RNs in all_RNs list
all_RCs(A_RNs_TF) = {'A'};
%-----------------------------------------------------------------------------------------------------------------------


% Storage in RC:
RC.all_RCs = all_RCs;


%% Getting number of regions for each category %%

Clist = {'C';'R';'D';'A';'J';'N';'F';'Jb'}; % added R (1.3)
RC.Clist = Clist;

for c = Clist'
    cTF = strcmp(all_RCs, c);
    nc = sum(cTF);                  %#ok<NASGU>
    eval(['n' c{1} '= nc;']);
    eval(['RC.n' c{1} '= nc;']);
end
% NB: nR always = 0 by construction

% Total number of RNs to consider for the balance
% NB: this should exactly yield the Core_cells or corresponding image sice DM = Mf_core - Mi_core
Tot_TF = ~strcmp(all_RCs,'n/a');
nTot = sum(Tot_TF);
RC.nTot = nTot;

nSum = nC + nR + nJ + nJb + nD + nA + nN + nF; % added nR (1.3)
RC.nSum = nSum;

% Check nSum and nTot are the same:
if nSum ~= nTot
    disp(['HLC2RC WARNING: nSum = ' num2str(nSum) ' is different from nTot = ' num2str(nTot) '!'])
end


%% History 

% 27,31/03/2015: 1.4
% - introduction of G, A+/-, N+/-, TA- and TN+

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTRODUCTION OF A+/-, N+/-, TA- and TN+ (TA 2.1+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 17/03/2015: 1.3
% - added 'R' in Clist with to mirror "HLCcounter" variables. Here no region can be tagged R and nR always = 0.

% 05/03/2015: 1.2

% 27/02/2015: 1.1
% - when looking for conserved cells added research of HL tags corresponding to topological events *OF NEIGHBORS*!!!

% 21/02/2015: creation & test on full scutellum WT2NEW:
% - checked that number of conserved region is the same with all_HLC or all_HLC_old
% - checked that keeping or removing Core-FL HL did not changed numbers for any process, as it should since we are
% defining REGION properties that must be robust to the number of HL considered for this REGION.
% - tested on 124x124 grid for Jb => solved many bugs thanks to that (nConserved not matching in old and current box, total
% number of cells not matching the number of lines in "all_RNs" when using a box not touching image frame)
% - checked that nSum = nTot and nC_old (from all_HLC_old) = nC_current (from all_HLC) on the whole scutellum movie!

