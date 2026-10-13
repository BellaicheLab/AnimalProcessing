function PlotANs(RNs, Correspondence, coalescedRNs, XYs, fontColor, fontSize, fontWeight)
%
% PlotANs(RNs, Correspondence, coalescedRNs, XYs, fontColor, fontSize, fontWeight)
%
% Simply plots (on an image already opened) the ANs corresponding to the RNs listed based on "Correspondence" matrix.
% RNs = list of region numbers to plot. Numbering based on ALL IMAGE REGIONS.
% coalescedRNs = list of coalesced RNs
% XYs = matrix of centroids FOR ALL IMAGE REGIONS.
%
% version 1.0
% Boris Guirao

%% Code %%

RNs = Row2Col(RNs); % makes sure RNs is a column vector

% splits RNs list into non-coalesced and coalesced:
ncRNs = setdiff(RNs, coalescedRNs);
cRNs = intersect(RNs, coalescedRNs);

% non-coalesced RNs:
if ~isempty(ncRNs)
    [ANs, ncRNs] = RNs2ANs(ncRNs, Correspondence); % these ANs do NOT correspond to new cells in general!!
    Xs = XYs(ncRNs,1);
    Ys = XYs(ncRNs,2);
    text(Xs, Ys, num2str(ANs(:,1)), 'HorizontalAlignment','center', 'FontSize', fontSize,'Color',fontColor,'FontWeight', fontWeight)
end

% coalesced RNs: loop
for c = cRNs'
    cX = XYs(c,1);
    cY = XYs(c,2);
    cANs_TF = ismember(Correspondence(:,1),c);
    cANs = Correspondence(cANs_TF,2);
    text(cX, cY, num2str(cANs),'HorizontalAlignment','center', 'FontSize', fontSize,'Color',fontColor,'FontWeight', fontWeight)
end

%% History %%

% 10/12/2015: creation