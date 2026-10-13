function [Mi, nLinks] = CalculateTexture(i, cellCategoryTags, cellNeighbors, cellVertices, cellCentroids, fourVertices)
%
% [Mi, nLinks] = CalculateTexture(i, cellCategoryTags, cellNeighbors, cellVertices, cellCentroids, fourVertices)
%
% Version 1.2
% Boris Guirao
% Isabelle Bonnet

%% Code %%

%%% Extracts cell categories:
[~, ~, ~, nonBorderRNs] = GetCellCategories(cellCategoryTags); % 1.2
% ExtractData(cellCATEGORIES,'','caller')                  % 'caller' to make extracted variables available in the FUNCTION workspace

if ismember(i,nonBorderRNs)
    
    % Extracts cell i relevant info:
    ithCellNeighbors = cellNeighbors{i};
    nNeighbors = length(ithCellNeighbors);
    ithCellVertices = cellVertices{i};
    
    % Fills up "FullLinks" and "Halflinks":
    HalfLinks=[];
    FullLinks=[];

    for k = 1:nNeighbors
        kthNeighbor = ithCellNeighbors(k);
        kthNeighborVertices = cellVertices{kthNeighbor};
        ikCommonVertices = intersect(ithCellVertices, kthNeighborVertices);                  % gets numbers of vertices shared by i and k
        if length(ikCommonVertices) == 1 && ismember(ikCommonVertices, fourVertices)
            HalfLinks = [HalfLinks; cellCentroids(i,:) cellCentroids(kthNeighbor,:)];         %#ok<*AGROW>
        else
            FullLinks = [FullLinks; cellCentroids(i,:) cellCentroids(kthNeighbor,:)];
        end
    end

    %%% Links weights:
    Links = [FullLinks; sqrt(0.5)*HalfLinks];                 % 1-weighted links first and the 1/2-weighted links
    nLinks = size(FullLinks,1)+ 0.5 * size(HalfLinks,1) ;    % total number of weighted links see eq. A3 of "Tools" (Graner et al.)
    nLinks = nLinks/2;                                      % New since SIA 12: factor 1/2
    
    %%% Quadratic Terms
    x2 = (Links(:,3) - Links(:,1)).^2;                        % (Xk-Xi)^2
    y2 = (Links(:,4) - Links(:,2)).^2;                        % (Yk-Yi)^2
    xy = (Links(:,3) - Links(:,1)).*(Links(:,4) - Links(:,2));  % (Xk-Xi)*(Yk-Yi)
    
    %%% Weighted mean
    % New in 13: EXTENSIVE texture (not dividing by Nlinks_tot anymore)
    Mxx = 1/2*sum(x2); % sum(X) sums all terms of vector X. see eq. A3 of "Tools" (Graner et al.)
    Myy = 1/2*sum(y2);
    Mxy = 1/2*sum(xy);
    Myx = 1/2*sum(xy);
    
    %%% Use of function "Tensor_Quantities" to calculate M quantities. New 1.7:
    Mi = [Mxx Mxy Myx Myy];
    
else
    Mi = [NaN NaN NaN NaN];                                              % No computation for Border cells
    nLinks = NaN;
end

%% History

% 04/05/2018: 1.2
% - replaced "cellCATEGORIES" by "cellCategoryTags" as input

% 18/01/2018: 1.1
% - added 4th component to Mi
% - loading nonBorderRNs

% 25/07/2010: creation
% - significantly simplified the code extracted from SIA 2.0v: HalfLink_Cells_ik and
% FullLink_Cells_ik turn out to be useless, and HalfLinks and FullLinks
% can be filled immediately in a more straightforward way.


