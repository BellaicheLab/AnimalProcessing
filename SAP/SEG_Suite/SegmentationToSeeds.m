function [seed] = SegmentationToSeeds(I, n)

seed = zeros(size(I));
Idil = imerode(I, strel('disk', n) );
% shrink = bwmorph(Idil, 'shrink', Inf); %shrink regions towards points
seed(Idil>0) = 1;

end

