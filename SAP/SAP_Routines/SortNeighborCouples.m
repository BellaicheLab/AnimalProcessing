function [sortedNeighborCoupleANs, neighborCouples1Sorted, neighborCouples2Sorted] = SortNeighborCouples(neighborCoupleANs)
%
% [sortedNeighborCoupleANs, neighborCouples1Sorted, neighborCouples2Sorted] = SortNeighborCouples(neighborCoupleANs)
%
% Sorting couples of ANs listed "neighborCoupleANs" according to smaller root ANs, THEN according to
% smaller division tags in successive columns. Obvioulsy, also works with RNs.
%
% Version 1.1
% Boris Guirao


%% Code %%

nRow = size(neighborCoupleANs,1);
nCol = size(neighborCoupleANs,2)/2;

neighborCouple1 = neighborCoupleANs(:,1:nCol);
neighborCouple2 = neighborCoupleANs(:,nCol+1:2*nCol);

deltaNeighborCouples = neighborCouple2 - neighborCouple1;
deltaNeighborCouplesBare = deltaNeighborCouples(:,1);

% finds where its is NEGATIVE AND NULL
neighborCouples1Sorted = neighborCouple1;
neighborCouples2Sorted = neighborCouple2;

% negative:
deltaNegTF = deltaNeighborCouplesBare < 0;

if any(deltaNegTF)
    
    % switching ANs from columns 1 & 2
    neighborCouples1Sorted(deltaNegTF,:) = neighborCouple2(deltaNegTF,:);
    neighborCouples2Sorted(deltaNegTF,:) = neighborCouple1(deltaNegTF,:);
end

% null
deltaNullTF = deltaNeighborCouplesBare == 0;

if any(deltaNullTF)
    
    deltaDoneTF = false(nRow,1);
    deltaDoneTF(~deltaNullTF) = true; % tags the non-zero deltas as done
    
    for c = 2:nCol
        
        deltaDivTags = deltaNeighborCouples(:,c);
        
        % NOT touching when daughter/cousin with lowest divTag is listed first (1.1)
        deltaPosTF = deltaDivTags > 0; %
        deltaDoneTF = any([deltaDoneTF deltaPosTF],2); % updating deltaDoneTF accordingly
        
        % Swapping the ones whose lowest divTag is listed second:
        deltaNegTF = deltaDivTags < 0;
        deltaNegTF = all([deltaNegTF ~deltaDoneTF],2); % only does those NOT done
        
        if any(deltaNegTF)
            
            % switching ANs from columns 1 & 2
            neighborCouples1Sorted(deltaNegTF,:) = neighborCouple2(deltaNegTF,:);
            neighborCouples2Sorted(deltaNegTF,:) = neighborCouple1(deltaNegTF,:);
            
            % updates "deltaDoneTF"
            deltaDoneTF = any([deltaDoneTF deltaNegTF],2);
        end
    end
end

sortedNeighborCoupleANs = [neighborCouples1Sorted neighborCouples2Sorted];


%% History %%

% 06/12/2017:
% - added "neighborCouples1Sorted", "neighborCouples2Sorted" as outputs

% 01/03/2017: 1.1
% - removed "ANs" everywhere (including the name of the function) since can work for RNs as well

% 28/02/2017: creation

