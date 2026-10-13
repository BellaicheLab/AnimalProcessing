% FilterFourPixelBlocks
%
% Loads ['AIA_info_' Animal] (without running any program) to process segmented images and remove 4-pixel block
% vertices in segmented images. A backup of the original segmented image "Unionseg" is saved in the folder
% "Fixed_images", together with a RGB image locating the changes made. The fixed Unionseg images overwrites the old
% one in the folder containing the "Unionseg" segmented images.
% Ex: Animal = 'wt2NEW' will load file "AIA_info_wt2NEW.m".
%
% Formerly "Four_Pixel_Vertex_Filter", then "Four_Pixel_Block_Filter"
%
% Boris Guirao
version = '1.8';


%% Iteration over frames %%

saveFixedBlockImage = false;
printResolutionFFPB = '-r600'; % corrected images saved at high resolution (1.5)
correctedImagesFolder = [pathFolder filesep 'fixed_images'];
txtFilenamePathFFPB = [correctedImagesFolder filesep 'FFPB_' Animal '_' num2str(startFrame) '-' num2str(finalFrame) '.txt'];

if ~exist(txtFilenamePathFFPB,'file')
    
    for n = startFrame:finalFrame
        
        iterationIndex = n - startFrame + 1; % 1.7
        frameNumber = num2str(n,digitsFormat);
        
        %% Loading of nth segmented image %%
        
        segFilename = [pathFolder filesep filename num2str(n, digitsFormat) '.' imageFormat];
        if exist(segFilename,'file')                                       % check for existence of file (2.0GMs)
            thisImage = imread(segFilename);                                   % loads the segmented images (2.0b)
            imageSize = size(thisImage);                                       % updating  imageSize (1.6)
        else
            fprintf(['\nFFPB ERROR: Segmented image "' segFilename '" not found => Stopped FFPB execution!\n'])
            return                                                          % exit if not found
        end
        
        %% Correction of 4pixel blocks %%
        
        %%% Display info regarding frame being processed:
        disp(' '); disp(' ');
        disp(['FilterFourPixelBlocks ' version  ': processing "' Animal '" frame # ' frameNumber ' (' num2str(iterationIndex) '/' num2str(nFrames) ')']);
        disp('---------------------------------------------------------------------------------');
        
        %%% Apply "Four_Pixel_Block_Remover" on image and generate "corrected_image":
        disp('Looking for 4-pixel blocks...');
        [fixedImage, oldPixels] = RemoveFourPixelBlocks(thisImage);                                                        % 1.2,1.4
        
        nBlocksFixed = length(oldPixels);
        [oldPixelYs, oldPixelXs]  = ind2sub(imageSize,oldPixels);
        oldPixelXYs = [oldPixelXs oldPixelYs];
        
        %%% Saves a backup of original image as well as a rgb image pointing out changes made in "Corrected_Images_Folder",
        %%% and OVERWRITES "Unionseg_" image with corrected image (2.0zi):
        if  nBlocksFixed > 0                                                                                                              % some vertices were fixed
            
            % creates directory:
            if ~exist(correctedImagesFolder,'dir') % mod 1.7
                mkdir(correctedImagesFolder);
            end
            
            % Saves a backup of original Unionseg image in "Fixed_images" folder:
            disp('Saving backup of original segmented image in "fixed_images" folder...');
            originalImage = thisImage;
            thisImage = fixedImage;                                                                                                                  % updates image
            imwrite(originalImage, [correctedImagesFolder filesep filename num2str(n,digitsFormat) '.' imageFormat], imageFormat); % saves backup of original image (2.0zi)
            
            % Overwrites segmented image with fixed one in regular segmented image folder:
            imwrite(thisImage, [pathFolder filesep filename num2str(n,digitsFormat) '.' imageFormat], imageFormat);                      % saved corrected Unionseg image in subfolder
            
            % creates RGB image of modified pixels with location tag (mod 1.6):
            if saveFixedBlockImage % 1.6
                disp('Saving image of changes made in image in "fixed_images" folder...'); %#ok<UNRCH>
                modifiedPixels = ~fixedImage;                                                                                               % white membranes (1s), black cells (0s)
                modifiedPixels = double(modifiedPixels);                                                                                        % logical to double
                modifiedPixels = 4 * modifiedPixels;
                modifiedPixels(oldPixels) = 11 * ones(nBlocksFixed,1);
                modifiedPixelsRGB = label2rgb(modifiedPixels, 'jet');
                % displays and save figure:
                figure('PaperPositionMode','auto')
                imshow(modifiedPixelsRGB,'Border', 'tight')
                hold on
                scatter(oldPixelXYs(:,1), oldPixelXYs(:,2), 15,'LineWidth', 1, 'MarkerEdgeColor', 'red')
                print(printFormat, printResolutionFFPB, [correctedImagesFolder filesep Program '_' Animal '_ModifiedPixels_'  frameNumber '.' imageFormatOutput]);
                close
                pause(0.1)
            end
        end
        disp('---------------------------------------------------------------------------------');
    end
    % disp(' ')
    % disp('Done!')
    
    %% Saving txt file (1.7)
    
    % NB: only motivation is to be able to check the program has already run on
    % segmented images.
    
    % creates directory to write txt file if doesn't exists:
    if ~exist(correctedImagesFolder,'dir') % mod 1.7
        mkdir(correctedImagesFolder);
    end
    
    today = datestr(now,29);                      % format 29 displays date yyyy-mm-dd style
    
    % Writing main parameters in txt file
    parameterCell = {
        'version = ', version;
        'today = ', today};
    
    dlmcell(txtFilenamePathFFPB, parameterCell,' ');
    
else
    fprintf('\nWARNING: "FilterFourPixelBlocks" has already run on ALL images and was skipped!\n')
end


%% History %%

% 04/05/2018: 1.7
% - now writes txt file to be able to figure out whether it has already run
% (skipping execution if so)

% 29/06/2017
% - re-updates "imageSize" for each image

% 03/12/2015: 1.6
% - stopped diplaying and savig RGB image showing fixed 4pixel blocks

% 03/06/2015: 1.5
% - turned function into script executable from AIA_parameters
% - changed many parameter names to match AIA 6.0

% 21/05/2015: 1.4 changed name to "FourPixelBlockFilter"
% - call to "FourPixelBlockRemover" instead of "Four_Pixel_Block_Remover"

% 23/07/2014: 1.3
% - use of filesep for mac compatibility

% 18/02/2014: 1.2 changed name to "Four_Pixel_Block_Filter"
% - adjustments to use new function "Four_Pixel_Block_Remover"
% - now only saves Unionseg image when modified (no global image skeletonization done anymore in "Four_Pixel_Block_Remover")

% 18/02/2014: 1.1
% - turned it into a function taking animal name in argument (ex: 'BIGwt2')

% 15/05/2012: creation

