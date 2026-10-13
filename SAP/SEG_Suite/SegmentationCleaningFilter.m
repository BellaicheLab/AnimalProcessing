%% Cleanning filter %%
% Iterate over segmented image to identify region with only one or two neighbors
% and remove them until no more can be found or it reach the maximum iteration
% criteria.
%
% 25/04/2018 - Boris Guirao, Stephane Rigaud
%
version = '2.0';
%

% Initialize output folder
if ~exist(tmpPathFolderOUT,'dir'), mkdir(tmpPathFolderOUT); end
nRoundsMax = 10;

% Initialize log txt file (1.1)
txtFilename = [tmpPathFolderOUT filesep 'P1CellFilter_fixed_frames_#' num2str(startFrame) '_' num2str(finalFrame) '.txt'];
dlmcell(txtFilename, {});


%% Frame iteration
for n = startFrame:finalFrame
    
    % I/O file name
    segFilenameIN = [tmpPathFolderIN filesep filename num2str(n, digitsFormat) '.' imageFormat];    % 1.2
    segFilenameOUT = [tmpPathFolderOUT filesep filename num2str(n, digitsFormat) '.' imageFormat];  % 1.2
    
    if ~exist(segFilenameOUT,'file') % only process frame if its filtered version has NOT been generated yet
        
        % initialize max iteration criteria
        iteration = 0;
        
        %% Determination of image neighbors %%
        
        % read input binary image
        In = double(imread(segFilenameIN));   % input read
        imWasFixed = false;
        imsize = size(In);
        
        % region labeling and categorisation
        InLabels = bwlabel(In, 4);
        
        % identify border regions
        InBorderless = imclearborder(In, 4);
        regBorderRNs = unique(InLabels(~InBorderless));
        
        % get number of neighbors per region
        [Centroids,Neis] = imRAG(InLabels);   % bottle neck processing cost
        [regNumbNeighbors, RegRNs] = hist(Neis(:),unique(Neis(:)));
        
        % count number of 1-neighbors region
        oneNeighborRegRNsTF = (regNumbNeighbors == 1)';
        oneNeighborRegRNs = RegRNs(oneNeighborRegRNsTF);
        oneNeighborRegRNs = setdiff(oneNeighborRegRNs, regBorderRNs);
        nOneNeighborRegRNs = length(oneNeighborRegRNs);
        
        % count number of 2-neighbors region
        twoNeighborRegRNsTF = (regNumbNeighbors == 2)';
        twoNeighborRegRNs = RegRNs(twoNeighborRegRNsTF);
        twoNeighborRegRNs = setdiff(twoNeighborRegRNs, regBorderRNs);
        nTwoNeighborRegRNs = length(twoNeighborRegRNs);
        
                
        %% While TwoNeigbors remain or reach max iteration
        while (nTwoNeighborRegRNs > 0 || nOneNeighborRegRNs > 0) && iteration < nRoundsMax
            
            fprintf(['\nProcessign frame # ' num2str(n) ': round # ' num2str(iteration) '\n'])
            iteration = iteration + 1; % Update while conditions
            
            
            %% Removal of regions having ONE neighbors
            if ~isempty(oneNeighborRegRNs)
                
                disp(['Found ' num2str(nOneNeighborRegRNs) ' 1-neighbors regions and eliminating them...' ]);
                imWasFixed = true;
                
                for r = 1:nOneNeighborRegRNs
                    % get region neighbors list
                    rOne = oneNeighborRegRNs(r);
                    [row, ~] = find(Neis == rOne);
                    neiReg = Neis(row,:);
                    neiReg(neiReg == rOne) = [];                   
                    % get region pixel list
                    rOnePixel = find(InLabels == rOne);
                    rOneDil = SideDilator(imsize, rOnePixel , 1, 4);
                    % get neighbor pixel list
                    rOneNeiPixel = find(InLabels == neiReg);
                    rOneNeiDil = SideDilator(imsize, rOneNeiPixel , 1, 4);
                    % get merge region-neighbor pixel list
                    OneBorderSharedPixels = rOneDil(ismember(rOneDil, rOneNeiDil));
                    InOneNeiDilMerge = unique([rOnePixel ; rOneNeiPixel ; OneBorderSharedPixels]);
                    % apply merging
                    InLabels(InOneNeiDilMerge) = neiReg;
                end
            else
                disp('No 1-neighbors regions were found')
            end
            
            
            %% Removal of regions having TWO neighbors
            if ~isempty(twoNeighborRegRNs)
                
                disp(['Found ' num2str(nTwoNeighborRegRNs) ' 2-neighbors regions and eliminating them...' ]);
                imWasFixed = true;
                InTwoNeiDilMerge = cell(2,1);
                twoBorderSharedPixels = cell(2,1);
                rTwoNeiDil = cell(2,1);
                rTwoNeiPixel = cell(2,1);
                nSharedPixels = zeros(2,1);
                for r = 1:nTwoNeighborRegRNs
                    % get region neighbors list
                    rTwo = twoNeighborRegRNs(r);
                    [row,~] = find(Neis == rTwo);
                    neiRegList = Neis(row,:);
                    neiRegList(neiRegList == rTwo) = [];
                    % get region pixel list
                    rTwoPixel = find(InLabels == rTwo);
                    rTwoDil = SideDilator(imsize, rTwoPixel , 1, 4);
                    % get neighbor 1 pixel list
                    rTwoNeiPixel{1} = find(InLabels == neiRegList(1));
                    rTwoNeiDil{1} = SideDilator(imsize, rTwoNeiPixel{1} , 1, 4);
                    % get neighbor 2 pixel list
                    rTwoNeiPixel{2} = find(InLabels == neiRegList(2));
                    rTwoNeiDil{2} = SideDilator(imsize, rTwoNeiPixel{2} , 1, 4);
                    % sort neighbors per maximum adjacency
                    twoBorderSharedPixels{1} = rTwoDil(ismember(rTwoDil, rTwoNeiDil{1}));
                    twoBorderSharedPixels{2} = rTwoDil(ismember(rTwoDil, rTwoNeiDil{2}));
                    nSharedPixels(1) = numel(twoBorderSharedPixels{1});
                    nSharedPixels(2) = numel(twoBorderSharedPixels{2});
                    [~,maxIdx] = max(nSharedPixels);
                    % get merge region-neighbor pixel list
                    InTwoNeiDilMerge = unique([rTwoPixel ; rTwoNeiPixel{maxIdx}; twoBorderSharedPixels{maxIdx}]);
                    % apply merging
                    InLabels(InTwoNeiDilMerge) = neiRegList(maxIdx);
                end
            else
                disp('No 2-neighbors regions were found')
            end
            
            %% Update number of neighbors per region           
            if imWasFixed
                % backup Neighbors couple
                oldNeis = Neis;
                % remove from couple list any couple containing a label that was deleted
                deletedLabels = [twoNeighborRegRNs; oneNeighborRegRNs];
                AffectedNeisIdx = any(ismember(Neis,deletedLabels),2);
                Neis(AffectedNeisIdx,:) = [];
                % recount number of neighbors per label
                [regNumbNeighbors, RegRNs] = hist(Neis(:),unique(Neis(:)));
                % count number of 1-neighbors region
                oneNeighborRegRNsTF = (regNumbNeighbors == 1)';
                oneNeighborRegRNs = RegRNs(oneNeighborRegRNsTF);
                oneNeighborRegRNs = setdiff(oneNeighborRegRNs, regBorderRNs);
                nOneNeighborRegRNs = length(oneNeighborRegRNs);
                % count number of 2-neighbors region
                twoNeighborRegRNsTF = (regNumbNeighbors == 2)';
                twoNeighborRegRNs = RegRNs(twoNeighborRegRNsTF);
                twoNeighborRegRNs = setdiff(twoNeighborRegRNs, regBorderRNs);
                nTwoNeighborRegRNs = length(twoNeighborRegRNs);
            end
            
        end
        
        %% Output cleaning %%
        In(InLabels>0) = true;
        In = ~watershed(~In,4);
        
        %% Saving Fixed image %%
        
        % saving image, even untouched in order to have a complete set of segmented images
        segFilenameFixed = [tmpPathFolderOUT filesep filename num2str(n,digitsFormat) '.' imageFormat];
        imwrite(~In, segFilenameFixed);
        
        % updating log file for traceability
        if imWasFixed
            disp('Updating Execution log file...')
            fullText =  {num2str(n,digitsFormat)};
            dlmcell(txtFilename, fullText,'-a');
        end
        
    else
        fprintf(['\nP1 filtered version of frame # ' num2str(n) ' was found => skipping...\n'])
    end
end

%% History %%

% Improvement:
% - verify first layer region impact ?
% - speed up dilate/erode filter approach ?

% 25/04/2018: 2.0 (stephane)
% - remove usage of SkeletonPixelList and therefor usage of tracking, compute neighbors using
%   Region Adjacency Graph (RAG) and fuse region using dilate/erode filter

% 07/02/2017: 1.3 (stephane)
% - include the filter inside the script pipeline process
% - add an exception for first layer cells

% 03/07/2016: 1.2
% - only allowing nRoundsMax rounds to fix newly generated 2-neighbor regions (otherwise takes forever just to remove a couple of them)
% - now only processs a frame IF its P1 filtered version was NOT found.

% 01/07/2016: 1.1
% - redetermination of "SkeletonPixelList" by Matlab (in parallel) when txt file not available OR when additional rounds of correction are required
% - for 2-neighbor elimination, erased part based on region size: now based on the amount of shared contour (=> much more accurate elimination)
% - save log of corrected images

% 30/06/2016: creation 1.0
