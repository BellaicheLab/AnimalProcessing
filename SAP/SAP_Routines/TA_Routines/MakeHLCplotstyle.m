function HLCplotstyle = MakeHLCplotstyle(HL_styles)
%
% HLCplotstyle = MakeHLCplotstyle(HL_styles)
%
% Returns a cell array containing all possible link categories ('B', 'R+'...), one per line, and their corresponding
% display colors and styles. As of 1.1, depends on value of parameter "TA_Grid". Cell array of strings "link_styles"
% defines the style to use for display of solid and vanishing links.
% NB: 'n/a' MUST BE KEPT AT THE VERY END
%
% Version 2.2
% Boris Guirao


%% Defining Colors and Linestyle for HLC %%

CustomColors;
solid = HL_styles{1};
vanishing = HL_styles{2};

% Categories:
AllCat1 =    {   'G'    ;  'G/R+'  ;   'G/R-'  ;   'R+'  ;    'R-'   ;     'Ds'   ;   'Dn'    ;   'Dm'    ;  'A+' ;    'A-'   };
% Colors
AllColors1 = { mid_blue ; mid_blue ;  mid_blue ; magenta ;  magenta  ; PLuc_green ; turquoise ; turquoise ; black ;   black   };
% AllColors1 = { mid_blue ; mid_blue ;  mid_blue ;  red  ;    red    ; dark_green ; turquoise ; turquoise ; black ;   black   };
% LineStyles:
AllStyles1 = {  solid   ;  solid   ;   solid   ;  solid  ; vanishing ;    solid   ;   solid   ; vanishing ; solid ; vanishing };

% Categories:
AllCat2 =    {    'N+'     ;     'N-'    ;    'J+'     ;     'J-'    ;   'TD+'   ;   'TD-'   ;   'TA-'   ;    'TN+'    ;   'F'   ;  'Jb+' ;   'Jb-' ;   'n/a'   };
% Colors
AllColors2 = { dark_purple ; dark_purple ; dark_orange ; dark_orange ; turquoise ; turquoise ;   black   ; dark_purple ; crimson ; orange ;  orange ; light_grey};
% AllColors2 = { dark_purple ; dark_purple ; dark_orange ; dark_orange ;mid_dark_green;mid_dark_green;   grey    ; green ; crimson ; orange ;  orange ; light_grey};
% LineStyles:
AllStyles2 = {   solid     ;  vanishing  ;    solid    ;  vanishing  ;   solid   ; vanishing ; vanishing ;    solid    ;  solid  ;  solid ;vanishing;    solid  };

% Merging
AllCat = [AllCat1 ; AllCat2];
AllColors = [AllColors1 ; AllColors2];
AllStyles = [AllStyles1 ; AllStyles2];

% Merging all three columns into "HLCplotstyle";
HLCplotstyle = [AllCat AllColors AllStyles];

% OLD list
% AllCat = {'B';'B/R+';'B/R-';'R+';'R-';'Ds';'Dn';'Dm';'A';'N';'J+';'J-';'TD+';'TD-';'TA';'TN';'F';'Jb+';'Jb-';'n/a'};



%% History %%

% 03/04/2015: 2.2
% - custom_cyan became custom_blue because too visible
% - changed colors to match paper being written (20/04/2015)
% - changed colors to match paper being written (29/04/2015)

% 26/03/2015: 2.1
% - replaced categories A by A+,A-, TA by TA-, N by N+,N- and TN by TN+. Note that A- = old A and N+ = old N.
% NB: there is no TA+ (resp TN-) since the cells has disappeared (resp appeared), Half-links created between remaining
% (preexisting) cells 
% - turned B into G
% - changed G/R+,- color to custom_cyan from light_red since it always involves existing links in blue that shift to
% lighter blue from mid_blue (B/R+ case), or the opposite (B/R- case)
% - removed commented old colors

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% INTRODUCTION OF A+/-, N+/-, TA- and TN+ (TA 2.1+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 04/03/2015: 2.0 changed name to HLCplotstyleMaker
% - now only defines "AllCat" with all possible categories, namely including Jb+/-
% - removed argument "TA_Grid" accordingly

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NEW FRAMEWORK RENORMALIZATION (TA 2.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 13/06/2013: 1.3
% - changed colors of R+/R-, A, and TA

% 17/01/2012: 1.2
% - added "HL_styles" as input

% 11/01/2012: 1.1
% - added "TA_Grid" as input
% - adding Jb+/- contributions (mid_custom_magenta) for grid support
% - changed A color to custom yellow
% - changed B/R color to custom_cyan 
% - Jb to turquoise

% 21/11/2011: creation