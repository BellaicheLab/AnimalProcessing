function [daughterOneANs, daughterTwoANs, noDaughterTF] = MakeDaughters(motherANs)
%
% [daughterOneANs, daughterTwoANs, noDaughterTF] = MakeDaughters(motherANs)
%
% Generates matrices "daughterOneANs" and "daughterOneANs"  corresponding to matrix array "motherANs" as follows:
%
% motherANs =       [123    0     0; 
%                    345    1     0;
%                    512    2     1;
%                    609    2     0]
%
% daughterOneANs =  [123     1     0;
%                    345     1     1;
%                    NaN    NaN   NaN;
%                    609     2     1]
%
% daughterTwoANs =  [123     2     0;
%                    345     1     2;
%                    NaN    NaN   NaN;
%                    609     2     2]
%
% And logical vector "noDaughterTF" indicating rows of "motherANs" for which daughters couldn't be generated:
%
% noDaughterTF =    [0;
%                    0;
%                    1;
%                    0]
%
% Version 2.0
% Boris Guirao

%% NEW Code (2.0)%%

% Initialization:
tableSize = size(motherANs);
nMothers = tableSize(1);
ANlength = tableSize(2);

daughterOneANs = motherANs;
daughterTwoANs = motherANs;

% For each AN, finding the column to update:
motherANsTF = logical(motherANs);
cols2update = sum(motherANsTF,2)+1; % for each row, gives the column to update to make daughters
rows2update = (1:nMothers)';        % rows to update (all rows at this point)

% Excluding rows corresponding to ANs having reached max division round:
rows2skipTF = cols2update > ANlength;
cols2update = cols2update(~rows2skipTF);            % cropping
rows2update = rows2update(~rows2skipTF);
nRows2skip = sum(rows2skipTF,1);
daughterOneANs(rows2skipTF,:) = NaN(nRows2skip,ANlength);    % Filling corresponding daughter ANs with NaNs
daughterTwoANs(rows2skipTF,:) = NaN(nRows2skip,ANlength);

% Updating daugther ANs with proper division tags
ind2update = sub2ind(tableSize, rows2update, cols2update);
daughterOneANs(ind2update) = 1;
daughterTwoANs(ind2update) = 2;
noDaughterTF = rows2skipTF;         % logical vector indicating rows where daughters couldn't be generated.


%% OLD Code (1.2-)%%

% tableSize = size(motherANs);
% nMothers = tableSize(1);
% ANlength = tableSize(2);
% daughtersANs = zeros(nMothers*2,ANlength); % maximal final size
% 
% % Checking all mother ANVS have room for daughter tag (com 1.2):
% % last_column = mothers_ANVS(:,vector_size);
% % if any(last_column)
% %     disp('"Daughter_Maker" warning: ANVS of some mothers are too short to create their daughters');
% % end
% 
% % Making daughters ANVS:
% id = 0;
% for i = 1:nMothers
%     maxInd = find(motherANs(i,:), 1, 'last');
%     % last column number is 0:
%     if maxInd < ANlength
%         daughterOne = motherANs(i,:);
%         daughterTwo = motherANs(i,:);
%         daughterOne(maxInd + 1) = 1;
%         daughterTwo(maxInd + 1) = 2;
%         id = id+1;
%         daughtersANs(id,:) = daughterOne;
%         id = id+1;
%         daughtersANs(id,:) = daughterTwo;
%     % last column number is NOT 0:
%     else
%         id = id+1;
%         daughtersANs(id,:) = motherANs(i,:);                                                                       % keeps mother's number unchanged (1.1)
%     end
% end
% 
% % Croping to non-zero lines:
% zeroLinesTF = any(daughtersANs,2);
% daughtersANs = daughtersANs(zeroLinesTF,:);


%% History %%

% 10/11/2017: 2.0 complete overhaul
% - now returns two separate matrices daughterOneANs and daughterTwoANs (see help at the top)

% 18/10/2017: became "MakeDaughters"

% 01/03/2016: 1.2
% - commented warning message: "Daughter_Maker" warning: ANVS of some mothers are too short to create their daughters"

% 25/04/2012: 1.1
% - replaced error message by warning when last column of 1+ mother_ANVS contains1 or 2 and leave mother unchanged in list

% 16/11/2011: creation
