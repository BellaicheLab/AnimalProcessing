%% ITK to Matlab Unionseg cleaner
% so far, itk does not provide a way to skeletonise the segmentation in
% 8-connectity, but only 4-connectity. Also, matlab has a unconventional way
% to save 8bit png into 8bit-rgb png. For compatibility purposes, this script
% take itk generated unionseg and process them to fit matlab way (which is 
% not the good way!)
% In future, we should solve this in order to fit the general way.
% 
% 31/01/2018 by Stephane Rigaud - v1
%

%% load all unionseg files
unionList = dir(pathFolderRES);
unionList(strncmp({unionList.name}, '.', 1)) = [];                          % remove trash files
ind = cellfun(@(x)( ~isempty(x) ), regexpi({unionList.name}, 'png')); % find files that match the regexp
unionList(~ind) = [];

%% Loop over each files
parfor i = 1:length(unionList)
    unionSeg = imread([pathFolderRES filesep unionList(i).name]);
    unionSeg = imcomplement(unionSeg);
    unionSeg = bwmorph(unionSeg, 'skel', Inf);
    unionSeg = imcomplement(unionSeg);
    imwrite( unionSeg, [pathFolderRES filesep unionList(i).name] );
end