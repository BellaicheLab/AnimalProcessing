function A = PolygonArea(Vs, VXs, VYs)
%
% A = PolygonArea(Vs, VXs, VYs)
%
% Calculate area of polygon defined by the vertex list "Vs" of
% vertices belonging to a cell. "Vs" list the vertex numbers that
% point at the relevant rows in VXs,VYs.
% Ex: number 128 in Vs has its coordinates at row 128 in VXs,VYs
%
% Ex: square of side length = 1
% SVs = [1:4];
% SVXs = sqrt(2)/2*[1 0 -1 0]';
% SVYs = sqrt(2)/2*[0 1 0 -1]';
% Polygon_Area(SVs, SVXs, SVYs) must yields 1.0000
%
% Version 1.0
% Boris Guirao


%% Code %%

% REPEATING FIRST VERTEX IN VS (otherwise formula not valid!):
if size(Vs,1) < size(Vs,2) % Vs = row vector
    Vs = [Vs Vs(1)];
elseif size(Vs,1) > size(Vs,2) % Vs = column vector
    Vs = [Vs ; Vs(1)];
else
    disp('Polygon_Area ERROR: vertex list Vs has not the proper format!!')
    return
end

% checking VXs,VYs format:
if size(VXs,1) < size(VXs,2)
    VXs = VXs';
end
if size(VYs,1) < size(VYs,2)
    VYs = VYs';
end

% Determining area sign and defining new_cjs accordingly:
Vs_is = Vs(1:end-1);       % vertices i
Vs_ip1s = Vs(2:end);       % vertices i+1

Xis = VXs(Vs_is);
Yis = VYs(Vs_is);
Xip1s = VXs(Vs_ip1s);
Yip1s = VYs(Vs_ip1s);

A = 1/2*(Xis'*Yip1s - Xip1s'*Yis);

%% History %%

% 18/09/2013: creation

