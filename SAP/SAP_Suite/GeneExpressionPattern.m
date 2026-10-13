% GeneExpressionPattern
%
% Compute the mean intensity map of a signal
% ONLY global treatment of images (non-local)
%
version = '1.3';
% Stephane Rigaud
% Boris Guirao


%% Initialization %%

disp(' '); disp(' ');
disp(['GEP' ' (' version  '): processing "' Animal '" between frames # ' num2str(startFrame) ' and ' num2str(finalFrame)]);
disp('---------------------------------------------------------------------------------');

if ~strcmp(gridType,'E')
    disp('GEP ERROR: GEP can only support "E" grids for now!')
    disp('---------------------------------------------------------------------------------');
    return;
end

% %%% Load grid ------------------------------------------------------------
xywh = GRID_DEF.xywh;
% boxSize = [xywh(3) xywh(4)]; % redefines boxSize in case it was empty (fullImage processing)
nx = GRID_DEF.Size(2);
ny = GRID_DEF.Size(1);
dX = round(GRID_DEF.xywh(3));
dY = round(GRID_DEF.xywh(4));
% %--------------------------------------------------------------------------

%%% Defines subfolder name ------------------------------------------------
pathAverageFolder = [pathFolderGEP filesep gridSpecs filesep 'Backups'];
if ~isdir(pathAverageFolder)
    mkdir(pathAverageFolder)
end

% Checking existence of last GEP backup before running (1.3):
lastBackupName = [pathAverageFolder filesep filenameGEP '_' num2str(finalFrame,digitsFormat) '.mat'];
if exist(lastBackupName,'file')
    disp('GEP WARNING: last GEP backup already exists! Skipped GEP execution.')
    disp('---------------------------------------------------------------------------------');
    return
end
%--------------------------------------------------------------------------

%% GEP data computation %%

%%% For each grid compartment, gets the corresponding pixel list -------------------------------------------------
boxArea = (dX+1)*(dY+1);            % 1.1
gridPixelLs = NaN(nx*ny, boxArea);

for b = 1:(nx * ny)
    % turns linear index into grid coordinate
    [ky, kx] = ind2sub([ny nx], b);
    % get the box
    x1 = round(GRID_DEF.ULCs{ky,kx}(1));
    y1 = round(GRID_DEF.ULCs{ky,kx}(2));
    [X, Y] = meshgrid(x1:x1+dX,y1:y1+dY);
    coord = sub2ind(imageSize,Y,X);
    % store index in matrix
    gridPixelLs(b,:) = coord(:);
end
%--------------------------------------------------------------------------

%%% compute mean intensity ----------------------------------------
% nframes = finalFrame - startFrame;
% imageStack = NaN(imageSize(1), imageSize(2), length(filenameRaw), nframes);
% for f = startFrame:finalFrame
%     for c = 1:length(filenameRaw)
%         channelName = Filename_Formatter(filenameRaw{c});
%         imageName = [pathFolderRaw filesep channelName '_' num2str(f,digitsFormat) '.' imageFormatRaw];
%         imageStack(:,:,c,f) = double(imread(imageName));
%     end
% end
%
% if normalize_GEP
%     imageStack(imageStack==0) = NaN;
%     for c = 1:length(filenameRaw)
%         channel = imageStack(:,:,c,:);
%         meanIntensity(c) = nanmean(channel(:));
%     end
% end
%------------------------------------------------------------------

progressbar(['GEP iteration over ' Animal ' frames...']); %
nframes = finalFrame - startFrame + 1; % +1 (1.0)

for f = startFrame:finalFrame
    
    backupName = [pathAverageFolder filesep filenameGEP '_' num2str(f,digitsFormat) '.mat'];
    if ~exist(backupName,'file')
        for c = 1:length(filenameRaw)
            
            channelName = FormatFilename(filenameRaw{c});
            cSignal = signalName{c}; % 1.1
            imageName = [pathFolderRaw filesep channelName '_' num2str(f,digitsFormat) '.' imageFormatRaw];
            image  = double(imread(imageName));
            
            %         if normalize_GEP
            %             image = image - meanIntensity(c);
            %             image(image<0) = 0;
            %
            %             bins = 1:nanmax(image(:));
            %             n_elements = histc(image(:),bins);
            %             c_elements = cumsum(n_elements);
            %             nbElement = sum(n_elements);
            %             invCumSum = nbElement - c_elements;
            %             CropValue = nbElement * percentage_GEP ./ 100;
            %             intensityToCrop = bins(invCumSum<CropValue);
            %             image(image>intensityToCrop(1)) = 0;
            %         end
            
            image = (image - nanmin(image(:))) * (1 ./ (nanmax(image(:)) - nanmin(image(:)))); % resets all intensity values between 0 and 1
            intensityDistribution = sum(image(gridPixelLs),2) / boxArea; % 1.0
            intensityDistribution = reshape(intensityDistribution, ny, nx);
            
            GRID.(cSignal) = intensityDistribution; % 1.1
            %         eval(['GRID.ID' num2str(c) ' = intensityDistribution;']);
        end
        
        %%% compute the areas ratio (mod 1.3) -------------------------------------------
        RoIname = [pathFolderROI filesep roiname num2str(f,digitsFormat) '.' imageFormat];
        
        if ~exist(RoIname,'file')
            RoI = ones(imageSize) .* 255;
        else
            RoI = double(imread(RoIname));
        end
        RoI = RoI ./ nanmax(RoI(:));
        
        AR = sum(RoI(gridPixelLs),2) ./ size(gridPixelLs,2);
        AreaRatios = reshape(AR,ny,nx);
        %----------------------------------------------------------------------
        
        GRID.AreaRatios = AreaRatios;
        
        %%% save backup -------------------------------------------------------
        save(backupName,'-struct','GRID');
        %----------------------------------------------------------------------
        
    else
        disp(['GEP WARNING: backup "' filenameGEP '_' num2str(f,digitsFormat) '.mat" already exists and was skipped!'])% 1.3
    end
    progressbar(f/nFrames)
end
disp('---------------------------------------------------------------------------------');


%% History %%

% TO DO:
% - stop creating a backup for every single frame but rather directly stack
% it like it's done for VM

% 17/09/2018: 1.3 (Boris)
% - now sets AreaRatios to 1 in every grid compartment if RoI mask are not found (like in VM)
% - removed outdated creation of "olap_tag" (now "olapTag" defined earlier in SAP)
% - skipping GEP execution when last backup is found.
% - skipping frame processing when corresponding GEP backup is found.

% 01/06/2016: 1.2 (Stephane)
% - changes for compatibility

% 14/12/2016: 1.1 (Boris)
% - dropped signal naming "ID1", "ID2" using instead "signalName" (defined in AIA_info of each animal)
% - fixed bug related to AIA parameter "boxSize" being overwritten by what is now "boxArea"

% 15/06/2016: 1.0 (Boris)
% - simplification by removing subtraction of mean intensity AND definition of a common intensity range for all images
% (now done in Fiji by background removal followed by a 2-step contrast adjustment)
% - accordingly merged the two loops into a single one since mean intensity no longer required

% : creation: 0.1 (Stephane)



