function ComputeColorPatches(ALL_FRAMES, frameA, frameB, firstSegImage, digitsFormat, backupFolder, DISPLAY)
% Creation of color masks (0.8k)
% Extracted from Dynamic processing stage of the segmentation pipeline
% by Stephane Rigaud

if ~exist(backupFolder,'dir')
mkdir(backupFolder);
end

% image path parsing to reduce number of parameters of the function
[segFolder, fullImageName, imageFormat] = fileparts(firstSegImage);

C = strfind(fullImageName,'_');
segTag = fullImageName(1:C(1));
imageName = fullImageName(C(1)+1:C(end));

% C = strsplit(fullImageName,'_');
% segTag = [C{1} '_'];
% imageName = [C{2} '_'];

% for each frame loop
for f = frameA:frameB

    % Loading of images:
    I_seg = imread([segFolder filesep segTag imageName num2str(f, digitsFormat) imageFormat]); % Reload segmented image
    image_size = size(I_seg); % 0.8h

    % Use of "regionprops" ONLY ONCE AND IN CONNECTIVITY 4 to get useful info back
    I_seg_CC = bwconncomp(I_seg, 4);
    Stat_All_Regions = regionprops(I_seg_CC, 'Centroid', 'PixelIdxList'); % WARNING: ORDERING OF MATLAB OUTPUT
    Stat_All_Regions_cell = (struct2cell(Stat_All_Regions))';    
    cell_indices = Stat_All_Regions_cell(:,2);  
    
    %%% Loading data:
    this_name = ['FRAME_' num2str(f)];
    THIS_FRAME = ALL_FRAMES.(this_name);
    Border_cells = THIS_FRAME.Border_cells ;
    cell_tags = THIS_FRAME.cell_tags;
    cell_tags_only = cell_tags(:,2);
    
    %%% Merging pixels according to cell tags (0.8k):
    %%%% Basic masks:
    tf_just_coalesced = cell_tags_only == 2; % gets locations in cell_tags_only where = 2
    if ~DISPLAY.bordercell
        tf_just_coalesced(Border_cells) = 0;
    end
    pixels_cells_just_coalesced = cell2mat(cell_indices(tf_just_coalesced));
    maskred = zeros(image_size);
    maskred(pixels_cells_just_coalesced) = 1;
    
    % tag = -2 (coalescing):
    tf_coalescing= cell_tags_only == -2; % gets locations in cell_tags_only where = -2
    if ~DISPLAY.bordercell
        tf_coalescing(Border_cells) = 0;
    end
    pixels_cells_coalescing = cell2mat(cell_indices(tf_coalescing));
    maskblue = zeros(image_size);
    maskblue(pixels_cells_coalescing) = 1;
    
    % tag = 1 (just divided):
    if DISPLAY.darkgreen % ADJUSTMENT OF 2.0
        tf_just_divided= cell_tags_only ==1; % gets locations in cell_tags_only where = 1
        if ~DISPLAY.bordercell
            tf_just_divided(Border_cells) = 0;
        end
        pixels_cells_just_divided = cell2mat(cell_indices(tf_just_divided));
        maskgreen = zeros(image_size);
        maskgreen(pixels_cells_just_divided) = 1;
    else
        maskgreen = zeros(image_size); % ADJUSTMENT OF 2.0
    end
    
    %%%% New (optional) masks (0.8k):
    if DISPLAY.darkred
        % tag = 3 (old coalesced):
        tf_old_coalesced= cell_tags_only == 3; % gets locations in cell_tags_only where = 3
        if ~DISPLAY.bordercell
            tf_old_coalesced(Border_cells) = 0;
        end
        pixels_cells_old_coalesced = cell2mat(cell_indices(tf_old_coalesced));
        maskdarkred = zeros(image_size);
        maskdarkred(pixels_cells_old_coalesced) = 0.5;
    else
        maskdarkred = zeros(image_size);
    end
    
    if DISPLAY.cyan
        % tag = 4 (new cells):
        tf_new= cell_tags_only == 4; % gets locations in cell_tags_only where = 4
        if ~DISPLAY.bordercell
            tf_new(Border_cells) = 0;
        end
        pixels_cells_new = cell2mat(cell_indices(tf_new));
        maskcyan = zeros(image_size);
        maskcyan(pixels_cells_new) = 1;
    else
        maskcyan = zeros(image_size);
    end
    
    clear maskRGB; % required before loading of new image
    % basic masks:
    maskRGB(:,:,1) = maskred;
    maskRGB(:,:,2) = maskgreen;
    maskRGB(:,:,3) = maskblue;
    % additional masks
    maskRGB(:,:,1) = maskRGB(:,:,1) + maskdarkred;
    maskRGB(:,:,2) = maskRGB(:,:,2) + maskcyan;
    maskRGB(:,:,3) = maskRGB(:,:,3) + maskcyan;
    
    % conversion to 8 bit image:
    maskRGB = im2uint8(maskRGB);    

    % Saving RGB mask
    imwrite(maskRGB, [backupFolder filesep 'maskRGB_' imageName num2str(f, digitsFormat) imageFormat], imageFormat(2:end));
end

%% Historique 

% 19/01/2017 - v1