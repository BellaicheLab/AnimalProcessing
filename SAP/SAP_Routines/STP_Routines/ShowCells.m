function ShowCells(V_NUM,edge,cell,x,y)
%
%
%

figure
nmatrix = zeros(V_NUM,V_NUM);
juncs = [edge.junc2] +V_NUM*([edge.junc1]-1);
nmatrix( juncs )=1;
xy = [x',y'];
gplot(nmatrix,xy,'-');
axis off equal

hold on
cmap = colormap(autumn(128));  
i=1;
for c=cell
  pgx = x([c.junc]);
  pgy = y([c.junc]);
%  fill(pgx,pgy,cmap(i));
  if c.in_out == 'i'
      fill(pgx,pgy,cmap(1));
  elseif c.in_out == 'o'
      fill(pgx,pgy,'r');
  end
  i=i+1;
end
hold off



