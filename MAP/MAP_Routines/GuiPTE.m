function [Qboxes, guiImage, guiFH] = GuiPTE(BACKUP, clickTime, DISPLAY)
%
% [Qboxes, guiImage, guiFH] = GuiPTE(BACKUP, clickTime, PLOT)
%
% GUI for area selection in PTE
% version = 1.1
% Stephane
% Boris

%% Code %%

%%% Build grid with AreaRatios as animal boundaries
TimeDecArray = mean(cellfun(@TimeStr2Dec,BACKUP.TimeArray),2);
[~,TimeDecArrayIdx] = min(abs(TimeDecArray - repmat(TimeStr2Dec(clickTime),[numel(TimeDecArray) 1])));
if isempty(DISPLAY.path2BackgroundMap)
    backgroundMap = BACKUP.AreaRatios(:,:,1,TimeDecArrayIdx,1);
else
    backgroundMap = imread(DISPLAY.path2BackgroundMap);
end
guiImage = imresize(backgroundMap,[BACKUP.REG.SizeImageY,BACKUP.REG.SizeImageX]);
GUIgrid = MakeGrid(size(guiImage), DISPLAY.boxSize, BACKUP.ULCs{1,1}, BACKUP.Size, [0 0 0], 0.5, BACKUP.Overlap);
% GUIgrid = MakeGrid(size(guiImage), PLOT.boxSize, BACKUP.REG.xywh(1:2), [], [0 0 0], 1, 0.5);
% Updating grid xywh by actual origin [newOxReg newOyReg]:
GUIgrid.xywh = BACKUP.REG.xywh; 
% Updating array "Coordinates" to set compartment containing orgin to [0,0] (3.4): 
GUIgrid.Coordinates = BACKUP.Coordinates;
GUIgrid.originBoxIJ = BACKUP.originBoxIJ;

%%% plot GUI interface
[guiImage,guiFH] = PlotGrid(guiImage,GUIgrid);
hold on
% origin and axis bar
plot(GUIgrid.xywh(1),GUIgrid.xywh(2),'or');
plot([GUIgrid.xywh(1) GUIgrid.xywh(1)],[1 size(guiImage,2)],'-r');
plot([1 size(guiImage,1)],[GUIgrid.xywh(2) GUIgrid.xywh(2)],'-r');

% macrochaetes
scatter(BACKUP.REG.Macrocaetes(1,:),BACKUP.REG.Macrocaetes(2,:),DISPLAY.macroSize,...
    'MarkerFaceColor',DISPLAY.colorMacrochaetes,'MarkerEdgeColor',[0 0 0],'LineWidth',DISPLAY.lineWidth)

% centroidCoordMatX = cellfun(@(x)(x(1)),GUIgrid.Centroids) - (GUIgrid.xywh(3) * GUIgrid.Overlap) ./ 2;
% centroidCoordMatY = cellfun(@(x)(x(2)),GUIgrid.Centroids) - (GUIgrid.xywh(4) * GUIgrid.Overlap) ./ 2;

waitSelectionLoop = true;
listIdx = [];
hboxarray = [];
while waitSelectionLoop
    %%% loop on the ploted grid for user to select ULC of interest
    try
        [nx, ny, buttemp] = ginput(1);
    catch err
        if strcmp(err.identifier,'MATLAB:ginput:FigureDeletionPause')
            disp(err.identifier); % other error
        end
        return;
    end
    
    %%% manage input
    switch buttemp
        case 1 % left click
            % get box index IJ of the click 
            [~, clickBoxIJ] = gridULCs2gridCoordinates(GUIgrid.ULCs, [nx ny]); 
            idx = sub2ind(GUIgrid.Size, clickBoxIJ(1), clickBoxIJ(2));
            if ~ismember(idx,listIdx)
                listIdx = [listIdx ; idx];
            end
            % plot box marker
            boxCentroid = GUIgrid.Centroids{idx};
            hboxarray = [hboxarray plot(boxCentroid(1),boxCentroid(2), '*b')];
%             hboxarray = [hboxarray plot(centroidCoordMatX(idx), centroidCoordMatY(idx), '*b')];
            
        case {113 ; 27}
            % esc or q for closing the gui, with selection validation
            butExit = questdlg('Is this the region you want to process?','Selection Validation','Yes','Reset','Exit','Yes');
            switch butExit
                case 'Yes'
                    waitSelectionLoop = false;
%                     close;
                case 'Reset'
                    listIdx = [];
                    delete(hboxarray)
                case 'Exit'
                    close;
                    return;
            end
            
        case 98
            % b for box creation
            if numel(listIdx) == 2
                listIdx = ComputeAreaCoord(listIdx(1), listIdx(2), GUIgrid.Size);

                boxCentroid = GUIgrid.Centroids(listIdx);
                boxCentroid = cell2mat(boxCentroid);
                % plot box marker
                delete(hboxarray)
                hboxarray = [hboxarray plot(boxCentroid(:,1), boxCentroid(:,2), '*b')];
%                 hboxarray = [hboxarray plot(centroidCoordMatX(listIdx), centroidCoordMatY(listIdx), '*b')];
            else
                ok = warndlg(['You need 2 coordinates clicked, please reset your selection and click only two boxes ' ...
                              'for BoxCreation'],'Selection Validation','modal');
            end
            
        otherwise
            % nothing for now
    end
    
end

%%% Index to Qboxes coordinates from origin
Qboxes = GUIgrid.Coordinates(listIdx);
end

%% History (Boris) %%

% 21/05/2020: 1.1





