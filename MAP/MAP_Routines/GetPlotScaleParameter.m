function [res] = GetPlotScaleParameter(Qparam, idx)
% simple function that return the PlotScaleParameter (e.g. Qsr, Qscalebar, ...)
% and manage error cases
if idx > numel(Qparam)
    idx = 1;
end
switch class(Qparam)
    case "cell" 
        res = Qparam{idx};
    otherwise
        res = Qparam(idx);
end
end

