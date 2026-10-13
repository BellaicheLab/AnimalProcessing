function [FullArchetype,HalfArchetype] = CreateSymmetricArchetype(X,Y,M,halfNotum,nMacroMin,flagMidLandmark)
%
% [FullArchetype,HalfArchetype] = CreateSymmetricArchetype(X,Y,M,halfNotum,nMacroMin,flagMidLandmark)
%
% Version 1.0
% Stephane Rigaud

%% Code %%

% flagMidLandmark = false;
nMacroMax = size(X,1); 
Ox = 0;
Oy = 0;
fOx = 0;
fOy = 0;

if halfNotum == 'b'
    
    nMacroMax = nMacroMax/2;
    
    % we crop the data into two half
    rX =  X(1:nMacroMax); % right -> right
    rY =  Y(1:nMacroMax); % right -> right
    lX =  X(nMacroMax+1:end); % left -> right
    lY = -Y(nMacroMax+1:end); % left -> right
    
    % mean both side into one half animal
    X = mean([rX lX], 2);
    Y = mean([rY lY], 2);
    
    % calculate the new origin of the half animal
    Ox = mean([rX(1:nMacroMin) ; lX(1:nMacroMin)]);
    Oy = mean([rY(1:nMacroMin) ; lY(1:nMacroMin)]);
    if flagMidLandmark
        Ox = mean([rX(1:nMacroMin) ; lX(1:nMacroMin) ; M(1)]);
        Oy = mean([rY(1:nMacroMin) ; lY(1:nMacroMin) ; M(2)]);
    end
    % NB: we keep the origin value for validation purpose
    
    % shift coordinate base on the new origin
    X = X - Ox;
    Y = Y - Oy;
    M = M - [Ox Oy];
    
    % using half animal, create a new full by midline mirroring
    fX = [X; X];
    fY = [Y; M(2) - abs(Y-M(2))];
    
    % we calculate the new origin coordinates
    fOx = mean([fX(1:nMacroMin) ; fX(nMacroMax+1:nMacroMax+nMacroMin)]);
    fOy = mean([fY(1:nMacroMin) ; fY(nMacroMax+1:nMacroMax+nMacroMin)]);
    if flagMidLandmark
        fOx = mean([fX(1:nMacroMin) ; fX(nMacroMax+1:nMacroMax+nMacroMin) ; M(1)]);
        fOy = mean([fY(1:nMacroMin) ; fY(nMacroMax+1:nMacroMax+nMacroMin) ; M(2)]);
    end
    
    % shift coordinate base on the new origin
    fX = fX - fOx;
    fY = fY - fOy;
    fM = [M(1)-fOx M(2)-fOy];
    
    % reset full origin back to 0
    fOx = 0;
    fOy = 0;
    
elseif halfNotum == 'r'
    
    % create full by midline mirroring
    fX = [X; X];
    fY = [Y; M(2) - abs(Y-M(2))];
    
    % we calculate the new origin coordinates
    fOx = mean([fX(1:nMacroMin) ; fX(nMacroMax+1:nMacroMax+nMacroMin)]);
    fOy = mean([fY(1:nMacroMin) ; fY(nMacroMax+1:nMacroMax+nMacroMin)]);
    if flagMidLandmark
        fOx = mean([fX(1:nMacroMin) ; fX(nMacroMax+1:nMacroMax+nMacroMin) ; M(1)]);
        fOy = mean([fY(1:nMacroMin) ; fY(nMacroMax+1:nMacroMax+nMacroMin) ; M(2)]);
    end
    % NB: we keep the origin value for validation purpose
    
    % shift coordinate base on the new origin
    fX = fX - fOx;
    fY = fY - fOy;
    fM = [M(1)-fOx M(2)-fOy];
    
end

fxmin = min([fX(:) ; fM(1)]);
fxmax = max([fX(:) ; fM(1)]);
fymin = min([fY(:) ; fM(2)]);
fymax = max([fY(:) ; fM(2)]);

xmin = min([X(:) ; M(1)]);
xmax = max([X(:) ; M(1)]);
ymin = min([Y(:) ; M(2)]);
ymax = max([Y(:) ; M(2)]);


% store in struct
FullArchetype.origin      = [fOx fOy];
FullArchetype.midpoint    = fM;
FullArchetype.macrochaete = [fX fY]; 
FullArchetype.range       = [fxmin fxmax fymin fymax];
HalfArchetype.origin      = [Ox Oy];
HalfArchetype.midpoint    = M;
HalfArchetype.macrochaete = [X Y];
HalfArchetype.range       = [xmin xmax ymin ymax];

