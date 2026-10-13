%% ParticleImageVelocimetry %%

version = '3.4';
% Boris Guirao
% Yuki Goya
% Anais Bailles


%% Additional Information, Notations and creation of directories %%

program = 'PIV';                                                             % This program name. Used for saving files

% CHECKS THAT AN APPROPRIATE GRIDSIZE WAS ENTERED:
if strcmp(PIVgrid,'XS')
    PIVgridSize = 1;
elseif strcmp(PIVgrid,'S')
    PIVgridSize = 2;
elseif strcmp(PIVgrid,'M')
    PIVgridSize = 4;
elseif strcmp(PIVgrid,'L')
    PIVgridSize = 8;
elseif strcmp(PIVgrid,'XL')
    PIVgridSize = 16;
elseif strcmp(PIVgrid,'XXL')
    PIVgridSize = 32;
else
    disp('Error: Please choose a proper grid size: XS, S, M, L, XL, XXL')
    return
end


%% Creation of directories %%

%%% Backup & Frame folders (mod 3.0, 3.3):
backupFolder = [pathFolderPIV filesep 'Backups'];
frameFolder = [pathFolderPIV filesep 'Frames'];
resultFolder = [pathFolderPIV filesep 'Results']; % for png images (3.1)

mkdir(backupFolder);
mkdir(resultFolder); % 3.1

if velocityDisplay == 1 || speedDisplay == 1 || divergenceDisplay == 1
    mkdir(frameFolder);
end

%%% Saving txt file to specify program version:
today = datestr(now,29);                   % format 29 displays date yyyy-mm-dd style. Look up date for details
todayStart = datestr(now);

txtFilename = [today '_PIV_' version '.txt'];

% Writing main parameters in txt file (3.0)
parameterCell = {'PIVgrid = ',PIVgrid;
                 'PIV start = ', todayStart};             
dlmcell([pathFolderPIV filesep txtFilename], parameterCell,' ');


%% Iteration over frames

%%% the grid size is specified here
if PIVgridSize<=16
    PIVgridSize1 = 16*PIVgridSize;   
else                                                                       % for XXL grid_size
    PIVgridSize1 = 8*PIVgridSize;
end
PIVgridSize2 = 8*PIVgridSize;

%%% Loads raw images. All raw images assumed to be in same folder (1.3):
startRawImage = imread([pathFolderRaw filesep filenameRaw{1} num2str(startFrame, digitsFormat) '.' imageFormatRaw]);               % selects 1st raw image 
imageSize = size(startRawImage);
HEIGHT = imageSize(1);
WIDTH = imageSize(2);

tic
parfor n = startFrame:finalFrame-1
    
    nthPIVfilename = [filenamePIV '_' num2str(n, digitsFormat) '.mat'];  % 2.7, 3.0
    nthPIVfile = [backupFolder filesep nthPIVfilename];                 % 2.7
    % Defines u & v png backup files (3.1):
    uImageFilename = [resultFolder filesep filenamePIV '_u_' num2str(n,digitsFormat) '.png'];
    vImageFilename = [resultFolder filesep filenamePIV '_v_' num2str(n,digitsFormat) '.png'];
    
    if ~exist(nthPIVfile,'file') || ~exist(uImageFilename,'file') || ~exist(vImageFilename,'file')
        
        %% PIV processing %%
        
        % All raw images assumed to be in same folder (1.3):
        disp(' ');
        disp(['Applying "matpiv" on image # ' num2str(n) '...']);                                                           % 2.2
        [x,y,u,v,snr,pkh] = matpiv([pathFolderRaw,filesep,filenameRaw{1} num2str(n,digitsFormat) '.' imageFormatRaw],...    % selects 1st raw image
            [pathFolderRaw,filesep,filenameRaw{1} num2str(n+1,digitsFormat) '.' imageFormatRaw],...                         % selects 1st raw image
            [PIVgridSize1 PIVgridSize1; PIVgridSize2 PIVgridSize2],1,0.5,'multin');                                         %#ok<PFBNS,PFTUS>
        % ... [s1 s1 ; s2 s2] =gridsize; 1 =timescale; 0.5 =overlap; 'multin' =several iterations
        
        
        %% Applying filters (edit 2.2)%%
        
        [u, v] = inffilter(u,v,[WIDTH HEIGHT]);        % removes "Inf" values from displacement field (2011-10-14)
        
        disp(' ');
        disp('Applying "snrfilt" filter based on signal to noise ratio: putting NaNs at locations corresponding to areas of image deemed irrelevant (snr<1.3)...');
        disp(' ');
        [u,v] = snrfilt(x,y,u,v,snr,1.3);
        % NB: this filter is pretty good at finding the borders of the animal!
        
        disp('Applying "peakfilt" filter based on normalized height of correlation peaks: putting NaNs at locations where a weak correlations was found (pkh<0.3)...');
        disp(' ');
        [u,v] = peakfilt(x,y,u,v,pkh,0.3);          % peak height filter
        disp(' ');
        
        %[u,v] = globfilt(x,y,u,v,3);                % global filter (based on std)(commented 2.2)
        % NB: commented in 2.2 because in fullt thorax, velocity fields can be very heterogeneous. Applying not-so-local filter instead
        
        disp(' ');
        disp('Applying local filter "localfilt" replacing displacement values outside [median (over 5?-1 neighbors) +/- 4*sigma] by NaNs...');
        disp(' ');
        [u,v] = localfilt(x,y,u,v,4,'median',5);    % local filter (based on 'median' or 'mean') (changed parameters 2.2)
        % OLD:
        %[u,v] = localfilt(x,y,u,v,2,'median',3);    % local filter (based on 'median' or 'mean')
        
        % Loading image to determine regions with no signal (0 intensity)(2011-10-14)
        im = imread([pathFolderRaw,filesep,filenameRaw{1} num2str(n,digitsFormat) '.' imageFormatRaw]);
        
        % SPLITTING VELOCITY FIELDS to be used for segmentation/tracking (u,v) and for quantitative analysis (uq,vq) (2.2, STOPPED 3.4):
        %-------------------------------------------------------------------------------------------
        % Put NaNs at xy gridpoints whose surounding boxes (of size "size_grid_2") only contain pixels with 0 gray level.
%         [uq, vq] = signalFilterNaN(x,y,u,v,im,PIVgridSize2); % changed size of the box used to cut signal closer to black regions (to size_grid_2 from 2*size_grid_2)
        %-------------------------------------------------------------------------------------------
        
        % segmentation/tracking: (u,v)
        %-------------------------------------------------------------------------------------------
        % Put 0s at xy gridpoints whose surounding boxes (of size "size_grid_2") only contain pixels with 0 gray level.
        [u, v] = signalFilter(x,y,u,v,im,PIVgridSize2); % changed size of the box used to cut signal closer to black regions (to size_grid_2 from 2*size_grid_2)
        % OLD:
        % [u v] = signalfilter(x,y,u,v,im,2*size_grid_2);
        [u,v] = naninterp(u,v,'linear');                    % interpolate NaN from the field
        %-------------------------------------------------------------------------------------------
        
        
        %% Saving backups %%
        
        %%% Saving "GridDef " x and y for start frame ONLY
        if n == startFrame
            disp(['Saving "' filenamePIV  '_GridDef"']);                % mod 3.0
            parSavePIVxy(pathFolderPIV, [filenamePIV  '_GridDef'], x, y);  % 3.0
        end
        %%% Saving "u" and "v" for each interframe WITHIN THE PARFOR LOOP (1.4a):
        display(['Saving Backup file #' num2str(n,digitsFormat)]);
        parSavePIVuv(backupFolder, [filenamePIV '_'], digitsFormat, n, u, v); % 2.2, 2.7, 3.4
%         parSavePIVuv(backupFolder, [filenamePIV '_'], digitsFormat, n, u, v, uq, vq); % 2.2, 2.7
        
        
        %% Creates and saves PNG images for C++ tracking  (3.1) %%
        
        fprintf('Generating PNG result images...')
        
        [~, ~, uImage, vImage] = InterpolatePIV(imageSize,x,y,u,v, 'spline', PIVgrid); %#ok<PFTUS> % switched to "spline" from "cubic" (2.3)
        
        % rount to uint8 & set 0 to 128
        uImage = uint8(round(uImage)+128);
        vImage = uint8(round(vImage)+128);
        
        % uImage
        imwrite(uImage, uImageFilename);
        % vImage
        imwrite(vImage, vImageFilename);
        
        fprintf('Done.\n');
        
 
    else
        disp(['File "' nthPIVfilename '" already exists => skipping time step # ' num2str(n) '!'])
    end
end
firstLoop = toc;
disp(['Loop #1 duration: ' num2str(firstLoop) ' seconds'])

% Update of txt file (mod 3.0):
todayEnd = datestr(now);
parameterCell = {'PIVgrid = ', PIVgrid;
                 'PIV start = ', todayStart;
                 'PIV end = ', todayEnd};             
dlmcell([pathFolderPIV filesep txtFilename], parameterCell,' ');


%% Display Vector field, Speed map, Divergence map %%

if velocityDisplay == 1 || speedDisplay == 1 || divergenceDisplay == 1
    
    %%% progressbar initialization:
    progressbar('PIV display and saving...') 
    
    % assigns default color for PIV arrows (2.7)
    if ~exist('PIVarrowColor', 'var')
        PIVarrowColor = 'c';                                                          % changed arrow color to magenta (2.2)
    end

    tic
    for n = startFrame:finalFrame-1
        
        When = datestr(now);
        

        %% Loading x,y,u,v from backups %%
        
        %%% Loads grid xy only for 1st frame:
        if n == startFrame
            xyGrid = load([pathFolderPIV filesep filenamePIV  '_GridDef']); % 3.0
            x = xyGrid.x;
            y = xyGrid.y;
        end
        
        %%% Loads u,v backups (edit 2.2, 3.4):
        nthPIVbackup = load([backupFolder filesep filenamePIV '_' num2str(n,digitsFormat) '.mat']); % 3.0
        u = nthPIVbackup.u;
        v = nthPIVbackup.v;
        
        %%% Vector field:
        thisFilename = [frameFolder filesep  filenamePIV '_Velocity_'  num2str(n,digitsFormat)  '.' imageFormatOutput];
        if velocityDisplay == 1 && ~exist(thisFilename,'file')
            figure('PaperPositionMode','auto')     % REQUIRED SO THAT "SAVEAS" DOES THE SAME AS "FILE->SAVE AS" FROM THE FIGURE WINDOW. ALSO REQUIRED TO SAVE IMAGES WITHOUT BORDERS
            %All raw images assumed to be in same folder (1.3):
            imshow([pathFolderRaw,filesep,filenameRaw{1} num2str(n,digitsFormat)  '.' imageFormatRaw],'Border', 'tight') % REQUIRED TO REMOVE BORDERS IN THE FIGURE (.fig) DIPLAYED BY MATLAB
            hold all 
            quiver(x,y,u,v,1.,PIVarrowColor);                                % put back to 1
            %quiver(x,y,u,v,0,arrow_color);                                % 0 for no autoscale, y for yellow
            disp(['Saving Velocity map for interframe #' num2str(n,digitsFormat) '-' num2str(n+1,digitsFormat)]);         
            print(printFormat,printResolution, thisFilename);
            hold off
            close
        end
        
        %%% Rebuilds xImage, yImage, uImage, vImage (2.2,3.4):
        if speedDisplay == 1 || divergenceDisplay == 1
            
            [xImage, yImage, uImage, vImage] = InterpolatePIV(imageSize,x,y,u,v, 'spline', PIVgrid); % switched to "spline" from "cubic" (2.3)
            
            % Loads "figRefPosition" from "SAPparameterFile" OR redetermines it (3.0)
            if n == startFrame
                if ~exist(SAPparameterFile,'file')
                    
                    figure('PaperPositionMode','auto')
                    imRefFile = [pathFolderRaw filesep filenameRaw{1} num2str(n,digitsFormat)  '.' imageFormatRaw];
                    imshow(imRefFile,'Border', 'tight');
                    figRef = gcf;
                    figRefPosition = figRef.Position;
                    close
                else
                    load(SAPparameterFile,'refFigPosition')
                end
            end
        end
        
        %%% Speed display 
        thisFilename = [frameFolder filesep  filenamePIV '_Speed_'  num2str(n,digitsFormat)  '.' imageFormatOutput];        
        if speedDisplay == 1 && ~exist(thisFilename,'file')
            
            % moved inside if:
            uImageSquare = uImage.^2;
            vImageSquare = vImage.^2;
            speedField = sqrt(uImageSquare + vImageSquare);
            
            figure('PaperPositionMode','auto'); 
            imagesc(speedField);
            set(gca,'XTick',[])                 % Removes the ticks in the x axis!
            set(gca,'YTick',[])                 % Removes the ticks in the y axis
            set(gcf,'Position',refFigPosition); % Sets FIGURE position AND SIZE, aspect ratio (PIXELS)
            set(gca,'Position',[0 0 1 1])       % Makes the axes occupy the whole figure WITHOUT GREY BORDERS!!
            colormap(jet);
            caxis([0 max(max(speedField))]); % very important so as not to saturate the colorscale to value 1
            disp(['Saving Speed map for interframe #' num2str(n,digitsFormat) '-' num2str(n+1,digitsFormat)]);
            print(printFormat,printResolution, thisFilename);
            close
        end   

        %%% Velocity gradient display:
        thisFilename = [frameFolder filesep  filenamePIV '_Divergence_'  num2str(n,digitsFormat)  '.' imageFormatOutput];
        if divergenceDisplay == 1 && ~exist(thisFilename,'file')
            
            % moved inside if:
            [uxImage, uyImage] = gradient(uImage,1);
            [vxImage, vyImage] = gradient(vImage,1);
            divVelocity = uxImage + vyImage;
            
            figure('PaperPositionMode','auto')   
            imagesc(divVelocity);
            set(gca,'XTick',[])                 % Removes the ticks in the x axis!
            set(gca,'YTick',[])                 % Removes the ticks in the y axis
            set(gcf,'Position',refFigPosition); % Sets FIGURE position AND SIZE, aspect ratio (PIXELS)
            set(gca,'Position',[0 0 1 1])       % Makes the axes occupy the whole figure WITHOUT GREY BORDERS!!
            colormap(jet);
            caxis([min(min(divVelocity)) max(max(divVelocity))]); % THE VELOCITY DIVERGENCE CAN BE NEGATIVE!!
            disp(['Saving Divergence map for interframe #' num2str(n,digitsFormat) '-' num2str(n+1,digitsFormat)]);
            print(printFormat,printResolution, thisFilename);
            close
        end
        
        %%% Progress display:
        progressbar(n / (finalFrame-1));
    end
    secondLoop = toc;
    disp(['Loop #2 duration: ' num2str(secondLoop) ' seconds'])
end


%% History %%

% IMPROVEMENTS: 

% 14/10/2020: 3.4
% - stopped defining and saving uq,vq because was giving aberrant maps on
% some movies (huge gaps). The ROI mask killing values outside of
% animal is anyway used with VM for quantitative purposes.

% 07/05/2018: 3.3
% - now "pathFolderPIV" include the PIV subfolder => removed definition of
% "saveFolder"

% 30/03/2018: 3.2
% - Change path to transposed PIV png to fit new organisation. transposed folder is defined in AIA_parameters

% 08/03/2018: 3.1
% - now directly generates png files from "PIV_pngmaker.m" in an additional
% "Results" folder.

% 07/03/2018: 3.0
% - removed parameter "replotPIV" since backups are NOT recalculated when they exist
% - changed folder path and names
% - "PIV_animal_GridDef.mat" now saved in the saveFolder
% - fixed display of Speed and Divergence (and learned a lot about figure
% size and aspect ratio and "imagesc"!).
% - skipping images when they exist

% 05/02/2018: 2.7
% - adjustments to make it work with latest program names
% - renamed variables
% - now checks existence of PIV backup .mat file before running on each
% interframe and skips interframe if backup file was found.
% - "PIVarrowColor" can now be set in "AIA_parameters"

% 27/05/2015: 2.6 became "ParticleImageVelocimetry"
% - changed name of parameters to match AIA 6.0

% 13/04/2015: 2.5
% - stopped using ParforProgMon: it was causing too many problems!

% 10/04/2015: 2.4
% - use of "ParforProgMonv2"

% 21/07/2014: 2.3
% - replaced all \ with filesep
% - switched PIV interpolation to "spline" from "cubic" since the latter always gave a warning and was replaced by "spline" anyway

% 24/02/2014: 2.2
% - now saves 2 versions of velocity fields in PIV backups:
%   * (u,v) for segmentation/tracking use, that were interpolated and are "NaN free"
%   * (uq,vq) for quantitative analysis, that were NOT interpolated and still contain all the NaNs added by the filters, including "signalfilter_nan"
% - created "signalfilter_nan" from "signalfilter" that puts NaNs instead of 0s where gray level = 0
% - removed global filter and changed parameters of filters according to discussions with Ana?s Bailles
% - applying signalfilter on a box twice as small as before to limit overflowing beyond the animal
% - removed Border_parameter_PIV to always use "tight".
% - fixed minor bugs to display speed and divergence maps
% - added messages specifying which filter is being applied
% - changed names of figure saved to Velocity, Speed and Divergence.

% 2011-10-14: 2.1.1
% - absurd displacement values (beyond image, Inf...) & non-image data filters replaced by functions.
% - increased boxe size for "signalfilter" to 2*size_grid_2

% 2011-10-13: 2.1
% - use of polymask.mat for PIV filtering removed.
% - filter of absurd displacement values (beyond image, Inf...) added.
% - non-image data filter added (regions of raw images with 0 gray level).

% 15/02/2011: 2.0GMc
% - replaced specification of grid size by number "grid_size", by string "PIVgrid" (that replaced "grid_size_letter")

% 08/02/2011: 2.0GMb CHANGED NAME FROM "PIV" TO "Particle_Image_Velocimetry"
% - removed version from program name and changed name
% - added name program version, animal name and grid used in progressbar display
% - only one number of digits specified now: "digits" + "digit_format" now defined in AIA.

% 06/12/2010: 2.0GMa
% - minor adjustments to make it compatible with n_raw_images >1
% - use of function "progressbar" instead of "waitbar"
% - changed  "Image_..."  to  "image_..." 

% 01/09/2010: 2.0b
% - fixed bug: "Path_folder_PIV" to "Backup_folder" when loading backups to
% plot images

% 29/06/2010: 2.0a WORKS
% - removed opening/closing of matlabpool that is done in AIA
% - skips 1st loop if replotPIV == 1
% - new name (1.4 to 2.0) to acknowledge implementation of parallel
% computing.

% 28/06/2010:1.4c WORKS
% - execute display (2nd loop) ONLY if >=1 display has been selected
% - update the txt file with starting time AND ending time

% 21/06/2010: 1.4b WORKS
% - now only saves u,v (Backup) for each frame and x,y (Backup_XY_Grid) when processing "startFrame".
% - use of homemade function "PIV_Interpolate" to get x,y_image and u,v_image
% - plot and save all graphics AFTER the main (parfor) loop.
% - progress display for parfor AND classic loop
% - Now uses "naninterp(mu,mv,'linear')" instead of "naninterp(mu,mv,'linear','polymask.mat',x,y)"
% which REMOVES EVERY SINGLE NaNs in the field and allows better subsequent
% interpolation using "interp2" within "PIV_Interpolate". Checked the
% relevance and the locality of modified values.

% 17/06/2010: 1.4a NOT WORKING (imshow issue)
% - now use a parfor loop
% - removed U_image and V_image that could require a lot of memory and were
% not used anymore.
% - remove N_Vfields, checking of parameter Multiple_Backups

% 18/05/2010:
% - Removed case where each raw image is in a different folder (Benoit)

% 06/04/10: 1.2
% - only saves variables called by CT to lighten backups

% 31/03/2009: start modifying Fanny's program

% 07/04/2009: switch to original_image_PIV 01
% - interpolation of u v to u_image, v_image where each image pixel has
% been assigned a velocity using 3 types of interpolation: (bi)linear,
% first neighbors and cubic (look up "interp2" in Matlab help)
% - graphic display of the speed in the whole image with colormap(jet)

% 08-09/04/2009: switch to 0.1a, 0.1b, 0.1c:
% - Selection of the cubic interpolation function.
% - using the velocity gradients to extrapolates u,v values to borders (yielding u_extended, v_extended)
% before performing the interpolation to get u_image, v_image.
% - graphic display of the velocity dirvergence and use to test relevant
% grid sive to use for PIV

% 14/04/2009: switch to 0.1d
% - creates subfolders for each grid size now
% - change of file naming to make quantity names appear first

% 27/04/2009
% - introduced "Image_extension_input_Raw" to specify the source image format

% 06/07/2009: switch to "PIV 1.0a"
% - possibility to choose which images will be saved
% - choose input and output number of digits
% - choose input/output image format
% - choose the resolution of output image
% - choose between saving individual backup files for each interframe OR an
% overall backup file (as in older version)

% 21/07/2009: switch to "PIV 1.0c" occured earlier
% - Doesn't specify the date when creating the folder because, in contrast
% to SIA, CT, DTaS, PIV doesn't depend on the segmentation.

% 21-22/07/2009: switch to 1.0d
% - Adjustments for execution from Advanced_Image_Inalysis and use for
% Fanny's segmentation set of programs.

% 23/07/2009: switch to 1.0e
% - Removed the date from the name of the folder created for PIV since it
% has to be executed only once.

% 18/08/2009: switch to 1.0f then 11
% - removed the program version from all filenames given + created a txt
% file containing all info on date and program version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


