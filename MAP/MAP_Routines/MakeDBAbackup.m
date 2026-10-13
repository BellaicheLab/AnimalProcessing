function DBAbackup = MakeDBAbackup(deltaAnimals, LoadedBackupsIn, gridOverlap, halfNotum, cloneTracking, DISPLAY)
%
% DBAbackup = MakeDBAbackup(deltaAnimals, LoadedBackupsIn, gridOverlap, halfNotum, cloneTracking, DISPLAY)
%
% Version 2.0
% Boris Guirao

%% Building common Grid (2.0) %%

% Updating RAW macro coordinates in new common image with average (rewritten 1.2)
macro1cRaw = LoadedBackupsIn{1}.REG.MacrocaetesRaw;
macro2cRaw = LoadedBackupsIn{2}.REG.MacrocaetesRaw;
% NB: MacrocaetesRaw are macro positions in MICRON using ANIMAL
% ORIGIN (ususally macro barycenter)
meanMacrocaetesRaw = 0.5*(macro1cRaw + macro2cRaw); % taking average

% Updating RAW midline coordinates in new common image (rewritten 1.2)
yMid1cRaw = LoadedBackupsIn{1}.REG.yMidRaw;
yMid2cRaw = LoadedBackupsIn{2}.REG.yMidRaw;
meanDeltaYmidRaw = 0.5*(yMid1cRaw + yMid2cRaw); % taking average

% Building commond grid (2.0)
[GRID,LOCxy] =  BuildCommonGrid(deltaAnimals, deltaAnimals, LoadedBackupsIn, meanMacrocaetesRaw, meanDeltaYmidRaw, gridOverlap, halfNotum, cloneTracking, DISPLAY);


%% Filling "DBAbackup" %%

fields2skip = {'Coordinates', 'ULCs', 'Color','FrameArray','TimeArray','LineWidth','Size','fullImage','originBoxIJ','Overlap','REG','FULL','filteringTag'};
% fields2skip = {'Coordinates', 'ULCs', 'Color','FrameArray','TimeArray','LineWidth','Size','fullImage','originBoxIJ','Overlap'};

LtotX = GRID.Size(2);
LtotY = GRID.Size(1);
fieldList = fieldnames(LoadedBackupsIn{1}); % Get the list of field to process from one of the backup

for f = 1:length(fieldList)
    
    fthFieldIn1 = LoadedBackupsIn{1}.(fieldList{f});
    fthFieldIn2 = LoadedBackupsIn{2}.(fieldList{f});
    
    if ~ismember(fieldList{f},fields2skip) && ~isstruct(fthFieldIn1) && ~strcmp(fieldList{f},'AreaRatios') && isempty(strfind(fieldList{f},'_Smap'))
        
        fthFieldOut1 = NaN(LtotY,LtotX, size(fthFieldIn1,3), size(fthFieldIn1,4)); % now initializes matrices with NaNs rather then Zeros (2.0)
        fthFieldOut1(LOCxy.startLocY(1):LOCxy.endLocY(1), LOCxy.startLocX(1):LOCxy.endLocX(1),:,:) = fthFieldIn1(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values

        fthFieldOut2 = NaN(LtotY,LtotX, size(fthFieldIn2,3), size(fthFieldIn2,4));
        fthFieldOut2(LOCxy.startLocY(2):LOCxy.endLocY(2), LOCxy.startLocX(2):LOCxy.endLocX(2),:,:) = fthFieldIn2(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
               
        % CALCULATING DIFFERENCE BETWEEN Q1 AND Q2:
        fthDeltaFields = fthFieldOut1 - fthFieldOut2;
        DBAbackup.(fieldList{f}) = fthDeltaFields;
        
    elseif ~ismember(fieldList{f},fields2skip) && ~isstruct(fthFieldIn1)        % Special case for AreaRatios and Smap matrices: initialization with Zeros (2.0)
        
        % For AreaRatios, initializes new matrices with ZEROS:
        fthFieldOut1 = zeros(LtotY,LtotX, size(fthFieldIn1,3), size(fthFieldIn1,4)); % /!\ SHOULD PROBABLY BE INITIALIZED WITH NaNS RATHER THEN Zeros  /!\
        fthFieldOut1(LOCxy.startLocY(1):LOCxy.endLocY(1), LOCxy.startLocX(1):LOCxy.endLocX(1),:,:) = fthFieldIn1(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
        
        fthFieldOut2 = zeros(LtotY,LtotX, size(fthFieldIn2,3), size(fthFieldIn2,4));
        fthFieldOut2(LOCxy.startLocY(2):LOCxy.endLocY(2), LOCxy.startLocX(2):LOCxy.endLocX(2),:,:) = fthFieldIn2(:,:,:,:,1);
        % NB: only keeps average value (located at slice 1) not single animal values
        
        if strcmp(fieldList{f},'AreaRatios') % min(A.ar, B.ar)
            disp(['min : ' fieldList{f}]);
            ARfield = min(fthFieldOut1, fthFieldOut2);
            DBAbackup.(fieldList{f}) = ARfield;
            
        elseif ~isempty(strfind(fieldList{f},'_Smap'))% if Significance map, logical AND(A.map, B.map)
            disp(['logical OR : ' fieldList{f}]); 
            fthFieldSmap = or(fthFieldOut1, fthFieldOut2);
            DBAbackup.(fieldList{f}) = fthFieldSmap;
        end
    else
        DBAbackup.(fieldList{f}) = fthFieldIn1; % copy FIRST value of fields2skip as it is
    end
end

%% Overwritting with common grid values %%

%common size:
DBAbackup.Size = GRID.Size;
% originBoxIJ
DBAbackup.originBoxIJ = GRID.originBoxIJ;
% ULCs, Coordinates
DBAbackup.Coordinates = GRID.Coordinates;
DBAbackup.ULCs = GRID.ULCs;
% REG & FULL structures:
DBAbackup.REG = GRID.REG;
DBAbackup.FULL = GRID.FULL;


%% History %%

% NB: FULL structure has not been much tested/checked

% 03/10/2024: 2.0 (Boris)
% - now uses "BuildCommonGrid" function to build common grid between WT and
% mutant archetypes
% - now initializes matrices with NaNs for regular quantities and with
% Zeros for AreaRatios and Smap quantities

% 30/09/2024: 1.2 (Boris)
% - fixed issue with macrocaetes (and midline) dipslay: used to crash when
% NOT 16 and were misplaced (stopped using MacrocaetesMCU to rather use
% MacrocaetesRaw)

% 15/01/2024: 1.1
% - fixed macrocaetes and midline display

% 03/06/20: creation

