function N = GetMatrixLocalMin(M)
%
% N = GetMatrixLocalMin(M)
%
% At each M matrix location, returns the minimum value of the 4 neighboring
% sites and put at same location in N matrix.
% NB: could be improved to be less specific
%
% Version 1.1
% Anaïs Bailles
% Boris Guirao


%% Code %%

ny = size(M,1);
nx = size(M,2);
nBoxes = nx * ny;
N = zeros(ny,nx);

for b = 1:nBoxes
    
    [ky, kx] = ind2sub([ny nx], b); % 1.1
    
    % Bulk case
    if ky ~= 1 && kx ~= 1 && ky ~= ny && kx ~= nx
        N(ky,kx) = min([M(ky-1,kx) M(ky+1,kx) M(ky,kx-1) M(ky,kx+1)]);
       
    % Treating Boundaries    
    elseif ky == 1
        if kx ~= 1 && kx ~= nx
            N(ky,kx) = min([M(ky,kx) M(ky+1,kx) M(ky,kx-1) M(ky,kx+1)]);
        elseif kx == 1
            N(ky,kx) = min([M(ky,kx) M(ky+1,kx) M(ky,kx+1)]);
        elseif kx == nx
            N(ky,kx) = min([M(ky,kx) M(ky+1,kx) M(ky,kx-1)]);
        end
        
    elseif ky == ny
        if kx ~= 1 && kx ~= nx
            N(ky,kx) = min([M(ky-1,kx) M(ky,kx) M(ky,kx-1) M(ky,kx+1)]);
        elseif kx == 1
            N(ky,kx) = min([M(ky-1,kx) M(ky,kx) M(ky,kx+1)]);
        elseif kx == nx
            N(ky,kx) = min([M(ky-1,kx) M(ky,kx) M(ky,kx-1)]);
        end
        
    elseif kx == 1
        N(ky,kx) = min([M(ky-1,kx) M(ky+1,kx) M(ky,kx) M(ky,kx+1)]);
        
    elseif kx == nx
        N(ky,kx) = min([M(ky-1,kx) M(ky+1,kx) M(ky,kx-1) M(ky,kx)]);
        
    end
end

end

%% History

% 01/06/2018 : 1.1 became "GetMatrixLocalMin"

% 19/09/2014 : creation
