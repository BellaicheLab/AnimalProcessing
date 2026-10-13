function [Qboxes] = GuiLTA(Ori, BACKUP, clickTime, PLOT)
% GUI for area selection in LTA
% version = 1.0
% Stephane

%%% Build grid with AreaRatios as animal boundaries
TimeDecArray = mean(cellfun(@TimeStr2Dec,BACKUP.TimeArray),2);
[~,TimeDecArrayIdx] = min(abs(TimeDecArray - repmat(TimeStr2Dec(clickTime),[numel(TimeDecArray) 1])));
matAR = BACKUP.AreaRatios(:,:,1,TimeDecArrayIdx,1);
guiImage = imresize(matAR,[BACKUP.REG.SizeImageY,BACKUP.REG.SizeImageX]);
GUIgrid = MakeGrid(size(guiImage), PLOT.boxSize, BACKUP.REG.xywh(1:2), [], [0 0 0], 1, 0.5);

%%% plot GUI interface
gui1 = PlotGrid(guiImage,GUIgrid);
hold on
% origin and axis bar
haxis2 = plot(GUIgrid.xywh(1),GUIgrid.xywh(2),'or');
haxis2 = plot([GUIgrid.xywh(1) GUIgrid.xywh(1)],[1 size(guiImage,2)],'-r');
haxis2 = plot([1 size(guiImage,1)],[GUIgrid.xywh(2) GUIgrid.xywh(2)],'-r');
% macrochaetes
for i = 1:size(BACKUP.REG.Macrocaetes,2)
    a = 10;
    b = 10;
    x = BACKUP.REG.Macrocaetes(1,i);
    y = BACKUP.REG.Macrocaetes(2,i);
    EDISPLAY.EdgeWidth = 1.5;
    EDISPLAY.FaceColor = [1 1 0];        % 1.19
    EDISPLAY.EdgeStyle = '-';
    EDISPLAY.FaceOpacity = 0.75;
    Ellipse(10,10,x,y, 0, EDISPLAY); % put a,b (1.25)
end

centroidCoordMatX = cellfun(@(x)(x(1)),GUIgrid.Centroids) - (GUIgrid.xywh(3) * GUIgrid.Overlap) ./ 2;
centroidCoordMatY = cellfun(@(x)(x(2)),GUIgrid.Centroids) - (GUIgrid.xywh(4) * GUIgrid.Overlap) ./ 2;

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
            % get index coordinate of the click 
            nX = floor(nx ./ (GUIgrid.xywh(3) * GUIgrid.Overlap));
            nX(nX > GUIgrid.Size(2)) = GUIgrid.Size(2);
            nY = floor(ny ./ (GUIgrid.xywh(4) * GUIgrid.Overlap));
            nY(nY > GUIgrid.Size(1)) = GUIgrid.Size(1);
            idx = sub2ind(GUIgrid.Size, nY, nX);
            if ~ismember(idx,listIdx)
                listIdx = [listIdx ; idx];
            end
            % plot box marker
            hboxarray = [hboxarray plot(centroidCoordMatX(idx), centroidCoordMatY(idx), '*b')];
            
        case {113 ; 27}
            % esc or q for closing the gui, with selection validation
            butExit = questdlg('Is this the region you want to process?','Selection Validation','Yes','Reset','Exit','Yes');
            switch butExit
                case 'Yes'
                    waitSelectionLoop = false;
                    close;
                case 'Reset'
                    listIdx = [];
                    delete(hboxarray)
                case 'Exit'
                    return;
            end
            
        case 98
            % b for box creation
            if numel(listIdx) == 2
                listIdx = ComputeAreaCoord(listIdx(1), listIdx(2), GUIgrid.Size);
                
                % plot box marker
                delete(hboxarray)
                hboxarray = [hboxarray plot(centroidCoordMatX(listIdx), centroidCoordMatY(listIdx), '*b')];
            else
                ok = warndlg(['You need 2 coordinates clicked, please reset your selection and click only two boxes ' ...
                              'for BoxCreation'],'Selection Validation','modal');
            end
            
        otherwise
            % nothing for now
    end
    
end

%%% Index to Qboxes coordinates from origin
[yl,xl] = ind2sub(GUIgrid.Size, listIdx);
Qboxes = mat2cell([xl yl],ones(numel(xl),1),2);
Qboxes = cellfun(@(x)(x - (Ori)), Qboxes,'UniformOutput',false);

end






