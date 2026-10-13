function [su, sv] = signalFilterNaN(x,y,u,v,im,gsize)
%
% SIGNALFILTER - filter PIV data based on signal value in the input image.
%
% [su, sv] = signalFilterNaN(x,y,u,v,im,gsize);
%
% Replace all values of u & v in no-signal areas by NaNs. a no-signal area is
% definied by an area in the raw image where all its values are 0.
% areas are definied by square boxes of size gsize and which centers are given by
% x and y.
%
% version 0.1
% GOYA Yuki
% Boris Guirao
%
% For use with MatPiv 1.6
    su=u;
    sv=v;
    cmpt=0;    
    for j=1:size(u,2)
        for k=1:size(u,1)
            % get current element grid box
            col=max(1,x(k,j)-gsize/2+1):min(size(im,2),x(k,j)+gsize/2);
            line=max(1,y(k,j)-gsize/2+1):min(size(im,1),y(k,j)+gsize/2);                
            % all zeros area ?
            if(sum(sum(im(line,col))) == 0)
                su(k,j) = NaN;
                sv(k,j) = NaN;
                cmpt=cmpt+1;
            end              
        end
    end
    fprintf('%d elements replaced by NaN.\n',cmpt);

end

%% HISTORY %%

% 26/02:2014: 0.1 creation from "signalfilter"