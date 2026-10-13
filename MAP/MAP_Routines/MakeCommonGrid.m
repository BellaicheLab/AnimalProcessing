function LoadedBackupsOut = MakeCommonGrid(LoadedBackupsIn, DISPLAY, gridOverlap)
%
% LoadedBackupsOut = MakeCommonGrid(LoadedBackupsIn, DISPLAY, gridOverlap)
%
% Version 1.0
% Boris Guirao

 
%% Code %%

% Get the grid size
s1 = LoadedBackupsIn{1}.Size; % (H1,W1)
s2 = LoadedBackupsIn{2}.Size; % (H2,W2)

oIJ1 = LoadedBackupsIn{1}.originBoxIJ;
oIJ2 = LoadedBackupsIn{2}.originBoxIJ;

oIJc = max([oIJ1;oIJ2],[],1); %  originBoxIJ in common grid
sc = oIJc + max([s1-oIJ1; s2-oIJ2],[],1); % common grid size (Hc,Wc)

%% Determining startLocIJ, endLocIJ %%

startLocIJ = 1 + oIJc - [oIJ1 ; oIJ2];
endLocIJ = startLocIJ + [s1 ; s2] - 1;

%% Determining image size

% Minimal image size
sizeImageXmin = ceil(DISPLAY.boxSize(1) * (1 + (sc(2)-1) * (1 - gridOverlap)));  
sizeImageYmin = ceil(DISPLAY.boxSize(2) * (1 + (sc(1)-1) * (1 - gridOverlap)));

% Adding at least one full box size along X and Y on BOTH sides of images (2.7)
leeway = 0.05;
sizeImageXext = ceil(min(sizeImageXmin * (1+leeway), sizeImageXmin + 2 * DISPLAY.boxSize(1)));
sizeImageYext = ceil(min(sizeImageYmin * (1+leeway), sizeImageYmin + 2 * DISPLAY.boxSize(2)));
% NB: Adding leeway so as NOT to start grid at [0,0] but further from image border and still fit it in image

% setting final leeway:
leewayPixX = sizeImageXext - sizeImageXmin; % image extra pixels along X
leewayPixY = sizeImageYext - sizeImageYmin; % image extra pixels along Y

sizeImageXreg = sizeImageXext;
sizeImageYreg = sizeImageYext;

% Setting new origin
% % ACTUAL new origin in image:
newOxReg = DISPLAY.boxSize(1) * (oIJc(2)-1) * (1 - gridOverlap) + leewayPixX/2;
newOyReg = DISPLAY.boxSize(2) * (oIJc(1)-1) * (1 - gridOverlap) + leewayPixY/2;
% meanYmidReg = newOyReg - meanDeltaYmid; % 2.5
% NB: subtracting "PLOT.boxSize" because box origin is normally at ULC of box => subtraction of one full box width/height

% Build global common REGULAR grid
% since using gridSize to keep previous size, need to determine grid new ULC in extended image (2.7)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
GRIDreg = MakeGrid([sizeImageYreg sizeImageXreg], DISPLAY.boxSize, [leewayPixX/2 leewayPixY/2], sc , [], [], gridOverlap);
% NB: at this stage, array "Coordinates" is NOT up to date as temporary
% grid origin was taken at top left corner of grid.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Updating grid xywh by actual origin [newOxReg newOyReg]:
GRIDreg.xywh = [newOxReg newOyReg GRIDreg.xywh(3) GRIDreg.xywh(4)];                 
% Updating array "Coordinates" to set compartment containing orgin to [0,0] (3.4):
[gridCoordinates, originBoxIJcheck] = gridULCs2gridCoordinates(GRIDreg.ULCs, round([newOxReg newOyReg]));  

if norm(originBoxIJcheck - oIJc) > 0
    warndlg('Discrepancy between variables "oIJc" and "originBoxIJcheck"!!','WARNING!')
end

%% Filling "LoadedBackupOut" %%

LoadedBackupsOut = cell(1,2);

fields2skip = {'Coordinates', 'ULCs', 'Color','FrameArray','TimeArray','LineWidth','Size','fullImage','originBoxIJ','Overlap'};

fieldList = fieldnames(LoadedBackupsIn{1}); % Get the list of field to process from one of the backup
for f = 1:length(fieldList)  
    for a = 1:2
        
        fthFieldIn = LoadedBackupsIn{a}.(fieldList{f});
        
        if ~ismember(fieldList{f},fields2skip) && ~isstruct(fthFieldIn)
            
                fthFieldOut = zeros(sc(1),sc(2),size(fthFieldIn,3),size(fthFieldIn,4),size(fthFieldIn,5));
                
                fthFieldOut(startLocIJ(a,1):endLocIJ(a,1), startLocIJ(a,2):endLocIJ(a,2),:,:,:) = fthFieldIn;
                
                fthFieldOut = fthFieldOut(:,:,:,:,1); % only keeps average value (not each animal value)
                
                LoadedBackupsOut{a}.(fieldList{f}) = fthFieldOut;
        else         
            LoadedBackupsOut{a}.(fieldList{f}) = fthFieldIn; % copy it as it is
        end
            
    end
end

% overriding common size:
LoadedBackupsOut{1}.Size = sc;
LoadedBackupsOut{2}.Size = sc;
% originBoxIJ
LoadedBackupsOut{1}.originBoxIJ = oIJc;
LoadedBackupsOut{2}.originBoxIJ = oIJc;
% ULCs, Coordinates
LoadedBackupsOut{1}.Coordinates = gridCoordinates;
LoadedBackupsOut{2}.Coordinates = gridCoordinates;
LoadedBackupsOut{1}.ULCs = GRIDreg.ULCs;
LoadedBackupsOut{2}.ULCs = GRIDreg.ULCs;


%% History %%

% 03/06/2020: creation

