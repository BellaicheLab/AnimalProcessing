function [is, ioiMatch] = ioiMatcher(ios, Correspondence, CorrespondenceOLD, dividingRNsOLD)
%
% [is, ioiMatch] = ioiMatcher(ios, Correspondence, CorrespondenceOLD, dividingRNsOLD)
%
% From a list of cell RNs "ios", the program will find all regions in CURRENT frame "is" that contain all ANs listed
% in regions "ios" in OLD frame, including daughters of mothers listed in "ios" that just divided between OLD and
% CURRENT, and that belong to "dividingRNsOLD" (that lists RNs of cells dividing between n-1 and n).
% Also returns "ioiMatch" = [io i1; io i2 ; io' i1' ; ...], with i = 0 when i is APOPTOTIC
%
% Version 2.0
% Boris Guirao


%% Code %%

% Splitting "ios" into mother and non-mothers:
iosMothers = intersect(ios,dividingRNsOLD); % ios that are mother cells in OLD and that will be divided in CURRENT frame

% Getting mother ANs and generating corresponding daughter ANs:
if ~isempty(iosMothers)
    
    % Getting corresponding ANs:
    iosMotherTF = ismember(CorrespondenceOLD(:,1), iosMothers);
    iosMothersANsMatch = CorrespondenceOLD(iosMotherTF,:);
    % NB: iosMothers cannot correspond to coalesced ANs, otherwise they
    % would NOT be listed as dividing!
    
    % Builds "iosMothersVect" by duplicating mother RNs (overhaul 2.0)
    iosMothersVect = [iosMothersANsMatch(:,1) ; iosMothersANsMatch(:,1)];   % ex: [12 ; 23 ; 42 ; 12 ; 23 ; 42 ]
    % Generating "iosMothers" AN daughters
    iosMothersANs = iosMothersANsMatch(:,2:end);
    [iosD1ANs, iosD2ANs] = MakeDaughters(iosMothersANs);        % NB: those "iosMothersANs" ARE dividing => EACH daughter ANs CAN be generated !
    iosD12ANs = [iosD1ANs ; iosD2ANs];                          % stacking daughter ANs
    % Reassociating mother RNs with corresponding daugther ANs on same row:
    iosMothersVectD12ANs = [iosMothersVect iosD12ANs]; 
    % Resorting rows according to increasing "iosMothers", thereby putting sisters in successive rows:
    iosMothersVectD12ANs = sortrows(iosMothersVectD12ANs,1);  
    % Reseparating "iosMothers" RNs from corresponding daughter ANs:
    iosMothersVect = iosMothersVectD12ANs(:,1);                             % ex: [12 ; 12 ; 23 ; 23 ; 42 ; 42]
    iosD12ANs = iosMothersVectD12ANs(:,2:end);
    
    % OLD
%     % Builds "iosMothersVect" by duplicating mother RNs:
%     iosMothersVect = [iosMothersANsMatch(:,1) iosMothersANsMatch(:,1)]; 	% [12 12 ; 23 23 ; 42 42]
%     nios = sum(iosMotherTF);
%     iosMothersVect = reshape(iosMothersVect',2*nios,1);                	% [12 ; 12 ; 23 ; 23 ; 42 ; 42]
%     iosMothersANs = iosMothersANsMatch(:,2:end);
%     [iosD1ANs, iosD2ANs, noDaughterTF] = MakeDaughters(iosMothersANs);  	% 1.3
%     iosD1ANs = iosD1ANs(~noDaughterTF,:);                                 % removing rows of NaNs where daughters could NOT be generated (1.3)
%     iosD2ANs = iosD2ANs(~noDaughterTF,:);                                 % 1.3
%     iosD12ANs = [iosD1ANs ; iosD2ANs];                                    % restacking daughters ANs (1.3)
     
else
    iosMothersVect = [];
    iosD12ANs = [];
end

% Getting non-mother ANs:
iosNonMothers = setdiff(ios,iosMothers);                                          % Builds complementary list of non-mother "ios"
iosNonMothersTF = ismember(CorrespondenceOLD(:,1), iosNonMothers); 
iosNonMothersANsMatch = CorrespondenceOLD(iosNonMothersTF,:);
iosNonMothersVect = iosNonMothersANsMatch(:,1);
iosNonMothersANs = iosNonMothersANsMatch(:,2:end);

% ANs to look for:
iosVect = [iosMothersVect ; iosNonMothersVect];
iosANs2lookFor = [iosD12ANs ; iosNonMothersANs];

% "ioiMatch":
[isFoundTF,isLoc] = ismember(iosANs2lookFor, Correspondence(:,2:end),'rows');
% NB: for each "iosANs2lookFor" line, gets highest index in "Correspondence(:,2:end)" where ANs was found (only one index)

% Determining "isVect" matching "iosVect" (overhaul 2.0)
n = length(iosVect);      
isVect = zeros(n,1);                                        % initialization                                                                        
isLoc = isLoc(isFoundTF);                                   % removing 0s of unfound iosANs = APOPTOTIC/GONE OUT cells
isVect(isFoundTF) = Correspondence(isLoc,1);                % filling is when found, leaving 0s when unfound (APOPTOTIC/GONE OUT cells)   
ioiMatch = [iosVect isVect];
ioiMatch = sortrows(ioiMatch,1);                          	% sorts in ascending order of ios

% OLD (commented 2.0)                                                                       
% zeroTF = isLoc == 0;                                                     % look for cells not found = APOPTOTIC/GONE OUT cells                                                                                     
% isLocMod = isLoc;
% isLocMod(zeroTF) = 1;                                                    % replaces 0 indices with 1 by default to avoid error
% ioiMatch = [iosVect Correspondence(isLocMod,1)];
% ioiMatch(zeroTF, 2) = 0;                                                 % now puts back is of APOPTOTIC/GONE OUT cells to 0s
% ioiMatch = sortrows(ioiMatch,1);                                         % sorts in ascending order of ios

% "is":
is = unique(ioiMatch(:,2));                                              % only keep one occurrence of "is"
is = is(is > 0);                                                         % removes 0 from "is", if any
                                                                                                                  
                                                                                                                        
%% History %%

% 26/07/2018: 2.0
% - fixed major MISTAKE where daughter ANs were stacked in a sloppy way,
% NOT matching their mother RNs in each row, therebey leading to NON
% matching daughter RNs in "ioiMatch" matrix!!! This was due to a bad use
% of "MakeDaughters" ouputs, that provides separate matrices of sisters set
% #1 and sisters set #2, as opposed to "Daughter_Maker" that used to yield
% sister ANs in consecutive rows.
% - also improved other parts of the code

% 19/12/2017: 1.3 changed name to "ioiMatcher" 
% - adjustments to use "MakeDaughters" instead of "Daughter_Maker"
% - updated variable names
% - removed commented part

% 26/11/2011: 1.2
% changed name to "ioi_Matcher" from "RN_Match"

% 16/11/2011: 1.1
% - added "kosk_match"

% 15/11/2011: creation
% - possibility to process a list of RNs now
