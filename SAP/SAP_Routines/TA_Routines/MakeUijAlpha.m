function [UIJs, MCIJs, mWijs]= MakeUijAlpha(Lijs, Wijs, HLCs, ijMatch, Liokos, Wiokos, HLCsOLD, iokoMatch, iioMatch, alpha)
%
% [UIJs, MCIJs, mWijs]= MakeUijAlpha(Lijs, Wijs, HLCs, ijMatch, Liokos, Wiokos, HLCsOLD, iokoMatch, iioMatch, alpha)
%
% Returns a nHL (number of Half-Links) x 4 matrix "Uijs" [Uxx Uxy Uyx Uyy ; ...] calculated from nHL x 2 matrix "Lijs"
% [Lx Ly; Lx' Ly';...] AND from nHLo x 2 matrix "Liokos" [Lox Loy; Lox' Loy';...], calculating the outer product for EACH LINK with
% regular matrix product:
%
% UijsAlpha = DLijs*LijsAlpha', with DLijs = Lijs-Liojos and LijsAlpha = alpha*Lijs + (1-alpha)*Liojos, ON CONSERVED LINKS
% MCijsAlpha = Liojos*LijsAlpha', ON CONSERVED LINKS, that will be used to get the displacement gradient grad(u)
% 
% Parameter "alpha" (0<= alpha <=1 was introduced in 1.6 to use intermediate state of links for calculation.
% (alpha = 0, initial; 1/2, mean; 1, final).
%
% NB: PAY ATTENTION TO THE LISTING OF XY AND YX INDICES IN Uijs!
% M = Vec2Mat(V) will turn vector V = [Mxx Mxy Myx Myy] into 2x2 matrix M = [Mxx Mxy ; Myx Myy].
%
% NB: output UijsAlpha has same number of lines as all_Lijs (nHL), and NOT as all_Liokos (nHLo).
%
% Version 2.0 (formerly UijMaker)
% Boris Guirao


%% Initializing %%

% gets list of conserved HalfLinks in HLCs(_old):
nHL = size(Lijs,1);
consHL_TF = any([strcmp(HLCs,'G/R-') strcmp(HLCs,'G') strcmp(HLCs,'G/R+')],2); % 1.2
nConsHL = sum(consHL_TF);
consHLo_TF = any([strcmp(HLCsOLD,'G/R-') strcmp(HLCsOLD,'G') strcmp(HLCsOLD,'G/R+')],2); % 1.2
nConsHLo = sum(consHLo_TF);

% Consistency check:
if nConsHL ~= nConsHLo
    disp('"UijMaker" WARNING: numbers of conserved Half-Links (HL) found are different in "HLCs" and in "HLCs_old"!')
end


%% Buidling "consLiokos" matrix %%

% NB:   "iios_match" = [i io1 ; i io2 ; i' io1' ; ...], with io = 0 when i is NEW
%       rows of "Liokos", "HLCs_old" and "ioko_match" all match: looking at row r, one finds XY coordinates of rth HL io-ko, its category and
%       the couple of relative numbers identifying this HL io(r)-ko(r), respectively.

consIJmatch = ijMatch;
consIJmatch(~consHL_TF,:) = NaN; % killing non-conserved RN couples

% Fiding OLD RN couples io-ko corresponding to CURRENT RN couples i-j using "iio_match":
[~,locIs] = ismember(consIJmatch(:,1), iioMatch(:,1));
[~,locJs] = ismember(consIJmatch(:,2), iioMatch(:,1)); 
% NB: using "ismember" like this ONLY picks last index found, but there should be only one (since coalescences are left out)

% Cropping to rows where BOTH i and j were matched:
locIJs = [locIs locJs];             % 0s when not found
locIJsBothFoundTF = all(locIJs,2);  % true on rows where both i and j were matched, false where NaNs AND where NOT matched
locIJsFilt = locIJs(locIJsBothFoundTF,:);

% NB: some of the ij couples could not be matched => "locIJsBothFoundTF" has less true than "consHL_TF" and should be used  INSTEAD below!!!

locIsFilt = locIJsFilt(:,1);
locJsFilt = locIJsFilt(:,2);

Ios = iioMatch(locIsFilt,2);   % finds ios corresponding to is
Jos = iioMatch(locJsFilt,2);   % finds jos corresponding to js

IoJos = [Ios Jos];                                          % OLD RN couples (ONLY) matching current ones.
% NB: The matching matrix of CURRENT RN would be ij_match(consHL_TF,:) (unused).
[~,locIoJos] = ismember(IoJos, iokoMatch,'rows');          % finds locations of io-jo couples in ioko_match (AND Liokos since they match).

% Extra filtering because some IoJos couples may have not been found in ioko_match (1.5)
okLoc = logical(locIoJos);                                  % 1 when a couple io-jo has been found in ioko_match, 0 when NOT
locIoJos = locIoJos(okLoc);                                 % crops to found io-jo couples

% Update of "locIJsBothFoundTF" to remove UNfound couples (1.5):
if any(~okLoc)
    disp('"UijMaker" WARNING: some iojo couples where not found in "ioko_match": updating "locIJsBothFoundTF" accordingly.');
    IJs = consIJmatch(locIJsBothFoundTF,:);                 % matrix matching IoJos
    notOkIJs = IJs(~okLoc,:);                               % ij couples whose iojo were not found in ioko_match
    notOKIJsTF = ismember(consIJmatch, notOkIJs, 'rows');   % finds locations in consIJmatch of problematic IJs
    locIJsBothFoundTF(notOKIJsTF) = false;                  % updates "locIJsBothFoundTF" by putting corresponding locations to false
end

onlyConsLiokos = Liokos(locIoJos,:);        % selects link coordinates of conserved links ONLY and SORTED in order listed in locIoKos

consLiokos = NaN(nHL,2);                    % builds matrix similar to "consLijs" (see below)
consLiokos(locIJsBothFoundTF,:) = onlyConsLiokos;   % fills with OLD coordinates AT LOCATIONS WHERE BOTH I AND J WHERE MATCHED (1.3)


%% Building "consLijs" and "consDLijs", "Uijs" and "MCijs" matrices %%

% Building "consLijs" matrix:
consLijs = Lijs;
consLijs(~locIJsBothFoundTF,:) = NaN; % Overwritting NON-conserved HalfLinks with NaNs (1.3)

% Building "consDLijs" matrix:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
consDLijs = consLijs - consLiokos;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Building "ConsLijsAlpha" matrix (1.6):
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
consLijsAlpha = alpha*consLijs + (1-alpha)*consLiokos; % alpha = 0 => consLijsAlpha = consLiokos; alpha = 1 => consLijsAlpha = consLijs;
consLijs0 = consLiokos;     % Alpha = 0 (1.7)
consLijs1 = consLijs;       % Alpha = 1 (1.7)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Building "UijsAlpha" and "MCijsAlpha" (1.6):
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
UijsAlphaDiag = consDLijs.*consLijsAlpha;             % builds [AxBx AyBy] rows by doing A.*B. PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)
UijsAlphaOffDiag = consDLijs.*fliplr(consLijsAlpha);  % builds [AxBy AyBx] rows by doig A.*(fliplr(B)). PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)

% Building "alpha" texture matrix based on conserved links for U renorm:
MCijAlphaDiag = consLiokos.*consLijsAlpha;
MCijAlphaOffDiag = consLiokos.*fliplr(consLijsAlpha);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Builds "Uijs" and "MCijs" matrices:
UijsAlpha = [UijsAlphaDiag(:,1) UijsAlphaOffDiag(:,1) UijsAlphaOffDiag(:,2) UijsAlphaDiag(:,2)]; % builds [AxBx AxBy AyBx AyBy] rows
MCijsAlpha = [MCijAlphaDiag(:,1) MCijAlphaOffDiag(:,1) MCijAlphaOffDiag(:,2) MCijAlphaDiag(:,2)];

% NB: M = Vec2Mat(V) will turn vector V = [Mxx Mxy Myx Myy] into 2x2 matrix M = [Mxx Mxy ; Myx Myy].


%% Building "Uijs0","Uijs1" and "MCijs0","MCijs" (1.7) %%

% "Uijs0" & "MCijs0"
%-------------------------------------------------------------------------------
Uijs0Diag = consDLijs.*consLijs0;             % builds [AxBx AyBy] rows by doing A.*B. PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)
Uijs0OffDiag = consDLijs.*fliplr(consLijs0);  % builds [AxBy AyBx] rows by doig A.*(fliplr(B)). PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)

% Building "0" texture matrix based on conserved links for U renorm:
MCijs0Diag = consLiokos.*consLijs0;
MCijs0OffDiag = consLiokos.*fliplr(consLijs0);

% Builds "Uijs0" and "MCijs0" matrices:
Uijs0 = [Uijs0Diag(:,1) Uijs0OffDiag(:,1) Uijs0OffDiag(:,2) Uijs0Diag(:,2)]; % builds [AxBx AxBy AyBx AyBy] rows
MCijs0 = [MCijs0Diag(:,1) MCijs0OffDiag(:,1) MCijs0OffDiag(:,2) MCijs0Diag(:,2)];
%-------------------------------------------------------------------------------

% "Uijs1" & "MCijs1"
%-------------------------------------------------------------------------------
Uijs1Diag = consDLijs.*consLijs1;             % builds [AxBx AyBy] rows by doing A.*B. PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)
Uijs1OffDiag = consDLijs.*fliplr(consLijs1);  % builds [AxBy AyBx] rows by doig A.*(fliplr(B)). PRODUCT WITH ALPHA LINKS consLijsAlpha!!! (1.6)

% Building "0" texture matrix based on conserved links for U renorm:
MCijs1Diag = consLiokos.*consLijs1;
MCijs1OffDiag = consLiokos.*fliplr(consLijs1);

% Builds "Uijs0" and "MCijs0" matrices:
Uijs1 = [Uijs1Diag(:,1) Uijs1OffDiag(:,1) Uijs1OffDiag(:,2) Uijs1Diag(:,2)]; % builds [AxBx AxBy AyBx AyBy] rows
MCijs1 = [MCijs1Diag(:,1) MCijs1OffDiag(:,1) MCijs1OffDiag(:,2) MCijs1Diag(:,2)];
%-------------------------------------------------------------------------------


% final texture "mCijs" (2.0)
%-------------------------------------------------------------------------------
mCijsDiag = consLijs.*consLijs;
mCijsOffDiag = consLijs.*fliplr(consLijs);
mCijs = [mCijsDiag(:,1) mCijsOffDiag(:,1) mCijsOffDiag(:,2) mCijsDiag(:,2)];
%-------------------------------------------------------------------------------

%% Filling structures (1.7)

UIJs.UijsAlpha = UijsAlpha;
UIJs.Uijs0 = Uijs0;
UIJs.Uijs1 = Uijs1;

MCIJs.MCijsAlpha = MCijsAlpha;
MCIJs.MCijs0 = MCijs0;
MCIJs.MCijs1 = MCijs1;
MCIJs.mCijs = mCijs;            % 2.0


%% Building "mWijs" %

% Calculates average weights between OLD and Current frames.
% NB: since consDLijs is always involved in Uijs, it's more relevant to consider mean Wijs rather than an "alpha-weighted" version of weights.

consWijs = Wijs;
consWijs(~locIJsBothFoundTF) = NaN; % 1.3

consWiokos = NaN(nHL,1);
consWiokos(locIJsBothFoundTF) = Wiokos(locIoJos); % 1.3

mWijs = (consWijs + consWiokos)/2; % takes mean values of weights


%% History %%

% IMPROVEMENTS
% - be more rigorous with the weights: 1->1/2 and 1/2->1 cases should all end up with 1/2->1/2 weights IN THE CONSERVED
% TEXTURES MC and mC (the other 1/2 being put in R- and R+, respectively). 

% 19/01/2016: 2.0
% - added computation and storage of conserved texture in final configuration mCjis (for TensorCalculator 3.0).

% 08/09/2015: 1.7
% - now systematically calculating UijsAlpha and MCijsAlpha for Alpha = 0 and 1 and storing it into structures UIJs and MCIJs

% 22/07/2015: 1.6 became "UijAlphaMaker"
% - implemented properly the use of intermediate states of links to calculate Uijs and MCijs thanks to parameter "alpha".
% - accordingly removed string parameter "flag" replaced by double "alpha".
% - moved mWijs output to last.

% 30/06/2015: 1.5
% - supports cases where numbers of conserved Half-Links (HL) found are different in "HLCs" and in "HLCs_old" which apparently leads to
% IoJos couples that are not found in ioko_match => need to update "locIJsBothFoundTF" accordingly
% - reintroduced "flag" argument (different from renormType) to chose between the use of Lf ("old") or (Li+Lf)/2 "mean" to calculate Uijs
% and MCijs. ONLY "mean" GIVES MEANINGFUL RESULTS WHEN TESTED ON POTTS SIMULATIONS.

% 29/06/2015: 1.4
% - added output "MCijs", matrix of elementary textures for each found conserved Half-Links ij that will be used to renormalize U

% 26/06/2015: 1.3
% - use of "locIJsBothFoundTF" (instead of "consHL_TF") to make sure we only use conserved link RNs that we were able to match to their old RNs
% - fixed wrong product to calculate "UijsDiag": used to use final link vectors Lijs instead of initial Liokos!!

% 25/06/2015: 1.2
% - included 'G/R-' and 'G/R+' cases

% 23/06/2015: 1.1 renamed "UijMaker" from "Cij_Maker"

% 25/02/2015: creation (unfinished)