function [h, nData] = BinPlot(Xdata, Ydata, binVector, color, plotMode)
%
% [h, nData] = BinPlot(Xdata, Ydata, binVector, color, plotMode)
%
% Will bin data according to "binVector" (see code) and "Xdata", and will
% bin accordingly "Ydata" to plot the average value of "Ydata" for every
% bin along X. If "plotMode" = 'std', than will plot curve + std stripes,
% otherwise, leave empty.
%
% NB: Xdata and Ydata must be COLUMN VECTORS and have same length
%
% Version 1.0
% Boris Guirao

%% Code %%
        
binMin = binVector(1);
binStep = binVector(2);
binMax = binVector(3);

Xbins = (binMin:binStep:binMax)';
nBins = length(Xbins);
Ymean = NaN(nBins-1,1);
Ystd = NaN(nBins-1,1);

% get number of datapoints
dataTF = all([~isnan(Xdata) ~isnan(Ydata)],2);
Xdata = Xdata(dataTF);
Ydata = Ydata(dataTF);
nData = sum(dataTF);

for b = 1:nBins-1
    
    xb = Xbins(b);
    xbTF = Xdata >= xb & Xdata <= xb + binStep;
    Ymean(b) = mean(Ydata(xbTF));
    Ystd(b) = std(Ydata(xbTF));
end

Xbins = Xbins(1:end-1) + binStep/2;

if strcmp(plotMode,'std')
CurveFill(Xbins,Ymean+Ystd,Ymean-Ystd,color, 0.8);
elseif ~isempty(plotMode)
    disp('"BinPlot" ERROR: "plotMode" can only be empty or "std"!!!')
    return
end
h = plot(Xbins,Ymean,'Color',color,'Marker','o','LineWidth',1);

%% History %%

% 05/10/2018: creation