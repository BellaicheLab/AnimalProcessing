function [M3D,s] = cell2mat3D(C)
%
% Converts a ny*nx cell array C containing vectors of size s in each compartment into a 3D matrix M3D of size ny*nx*s.
% Empty compartements in C are replaced by NaNs in M3D.
% NB: cannot use global reshape of cell array or matrices because initial cell arrays can contain empty compartements!
%
% Version 1.0
% Boris Guirao

%% Code %%

Csize = size(C);
ny = Csize(1);
nx = Csize(2);
n = ny*nx;

for k = 1:n
    if ~isempty(C{k})
        s = length(C{k});
        break
    end
end

M3D = NaN(ny,nx,s);

for k = 1:n
    if ~isempty(C{k})
        [ky,kx] = ind2sub(Csize,k);
        M3D(ky,kx,:) = C{k};
    end
end



%% History %%

% 16/09/2014: creation
