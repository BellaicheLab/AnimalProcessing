function cell_area = CellArea(cell,x,y)


cell_area=[];
for i=1:length(cell)
    
    c=cell(i);
    area = 0.0;
    xx = x(c.junc);
    yy = y(c.junc);
    sx = circshift(xx,[0 -1]);
    sy = circshift(yy,[0 -1]);
    area = 0.5*sum(xx.*sy-yy.*sx);
    if area<= 0.0
        ff=1;
        fprintf('!! error: %c %d %f\n',c.in_out,i,area);
    end
    cell_area(i) = area;
end
