function [rsq] = R2_value(x,y,p,w)
% This function returns the coefficient of determination of a fit.
% x and y must be vectors of the same length, p is polynomial coefficient
% vector, w the weights, which must be of the same length as x,y.

yfit = polyval(p, x); % y values extrapolated from the fit
ymean = mean(y) ; % mean of y values
if isempty(w) == 1
    %SSresid = sum((y - yfit).^2); % sum of y deviation squared
    %SStotal = (length(y)-1) * var(y) % is equal to SCT
    SCE = sum( (yfit - ymean).^2 ); %sum of squared errors
    SCT = sum( (y - ymean).^2 );
    SCR = sum( (y - yfit).^2 ); %sum of squared residuals
else
    % SSresid = sum(((y - yfit).^2).*w); % sum of y deviation squared
   % SStotal = (length(y)-1) * var(y,w);
    SCE = sum( w.*((yfit - ymean) .^2) );
    SCT = sum( w.*((y - ymean) .^2) );
    SCR = sum( w.*((y - yfit) .^2) );
end
%rsq = 1 - SSresid/SStotal; % coefficient of determination R squared
rsq = 1-SCR/SCT ;
%rsq = SCE/SCT;
%if rsq ~= (SCE/SCT)
   % disp ('bug !') % check hypothesis for linear regression
   % (SCE/SCT) /(1-SCR/SCT)
   %  sum(y-yfit)
        %{var(y-yfit) (std(y-yfit))^2}
   %mean(x)/mean(yfit)
    % cov(x,y-yfit) ;%<10^-3
    % cov(y-yfit,y-yfit); % <10^-3
%end
end