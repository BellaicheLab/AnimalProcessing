function allTimeMatrixSync = SyncCellHistories(allTimeMatrix, allFirstFrames, allLastFrames, mode)
%
% allTimeMatrixSync = SyncCellHistories(allTimeMatrix, allFirstFrames, allLastFrames, mode)
%
% For any matrix "allTimeMatrix" containing values of the identity (RN) or
% the history of any cell feature (area,I,...), each row corresponding to a
% cell and each column to a frame (col # n corresponds to frame # n), this
% function will shift cell all-time data so that all cells have their first
% (mode = 'first') OR last (mode = 'last') frame of existence synchronized.
%
% *************************************************************************
% NB: only takes action if BOTH first and last frames are NOT NaN
% *************************************************************************
%
% Version 1.0
% Boris Guirao


%% Code %%

allLifeSpans = allLastFrames - allFirstFrames + 1; % life span is 1 if first = last

nRows = size(allTimeMatrix,1);      % number of columns of input and output
nCols = max(allLifeSpans);          % number of columns of OUTPUT
nLayers = size(allTimeMatrix,3);    % number of layers

allTimeMatrixSync = NaN(nRows,nCols,nLayers);

%%% Iteration over rows
for r = 1:nRows
    
    rLifeSpan = allLifeSpans(r);
    
    if ~isnan(rLifeSpan) % only takes action if both first and last frames are NOT NaN
        
        % initial matrix
        rFirstFrame = allFirstFrames(r);
        rLastFrame = allLastFrames(r);
        
        % syncrhonize cell histories in "sync" matrix
        if strcmp(mode, 'last')
            rFirstFrameSync = nCols - rLifeSpan + 1; % must be "nCols" if rLifeSpan = 1
            rLastFrameSync = nCols;
            
        elseif strcmp(mode, 'first')
            rFirstFrameSync = 1;
            rLastFrameSync = rLifeSpan;
        end
        
        allTimeMatrixSync(r,rFirstFrameSync:rLastFrameSync,:) = allTimeMatrix(r,rFirstFrame:rLastFrame,:);
    end
end

end

%% History %%

% 16/01/2018:
% - added "if ~isnan(rLifeSpan)" to skip rows involving NaNs

% 10/01/2018: creation

