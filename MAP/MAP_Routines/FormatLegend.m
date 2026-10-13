function legendOut = FormatLegend(legendIn)
%
% legendOut = FormatLegend(legendIn)
%
% Reformats strings listed in legendIn for better display in plots.
%
% version 1.0
% Boris Guirao


%% Code %%

nIn = length(legendIn);
legendOut = cell(nIn,1);

for i = 1:nIn
    iLegendIn = legendIn{i};
    iLegendOut = regexprep(iLegendIn, 'dot', '.u');
    iLegendOut = regexprep(iLegendOut, '_do', '_{do}');
    legendOut{i} = iLegendOut;
    
    % Attempt to use latex (using 'interpreter','latex' in "legend")
%     iLegendOut = regexprep(iLegendOut, '_i', '_{o}');
%     iLegendOut = regexprep(iLegendOut, '_do', '_{\perp}');
%     iLegendOut = regexprep(iLegendOut, '_d', '_{\parallel}');
%     legendOut{i} = ['$' iLegendOut '$'];
end

%% History %%

% 20/02/2017: creation