function [ABulk ABound] = FindOuterLayers(A,nLayers)
%
% [ABulk ABound] = FindOuterLayers(A,n)
%
% Fist turns matrix A into a logical matrix, then will split it into its bulk "ABulk" and boundary "ABound", the
% thickness of wich is defined by integer nLayers specifying the number of outer layers to include in the boundary. Both output
% matrices are logical
%
% Version 1.2 (formerly "FindLayerIndices")
% Boris Guirao

%% Code %%

%%% Building Aext = A surrounded with a frame of 0s:
sizeA = size(A);
sizeAext = sizeA + 2;
Aext = zeros(sizeAext);
Aext(2:end-1,2:end-1) = A;      % A framed by 2 rows and 2 col of 0s

ind0 = find(Aext==0);           % finds indices of 0s

layerIndices = cell(nLayers+1,1);     % initializes
layerIndices{1} = ind0;

AextBulk = logical(Aext);       % replaces Aext non-zero values with 1s
ABulk = AextBulk;               % initialization (1.2)
for l = 1:nLayers
    Layer = layerIndices{l};
    extLayer = SideDilator(sizeAext,Layer,1);    % dilates previous layer of 1 pixel in all directions
    allLayers = cell2mat(layerIndices(1:l));        % retrieves the pixels of all layers defined so far
    newLayer = setdiff(extLayer, allLayers);        % defines new layer
    layerIndices{l+1} = newLayer;                   % stores it as (l+1)th layer
    AextBulk(newLayer) = false;                     % First, updates AextBulk
    
    % IF above operation did NOT make AextBulk only 0s, ONLY THEN update ABulk (1.2)
    if any(AextBulk(:)) 
        ABulk = AextBulk;
    else
        disp(['WARNING "FindOuterLayers": parameter "nLayers" = ' num2str(nLayers) ' could not be applied! Used value ' num2str(l-1) ' instead.'])
        break
    end
end

%%% Cropping to initial A size:
ABulk = ABulk(2:end-1,2:end-1);
ABound = ~ABulk;                % negative of Abulk (1.2)
% ABound = ABound(2:end-1,2:end-1);

%% History %%

% 09/06/2016: 1.2
% - now prevents the bulk from becoming all filled with 0s if nLayers is too large => stopping ONE step before filling all grid
% compartements with 0s and issues a warning message indicating the nLayers actually used (necessarily < nLayers from asked by user).
% - improved code

% 20/05/2015: 1.1 changed name to "FindOuterLayers"

% 08/04/2015: creation