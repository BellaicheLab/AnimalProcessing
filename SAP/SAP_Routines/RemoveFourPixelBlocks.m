function [fixedImage, oldPixels] = RemoveFourPixelBlocks(image)
%
% [fixedImage, oldPixels] = RemoveFourPixelBlocks(image)
%
% Will find ANY kind of 4-pixel blocks in segmented image (using function "fourpixelblockdetector") and will resolve it.
% To proceed, it will randomly pick one of these 4 pixels and try to move it of 1 pixel (along x OR y, not diagonaly),
% without breaking the skeleton and without creating new regions of 1 pixel. An additional watershed and skeletonization
% is achieved LOCALLY, on the cropped zone around the 4pixel blocks, to provide a fixed but nevertheless perfectly normal
% "Unionseg" segmented image.
% NB: to debug, uncomment the "zone; pause;" lines in the code: it will display the successive changes made to the zone 
% being fixed.
%
% Version 1.5 (formerly "Four_Pixel_Block_Remover")
% Boris Guirao


%% Detection of 4-pixel blocks %%

image = ~image;                             % NOW WHITE MEMBRANES, BLACK CELLS
ULC_Ls = fourpixelblockdetector(image);     % gets list Linear indices of Upper Left Corner pixels of 4pixel blocks
n4PB = length(ULC_Ls);                      % number of 4PB found

if n4PB == 1
    disp('1 4-pixel block was found in the image.'); % 1.5
else
    disp([num2str(n4PB) ' 4-pixel blocks were found in the image.']);
end
% disp(' ');

imageSize = size(image);
[ULC_Is, ULC_Js] = ind2sub(imageSize, ULC_Ls);

if n4PB > 0
    oldPixels = NaN(n4PB,1);
else
    oldPixels = [];
    fixedImage = ~image;
    return
end

% pattern to avoid when moving pixel:
filter = [0  1  0;
          1 -1  1;
          0  1  0];

%% Resolving the 4-pixel block: random iteration and displacement of its pixels %%      

n4PBfixed = 0; % 1.5
zone_max_size = 6; % will try to make an extended zone of 2 + 2 pixels around = 6 pixelsn4PB
for b = 1:n4PB
    fprintf(['\nFixing block # ' num2str(b) ' ...\n']);
    zone_ULC_I = max(1, ULC_Is(b) - 2);                             % max because could fall on image border
    zone_ULC_J = max(1, ULC_Js(b) - 2);
    zone_LRC_I = min(imageSize(1), zone_ULC_I + zone_max_size - 1);    % min because could fall on image border
    zone_LRC_J = min(imageSize(2), zone_ULC_J + zone_max_size - 1);
    zone = image(zone_ULC_I:zone_LRC_I, zone_ULC_J:zone_LRC_J); % zone around this 4PB of 1 pixel thickness (16 pixels total)
    zone_size = size(zone);
    
% THIS DETERMINES WHETHER THE ZONE WAS CROPPED BECAUSE FALLING ON IMAGE BORDERS, BUT SEEMS USELESS (1.2):
%---------------------------------------------------------------------------------------------------
%     dim_cropped_tf = [6 6] - zone_size > 0; % 1 where dimension doesn't match 6
%     % NB: means that 4P block is too close to image border to define a 6x6 zone including it
%     % dim_cropped = [1 0] if cropped vertically, [0 1] if cropped horizonatlly, [1 1] if both
%     % Now need to determine whether it's top or bottom vertically, or left or right horizontally
%     
%     if any(dim_cropped_tf)
%         disp(['Zone around block # ' num2str(b) ' was cropped because it was going over image bounds...']);
%         % determining which sides touch image border:
%         zone_corners = [zone_ULC_I  zone_ULC_J ; zone_LRC_I  zone_LRC_J];
%         image_corners = [1  1 ; image_size(1)  image_size(2)];
%         zone_corners_tf = ismember(zone_corners, image_corners);
%         % NB: pixel could match without direction being cropped => need to cross it with dim_cropped
%         zone_cropped_bound = zone_corners_tf.*repmat(dim_cropped_tf,2,1);
%         % 2x2 matrix with 1s where zone sides touch image borders AND were cropped
%     end
%---------------------------------------------------------------------------------------------------
    
    [ULC_zI, ULC_zJ] = fourpixelblockdetector(zone);                                                 % gets 4PB ULC coordinate in zone
    block_pixels_zIs = [ULC_zI ; ULC_zI+1 ; ULC_zI ; ULC_zI+1];
    block_pixels_zJs = [ULC_zJ ; ULC_zJ ; ULC_zJ+1 ; ULC_zJ+1];
    block_pixels_zLs = sub2ind(zone_size, block_pixels_zIs, block_pixels_zJs);
    
    dilated_block_pixels_zLs = SideDilator(zone_size, block_pixels_zLs, 1);                      % dilating zone of 1 pixels in all directions
    surrounding_block_pixels_zLs = setdiff(dilated_block_pixels_zLs, block_pixels_zLs);
    non_membrane_pixels_zLs = find(~zone);
    candidate_pixels_zLs = intersect(surrounding_block_pixels_zLs, non_membrane_pixels_zLs);        % takes intersection with non-membrane pixels and pixels surrounding 4Pblock
    
    BP_order = randperm(4);
    for bp_loc = BP_order
        pixel_swap_OK = 0;                                                                          % initialize to 0
        bp_zI = block_pixels_zIs(bp_loc);
        bp_zJ = block_pixels_zJs(bp_loc);
        bp_zL = block_pixels_zLs(bp_loc);
        
        % Getting the 4 surrounding pixels (not diagonals, i.e. connectivity 4) = all possible candidates for the swap
        bp_swap_zIs = [bp_zI   ; bp_zI+1 ;  bp_zI  ; bp_zI-1];
        bp_swap_zJs = [bp_zJ-1 ;  bp_zJ  ; bp_zJ+1 ; bp_zJ];
        
        % filtering out out-of-bounds pixel coordinates(1.4):
        bp_swap_zIsOUT_tf = bp_swap_zIs == 0 | bp_swap_zIs == imageSize(1)+1;
        bp_swap_zJsOUT_tf = bp_swap_zJs == 0 | bp_swap_zJs == imageSize(2)+1;
        bp_swap_2keep_tf = ~any([bp_swap_zIsOUT_tf bp_swap_zJsOUT_tf]); % 1s on rows where NEITHER I or J are out of bounds
        bp_swap_zIs = bp_swap_zIs(bp_swap_2keep_tf);
        bp_swap_zJs = bp_swap_zJs(bp_swap_2keep_tf);
        
        % After calculating bp_swap_zIs and bp_swap_zJs, add this filtering step:
        valid_indices = bp_swap_zIs > 0 & bp_swap_zIs <= zone_size(1) & ...
                        bp_swap_zJs > 0 & bp_swap_zJs <= zone_size(2);
        bp_swap_zIs = bp_swap_zIs(valid_indices);
        bp_swap_zJs = bp_swap_zJs(valid_indices);

        bp_swap_zLs = sub2ind(zone_size, bp_swap_zIs, bp_swap_zJs);
        
        % Selecting ACTUAL possible candidates for the swap:
        bp_swap_candidates_zLs = intersect(bp_swap_zLs, candidate_pixels_zLs);
        
        if ~isempty(bp_swap_candidates_zLs)
            disp(['Turning block pixel index # ' num2str(bp_zL) ' into a non-membrane pixel...']);
            zone(bp_zL) = 0;                                                          % turn this pixel into a non-membrane pixel
 
            for bp_swap = bp_swap_candidates_zLs'
                disp(['Turning candidate pixel index # ' num2str(bp_swap) ' into a membrane pixel...']);
                zone(bp_swap) = 1;                                                       % turn this pixel into a membrane pixel
                
                % Looking for 1 pixel patterns:
                disp('Looking for 1 pixel patterns...');
                [pattern_zIs, pattern_zJs]  = find(bwhitmiss(zone,filter), 1);
                pattern_zLs = sub2ind(zone_size,pattern_zIs, pattern_zJs);
                % filtering pixels on bounds, taking zone cropping into account:
                if ~isempty(pattern_zLs)
                    % removes wrong detections on zone bounds:
                    pattern_zIs_TF = ismember(pattern_zIs, [1 zone_size(1)]); % 1 when element in pattern_zIs = 1 or zone_size(1)
                    pattern_zJs_TF = ismember(pattern_zJs, [1 zone_size(2)]);  
                    pattern_zLs_TF = any([pattern_zIs_TF pattern_zJs_TF],2);    % 1s where 1 was found in either column
                    pattern_zLs = pattern_zLs(~pattern_zLs_TF); % removes indices that involved image bounds
                end
                
                % Reassessing pattern_zLs emptyness after removal of border indices:
                if isempty(pattern_zLs)
                    pixel_swap_OK = 1;
                    break       % exits for loop on the swap candidates
                else
                    disp(['Pixel swap created a 1-pixel region at pixel # ' num2str(pattern_zLs)]);
                    disp('Reverting change and picking another candidate pixel...');
                    zone(bp_swap) = 0;                                               % switching back this candidate pixel to non-membrane type
                end
            end
            if pixel_swap_OK
                break           % exits for loop on the 4 pixels of the block
            else
                disp('This pixel could not be swapped with a neighboring pixel sucessfully.');
                disp('Reverting change and picking another pixel from the block ...');
                zone(bp_zL) = 1;                                          % switching back this block pixel to membrane type
            end
        end
    end

    if pixel_swap_OK
        disp('The pixel swap was successful! Applying change to image...');
        image(zone_ULC_I:zone_LRC_I, zone_ULC_J:zone_LRC_J) = zone;    % replacing entire zone in image
        
        % getting linear index of old pixel that was moved IN IMAGE:
        [bp_I, bp_J] = deal(zone_ULC_I + bp_zI - 1, zone_ULC_J + bp_zJ - 1);                        % ij coordinates of old pixel IN IMAGE
        disp(['Storing image old pixel (x=' num2str(bp_J) ', y=' num2str(bp_I) ') linear index...']);
        disp(' ');
        oldPixels(b) = sub2ind(imageSize, bp_I, bp_J);
        n4PBfixed = n4PBfixed + 1; % 1.5
        disp(['4-pixel block # ' num2str(b) ' has been fixed!']);disp(' ');
    else
        disp(['WARNING: 4-pixel block # ' num2str(b) ' could NOT be resolved and was skipped!']);
    end
end

% Applyig extra skeletonization after change to match classic Unionseg generation procedure:
disp('Applying extra watershed and skeletonization to full image...');
image = ~watershed(image,4);
image = bwmorph(image,'skel',Inf);
disp('Done!');

fixedImage = ~image;                         % BACK TO BLACK MEMBRANES, WHITE CELLS

disp(' ');
disp([num2str(n4PBfixed) ' 4-pixel blocks (out of ' num2str(n4PB) ') were fixed in the image.']); % mod 1.5
disp(' ');


%% History %%

% 29/06/2017: 1.5
% - improved display of info

% 11/01/2016: 1.4
% - fixed issue when some pixels coordinates surrounding the 4pixel-block zone were out of bounds (like value 0) and were causing a crash in
% sub2ind => added a filter to remove those pixels

% 21/05/2015: 1.3 changed name to "FourPixelBlockRemover"

% 24/02/2014: 1.2 WORKS! NB: this change enabled the "getVertex" processing of 12 additional BIGwt2 images!!
% - fixed important bug that removed a pixel at the boundary of cropped zone, thus cutting a junction in segmented image!
%   Now applying GLOBALLY the extra watershed & skeletonization

% 21/02/2014: 1.1 WORKS!
% - finalized code: now should work in every situation with any kind of 4pixel block!
% - added extra watershed and skeletonization of cropped zone to end up with a totally usual segmentated image.

% 20/02/2014: creation: NOT WORKING
% - started to thoroughly rewrite code from "Four_Pixel_Vertex_Removal"
