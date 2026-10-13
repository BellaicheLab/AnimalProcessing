function Aout = Normalizer(Ain, AinTF, method)
%
% Aout = Normalizer(Ain, AinTF, method)
%
% method = 'min' = > Will renormalize matrix Ain by MINIMUM value searched over locations specified by logical matrix AinTF and will ceil
% all values > 1 at 1 (so that core boxes all have AreaRatios = 1)
%
% method = 'max' = > Will renormalize matrix Ain by MAXIMUM value searched over locations specified by logical matrix AinTF and will SET
% all Ain values over AinTF to 1 (so that core boxes still all have AreaRatios = 1).
%
% All NaNs values in Aout replaced by 0s since Normalizer aims at providing matrices of weights in [0 1] (1.3+)
%
% NB: Ain can be a nD matrix!
%
% Version 1.4
% Boris Guirao

%% Code %%

Athreshold = 0.01;                  % threshold at 1% of bulk values (1.4)
if any(AinTF(:))                    % checks that there is at least one value at 1 in AinTF (1.1)
    
    % Renormalizing according to min,mean,max:
    if strcmp(method,'min')
        
        MinOnAinTF = min(Ain(AinTF));   % get SMALLEST value of Ain AMONG "1s" COMPARTMENTS IN AinTF
        Aout = Ain/MinOnAinTF;          % renormalizes ALL values by this minimum
        
    elseif strcmp(method,'mean') % 1.2
        
        MeanOnAinTF = mean(Ain(AinTF));   % get MEAN value of Ain AMONG "1s" COMPARTMENTS IN AinTF
        Aout = Ain/MeanOnAinTF;          % renormalizes ALL values by this mean
        
    elseif strcmp(method,'max') % 1.2
        
        MaxOnAinTF = max(Ain(AinTF));   % get LARGEST value of Ain AMONG "1s" COMPARTMENTS IN AinTF
        Aout = Ain/MaxOnAinTF;          % renormalizes ALL values by this maximum

    else
        disp('Normalize ERROR: string "method" must either be "min" or "max"!')
        return
    end
    
    % Setting AinTF location to 1 and ceiling to 1:
     Aout(AinTF) = 1;                % setting all values on AinTF to 1
     Aout(Aout > 1) = 1;             % ceiling all values at 1 in case some outside AinTF were above
         
     % Applying threshold (1.4):
     Aout(Aout < Athreshold) = 0;   % values are set to exactly 0 below threshold
else
    Aout = Ain;                     % otherwise Ain remains untouched (1.1)
end

% Replacing NaNs with 0s (1.3)
Aout(isnan(Aout)) = 0;


%% History %%

% 29/05/2015: 1.4
% - introduced a threshold at 0.01 below which Aout values are set exactly to 0. This is to avoid plotting huge circles that are almost
% transparent.

% 20/04/2015: 1.3
% - all NaNs values in Aout replaced by 0s since Normalizer aims at providing matrices of weights in [0 1]

% 20/03/2015: 1.2
% - added argument "method" and renomalization by mean and max
% - now always setting AinTF locations to 1

% 03/03/2015: 1.1
% - checks that there is at least one value at 1 in AinTF that can be used for renormalization, otherwhise let Ain
% unchanged

% 02/03/2015: creation