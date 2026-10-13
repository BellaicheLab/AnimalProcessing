% Take either two index or two points input and the grid dimension and return
% the index list of all the box in the rectangle defined by the inputs
%

function listIdx = ComputeAreaCoord(A,B,dim)

if (isequal(size(A), [1 2]) || isequal(size(A), [2 1])) && isequal(size(A),size(B))
    % sub input
    x1 = A(1);
    y1 = A(2);
    x2 = B(1);
    y2 = B(2);
elseif isequal(size(A), [1 1]) && isequal(size(A),size(B))
    % ind input
    [y1, x1] = ind2sub(dim, A);
    [y2, x2] = ind2sub(dim, B);
else
    fprintf('Error Compute Area Coord: Wrong inputs');
end

[xs] = sort([x1 x2]);
[ys] = sort([y1 y2]);
[Xrep,Yrep] = meshgrid(xs(1):xs(2),ys(1):ys(2));
listIdx = sub2ind(dim, Yrep(:), Xrep(:));

end

