function  [Ys, Xs] = PlotCumulative(Xdata,Xrange,nPoints,linestyle,linecolor,linewidth)
%
% [Ys, Xs] = CumulativePlot(Xdata,nPoints,Xrange,linestyle,linecolor,linewidth)
%
% Aims to draw cumulative plot for side/chord lengths for CNRS project 2011
% version 1.1
% Boris Guirao

%% Code %%

nData = length(Xdata);

if isempty(Xrange)
    Xmin = min(Xdata);
    Xmax = max(Xdata);
else
    Xmin = Xrange(1);
    Xmax = Xrange(2);
end

Xstep = (Xmax-Xmin)/(nPoints-1);
Xs = Xmin:Xstep:Xmax;
nSteps = length(Xs);

Ys = NaN(nSteps,1);
for n=1:nSteps
    Ys(n) = length(find(Xdata <= Xs(n)))/nData;
end

plot(Xs, Ys,'LineStyle',linestyle,'Color',linecolor,'LineWidth',linewidth)

%% History %%

% 02/03/2016: 1.1
% - added argument Xrange