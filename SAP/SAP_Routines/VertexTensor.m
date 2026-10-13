function [V, Vpolarity, Vorientation] = VertexTensor(cellVertexXYs,cellCentroid)
%
% [V, Vpolarity, Vorientation] = VertexTensor(cellVertexXYs,cellCentroid)
%
% will calculate the vertex tensor V (and related polarity and orientation) from cartesian coordinates of cell
% centoid and cell vertices. V is based on the outer product of UNIT vectors pointing from cell center to cell vertices.
% NB: V KEEPS THE SAME UNITS AS INPUT: if "cell_vertex_XYs" and "cell_centroid" are expressed in ?m (resp. pix), V will 
% be expressed in ?m? (resp pix?). V_polarity/orientation are dimensionless.
%
% Version 1.0
% Boris Guirao


%% Define vectors CoM-vertices %%

nv = size(cellVertexXYs,1);                       % number of vertices for this cell
repCellCentroid = repmat(cellCentroid,nv,1);     % cuplicates vertically cell centroid coordinates nv times 
CVs = cellVertexXYs - repCellCentroid;          % list of vectors pointing from cell CoM to each cell vertex

Zs = CVs(:,1) + 1i*CVs(:,2);                        % corresponding complex number         
Thetas = angle(Zs);                                 % angles of each vector
uZs = exp(1i*Thetas);                               % unit complex numbers
uCVs = [real(uZs) imag(uZs)];                       % unit vectors


%% Computes V & related quantities %%

V = zeros(2);
for v = 1:nv
    V = V + uCVs(v,:)'*uCVs(v,:);                   % outer product of each vector by itself
end
V = reshape(V,1,[]);                                % turns 2x2 V into [Vxx Vxy Vyx Vyy]

% Calculats V polarity and orientation:
Vdata = TensorData(V);
% V_data = Tensor_Data(V,0);
Vpolarity = 1 - Vdata.Es(2)/Vdata.Es(1);         % 1 - |smaller eig|/|larger eig|
Vorientation = Vdata.Angles(1);                   % ANGLES ARE POSITIVE WHEN VERTEX POLARITY IS POINTING DOWNWARDS


%% History %%

% 03/03/2015:
% - calls "TensorData"

% 28:10/2013: creation
