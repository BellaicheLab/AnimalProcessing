function indSideDilated  = SideDilator(imageSize, indSide, dilValue, conn)
%
% indSideDilated  = SideDilator(imageSize, indSide, value)
%
% will dilate initial side made up by indices "indSide" of "dilValue" layers of pixels.
%
% INPUTS: image size (1x2 vector), list of indices (COLUMN VECTOR!) making up the side to
% dilate(indSide), number of pixels to add around initial side
%
% OUTPUTS: list of indices making up the dilated side "indSideDilated"
%
% Version 1.5
% Boris Guirao; Stephane Rigaud

%% Code

% allIndSideDilated = indSide;

if ~exist('conn','var')
    conn = 8;
end

nPix = length(indSide);
allIndSideDilatedMat = zeros(6*dilValue*nPix,dilValue+1);  % 
allIndSideDilatedMat(1:nPix,1) = indSide;

% inSideDilatedArray = cell(value+1,1);
% inSideDilatedArray{1} = indSide;

for dil = 1:dilValue                                                          % dilatation of pixels made one layer after another
    
    nPix = length(indSide);
    [sideI, sideJ] = ind2sub(imageSize,indSide);
    sideIJ = [sideI sideJ];
    
    % dilatation:
    dilateOnePix = ones(nPix,1);
    sideIplus = sideI + dilateOnePix;
    sideIminus = sideI - dilateOnePix;
    sideJplus = sideJ + dilateOnePix;
    sideJminus = sideJ - dilateOnePix;
    
    if conn == 4
        % new pixels (starting right, finishing upper, rotating clockwise = 4 position)
        one = [sideI sideJplus];
        two = [sideIplus sideJ];
        three = [sideI sideJminus];
        four = [sideIminus sideJ];
        % merging all pixels together making up the dilated side:
        sideIJdilated = unique([sideIJ ; one ; two ; three ; four ], 'rows');
        sideIdilated = sideIJdilated(:,1);
        sideJdilated = sideIJdilated(:,2);
    else
        % new pixels (starting right, finishing upper right, rotating clockwise = 8 position)
        one = [sideI sideJplus];
        two = [sideIplus sideJplus];
        three = [sideIplus sideJ];
        four = [sideIplus sideJminus];
        five = [sideI sideJminus];
        six = [sideIminus sideJminus];
        seven = [sideIminus sideJ];
        eight = [sideIminus sideJplus];
        % merging all pixels together making up the dilated side:
        sideIJdilated = unique([sideIJ ; one ; two ; three ; four ; five ; six ; seven ; eight], 'rows');
        sideIdilated = sideIJdilated(:,1);
        sideJdilated = sideIJdilated(:,2);
    end
    

    
    % removes pixels out of image (1.2):
    rowsIoutTF = sideIdilated > imageSize(1) | sideIdilated <= 0;
    rowsJoutTF = sideJdilated > imageSize(2) | sideJdilated <= 0;
    rows2KeepTF = ~any([rowsIoutTF rowsJoutTF],2);
    
    % crops sideI/Jdilated to indices kept:
    sideIdilated = sideIdilated(rows2KeepTF);
    sideJdilated = sideJdilated(rows2KeepTF);
    
    % Getting linear indices
    indSideDilated = sub2ind(imageSize, sideIdilated, sideJdilated);
    
    % Determining indices that were NOT already in "indSide"
    indSideNew = setdiff(indSideDilated, indSide);
    
    % Storage in "allIndSideDilated"
    nNewIndices = length(indSideNew);
    allIndSideDilatedMat(1:nNewIndices,dil+1) = indSideNew;
    % VERY SIMILAR EXECUTION TIME BELOW:
%     allIndSideDilated = [allIndSideDilated ; indSideNew]; %#ok<AGROW>
%    %   OR
%     inSideDilatedArray{dil+1} = indSideNew;

    indSide = indSideNew; % update of "indSide" for next iteration
end

allIndSideDilated = RemoveZeros(allIndSideDilatedMat(:));
% allIndSideDilated = cell2mat(inSideDilatedArray);
indSideDilated = unique(allIndSideDilated);

%% History

% 26/04/2018: 1.5 (stephane)
% - add 4-conn option (default is 8-conn)

% 22/01/2018: 1.4
% NB: when commenting the filling of "allIndSideDilated" in the loop, goes from 7.5s to 3.5s!!!
% - tried several ways to fill it, but they all seem equivalently slow
% - removed outputs I,J corresponding to "indSideDilated"

% 22/01/2018: 1.3
% - NB: went from 8.5 to 7.5s (tested by performing background removal wt2NEw on frames #8,9 on my MacBookPro)...
% - to achieve this, went back to linear indices (rather than I,J)

% 22/01/2018: 1.2 
% - NB: went from 11s to 8.5s (tested by performing background removal wt2NEw on frames #8,9 on my MacBookPro, intDilati)...
% - to achieve this, when iterating, NOW only dilates NEW pixels that were just created during previous iteration
% - now mostly works on IJ couples rather than linear indices

% 09/06/2016: became "SideDilator"

% 09-10/06/2010: creation