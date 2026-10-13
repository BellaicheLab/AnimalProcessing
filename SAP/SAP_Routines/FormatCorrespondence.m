function Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal)
%
% Correspondence = FormatCorrespondence(CorrespondenceRaw, nColTotal)
%
% Reformats Correspondence matrix that is loaded for each frame to put the right amount of column "nColTotal" based on
% C++ tracking file "max_n_divisions_".
%
% Version 1.0
% Boris Guirao


%% Code %%

nRow = size(CorrespondenceRaw,1);                   % current number of rows
nCol = size(CorrespondenceRaw,2);                   % current number of columns
Correspondence = zeros(nRow, nColTotal);            % build empty Correspondence with total number of columns
Correspondence(1:nRow,1:nCol) = CorrespondenceRaw;  % filling up new Correspondence


%% History %%

% 14/09/2017: creation