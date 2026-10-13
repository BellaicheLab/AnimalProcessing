function [UStack, AreaRatiosStack, MissingFrames] = PIV2GridInterpolator(SAPparameterFile)
%
% [UStack, AreaRatiosStack, MissingFrames] = PIV2GridInterpolator(SAPparameterFile)
%
% This fonction converts the PIV from pixel per frame into micron per hours
% Then interpolate the values on the animal grid
%
% version 2.6
% Boris Guirao
% Stephane Rigaud

%% Initialization %%

threshAR = 0.01; % Area Ratio value below which velocity is replaced by NaN (1.1)

load(SAPparameterFile); %#ok<LOAD>

if exist(pathGridDefFile,'file')
    GRID_DEF = load(pathGridDefFile);
else
    disp('PIV2GridInterpolator ERROR: "pathGridDefFile" could not be found! Stopped execution.')
end

%%% declare variables -----------------------------------------------------
nx = GRID_DEF.Size(2); % grid size x
ny = GRID_DEF.Size(1); % grid size y
% Determining spacing between grid compartments NOT taking overlap into account
dX = round(GRID_DEF.xywh(3));
dY = round(GRID_DEF.xywh(4));
nBoxes = nx * ny;                           % number of grid compartment
AreaRatiosStack = zeros(ny, nx, 1, finalFrame); % 1.2
UStack = NaN(ny,nx,2,finalFrame);               % Ux,Uy stored in 3rd dimension (2.0)
gridPixels = cell(nBoxes,1);               % 2.4
% gridPixels = NaN(nBoxes,(dX+1)*(dY+1));
MissingFramesTF = false(finalFrame,1); % 2.0
%--------------------------------------------------------------------------

%%% compute the box areas -------------------------------------------------
imagePixels = (1:(imageSize(1)*imageSize(2)))';                 % 2.5
[imagePixelsYs,imagePixelsXs] = ind2sub(imageSize,imagePixels); % 2.5
for b = 1:nBoxes
    % turns linear index into grid coordinate
    [ky, kx] = ind2sub([ny nx], b);
    % get the box corner vertices (xbv,ybv) (2.4)
    x1 = round(GRID_DEF.ULCs{ky,kx}(1));
    y1 = round(GRID_DEF.ULCs{ky,kx}(2));
    x2 = x1+dX;
    y2 = y1+dY;
    xbv = [x1 x2 x2 x1];
    ybv = [y1 y1 y2 y2];
    % Looks for pixels inside the box (2.4)
    boxMaskInTF = inpolygon(imagePixelsXs,imagePixelsYs,xbv, ybv); % 2.5
%     boxMaskIn = FindInOnPoly(xbv, ybv, imageSize(2), imageSize(1));
    boxPixels = find(boxMaskInTF);
    gridPixels{b} = boxPixels; % list of linear indices of pixels inside each box compartment
    
%     [X, Y] = meshgrid(x1:x1+dX,y1:y1+dY);
%     boxPixels = sub2ind(imageSize,Y,X);
%     gridPixels(b,:) = boxPixels(:);             % linear indices of pixels inside each box compartment
end
%--------------------------------------------------------------------------

%% Process %%

progressbar(['Calculating velocity field from ' VMtag ' over ' Animal ' frames...']); % mod 1.1

% Loading PIV grid definition (2.0)
gridDefPIV = [pathFolderPIV4VM filesep filenamePIV  '_GridDef.mat']; % use of "pathFolderPIV4VM" instead of "pathFolderPIV" (2.2)
gridDefPIVbackup = load(gridDefPIV);
xPIV = gridDefPIVbackup.x; % in PIXELS
yPIV = gridDefPIVbackup.y;

% Gets INITIAL grid centroids ----------------------------------------------
XYmatCentroids = cell2mat(GRID_DEF.Centroids);
Xcentroids     = XYmatCentroids(:,1:2:end); % in PIXELS
Ycentroids     = XYmatCentroids(:,2:2:end);
%----------------------------------------------------------------------

MissingFramesTF(1) = true; % PIV value won't be stored for 1st frame

for f = 1:finalFrame-1 % NB: PIV BACKUP file N corresponds to displacements between N and N+1 => stops at finalFrame-1
    
    %%% load the piv mat file ---------------------------------------------
    backupFilename = ['PIV_' Animal '_' num2str(f,digitsFormat) '.mat'];
    backupFilePath = [pathFolderPIV4VM filesep 'Backups' filesep backupFilename];  % use of "pathFolderPIV4VM" (2.2)
    
    if exist(backupFilePath,'file')
        
        PIV    = load(backupFilePath);
        u     = PIV.u * scale1D * 60 / dt; % in IN MICRON PER HOURS; (mod 2.6)
        v     = PIV.v * scale1D * 60 / dt; % in IN MICRON PER HOURS; (mod 2.6)
        
        %%% Velocity interpolation --------------------------------------------
        Ux  = griddata(xPIV, yPIV, u, Xcentroids, Ycentroids);
        Uy  = griddata(xPIV, yPIV, v, Xcentroids, Ycentroids);
        %----------------------------------------------------------------------
        
        %%% load Region of Interest -------------------------------------------
        RoIname = [pathFolderROI filesep roiname num2str(f,digitsFormat) '.png'];
        if ~exist(RoIname,'file')
            RoI = ones(imageSize) .* 255;
        else
            RoI = double(imread(RoIname));
        end
        RoI     = RoI ./ nanmax(RoI(:)); % resets everything between 0 and 1
        %----------------------------------------------------------------------
        
        %%% compute the areas ratio -------------------------------------------
        ARraw = cellfun(@(C) sum(RoI(C))/length(C), gridPixels); % 2.4
%         AR = sum(RoI(gridPixels),2) ./ size(gridPixels,2);
        AR = reshape(ARraw,ny,nx);
        %----------------------------------------------------------------------
        
        % Filtering according to lowest AR values (2.0)
        killTF = AR <= threshAR;
        Ux(killTF) = NaN;
        Uy(killTF) = NaN;
        
        % Filling 4D matrices "V" and "AreaRatios" (2.0)
        UStack(:,:,1,f+1) = Ux;
        UStack(:,:,2,f+1) = Uy;
        AreaRatiosStack(:,:,1,f+1) = AR;            % 2.0
        % NB: STORING PIV BACKUP N AT ROW N+1 (for consistency with TA)
    else
        MissingFramesTF(f+1) = true; % 2.0
    end
    
    progressbar(f/(finalFrame-1)); % 2.0
end

MissingFrames = find(MissingFramesTF); % 2.0

%% History %%

% 2 DO:
% - use parfor (is it worth it?)
% - change griddata by TriScatteredInterp (if applicable)
% NB: the AreaRatios are all at 1

% 15/10/2020: 2.6 (Boris)
% - stopped loading uq,vq to use u,v instead (accordingly with PIV 3.4 update)
% - removed all calls to "PIVtype"
% - increased "threshAR" to 0.01 from 0.001

% 09/04/2020: 2.5 (Boris)
% - stopped using function "FindInOnPoly" that is UNRELIABLE!!! Now
% directly uses Matlab function "inpolygon" to determine which pixels lie
% inside a grid compartment.

% 05/11/2019: 2.4 (Boris)
% - fixed bug wrongly listing pixels of coordinates 0 or going out of image by
% using "FindInOnPoly" to determine pixels within each box.

% 17/09/2018: 2.3 (Boris)
% - "allPixelLs" became "gridPixelLs"
% - fixed mistake in dX and dY calculation that used to take grid overlap
% into account

% 06/09/2018: 2.2 (Boris)
% - use of "pathFolderPIV4VM" instead of "pathFolderPIV"

% 15/06/2018 : 2.1 (Stephane)
% - add case if RoI not found/generated, replace by fake RoI corresponding at 
%   image size

% 31/05/2018 : 2.0 (Boris)
% - now creates stacks ALWAYS having "finalFrame" depth and filled with
% NaNs for slices before "startFrame"
% - only one input parameter, "SAPparameterFile" which is the path to
% SAPparameters backup file
% - took loading of XY PIV and grid coordinates outside of loop over frame.
% - loading uq and vq rather than u and v

% 28/05/2018 : 1.1 (Boris)
% - changes to adapt it to new SAP structure
% - removed "PIVgrid" from arguments
