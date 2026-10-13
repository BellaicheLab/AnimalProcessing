function [h,X,Y,areaUC] = PlotPDF(data, nPoints, nSmooth, nRounds, xRange)
%
% [h,X,Y,areaUC] = PlotPDF(data, nPoints, nSmooth, nRounds, xRange)
%
% PDF = Probability Density Function
% plots PDF generated from "data", plotting "nPoints" points on x axis, using "nSmooth" points to average and smooth
% obtained curve (nRounds times). Area below curve is always 1.
%
% NB: enter negative value for "nPoints" to avoid plotting curve (1.7+) (EX: nPoints = 100 will plot PDF curve with 100
% points while nPoints = -100 will NOT)
%
% NB: start with nSmooth=0 and nRounds = 1 and adjust parameter nPoints so as NOT to get too noisy curves in the
% first place. Then tune nSmooth (and nRounds if necessary).
%
% Inputs:
% - data = datapoints
% - nPoints = number of points to plot on x axis
% - nSmooth = number of points used for smoothing curve (at point n, will use points in [n-nSmooth/2 n+nSmooth/2] for averaging)
% - nRounds = number of smoothing rounds
% - xRange = [min max] x values JUST FOR PLOT. if [], min and max values in data will be used
%
% Outputs:
% - h = plot handle
% - X Y used for plot(X,Y)
%
% Version 1.7
% Boris Guirao


%% Checking "nrounds" value %%

if nRounds <= 0
    nRounds = 1;                                            % sets minimum value to 1 datastep: no overlap in that case
    disp('Warning: nrounds value has been changed to 1');
end

nPointsUsed = abs(nPoints);

%% Min and Max values and datastep (mod 1.5, 1.6) %%

minData = min(data);
maxData = max(data);
if ~isempty(xRange)                                                                                                     
    minData = xRange(1);
    maxData = xRange(2);
end
dataStep = (maxData-minData)/nPointsUsed;         % step between 2 plotted values

X = (minData:dataStep:maxData)';
nPointsUsed = length(X);
Y = zeros(nPointsUsed,1);


%% Filling Y by pooling over value +/- overlap %%

dataProgress = minData;
for n = 1:nPointsUsed
    databack = dataProgress - dataStep;
    datafront = dataProgress + dataStep;
    dataselection = find(data > databack & data < datafront);
    Y(n) = length(dataselection);
    dataProgress = dataProgress + dataStep;
end



%% Curve smoothing %%

for p = 1:nRounds
    for n = 1:nPointsUsed
        nmin = max(1, n-round(nSmooth/2));
        nmax = min(nPointsUsed, n+round(nSmooth/2));
        Y(n) = mean(Y(nmin:nmax));
    end
end



%% Renormalizing and Plot %%

areaUC = trapz(X,Y);              % calculates area under curve
Y = Y/areaUC;                     % renormalization so that area below curve is always one
YmaxPlot = max(Y)*1.05;

if nPoints > 0                          % ONLY plot for positive values of nPoints (1.7)
    
    % looks for already opened figure:
    figOpenedTF = ~isempty(findobj('type','figure'));
    
    if ~figOpenedTF
        fh = figure('PaperPositionMode','auto');
    else
        fh = gcf;                             % gets current figure handle
    end
    
    set(fh, 'color', 'white');
    h = plot(X,Y);
    set(h, 'LineWidth',2);
    axis([minData maxData 0 YmaxPlot]);  % 1.6
    %axis([mindata_plot maxdata_plot 0 Ymaxplot]) ;         % replaced 1 by Ymaxplot because p DENSITY function can be >1
    ylabel('probability density function','fontsize',12);
    
else
    h = [];
    disp('PDF curve not plotted (nPoints < 0).')
end

%% History %%

% 14/11/2017: 1.7
% - added area under curve "areaUC" as output to enable subsequent rescaling of curves using X,Y and areaUC
% - parameter "nPoints" can now be negative to prevent curve plot, for subsequent rescaling using X,Y and areaUC

% 27/03/2014: 1.6
% - now uses xrange to generate the pdf data (NOT just the plot), reverting change made in 1.5

% 14/03/2014: 1.5
% - now actually uses xrange data JUST FOR PLOT

% 20/09/2012: 1.4
% - looks for opened figure before opening a new one. If finds a figure opened gets its handle.

% 19/06/2012: 1.3
% - fixed issue when limiting pdf values to 1
% - added option "xrange" as argument (min and max x values for plot ex: [0 2] (must contain min and max values in "data"))
% - improved plot

% 29/03/2011: 1.2
% - removed input noverlap
% - added input nrounds: number of rounds of smoothing

% 29/03/2011: 1.1 (changed name Density_Plot)
% - checks noverlap value and assign min value 1

% 28/03/2011: creation

