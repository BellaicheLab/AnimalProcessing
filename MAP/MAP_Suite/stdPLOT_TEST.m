

%%
% plot process parameters
PLOT.print = 1;                  % print the plot
PLOT.plot = 1;                   % plot the selected quantities (Qname)
PLOT.significance = 1;           % plot significance
PLOT.SignOpacityMap = [0.5 0.5]; % significance opacity [iso dev]
PLOT.extension = 'png';          % plot image type (png | svg)
PLOT.resolution = 300;           % plot resolution
PLOT.boxSize = [128 128];        % box size of the average grid
PLOT.macrocaetes = 1;            % plot macrocaetes position
PLOT.ARtreshold = 0;             % AreaRatios treshold (in progress)

animalTimeWidth   = 13;
animalTimeOverlap = 0.5;
multiTimeStart    = '14h55';
multiTimeStop     = '27h55';

% Format, resolution, and extention
printFormat     = ['-d' PLOT.extension];
printResolution = ['-r' num2str(PLOT.resolution)];
imageExtension  = ['.'  PLOT.extension];

% Store time information in struct more simple managment
TIME.animalTimeOverlap = animalTimeOverlap;
TIME.animalTimeWidth   = animalTimeWidth;
TIME.multiTimeStart    = multiTimeStart;
TIME.multiTimeStop     = multiTimeStop;

CustomColors;       % defines usual set of colors
AllQsColorsUnits;   % associate quantities with specific colors

% display parameters to be used during plot
minimalInfoDisplay = false;
minAEV = 0.0001;
fontSize = 12;
EVstyles = {'-' '--'};       % ONLY relevant for "merged" display type: styles to display ellipse axes representing tensor eigenvalues (default {'-' ':'})
pointSize = 2;
signOpacities = [0.7 0.3];   % ONLY relevant for "split+/-" and "circle" display types: specifies opacity of positive(white) and negative(black) disks, respectively.
lineWidth = 1.5;             % for circle, bars and ellipses (1.5 ok with BIG movies)
gridDisplay = false;         % Lagrangian grid ALWAYS displayed (6.0)
gridColor = black;
gridLineWidth = 0.5;        % only matters for Egrid, Lgrid thickness specified in LGridPlotter
imageFading = 0.6;
scaleBarWidth = 1;

% Scale values according to the information to be ploted
sr_AOS        = { 8e2 ; 50 ;  2 ; 100 ; [4 30] };   % sets ratio setting size of ellipses or bars in tensor representation for M,I.
srbar_AOS     = [ 0.1 ;  2 ; 50 ;  1  ;    10  ];   % scale bar lengths for each contribution
killtrace_AOS = [  0  ;  0 ;  0 ;  1  ;     1  ];   % Will set average compartment trace to 0 in the plots (mean isotropic part = 0). Choose this when tensors are known up to an additive constant
% contributions   Rho    I    M    V       CD
sr_SM        = { 1500 ; 1000 ; 1000 ; 1000 };
srbar_SM     = [  0.1 ; 0.05 ; 0.05 ; 0.05 ];
killtrace_SM = [    1 ;    1 ;    1 ;    1 ];
% contributions     S     SP     ST      P
sr_TA        = {  4e3 ;  4e3 ;  4e3 ;  8e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 ;  4e3 };  % average 14h
srbar_TA     = [ 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ; 2e-2 ];
killtrace_TA = [    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ;    0 ];
% contributions     G      S      R     Ds      D      A      N      F      J     Jb     DM      U     G*    PSI   PhiU


%%

load('D:\partage\AOA_Outputs\AOA_big156rl_13h_olap_0.5\AOA_stdMAP.mat');
eval(['BACKUP = AOA_stdMAP;']);
BACKUPnew = BACKUP;
Pname = 'TA';
Qname = {'EG';'ED';'ER';'ES';'EA'};
dev = 1;
name = 'meanDevBig';
PathName = 'D:\partage\AOA_Outputs';



% list information relative to the grid, not concerned by the operation, to be copied without modification
gridInfo = {'xywh';'size';'overlap';'color';'lineWidth';'fullImage';'centroids';'ULCs';'TimeArray';'FrameArray'};
% list information concerned by the operation but to be treated differently
exceptions = {'RConds';'Macrocaetes';'AreaRatios';'AreaRatios_TA';'AreaRatios_SM';'AreaRatios_AOS';'errorDnPs';'errorPs'};
% all other information contained in the backup will be processed as follow: A.x - B.x = C.x

new_BACKUP = struct(); % prepare the new backup structure
fieldList = fieldnames(BACKUP); % Get the list of field to process from one of the backup
for i = 1:length(fieldList)
    
    if ismember(fieldList(i), gridInfo) % if grid information, simply copy of the field
        disp(['grid info : ' fieldList{i}]);
        eval(['new_BACKUP.' fieldList{i} ' = BACKUP.' fieldList{i} ';']);
    elseif ismember(fieldList(i),exceptions)
        disp(['other info : ' fieldList{i}]);
        eval(['new_BACKUP.' fieldList{i} ' = BACKUP.' fieldList{i} ';']);
    else
        if ~isempty(strfind(fieldList{i},'_std')) % if Significance map, logical AND(A.map, B.map)
            disp(['std : ' fieldList{i}]);
            
            eval(['tensorStd = BACKUP.' fieldList{i} ';']);
            if dev && size(tensorStd,3) == 4
                STD = sqrt( tensorStd(:,:,4,:).^2 + tensorStd(:,:,2,:).^2 .* 4 );
            else
                STD = tensorStd(:,:,1,:);
            end
            eval( ['new_BACKUP.' fieldList{i} ' = STD;'] );
        end
    end
end




GRID = new_BACKUP;
%%% check dimension (compatibility for single time point plot)
Lt = size( eval(['GRID.' Qname{1} '_std']) ,4);
if Lt == 0
    Lt = size( eval(['GRID.' Qname{1} '_std']) ,3);
end

%%% initialisation of the plot
% get the BG image (simple white image)
size_image_x = PLOT.boxSize(1) * (GRID.size(2) * GRID.overlap + 1);
size_image_y = PLOT.boxSize(2) * (GRID.size(1) * GRID.overlap + 1);
if GRID.overlap == 0
    size_image_x = PLOT.boxSize(1) * (GRID.size(2) + 1);
    size_image_y = PLOT.boxSize(2) * (GRID.size(1) + 1);
end
Qimage = ones([size_image_y , size_image_x]);

%%% get the display info parameters
DISPLAY.Animal             = name;
DISPLAY.plotType           = 'circle';
DISPLAY.minimalInfoDisplay = minimalInfoDisplay;
DISPLAY.minAEV             = minAEV;
DISPLAY.scaleBarWidth      = scaleBarWidth;
DISPLAY.gridDisplay        = gridDisplay;
DISPLAY.lineWidth          = lineWidth;
DISPLAY.pointSize          = pointSize;
DISPLAY.EVstyles           = EVstyles;
DISPLAY.signOpacities      = signOpacities;
DISPLAY.fontSizeInfo       = fontSize;
DISPLAY.imageFading        = imageFading;
DISPLAY.errorPsMin         = 1; % 10^-10; % hard coded, todo
DISPLAY.errorDnPsMin       = 1; % 10^-10;
DISPLAY.errorFontSize      = 5;
if PLOT.macrocaetes
    DISPLAY.macrocaetes    = GRID.Macrocaetes;
end

for t = 1:Lt
    for j=1:length(Qname)
        
        [~,idx] = GetPname(Qname{j});
        if idx > 0
            Qcolor  = eval(['allColors_' Pname '{idx}']);
            Qunits  = eval(['allUnits_' Pname '{idx}']);
            Qsr     = eval(['sr_' Pname '{idx}']);
            Qsrbar  = eval(['srbar_' Pname '(idx)']);
            QKillTr = eval(['killtrace_' Pname '(idx)']);
        end
        
        eval(['GRID.AreaRatios = GRID.AreaRatios_' Pname ';']);
        % kill trace tag
        KillTrTag = '';
        if QKillTr
            KillTrTag = '_Tr=0';
        end
        
        % Set the time and n variable
        DISPLAY.time = [ GRID.TimeArray{t,1} ' - ' GRID.TimeArray{t,2} ];
        DISPLAY.n = round( ( GRID.FrameArray(t,1) + GRID.FrameArray(t,2) ) / 2 );
        
        if Lt > 1 %(1.2)
            DISPLAY.step = t;
        end
        
        toPlot = [Qname{j} '_std'];
        
        % Plot image
        PlotField(toPlot,QKillTr,Qcolor,Qunits,Qsr,Qsrbar,GRID,Qimage,DISPLAY);
        
        this_filename = ['AOA_' name '_' Qname{j} '_' GRID.TimeArray{t,1} 'to' GRID.TimeArray{t,2} KillTrTag '_sr=' num2str(Qsr(1)) printFormat];
        if ~exist([PathName filesep 'Frames_std'],'dir'); mkdir([PathName filesep 'Frames_std']); end       
        print (printFormat, printResolution, [PathName filesep 'Frames_std' filesep this_filename]);
        close
        
    end
end