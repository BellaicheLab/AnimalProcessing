
function [x,y,edge,cell,Rnd,CELL_NUMBER,E_NUM,V_NUM,INV_NUM,R_NUM,scale] = GetData(filename)
%
%  edge,cell,は構造体
%


R_NUM=0;  RndJ=[]; RndE=[]; RndC=[];
x=[];  y=[];  edge=[];  cell=[];
scale = 1.0;

Fid = fopen(filename,'r');
while feof(Fid) == 0;
    Line = fgetl(Fid);
    if findstr(Line,'#')
        fprintf('%s\n',Line);
        if strfind(Line,'C_NUM');
            token = strtok(Line, '# C_NUM ');
            CELL_NUMBER=sscanf(token,'%f');
        elseif strfind(Line,'IN_CNUM');
            token = strtok(Line, '##  IN_CNUM ');
            IC_NUM=sscanf(token,'%f');
        elseif findstr(Line,'EX_CNUM');
            token = strtok(Line, '##  EX_CNUM');
            R_NUM=sscanf(token,'%d');
        elseif strfind(Line,'# V_NUM');
            token = strtok(Line, '# V_NUM ');
            V_NUM=sscanf(token,'%f');
            INV_NUM=V_NUM-R_NUM;
            N = 2*V_NUM;   % !! Notice: Not 2*(V_NUM+R_NUM) !!
        elseif strfind(Line,'# E_NUM');
            token = strtok(Line, '# E_NUM ');
            E_NUM=sscanf(token,'%f');        
	elseif strfind(Line,'### Scale');
            token = strtok(Line, '### Scale =');
            scale=sscanf(token,'%f');  
        end
    else
        if strfind(Line,'J[')
            [token, remind] = strtok(Line, ' ');
            xx = sscanf(remind,'%f%f');
            x = [x,xx(1)];
            y = [y,xx(2)];
            if findstr(remind,'Ext');  RndJ = [RndJ,length(x)];   end
        elseif strfind(Line,'E[')
            [token, remind] = strtok(Line, ' ');
            tmp = sscanf(remind,'%f%f')+1;  % offset 1
            x1 = x(tmp(1));
            y1 = y(tmp(1));
            x2 = x(tmp(2));
            y2 = y(tmp(2));
            dx = x1-x2;
            dy = y1-y2;
            dist = sqrt( dx.^2 + dy.^2);
            angle = atan2(dy,dx);
            if angle<0 ;  angle = angle + pi; end
            tedge = struct('junc1',tmp(1), 'junc2',tmp(2),...
                           'x1',x1,'y1',y1,'x2',x2,'y2',y2,...
                           'dx',dx,'dy',dy,'dist',dist,'angle',angle);
            if findstr(remind,'Ext');  
                tedge.inout = 'o';
            else
                tedge.inout = 'i';
            end
            edge = [edge,tedge];
            if findstr(remind,'Ext');  RndE = [RndE,length(edge)];  end
        elseif strfind(Line,'C[')
            [token, remind] = strtok(Line,' ');
            [token, remind] = strtok(remind,':');
            tcell.jnum = sscanf(token,'%d');
            [token,remind] =  strtok(remind,':');
            tjunc = sscanf(token,'%d');
            tcell.junc = tjunc + 1;   % offset=1
            if findstr(Line,'Ext')
                tcell.in_out = 'o';  
            else
                tcell.in_out = 'i';   
            end
            cell = [cell tcell];
            if findstr(Line,'Ext');  RndC = [RndC,length(cell)];  end
        end
    end
end
fclose(Fid);

mx = mean(x);
my = mean(y);
%  x = x-mx;
%  y = y-my;



% check: cell positivity
ff=0;
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
end
if ff==1; return; end;


for i=1:length(edge)
    edge(i).dx = edge(i).x1 -edge(i).x2;
    edge(i).dy = edge(i).y1 -edge(i).y2;
end


Rnd=[RndJ; RndE; RndC];

%  fprintf('## CELL_NUMBER = %d\n',CELL_NUMBER);
%  fprintf('## E_NUM = %d\n',E_NUM);
%  fprintf('## V_NUM = %d\n',V_NUM);
%  fprintf('## R_NUM = %d\n',R_NUM);
%  fprintf('## INV_NUM = %d\n',INV_NUM);
