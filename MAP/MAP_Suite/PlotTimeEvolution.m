% PlotTimeEvolution
%
% Merge all MAP backups and allow the user to plot, in a specific region, one or more quantities over time

version = 1.7; % created from "LocalTimeAnalysis" 4.0
% Stephane Rigaud
% Boris Guirao

%% Code %%

QLineWidth = 1; % default line width

%%% Backup size check with first quantity listed in "QnamePTE"
if isfield(BACKUP, QnamePTE{1}) 
    [Ly, Lx, ~, Lt, La] = size(BACKUP.(QnamePTE{1})); 
else
    warndlg(['ERROR: quantity "' QnamePTE{1} '" listed in "QnamePTE" cannot be found in AOA backup!'],'PTE ERROR')
    return
end

% Skipping execution if only one timepoint to plot (1.4)
if Lt == 1
    disp(['WARNING: only one time point to plot with "timeWidth" = ' num2str(timeWidthAll(t)) 'h => PTE was skipped!'])
    return
end

TimeDecArray = mean(cellfun(@TimeStr2Dec,BACKUP.TimeArray),2);
startAPF = TimeDecArray(1);
endAPF   = TimeDecArray(end);
% startAPF = round(TimeDecArray(1));
% endAPF   = round(TimeDecArray(end));

%%% Define Areas to process
% Loads position of origin box (1.5)
originBoxI = BACKUP.originBoxIJ(1);
originBoxJ = BACKUP.originBoxIJ(2);
% shift grid based on origin
% gridOlap = 1 ./ (1-gridOverlap);
% originBox = cellfun(@(x)sum(abs(x - BACKUP.REG.xywh(1:2))), BACKUP.ULCs, 'UniformOutput', false);
% [originBoxI,originBoxJ] = find(cell2mat(originBox) == 0);
% ShiftBoxCoord = cellfun(@(x)(floor(x .* gridOlap) - [originBoxJ originBoxI]),BACKUP.Coordinates,'UniformOutput',false);

%NB: Not the case currently but end goal is that, whatever the mean, we get
% cell array of origin based coordinate of boxes.
[res] = InputParserPTE(Qboxes);
switch res
    case 'GUI'
        % graphic interface for area selection
        [Qboxes, guiImage] = GuiPTE(BACKUP, clickTime, DISPLAY); % Loading "DISPLAY" rather than "PLOT"
%         Qboxes = GuiPTE(BACKUP, clickTime, PLOT);
        boxTag = ['(' regexprep(num2str(Qboxes{1}), ' *' , ',' ) ')-('  regexprep(num2str(Qboxes{end}), ' *' , ',' ) ')'];

        
    case 'key' % keyword, only "full" for now
        % toBeExtended by other keyword
        Qboxes = BACKUP.Coordinates(:); % 1.5
%         Qboxes = ShiftBoxCoord(:);
        boxTag = '(full)';
        
    case 'LoGC' % List of Grid Compartments
        boxTag = ['(' regexprep(num2str(Qboxes{1}), ' *' , ',' ) ')-('  regexprep(num2str(Qboxes{end}), ' *' , ',' ) ')'];
        
    case 'RSoGC' % rectangle selection of grid comparments
        point1 = Qboxes{1}(1:2) + [originBoxJ originBoxI];
        point2 = Qboxes{1}(3:4) + [originBoxJ originBoxI];
        [listIdx] = ComputeAreaCoord(point1, point2, [Ly Lx]);
        [yl, xl] = ind2sub(BACKUP.Size, listIdx);
%         [yl, xl] = ind2sub(GUIgrid.Size, listIdx);
        Qboxes = mat2cell([xl yl], ones(numel(xl),1), 2);
        Qboxes = cellfun(@(x)(x - ([originBoxJ originBoxI])), Qboxes, 'UniformOutput', false);
        boxTag = ['(' regexprep(num2str(Qboxes{1}), ' *' , ',' ) ')-('  regexprep(num2str(Qboxes{end}), ' *' , ',' ) ')']; % same boxTag as for LoGC??!!
        
    otherwise
        return
end



%%% shift back boxes coordinate and switch them into indexes
QboxesShift = cellfun(@(x)(x + ([originBoxJ originBoxI])), Qboxes, 'UniformOutput', false); % reassigns [1 1] to top left grid compartment
PointList = cell2mat(QboxesShift); % removed the +1 that was a mistake
% PointList = cell2mat(Qboxes) + 1;
idxList = sub2ind([Ly Lx], PointList(:,2), PointList(:,1));

%%% reshape boxes into logical map for data extraction
nbBoxes = numel(Qboxes);
BoxIndexMap = false(Ly, Lx);
BoxIndexMap(idxList) = true;
reshapeBoxIndexMap = repmat(BoxIndexMap, [1 1 1 Lt La]);
boxTagFile = regexprep(boxTag,' *', '');


%%% iteration over tags
for t = 1:length(Qtags)
    
%     Total = zeros(1,Lt,La);
    Qmean = cell(1,size(QnamePTE,1));
    legendQname = {}; % 3.5
    
    %% formatting tensor to project on %%
    
    if ~ismember(Qtags{t},{'uPar','uOrt'})
        
        tUnitTensorTemp = GetUnitTensor(Qtags{t});     % extracts corresponding unitary tensor
        if isempty(tUnitTensorTemp)
           disp(['PTE WARNING: Qtag "' Qtags{t} '" is NOT among possible unitary tensors and was kipped!' ])
           continue
        end
        tUnitTensorTemp = reshape(tUnitTensorTemp, [1 1 4 1 1]);
        tUnitTensor = repmat(tUnitTensorTemp, [Ly, Lx, 1, Lt, La]);
        
    else
        
        % building sigma1 (5D version)
        sigma1 = GetUnitTensor('u1');
        sigma1 = reshape(sigma1, [1 1 4 1 1]);
        sigma1 = repmat(sigma1, [Ly, Lx, 1, Lt, La]);
        % building sigma3 (5D version)
        sigma3 = GetUnitTensor('u3');
        sigma3 = reshape(sigma3, [1 1 4 1 1]);
        sigma3 = repmat(sigma3, [Ly, Lx, 1, Lt, La]);
        
        % building thetaProj (5D version)
        thetaProj = GetAngleMap(Qproj);                 % returns the angle map in rad 
        thetaProj = thetaProj(:,:,:,:,1);               % only keeping 1st value = average value, not single animal values
        thetaProj = repmat(thetaProj, [1 1 1 1 La]);    % repeating it La times
        % managing time-related size
        if Lt > size(thetaProj, 4) && size(thetaProj, 4) == 1
            thetaProj = repmat(thetaProj, [1 1 1 Lt 1]); % repeating single value "Lt" times, namely as many times as there are timepoints
        else
            warndlg('ERROR: one can only project on backup having 1 or same number of timepoints as quantities to plot over time!','PTE ERROR')
            return
        end
        
        cosThetaProj = repmat(cos(2*thetaProj), [1 1 4 1 1]);
        sinThetaProj = repmat(sin(2*thetaProj), [1 1 4 1 1]);
        
        if strcmp(Qtags{t},'uPar')
            tUnitTensor  = cosThetaProj .* sigma3 + sinThetaProj .* sigma1;   
        elseif strcmp(Qtags{t},'uOrt')
            tUnitTensor = -sinThetaProj .* sigma3 + cosThetaProj.* sigma1;
        end
    end
    
    %% iteration over quantities
    for q = 1:length(QnamePTE)
        
        % Get information the data
        qQname = QnamePTE{q};
        
        % weight calculation (mod 3.4)
        subAreaRatios = reshape(BACKUP.AreaRatios(reshapeBoxIndexMap),[1 nbBoxes 1 Lt La]);
        Weight = subAreaRatios .^ 2;
        
        % Calculate quantity to plot
        if isfield(BACKUP, qQname) % 3.5
            fprintf(['\t\tExtracting ' QnamePTE{q} ' ...'])
            
            % extract quantity of the crop zone
            qQ = eval(['BACKUP.' qQname ';']);
            
            % If plotting dimensionless Qdev:
            if ismember(qQname,QDevRenorm) && size(qQ,3) == 4 && ~strcmp(Qtags{t},'u0') % NOT renormalizing if iso part or scalar
                detqQ = qQ(:,:,1,:,:).*qQ(:,:,4,:,:) - qQ(:,:,2,:,:).*qQ(:,:,3,:,:);
                Qo = sqrt(detqQ);
                Qo = repmat(Qo,[1 1 4 1 1]);
                
                % ALWAYS removing iso part when listed in QDevRenorm (1.2)
                qQtrace = qQ(:,:,1,:,:) + qQ(:,:,4,:,:);
                qQiso = repmat(qQtrace/2,[1 1 4 1 1]);
                qQiso(:,:,2:3,:,:) = 0; % setting off diagonal terms to zero
                qQ = qQ - qQiso; % Removing trace => forcing plot of DEV part
                % NB: removing the iso part doesn't change anything when
                % projecting on u3, u1, uPar, uOrt (as u0 is orthogonal to
                % those). Only make a difference when plotting xx,yy,xy
                % components.
                
                qQ = qQ./Qo;
            end

            if size(qQ,3) > 2      % not a scalar or vector => requires projection
%                 qQ = TensorNormMap(qQ);
                Qplot = TensorScalarProduct5D(qQ, tUnitTensor);
                % Vector case (1.4)
            elseif size(qQ,3) == 2 && strcmp(Qtags{t},'xx')
                Qplot = qQ(:,:,1,:,:); % only keeps x component
            elseif size(qQ,3) == 2 && strcmp(Qtags{t},'yy')
                Qplot = qQ(:,:,2,:,:); % only keeps y component
            else                    % scalar case => % nothing to project
                Qplot = qQ; 
            end
            
            % MUST HAVE A SCALAR BY NOW!
            subQuantity = reshape(Qplot(reshapeBoxIndexMap),[1 nbBoxes 1 Lt La]);
            
            % Calculate weighted mean of the crop zone
            weightedSubQuantity = subQuantity .* Weight;
            weightedSubMean = nansum(weightedSubQuantity,2) ./ sum(Weight,2);
            weightedSubMean = reshape(weightedSubMean,[1 Lt La]);
            
            % save
            Qmean{q} = weightedSubMean;
%             Total = Total + weightedSubMean;
            %--------------------------------------------------------------
            fprintf(' Done\n')
        end
    end
    
    
    %% Plot  %%
    
    % Updating "QmaxValues"
    if ~isempty(QmaxValues)
        if length(QmaxValues) == length(QnamePTE) % right number of maxValues was specified
            QmaxValuesMod = QmaxValues;
        elseif length(QmaxValues) == 1
            QmaxValuesMod = repmat(QmaxValues{1},length(QnamePTE),1); % repeating unique value specified
            QmaxValuesMod = num2cell(QmaxValuesMod);
        else
            warndlg('ERROR: parameter "QmaxValues" must either be empty or contain, 1 entry, or the same number of entries as "QnamePTE"!','PTE ERROR!!')
            return
        end
    end
    
    sth2PlotTF = any(~cellfun(@isempty, Qmean));

    if sth2PlotTF % only plots if there is something to plot
        
        fprintf('\t\tPlotting values ...')
        
        % define figure for plot
        figure(t);
        box on
        if ~isempty(Qrange)
            if length(Qrange) == 1
                Qrange = repmat(Qrange,4,1); % repeats range 4 times to do '', 'd', 'i', 'do' plots (3.5)
            end
            axis([ startAPF endAPF Qrange{t}]);
        end
        hold on
        
        for q = 1:length(QnamePTE)
            
            qQname = QnamePTE{q};
            qQnameFilt = QnameVMfilter(qQname); % turns UPIV or UCT into U...(1.5)

            if isfield(BACKUP, qQname) % 3.5
                
                % getting quantity color and units
                idx = find(strcmp(qQname,allQs));
                if isempty(idx) % need to rather look for "qQnameFilt" (1.5)
                    idx = find(strcmp(qQnameFilt,allQs));
                end
                Qcolor = allColors{idx};
                Qunits = allUnits{idx};
                
                qQ = eval(['BACKUP.' qQname ';']);
                projectionTag = '';
                if size(qQ,3) ~= 1 % not a scalar => requires projection
                    projectionTag = ['.' Qtags{t}];
                end
                
                projectionTagAll = projectionTag; % default
                if size(qQ,3) ~= 1 && ismember(Qtags{t},{'uPar','uOrt'})
                    projectionTagAll = [projectionTag '_' uAnimal '_' tagProjectionTime];
                end
                
                % If plotting dimensionless Qdev:
                QdevTag = '';
                [TF, loc] = ismember(qQname,QDevRenorm);
                if TF && size(qQ,3) == 4 && ~strcmp(Qtags{t},'u0')
                    Qunits = ''; % the dev part is no
                    QdevTag = ['/' qQname 'o'];
                    QmaxValuesMod{q} = QDevMaxValues{loc};
                end

                % get value and mean value
                value = Qmean{q};
                value = Qfactor(q)*value; % 3.4
                if length(value) == 1
                    Lt = 2;
                    value = Qmean{q} .* ones( size( startAPF:(endAPF-startAPF)/(Lt-1):endAPF ) );
                end
                
                % CUMULATIVE case: modifying units and defining cumTag
                cumTag = '';
                if strcmp(QplotType,'cum') && ~ismember(qQname,QDevRenorm)
                    value = nancumsum(value*dtH);
                    cumTag = '.cum';
                    if strcmp(Qunits,'h^{-1}')
                        Qunits = '';
                    else
                        Qunits = [Qunits '.h'];
                    end
                end
                
                % Renormalizing by max value of average or user given value (4.0)
                if strcmp(QplotRenorm,'renorm')
                    if isempty(QmaxValues) || isnan(QmaxValuesMod{q})
                        maxValue = max(abs(value(:,:,1)));
                    else
                        maxValue = QmaxValuesMod{q};
                    end
                    value = value/maxValue;
                end
                
                % Including x factor applied in the legend (3.4)
                QfactorTag = '';
                if Qfactor(q) ~= 1 && strcmp(QplotRenorm,'raw') % doesn't make sense to apply factor when QplotRenorm = 'renorm' (4.0)
                    QfactorTag = [' x ' num2str(Qfactor(q)) ' (' Qunits ')'];
                elseif strcmp(QplotRenorm,'renorm')
                    QfactorTag = [' (' num2str(maxValue,2) ' ' Qunits ')'];
                    ylim([-1,1]); % setting fixed limits
                end
                %--------------------------------------------------------------
                
                if length(QnamePTE) == 1 && strcmp(QplotOrigin,'AOA') % multi animal plot NOT possible in DBA (1.6)
                    
                    %%% Plotting single value but with multianimal details
                    legendAnimal = cat(1,mapAnimal,avgAnimals);
                    CM = spring(numel(legendAnimal) -1); % +1 is for the reference movie
                    
                    for a = 1:length(legendAnimal)
                        % plot, legend, color, units
                        if a == 1
                            QLineWidth = 2;
                            QLineStyle = '-';
                        else
                            Qcolor = rand(1,3);
                            QLineWidth = 1;
                            QLineStyle = '--';
                        end
     
                        plot(startAPF:(endAPF-startAPF)/(Lt-1):endAPF, value(:,:,a), 'color', Qcolor, 'LineWidth', QLineWidth, 'LineStyle', QLineStyle);
                        
                        if a > 1
                            QfactorTag = ''; % NOT repeating value used to renormalize
                        end
                        legendQname = [legendQname ; [legendAnimal{a} projectionTag cumTag QfactorTag]]; %#ok<*AGROW> % 4.0
                    end
                    
                    plotName = qQname;
                    filename = [mapAnimal '.all.' QnamePTE{q} projectionTagAll '_' QplotType '_' QplotRenorm]; % using projectOR animal (4.0)
                    %--------------------------------------------------------------

                else
                    %%% Plotting multiple values but only average values
                    %--------------------------------------------------------------
                    plot(startAPF:(endAPF-startAPF)/(Lt-1):endAPF, value(:,:,1), 'color', Qcolor, 'LineWidth', QLineWidth);
                    
                    qthLegend = [qQname QdevTag projectionTag cumTag QfactorTag];
                    legendQname = [legendQname ; qthLegend]; % 3.5
                    
                    plotName = PTEname; % 1.6
                    filename = [PTEname projectionTagAll '_' QplotType '_' QplotRenorm]; % using projectOR animal; mod 1.6
                    %--------------------------------------------------------------
                    
                    % saving plot data:
                    plotBU.(qQname) = value;
                end
            else
                disp(['WARNING: quantity "' qQname '" was not found in PTE backup and was NOT plotted!'])
            end
        end
        
        legendQname = FormatLegend(legendQname); % replaces "dot" by ".u"
        
        %------------------------------------------------------------------
        % plot zeros for reference
        plot(startAPF:(endAPF-startAPF)/(Lt-1):endAPF,zeros(size(startAPF:(endAPF-startAPF)/(Lt-1):endAPF)),'-k','LineWidth',0.5); % mod 4.0
        hold off
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % title, legend, and other graphic plot tweak
        title([plotName projectionTagAll '  | [' boxTag ']'],'interpreter','none');
        ylabel('Components');
        if length(QnamePTE) == 1 && strcmp(QplotRenorm,'raw')
           ylabel(['Components ( ' Qunits ' )']);
        end
        xlabel('Time ( hAPF )')
        legend(legendQname,'Location','eastoutside','FontSize',7)
        legend(legendQname,'Location','eastoutside')
        main_h = figure(t);
        set(main_h, 'color', 'white');
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Print
        filenameFull = [filename '_' boxTagFile ]; % 4.0
        if ~exist([OutputPathName filesep 'Plots_PTE'], 'dir')
            mkdir([OutputPathName filesep 'Plots_PTE']); 
        end
        
        PTEfilenameFull = [OutputPathName filesep 'Plots_PTE' filesep filenameFull imageExtension]; % 1.2
        if strcmp(imageExtension, '.svg')
            plot2svg(PTEfilenameFull, figure(t), 'png')
        elseif strcmp(imageExtension, '.pdf')
            export_fig(PTEfilenameFull,'-pdf')
        else
            print(printFormat, printResolution, PTEfilenameFull);
        end
        close
        
        % saving plot data (1.3):
        plotBU.value = value; 
        plotBU.legendQname = legendQname;
        plotBU.TimeDecArray = TimeDecArray;
        save([OutputPathName filesep 'Plots_PTE' filesep filenameFull '.mat'],'-struct','plotBU')
        %------------------------------------------------------------------
        fprintf(' Done\n')
    end
    
end % for each parts (dev, iso, ortho)

% Saving GUI image:
if exist('guiImage','var')
    figure(666);
    guiImagePath = [OutputPathName filesep 'Plots_PTE' filesep filenameFull '.GUImap' imageExtension]; % 1.2
    print(printFormat, printResolution, guiImagePath);
    close;
end
fprintf('\tDone\n')


%% History %%

% 17/01/2023: 1.7 (Boris)
% - stopped rounding TimeDecArray(1) and TimeDecArray(end) to define
% startAPF and endAPF, respectively. This was leading to incorrect range
% along time axis (x) and wrong estimated rates.

% 04/06/2021: (Lucas)
% - now saves "value" used for the plot into "plotBU" backup.

% 23/06/2020: 1.6 (Boris)
% - support of DBA time evolution plots

% 31/01/2020: 1.4
% - skipping execution if only one timepoint to plot
% - updated outputs of updated "InputParserPTE"

% 11/12/2019: 1.3
% - saving of a backup file containing the graphs data 

% 20/09/2019: 1.2
% - ALWAYS removing iso part when quantity is listed in QDevRenorm
% - possibility to save plot in pdf in addition to svg (and png).

% 16-18/07/2019: 1.1
% - many improvements

% 02/07/2019: 1.0

