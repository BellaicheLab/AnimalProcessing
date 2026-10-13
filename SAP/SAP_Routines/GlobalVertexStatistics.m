function Mout = GlobalVertexStatistics(Min, vertexCategory, threeVertices, fourVertices, n, iterationIndex)
%
% Mout = GlobalVertexStatistics(Min, vertexCategory, threeVertices, fourVertices, n, iterationIndex)
%
% Version 1.1
% Boris Guirao

%% Code

Mout = Min;

vertex_category_3V = intersect(threeVertices, vertexCategory);
vertex_category_4V = intersect(fourVertices, vertexCategory);
vertex_category_n_vertices = length(vertexCategory);
vertex_category_n_3vertices = length(vertex_category_3V);
vertex_category_n_4vertices = length(vertex_category_4V);
vertex_category_p_4vertices = vertex_category_n_4vertices/vertex_category_n_vertices * 100;

% Fills up global_vertex_statistics_'category':
Mout(iterationIndex,:) = [ n   vertex_category_n_vertices     vertex_category_n_3vertices    vertex_category_n_4vertices   vertex_category_p_4vertices ];

%% History

% 22/11/2010: 1.1
% - added "iteration_index" as input. Before, n was taken as such, causing
% problems when starting at n>1

% 05/08/2010: creation