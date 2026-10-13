function edges = MakeEdges(vertices)
%
% edges = MakeEdges(vertices)
%
% Builds nx2 matrix "edges" containing successive couples of vertices listed in "vertices" (n vector).
% NB1: ON EACH ROW OF EDGES, VERTEX ARE SORTED IN CRESCENT ORDER
% NB2: edges and vertices have the same number of lines n.
% Ex:
% vertices = [45 87 62 38] (or transposed)
% edges = [ 45 87
%           62 87
%           38 62
%           38 45]
%
% Version 1.0
% Boris Guirao


%% Code %%

% format vertices as column vector:
if size(vertices,1) < size(vertices,2)
    vertices = vertices';
end

Ecol1 = vertices;
Ecol2 = [vertices(2:end) ; vertices(1)];

edges = [Ecol1 Ecol2];
edges = sort(edges,2);


%% History %%

% 18/10/2013: creation
