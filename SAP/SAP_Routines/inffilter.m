function [nu nv]=inffilter(u,v,thres)
% INFFILTER - filter PIV data using a threshold.
%
% [nu nv]=inffilter(u,v,thres);
%
% Replace all values of u & v outside the interval [-thres thres] by NaN.
% thres MUST contain 2 threshold values, for u and v, respectively.
%
% version 0.1
% GOYA Yûki
% last update: 2011-10-14 
%
% For use with MatPiv 1.6
    nu=u;
    nv=v;    
    % filter out of bound values & set them to NaN
    nu(u>thres(1) | u<-thres(1))=NaN;
    nv(v>thres(2) | v<-thres(2))=NaN;
end

%% HISTORY %%

% 2011-10-14: 0.1
% creation