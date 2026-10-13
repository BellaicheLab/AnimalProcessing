function Vcol = Row2Col(Vrow)
%
% Vcol = Row2Col(Vrow)
%
% Turns row vector into column vector if necessary.
%
% Version 1.0
% Boris Guirao

%% Code %%

if min(size(Vrow)) > 1
    disp('ERROR in "Row2Col": argument must be a vector!!')
    return
end

if size(Vrow,2) > size(Vrow,1)
   Vcol = Vrow';
else
    Vcol = Vrow;
end


%% History %%

% 11/12/2015: creation