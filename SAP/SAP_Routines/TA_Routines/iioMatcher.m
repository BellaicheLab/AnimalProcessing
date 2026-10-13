function [ios, iioMatch] = iioMatcher(is, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs)
%
% [ios, iioMatch] = iioMatcher(is, Correspondence, CorrespondenceOLD, daughterRNs, coalescedRNs)
%
% From a list of cell RNs "is", the program will find all regions in previous OLD frame "ios" that contain all ANVS listed
% in regions "is" in CURRENT frame, including mothers of daughters listed in "is" that just appeared in CURRENT frame.
% Also returns "iioMatch" = [i io1 ; i io2 ; i' io1' ; ...], with io = 0 when i is NEW
%
% Version 1.5 (formerly "RN_Match_Old")
% Boris Guirao


%% Code %%

% Splitting is into daughters and non-daughters:    
isD = intersect(is, daughterRNs);                                       % daughters RNs among "is"

% Getting daughter ANVS and generating corresponding mother ANVS:
if ~isempty(isD)
    isDloc = ismember(Correspondence(:,1), isD);
    isDaNsMatch = Correspondence(isDloc,:);                             % lists all ANVS of region "is_d"
    isDvect = isDaNsMatch(:,1);
    isDaNs = isDaNsMatch(:,2:end);
    misDaNs = MakeMothers(isDaNs);                                      % "misDaNs" and "isDaNs" have exact same size
    if any(ismember(isD, coalescedRNs))
        mdisDaNs = [misDaNs ; isDaNs];                                  % RE-adds list of ANVS of daughters because not all cells
        isDvect = [isDvect ; isDvect];                                  % coalesced in "is" are daughters that just appeared!! (1.3)
    else
        mdisDaNs = misDaNs;                                             % "isDvect" remains unchanged here                                                                                 
    end
    isND = setdiff(is,isD);                                             % Builds complementary list of non-daughter "is"
else
    isND = is;
    isDvect = [];
    mdisDaNs = [];
end

% Getting non-dauther ANVS:
isNDloc = ismember(Correspondence(:,1), isND); 
isNDaNsMatch = Correspondence(isNDloc,:);    
isNDvect = isNDaNsMatch(:,1);
isNDaNs = isNDaNsMatch(:,2:end);

% ANVS to look for:
isANs2lookFor = [mdisDaNs ; isNDaNs];
isVect = [isDvect ; isNDvect];

% "iios_match":
[~,iosLoc] = ismember(isANs2lookFor, CorrespondenceOLD(:,2:end),'rows'); % for each "isANVS_tolookfor" line, gets highest index in
                                                                         % "CorrespondenceOLD(:,2:end)" where ANVS was found (only one index)
                                                                                                                        
zeroTF = iosLoc == 0;                                                    % look for cells not found = NEW cells                                                                                      
iosLocMod = iosLoc;
iosLocMod(zeroTF) = 1;                                                   % replaces 0 indices with 1 by default to avoid error
iioMatch = [isVect CorrespondenceOLD(iosLocMod,1)];
iioMatch(zeroTF, 2) = 0;                                                 % now puts back ios of NEW cells to 0s
iioMatch = sortrows(iioMatch,1);                                         % sorts in ascending order of is

% "ios":
ios = unique(iioMatch(:,2));                                             % only keep one occurrence of "ios"
ios = ios(ios > 0);                                                      % removes 0 from "ios", if any

                                                                                                               
                                                                                                                        
%% History %%

% 19/12/2017: 1.5 changed name to "iioMatcher"
% - adjustments to use "MakeMothers" instead of "Mother_Maker"
% - updated variable names
% - removed commented part

% 26/11/2011: 1.4
% changed name to "iio_Matcher"

% 24/11/2011: creation,1.3
% - fixed bug when "is" contained a new daughter (one RN listed in "Daughter_cells") coalesced with another cell that is
% not a dauhgter that just appeared in this frame (ONLY mother ANVS were looked for before, now both mothers AND
% daughters ANVS are).

% 16/11/2011: creation,1.2
% - added output "iios_match" without using any loop!

% 15/11/2011: creation,1.1
% - possibility to process a list of RNs now
