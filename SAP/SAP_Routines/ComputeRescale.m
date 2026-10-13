function [moviesA, moviesB, scalingFactorX, scalingFactorY] = ComputeRescale(Xall, Yall, halfNotum, archA)
%
% [moviesA, moviesB, scalingFactorX, scalingFactorY] = ComputeRescale(Xall, Yall, halfNotum, archA)
%
% Version 1.0
% Stephane Rigaud

%% Code %%

archetypeFlag = true;
if ~exist('archA','var') || isempty(archA)
    archetypeFlag = false;
end

nMovies = size(Xall,2);

nLandmarksMax = 8;
if halfNotum == 'b'
    nLandmarksMax = 16;
end


% Archetype calculation [A_x(1) A_y(1) ; ... ; A_x(nb_landmark) A_y(nb_landmark)];
% NB: USE OF Xall and Yall (1.3), thereby keeping a macro in the archetype anytime it is available in at least one archetype animal
% moviesA = [nanmean(Xall(1:end-1,:),2) nanmean(Yall(1:end-1,:),2) ; nanmean(Xall(end),2) nanmean(Yall(end),2)];
moviesB = [nanmean(Xall,2) nanmean(Yall,2)]; % (um)
moviesA = moviesB; % (um)
if archetypeFlag
    moviesA = archA;  % 1:nArch because only  the wild type movies are included in the archetype
end




% Defining X & Y matrices SOLELY USED FOR RESCALING (1.3):
%------------------------------------------------------------------------------------------------
% Y matrix (starting with Y matrix because contains the midline)
Y = NaN(nLandmarksMax+1, nMovies);
Ywt = Yall;
if archetypeFlag
    Ywt = moviesA(:,2);
end
okRowsWT = any(~isnan(Ywt),2);          % rows (= macrochaetes) where at least one WT macro coordinate was found among NaNs
% NB: "okRowsWT" also indicates rows of WT_A with macro coordinates: THIS IS THE MAXIMAL SET OF MACROCAETAE TO CONSIDER IN THE RESCALING (SEE
% eLIFE EQ. 10). IF an animal (WT or Muta00nt) has MORE macro available, the numerator of eq 10 will NOT take them into account (NaNs in WT_A
% giving NaN in the product) BUT THE DENOMINATOR WILL, thereby yielding an erroneous value of alpha for this animal.
% Inversely, if an animal has LESS macro available, the non-NaN values in WT_A will be overriden by the NaN in the animal, thereby
% considering the same macro at numerator and denominator of eq 10.
Y(okRowsWT,:) = Yall(okRowsWT,:); % version ONLY selecting the rows according to "nMacroMin" FOR RESCALE

% X matrix
X = NaN(nLandmarksMax+1, nMovies);
Xwt = Xall;
if archetypeFlag
    Xwt = moviesA(:,1);
end
okRowsWT = any(~isnan(Xwt),2); 
X(okRowsWT,:) = Xall(okRowsWT,:);           % version of Xall ONLY selecting these rows

% NB: previous code was NOT using "okRowsWT" to only limit calculations to available macro in WT archetype, sometime leading to wrong scalingFactorX/Y!!
%------------------------------------------------------------------------------------------------


% DETERMINING RESCALING FACTORS ALONG X AND Y DIRECTIONS
%------------------------------------------------------------------------------------------------
% X scaling factor calculation [alpha(1) ... alpha(nb_movies] USING X AND Y (NOT Xall, Yall) (1.3)
scalingFactorX = (nansum(X.*repmat(moviesA(:,1),1,nMovies),1))./(nansum(X.*X,1));

% Y scaling factor calculation [beta(1) ... beta(nb_movies] USING X AND Y (NOT Xall, Yall) (1.3)
scalingFactorY = (nansum(Y.*repmat(moviesA(:,2),1,nMovies),1))./(nansum(Y.*Y,1));
%------------------------------------------------------------------------------------------------



end