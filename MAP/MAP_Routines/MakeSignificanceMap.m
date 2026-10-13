function [ significanceMap, temp_meanT, stdT ] = MakeSignificanceMap( T, meanT, weight )
%
%[ significanceMap, temp_meanT, stdT ] = MakeSignificanceMap( T, meanT, weight )
%
% Calculate, for a given number of animal analysis, the biological variability
% and the significance at each position and time of the analysis
% input T is a 5D matrix (x,y,4,t,a) which contain the tensor map of each analysed animal
% input meanT is a 4D matrix (x,y,4,t) which contain the weighted mean of the analysed animal
% input weight a 5D matrix (x,y,4,t,a) which contain the weight map for each analysed animal

% Version 1.1 
% Stephane Rigaud
% Boris Guirao

%% Code %%

% significativity is a matrix of dimension X,Y,Z,T, where Z is the number of tensor part evaluated (iso,dev)

[h,w,z,t,~] = size( T );
isoSignificanceMap = zeros(h,w,1,t);
devSignificanceMap = zeros(h,w,1,t);
temp_meanT = [];

if z == 4 % This is a Tensor map
    % input Tensor map T = [ Txx Txy ]
    %                      [ Tyx Tyy ]
    
    % create the tensor map  [ Txx+Tyy   Txy ]
    %                        [ Tyx   Txx-Tyy ]
    temp_T = cat(3, (T(:,:,1,:,:) + T(:,:,4,:,:)) , T(:,:,2,:,:)  , ...
                     T(:,:,3,:,:) , (T(:,:,1,:,:) - T(:,:,4,:,:)) ) ;
    
    % create a mean tensor map [ <Txx>+<Tyy>   <Txy> ]
    %                          [ <Tyx>   <Txx>-<Tyy> ]
    temp_meanT = cat(3,  (meanT(:,:,1,:) + meanT(:,:,4,:)) , meanT(:,:,2,:) , ...
                          meanT(:,:,3,:) , (meanT(:,:,1,:) - meanT(:,:,4,:) ) ) ;

    % calculate the std map  [ std(Txx+Tyy)   std(Txy) ]
    %                        [ std(Tyx)   std(Txx-Tyy) ]
    stdT = UnbiasedWeightedStdMatrix( temp_T, temp_meanT, weight);

    % iso : | meanTxx + meanTyy | >= std(Txx + Tyy )
    indexIso = abs( temp_meanT(:,:,1,:) ) >= stdT(:,:,1,:) ;
    
    % dev : ((meanTxx - meanTyy).^2 + meanTxy.^2 .4 ).^(1/2) >= (std(Txx - Tyy.^2 + 4 sdt(Txy).^2 ).^(1/2)
    indexDev = sqrt( temp_meanT(:,:,4,:).^2 + temp_meanT(:,:,2,:).^2 .* 4 ) >=  sqrt( stdT(:,:,4,:).^2 + stdT(:,:,2,:).^2 .* 4 );
    
    devSignificanceMap( indexDev ) = 1;
    isoSignificanceMap( indexIso ) = 1;
    significanceMap = cat(3, isoSignificanceMap, devSignificanceMap);
    
elseif z == 2
    stdT = UnbiasedWeightedStdMatrix(T, meanT, weight);
    
    isoSignificanceMap( abs(meanT(:,:,1,:)) >= stdT(:,:,1,:) ) = 1; % added "abs" (1.1)
    devSignificanceMap( abs(meanT(:,:,2,:)) >= stdT(:,:,2,:) ) = 1; % added "abs" (1.1)
    % NB: here "iso/devSignificanceMap" actually corresponds to  x/y
    % components of vector being processed
    significanceMap = cat(3, isoSignificanceMap, devSignificanceMap);
    
elseif z == 1
    stdT = UnbiasedWeightedStdMatrix(T, meanT, weight);
    
    isoSignificanceMap( abs(meanT) >= stdT ) = 1;                   % added "abs" (1.1)
    significanceMap = cat(3, isoSignificanceMap, isoSignificanceMap);

else
    % there is a problem
    
end

end

%% History %%

% 29/04/2020: 1.1 (formerly "SignificavityMap")
% - fixed values wrongly sorted as unsignificant for scalars and vectors by comparing
% the absolute value of the mean (and not directly the mean).

% 2016-03-15: creation (Stephane)

