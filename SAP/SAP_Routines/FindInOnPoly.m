%
% UNRELIABLE FUNCTION, DIRECTLY USE "inpolygon" INSTEAD LIKE DONE IN
% "PIV2GridInterpolator".
%
% 2009/03/23
% Isabelle Bonnet

% For a given set of vertexes (xv,yv) choose inside an image of size(nx,ny)
% FindInOnPoly determines pixels which are Inside or On the polygon
% boundary whose vertices are specified by the vectors xv and yv.
% Look at the "inpolygon.m" from MatLab library for details.
%  
% [IN ON] = FindInOnPoly(xv,yv,nx,ny)
% IN and ON are 2 logical matrices of size (nx,ny)
% 
% IN(p,q) = 1  if (X(p,q),Y(p,q)) is inside the polygonal region or on the polygon boundary
% IN(p,q) = 0  if (X(p,q),Y(p,q)) is outside the polygonal region
% 
% ON(p,q) = 1 if (X(p,q),Y(p,q)) is on the polygon boundary
% ON(p,q) = 0 if (X(p,q),Y(p,q)) is inside or outside the polygon boundary


function   [Min, Mout] = FindInOnPoly(xv,yv,nx,ny)

Min = zeros(nx,ny);
Mout = zeros(nx,ny);
% Mon=zeros(nx,ny);


% Build 2 vectors x and y needed as input of "inpolygon.m"
% x=[1 2 3 ---- nx 1 2 3 ---- nx 1 2 3 ---- nx ...  1 2 3 ---- nx]
% y=[1 1 1 ------ 2 2 2 ------ 3 3 3 ------ 4 4 4 ...  ny ny ny ---- ny] 
% the size of x and y is nx*ny
% so :
% (x(1),y(1))= (1,1) = M(1,1)
% (x(2),y(2))= (2,1) = M(2,1)
% (x(3),y(1))= (3,1) = M(3,1)
%  ...
% (x(nx),y(1))= (nx,1) = M(nx,1)
% (x(1),y(2))= (1,2) = M(1,2)
% ...
% (x(1),y(ny))= (1,ny) = M(1,ny)

x=zeros(nx*ny,1);
y=zeros(nx*ny,1);

for k=0:nx*ny-1
    x(k+1,1)=mod(k,nx)+1;
    y(k+1,1)=floor(k/nx)+1;    
end

IN = inpolygon(y,x,xv,yv);
% [IN, ON]=inpolygon(y,x,xv,yv);
%IN and ON are the same size as x and y

ind_in=find(IN==1);
%ind_on=find(ON==1);


for k=1:length(ind_in)
     Min(x(ind_in(k)),y(ind_in(k)))=1;
end

Mout=~Min;

% for k=1:length(ind_on)
%     M_on(x(ind_on(k,1)),y(ind_on(k,1)))=1;
% end

