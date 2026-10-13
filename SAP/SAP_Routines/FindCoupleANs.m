function [foundCoupleANs, foundCoupleANsTF] = FindCoupleANs(neighborCOUPLES,type)
%
% [foundCoupleANs, foundCoupleANsTF] = FindCoupleANs(neighborCOUPLES,type)
%
% Finds couples of ANs in "neighborCoupleANs" according to specified "type" ("sisters", "offspring" or "delamination").
% Output boolean "foundCoupleANsTF" is such that foundCoupleANs = neighborCOUPLES.allNewCoupleANs(foundCoupleANsTF,:);
%
% Version 1.3
% Boris Guirao


%% Code %%

allNewCoupleANs = neighborCOUPLES.allNewCoupleANs; % now loading "allNewCoupleANs" from structure "neighborCOUPLES" (1.2)

nRow = size(allNewCoupleANs,1);
nCol = size(allNewCoupleANs,2)/2;

% Splitting ANs from each couple ANs:
[allNewCoupleANs1, allNewCoupleANs2] = SplitCoupleANs(allNewCoupleANs); % 3.31

lastFilledColLoc1 = sum(logical(allNewCoupleANs1),2);
lastFilledColLoc2 = sum(logical(allNewCoupleANs2),2);

deltaLastFilledColLocs = abs(lastFilledColLoc2 - lastFilledColLoc1);
deltaNeighborCoupleANs = abs(allNewCoupleANs2 - allNewCoupleANs1);
% NB: sister ANs will ONLY have a difference of 1 at their last index

sameBareANsTF = ~logical(deltaNeighborCoupleANs(:,1));
% NB: 1s where same Bare ANs => found all sisters and cousins

if strcmp(type,'sisters')
    
    deltaTF = logical(deltaNeighborCoupleANs);
    
    oneAsTotalDeltaTF = sum(deltaTF,2) == 1;
    % NB: 1s where sum of logicals was 1 => true for sisters, but also for some cousins and some ANs with same division tag
    
    sameLastIndices = ~logical(deltaLastFilledColLocs);
    % NB: 1s on rows corresponding to couples having same number of division rounds => true for sisters and cells with same
    % number of divisions
    
    lastFilledColLinearIndices1 = sub2ind([nRow nCol],(1:nRow)', lastFilledColLoc1);
    lastIndexValues = deltaTF(lastFilledColLinearIndices1);
    
    oneAtLastIndexTF = lastIndexValues;
    % NB: for sisters, lastIndices1 = lastIndices2
    
    % combining all criteria:
    sisterANsTF = all([sameBareANsTF oneAsTotalDeltaTF oneAtLastIndexTF  sameLastIndices],2);
    
    % retreving sisters:
    foundCoupleANs = allNewCoupleANs(sisterANsTF,:);
    foundCoupleANsTF = sisterANsTF; % 1.1
    
elseif strcmp(type,'offspring')
    
    offspringANsTF = sameBareANsTF;                         % only uses comparision of Bare ANs and keep all ANs having the same
    foundCoupleANs = allNewCoupleANs(offspringANsTF,:);
    foundCoupleANsTF = offspringANsTF; % 1.1
    
elseif strcmp(type,'delamination') % determining new ANs couples resulting of the death of a common neighbor (1.2)
    
    % Extracting quantities from "neighborCOUPLES"
    n = neighborCOUPLES.n;
    allLastFramesDel = neighborCOUPLES.allLastFramesDel;
    allDelaminatingLastRNs = neighborCOUPLES.allDelaminatingLastRNs;
    oldCellNeighborRNs = neighborCOUPLES.cellNeighborsOld;
    oldCorrespondence = neighborCOUPLES.CorrespondenceOld;
    allNewFrames = neighborCOUPLES.allNewFrames;
    % 1.3
    newDivCouplesTF = neighborCOUPLES.newDivCouplesTF;
    allDividingANs = neighborCOUPLES.allDividingANs;
    allLastFramesDiv = neighborCOUPLES.allLastFramesDiv;
    
    if isfield(neighborCOUPLES,'newDelCouplesTF')
        delCouplesTF = neighborCOUPLES.newDelCouplesTF; % about to be updated
        indDelCouples = find(delCouplesTF);
    else
        indDelCouples = [];
    end
    % reproduces vector pointing out couples formed by DEL and extends it to nRow
    delCouplesExtendedTF = false(nRow,1);  
    delCouplesExtendedTF(indDelCouples) = true;
    
    justAppearedCoupleANsTF = allNewFrames == n; % spotting junctions that JUST appeared
    
    justDelaminatedTF = allLastFramesDel == n-1;                                    % rows of cells that were there in n-1, NOT in n
    justDelaminatedOldRNs = allDelaminatingLastRNs(justDelaminatedTF);              % corresponding RNs from frame n-1
    neighborRNsOfjustDelaminatedOldRNs = oldCellNeighborRNs(justDelaminatedOldRNs);
    neighborANsOfjustDelamiatedOldRNs = cellfun(@(RNs) RNs2ANs(RNs',oldCorrespondence), neighborRNsOfjustDelaminatedOldRNs,'UniformOutput',false); % replacing RNs with ANs
    
    % finds ANs listed among dying cell neighbors
    indNewJunctionsByDEL = cellfun(@(X)  find(all([ismember(allNewCoupleANs1,X,'rows') ismember(allNewCoupleANs2,X,'rows') justAppearedCoupleANsTF],2)),...
                                   neighborANsOfjustDelamiatedOldRNs,'UniformOutput',false);
    indNewJunctionsByDEL = unique(cell2mat(indNewJunctionsByDEL));
    
    newDelCouplesANsTF = false(nRow,1);
    newDelCouplesANsTF(indNewJunctionsByDEL) = true;
    
    %%% Updating list of DEL couples with those that divided between n-1, n (1.3)
    %---------------------------------------------------------------------------------------------------
    justDividedTF = allLastFramesDiv == n-1;                                                            % rows of mother ANs that were there in n-1, NOT in n
    [justDividedDaughterANs1,justDividedDaughterANs2] = MakeDaughters(allDividingANs(justDividedTF,:));

    D1orD2FoundAmongNewCoupleANs1TF = any([ismember(allNewCoupleANs1,justDividedDaughterANs1,'rows') ismember(allNewCoupleANs1,justDividedDaughterANs2,'rows')],2);
    D1orD2FoundAmongNewCoupleANs2TF = any([ismember(allNewCoupleANs2,justDividedDaughterANs1,'rows') ismember(allNewCoupleANs2,justDividedDaughterANs2,'rows')],2);
    
    % killing couples new by DIV (in order NOT to reassign them to DEL)
    D1orD2FoundAmongNewCoupleANs1TF(newDivCouplesTF) = false;
    D1orD2FoundAmongNewCoupleANs2TF(newDivCouplesTF) = false;
    
    mothersOfD1orD2FoundAmongNewCoupleANs1 = MakeMothers(allNewCoupleANs1(D1orD2FoundAmongNewCoupleANs1TF,:));
    mothersOfD1orD2FoundAmongNewCoupleANs2 = MakeMothers(allNewCoupleANs2(D1orD2FoundAmongNewCoupleANs2TF,:));
    
    motheredAllNewCoupleANs1 = allNewCoupleANs1;
    motheredAllNewCoupleANs1(D1orD2FoundAmongNewCoupleANs1TF,:) = mothersOfD1orD2FoundAmongNewCoupleANs1;
    motheredAllNewCoupleANs2 = allNewCoupleANs2;
    motheredAllNewCoupleANs2(D1orD2FoundAmongNewCoupleANs2TF,:) = mothersOfD1orD2FoundAmongNewCoupleANs2;
    
    motheredAllNewCoupleANs = [motheredAllNewCoupleANs1 motheredAllNewCoupleANs2];

    delCoupleANs = allNewCoupleANs(delCouplesExtendedTF,:);
    
    % Looks for delCoupleANs among "mothered" allNewCoupleANs
    foundUpdatedDelCouplesANsTF = ismember(motheredAllNewCoupleANs, delCoupleANs, 'rows');
    %---------------------------------------------------------------------------------------------------
    
    % Creating "foundCoupleANsTF" and "foundCoupleANs":
    foundCoupleANsTF = any([newDelCouplesANsTF delCouplesExtendedTF foundUpdatedDelCouplesANsTF],2);
    foundCoupleANs = allNewCoupleANs(foundCoupleANsTF,:);

else
    disp('"findCoupleANs" ERROR: "type" must eiter be "sisters", "offspring" or "delamination"!!!')
end


%% History %%

% 03/04/2019: 1.3
% - now updating list of new DEL junctions after division of cells involved
% (thereby keeping track of the DEL junctions despite divisions)

% 02/04/2019: 1.2
% - introduced the "delamination" type to find new junctions due to
% delaminations

% 05/12/2017: 1.1
% - added "foundCoupleANsTF" as output

% 02/03/2017: creation

