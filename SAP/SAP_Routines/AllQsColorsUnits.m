% AllQsColorsUnits
%
% For program P = GEP, VM, AOS, SM, TA, defines "allQs_P", "allColors_P", "allUnits_P".
% NB: GEP & AOS part must be updated when new signals are introduced.
%
% Version 2.12
% Boris Guirao

%% Definitions %%

CustomColors

% Gene Expression Pattern (GEP):
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------
allQsGEP =        {   'Cad'    ;    'Esg'   ;    'Myo'    ;    'Sqh'    ;     'ID5'   ;    'Gene'   };
allColorsGEP =    { dark_green ;  turquoise ; dark_orange ; dark_orange ; mid_crimson ; mid_crimson };
allUnitsGEP =     {   'IL'     ;    'IL'    ;    'IL'     ;    'IL'     ;     'IL'    ;     'IL'    };   
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------


% Velocity Maps (VM)
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------
allQsVM =        {      'U'      ;    'Epsilon'  ;     'Omega'   }; 
allColorsVM =    { dark_orange   ;    mid_blue   ;  dark_purple  };
allUnitsVM =     { ['\mu' 'm/h'] ;    'h^{-1}'   ;     'h^{-1}'  };
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------


% Average Over Space (AOS):
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------
allQsAOS =     {   'PatchArea'   ;     'Rho'        ;      'I'        ;      'M'        ;     'V'     ;   'CellArea'    ;    'CellIaniso' ;   'nCoreRNs'   ; 'AreaDisorder' };
allColorsAOS = {   mid_blue      ;   dark_grey      ;   mid_purple    ;  dark_purple    ; mid_crimson ;   custom_cyan   ;      purple     ;   dark_orange  ;  mid_magenta  };  
allUnitsAOS =  { ['\mu' 'm^{2}'] ; ['\mu' 'm^{-2}'] ; ['\mu' 'm^{2}'] ; ['\mu' 'm^{2}'] ;     ''      ; ['\mu' 'm^{2}'] ;        ''       ;        ''      ;       ''      };
                   
allQsAOSrates =     {   'dnD'    ;  'dnA'   ;  'rRho'   ;  'rPatchArea'  ;     'U'      ;   'Epsilon'   ;    'Omega'    ;  'R2'   ; 'rCellArea' };
allColorsAOSrates = { dark_green ;  black   ; dark_grey ;  custom_blue   ; dark_orange  ;    mid_blue   ;  dark_purple  ; mid_red ;    cyan     };
allUnitsAOSrates =  { 'h^{-1}'   ; 'h^{-1}' ;  'h^{-1}' ;    'h^{-1}'    ;['\mu' 'm/h'] ;    'h^{-1}'   ;     'h^{-1}'  ;   ''    ;   'h^{-1}'  };

allQsAOScds =     {  'CDCad'   ;  'CDEsg'   ;   'CDMyo'   ;   'CDtest'   }; 
allColorsAOScds = { dark_green ;  turquoise ; dark_orange ; dark_orange };   
allUnitsAOScds =  {    'IL'    ;    'IL'    ;     'IL'    ;     'IL'    };

% Gathering all:
allQsAOS = [allQsAOS ; allQsAOSrates ; allQsAOScds];
allColorsAOS = [allColorsAOS ; allColorsAOSrates ; allColorsAOScds];
allUnitsAOS = [allUnitsAOS ; allUnitsAOSrates ; allUnitsAOScds];
%------------------------------------------------------------------------------------------------------------------------------------------------------------------

% Stress Map (SM):
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------
allQsSM =        {  'S'   ;    'SP'    ;    'ST'     ;     'P'     };
allColorsSM =    {  red   ;  mid_blue  ;  turquoise  ;    blue     };
allUnitsSM =     { 'A.U.' ;   'A.U.'   ;   'A.U.'    ;    'A.U.'    };
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------


% Tensor Analysis (TA):
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------
allQsTA =     { 'EG' ;    'ES'     ;     'ER'    ;    'EDs'   ;   'ED'    ; 'EA'  ;    'EN'     ;  'EF'   ;    'EJ'     ; 'EJb'  ;    'EDM'      };
allColorsTA = { blue ; custom_cyan ; mid_magenta ; dark_green ; turquoise ; black ; dark_purple ; crimson ; dark_orange ; orange ; custom_purple };

extQsTA =      {   'E'    ;   'EPSI'   ;    'Phi'    ;    'dMoldC'    };  
extColorsTA =  { mid_blue ; custom_red ; dark_purple ;       red   };   

extQsTAgeo =      {  'Egeo'  ; 'EGgeo' ;  'ESgeo'    ; 'EPSIgeo'  ;  'Phigeo'   };    
extColorsTAgeo =  { mid_blue ;   blue  ; custom_cyan ; custom_red ; dark_purple };    

extQsTAeig =      {  'Eeig'  ; 'EGeig' ;  'ESeig'    ; 'EPSIeig'  ;  'Phieig'   };  
extColorsTAeig =  { mid_blue ;   blue  ; custom_cyan ; custom_red ; dark_purple };   

% NB: below is only relevant when Qchol quantities exist in TA backups
extQsTAchol =      {  'Echol'  ; 'EGchol' ;  'ESchol' ; 'EPSIchol'  ;  'Phichol'   };  
extColorsTAchol =  { mid_blue ;   blue  ; custom_cyan ; custom_red ; dark_purple };   

allQsTA =      [allQsTA       ; extQsTA      ; extQsTAgeo       ; extQsTAeig       ; extQsTAchol];
allColorsTA =  [allColorsTA   ; extColorsTA  ; extColorsTAgeo   ; extColorsTAeig   ; extColorsTAchol];

% Repeating units:
nTA = length(allQsTA);
allUnitsTA = cell(nTA,1);

allUnitsTA(:) = {'h^{-1}'};
%-------------------------------------------------------------------------------------------------------------------------------------------------------------------

% ALL (2.11)
allQs = [allQsGEP ; allQsVM ; allQsAOS ; allQsSM ; allQsTA];
allUnits = [allUnitsGEP ; allUnitsVM ; allUnitsAOS ; allUnitsSM ; allUnitsTA];
allColors = [allColorsGEP ; allColorsVM ; allColorsAOS ; allColorsSM ; allColorsTA];


%% History %%

% 07/02/2019: 2.12
% - added AOS quantity "rCellArea"

% 28/01/2019: 2.11
% - added allQs, allUnits, allColors gathering quantity names, units and
% colors from all programs

% 30/10/2018: 2.10
% - added "AreaDisorder" in AOS

% 18/09/2018: 2.9
% - removed VM suffix for VM quantities: back to U, Epsilon and Omega,
% programs VM and AOT now adding a "PIV" or "CT" suffix according to
% parameter "modeVM".

% 06/09/2018: 2.8
% - added correlation coeff "R2" in AOS section

% 25/07/2018: 2.7
% - added new AOS quantities U, Epsilon and Omega calculated according to
% Kabla-Blanchard
% - renamed VM quantities U, Epsilon and Omega became UVM, EpsilonVM,
% OmegaVM accordingly
% - added "dMoldC" corresponding to difference in "old" matrices of
% conserved texture M for TA debug.

% 19/07/2018: 2.6
% - AOS quantities "BoxCellArea" became "PatchArea" ("rBoxCellArea" -> "rPatchArea")

% 02/07/2018: 2.5 (Boris)
% - added "nCoreRNs" in AOS quantities

% 14/06/2018: 2.4 (Boris)
% - Stopped specifying "Avg" in some quantities: "AvgCellArea" became
% "CellArea"; "AvgCellIaniso" became "CellIaniso"

% 01/06/2018: 2.3 (Boris)

% 30/05/2018: 2.2 (Boris)
% - removed inertia in VM part

% 24/04/2018: 2.1 (stephane)
% - add AvgCellArea and AvgCellIaniso in AOS values

% 08/02/2018: 2.0
% - removed all "_"

% 14-19/12/2016: 1.16
% - fixed AOS units of dnA an dnD (changed nA and nD names to those)
% - adjustments to match GEP update 1.1 where ID1, ID2 were dropped in favor of signal names "cad", "esg", "myo"...
% - adjustments to match AOS update 3.25 where "rRho", "rBoxCellArea" were introduced and "CD1","CD2"... replaced by "CDcad", "CDesg"...

% 19/07/2016: 1.15
% - AOS: removed CD4, added nA and nD

% 24/06/2016: 1.14
% - added CD1, CD2,... to match new AOS version (3.23) and new AOT (2.4)

% 14/06/2016: 1.13
% - added several entries in the GEP section so it can be treated like the other programs

% 01/03/2016: 1.12
% - added "Qeig" quantities

% 08/09/2015: 1.10
% - added 'EUstar' and 'PhiUstar' in "extQs_TA"

% 30/06/2015: 1.9
% - removed EGreen, added PhiU

% 26/06/2015: 1.8
% - added EGstar, EGreen and EPSI.

% 24/06/2015: 1.7
% - added U

% 02/06/2015: 1.6
% - removed AOS quantities "mQ" to only keep "Q": sum quantities "Q" have been replaced by the mean ones "mQ" that have been renamed "Q".

% 27/05/2015: 1.5
% - changed names of parameters

% 08/04/2015: 1.4
% - changed colors

% 17/03/2015: 1.3
% - removed ESum from all_Qs_TA
% - now testing "renormType" instead of "renorm"

% 24/02/2015: 1.2
% - simplified TA quantities by only defining EQ common to ALL renormalizations
% - added VMM quantities

% 23/02/2015: 1.1
% - added TA Qs,Colors,Units

% 04/10/2014: creation