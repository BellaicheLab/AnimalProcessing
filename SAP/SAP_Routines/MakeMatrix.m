function M = MakeMatrix(size,ind,value)
%
% M = MakeMatrix(size,ind,value)
%
% Builds a matrix M of size size(:,1)x size(:,2) with value "value" at indices "ind" and 0s everwhere else.
% Used to rebuild a matrix of image size materializing a single cell (or its contours) in an image out of a column vector of indices.
%
% Boris Guirao
% version 0.2

%% Code %%

M = zeros(size);                     % builds a 0 matrix of size "size"
M(ind) = value;                      % fills up the previous 0 matrix with number "value" at pixels belonging to the cell defined by the indice vector "ind"

%% History

% 09/06/2010: 0.2
% - changed M(ind) = value*ones(length(ind),1) to M(ind) = value;

% 18/05/2010: changed name from make_matrix_01 to Make_Matrix

% 17/02/2009: start