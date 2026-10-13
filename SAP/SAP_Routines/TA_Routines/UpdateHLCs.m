function [allHLC, updateTF] = UpdateHLCs(allHLC)
%
% [allHLC updateTF] = UpdateHLCs(allHLC)
%
% Will update all_HLC with new notations from HLCplotstyleMaker 2.1+. Also returns boolean updateTF = 1 if all_HLC is of
% the former type and that it needs to be updated.
% 
% OLD:
% AllCat = {'B';'B/R+';'B/R-';'R+';'R-';'Ds';'Dn';'Dm';'A';'N';'J+';'J-';'TD+';'TD-';'TA';'TN';'F';'Jb+';'Jb-';'n/a};
%
% NEW:
% AllCat = {'G';'G/R+';'G/R-';'R+';'R-';'Ds';'Dn';'Dm';'A+';'A-';'N+';'N-';'J+';'J-';'TD+';'TD-';'TA-';'TN+';'F';'Jb+';'Jb-';'n/a'};
%
% Version 1.0
% Boris Guirao


%% Assessing all_HLC and locating all changes to make %%

allBsTF = strcmp(allHLC,'B'); % looks for B, signature of all_HLC of the former type

if any(allBsTF)
    updateTF = true; % switches it to 1 if B have been found
else
    updateTF = false; % if no "B" found, means that this this all_HLC belongs to the new type, nothing to be done
    return
end

allBRpsTF = strcmp(allHLC,'B/R+');
allBRmsTF = strcmp(allHLC,'B/R-');
allAsTF = strcmp(allHLC,'A');
allTAsTF = strcmp(allHLC,'TA');
allNsTF = strcmp(allHLC,'N');
allTNsTF = strcmp(allHLC,'TN');


%% Updating with new notations%%

allHLC(allBsTF) = {'G'};
allHLC(allBRpsTF) = {'G/R+'};
allHLC(allBRmsTF) = {'G/R-'};
allHLC(allAsTF) = {'A-'};
allHLC(allTAsTF) = {'TA-'};
allHLC(allNsTF) = {'N+'};
allHLC(allTNsTF) = {'TN+'};

% NB: A+,N- appear through a different process in TA 2.1.2+.


%% History %%

% 30/03/2015: creation