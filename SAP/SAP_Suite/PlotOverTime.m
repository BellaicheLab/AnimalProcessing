% PlotOverTime
%
% In the AOT folder, will create a "time.plots" folder right next to
% map "split+" or "circle" folder.
%
% Version 1.6
% Boris Guirao

%% Code %%

AllQsColorsUnits;

nZones = length(boxIJs);       % 1.2

%%% Defining folder for average:
averageFolderStart = ['Average_' num2str(roundn(timeWidth,-2)) 'h_'];
averageFolderMiddle = [timeStart '_to_' timeStop];
averageFolderEnd = ['_olap_' num2str(roundn(timeOverlap,-2))];
if noAverage
    averageFolderStart = 'noAverage_';
    averageFolderEnd = '';
end
singleFrameTF = false;          % are we analyzing a SINGLE frame?
if strcmp(timeStart,timeStop)
    averageFolderMiddle = timeStart;
    singleFrameTF = true;
end
averageFolderName = [averageFolderStart  averageFolderMiddle averageFolderEnd];
averageFolderAOT = [gridFolderAOT filesep averageFolderName];
fullPathAOT = [averageFolderAOT filesep 'mean_' filenameAOT '.mat'];

AOTbackup = load(fullPathAOT);

%% Iteraton over TYPES (iso,devDiag,devOffDiag), then over ZONES %%

typeList = {'iso', 'devDiag', 'devOffDiag'}; % 1.1

% time array
meanFrameArray = mean(AOTbackup.FrameArray,2);
meanTimeArray = frame2time(meanFrameArray, timeRef, frameRef, dt, 'dec');

frameFolderPOT = [averageFolderAOT filesep 'time_plots_' plotTypePOT];
maxValueFile = [frameFolderPOT filesep 'maxValues.mat'];

%%% iteration over TYPES
for t = 1:3 
    
    if ~isempty(Qs2Plot.(typeList{t})) % skips if empty
        
        Qs2PlotType = Qs2Plot.(typeList{t});
        nQs2PlotType = length(Qs2PlotType);
        legendText = cell(1,nQs2PlotType);
        Qs2PlotMaxType = Qs2PlotMax.(typeList{t});          % 1.4
        
        % when Qs2PlotMaxType empty, creatig empty cell array of right size (1.5).
        if isempty(Qs2PlotMaxType)
            Qs2PlotMaxType = cell(1,nQs2PlotType);
            
        elseif length(Qs2PlotMaxType) == 1 % if only one value, repeating it (1.6)
            Qs2PlotMaxType = num2cell(repmat(Qs2PlotMaxType{1},1,nQs2PlotType));
        end

        % Generating "maxValuesAll"
        maxValuesAll.(typeList{t}) = NaN(nZones,nQs2PlotType); % 1.3
        
        %%% iteration over ZONES
        for z = 1:nZones                    % 1.2
            
            zBoxIJs = boxIJs{z};            % 1.2
            nzBoxesIJs = size(zBoxIJs,1);
            zBoxIJsText = '';
            
            for q = 1:nQs2PlotType
                
                qQname = Qs2PlotType{q};
                qQMax = Qs2PlotMaxType{q};
               
                % Looking for a ratio (1.3)
                barLoc = strfind(qQname,'/');
                if ~isempty(barLoc)                     % Case of a ratio entered (1.3)
                    
                    qQnameTop = qQname(1:barLoc-1);
                    qQnameBottom = qQname(barLoc+1:end);
                    
                    qQT = AOTbackup.(qQnameTop);
                    qQR = AOTbackup.(qQnameBottom);
                    qQ = qQT./qQR;
                    
                else
                    qQnameTop = qQname;
                    qQ = AOTbackup.(qQname);
                end
                
                qQind = find(strcmp(allQs, qQnameTop)); % keeps colors and units of the numerator (1.3)
                qQcolor = allColors{qQind};
                qQunits = allUnits{qQind};
                
                % creating cropped version of qQ corresponding to boxIJs:
                qQsize = size(qQ);
                qQcrop = NaN(nzBoxesIJs, qQsize(4)); % will store a scalar value for each box(1.1)
                
                for b = 1:nzBoxesIJs
                    
                    % Defining "boxIJsText"
                    if q == 1
                        zBoxIJsText = [zBoxIJsText '[' num2str(zBoxIJs(b,1)) '.' num2str(zBoxIJs(b,2)) ']' ]; %#ok<AGROW>
                    end
                    
                    % Processing this box Q:
                    qQbox = qQ(zBoxIJs(b,1),zBoxIJs(b,2),:,:);
                    
                    if qQsize(3) == 4               % Tensor case
                        
                        [qQboxSplit.iso, qQboxSplit.devDiag, qQboxSplit.devOffDiag] = SplitIsoDev(qQbox);
                        qQboxPlot = qQboxSplit.(typeList{t});
                        
                    elseif qQsize(3) == 2           % Vector case (1.2)
                        
                        % Will plot the vector norm:
                        qQboxPlot = squeeze(qQbox);                 % yields a 2 x qQsize(4) matrix
                        qQboxPlot = qQboxPlot';                     % now qQsize(4) x 2
                        qQboxPlot = (sum(qQboxPlot.^2,2)).^(1/2);   % take the norm
                        
                    else                            % Scalar case
                        qQboxPlot = qQbox;
                    end
                    
                    qQcrop(b,:) = qQboxPlot; % 1.1
                end
                
                % Taking mean over listed compartments/clone
                qQplot = nanmean(qQcrop,1);
                
                if strcmp(plotTypePOT,'cum')
                    qQplot = nancumsum(qQplot*dtH);
                    if strcmp(qQunits,'h^{-1}')
                        qQunits = '';
                    else
                        qQunits = [qQunits '.h']; %#ok<AGROW>
                    end
                end
                
                qQplotMax = max(abs(qQplot));
                
                maxValuesAll.(typeList{t})(z,q) = qQplotMax; % 1.3
                
                if strcmp(plotRenormPOT,'renorm')
                    
                    if isempty(qQMax)
                        qQMax = qQplotMax; % applies this max value if no value specified in "Qs2PlotMax"
                    end
                    qQplot = qQplot/qQMax;
                    legendText{q} = [qQname ' (' num2str(qQMax,2) ' ' qQunits ')'];
                    
                    ylim([-1,1]); % setting fixed limits
                    
                elseif strcmp(plotRenormPOT,'raw')
                    legendText{q} = [qQname ' (' qQunits ')'];
                else
                    warndlg('POT ERROR: parameter "plotRenormPOT" can only be "renorm" or "raw"!', 'Warning!')
                    return
                end
                
                figure(1)
                plot(meanTimeArray, qQplot, 'Color', qQcolor, 'LineWidth',1.5)
                hold on
            end
            
            line([meanTimeArray(1) meanTimeArray(end)],[0 0],'LineStyle','--','Color',black)
            
            ylabel('Qs')
            xlabel('time (hAPF)')
            legend(legendText,'Location','Best','FontSize',6);
            title([typeList{t} ' parts of regions ' zBoxIJsText])
            
            %%% Saving image "frameFolderAOT" (4.0):
            if ~exist(frameFolderPOT,'dir')
                mkdir(frameFolderPOT);
            end
            
            thisFilename = [plotTypePOT '_' plotRenormPOT '_' 'boxIJs_' zBoxIJsText '.' typeList{t}];
            print(printFormat, printResolution, [frameFolderPOT filesep thisFilename '.png']);
            close
        end
        % only keeps max value for each quantity among all zones:
        maxValues.(typeList{t}) = [Qs2Plot.(typeList{t}) ; num2cell(max(maxValuesAll.(typeList{t}),[],1))]; % 1.4
    end
end

save(maxValueFile,'maxValues');



%% History %%

% 12/12/2019: 1.6
% - if only one value is listed in "Qs2PlotMaxType", repeating it
% "nQs2PlotType" times to apply it to every quantity.
% - now redefines "zBoxIJsText" for every type of "typeList"

% 11/02/2019: 1.5
% - when Qs2PlotMaxType empty, creating empty cell array of right size (1.5).

% 11/02/2019: 1.4
% - reverted automatic application of max values in the plot series
% according to "Qs2PlotMaxTF". Now uses values manually entered in
% "Qs2PlotMax", which gives more possibilities.

% 08/02/2019: 1.3
% - now possible to directly enter a ratio of quantity like "dnA/nCoreRNs" into "Qs2Plot".
% - now saves "maxValues" vector into "maxValues.mat" file
% - now loads "maxValues.mat" to automatically apply max values in the plot
% series according to "Qs2PlotMaxTF".

% 07/02/2019: 1.2
% - now supporting the vector case (taking its norm)
% - now processing several series zones in a row => "boxIJs" defined in
% SAP_parameters became a cell array.

% 29/01/2019: 1.1
% - now support plot of tensors

% 28/01/2019: 1.0
% - support of scalar quantities
