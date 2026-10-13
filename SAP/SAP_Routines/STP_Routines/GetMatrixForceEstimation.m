function [MM,C_NUM,X_NUM]  = GetMatrixForceEstimation(x,y,edge,cell,E_NUM,CELL_NUMBER,R_NUM,INV_NUM,Rnd,ERR_MAX)
%
%
% Version 1.0
% Shuji Ishihara

RndE = Rnd(2,1:end);
RndC = Rnd(3,1:end);
RndJ = Rnd(1,1:end);

C_NUM = 2*(INV_NUM);       % �?�件数
X_NUM = E_NUM+CELL_NUMBER; % 未知変数

MX = zeros(INV_NUM+R_NUM,X_NUM);  % V_NUM = INV_NUM+R_NUM
MY = zeros(INV_NUM+R_NUM,X_NUM);

disp(['Iteration over edge number (E_NUM = ' num2str(E_NUM) ')...']);
tic
for i=1:length(edge)
  tedge = edge(i);
  MX(tedge.junc1,i) = -tedge.dx/tedge.dist;
  MY(tedge.junc1,i) = -tedge.dy/tedge.dist;
  MX(tedge.junc2,i) =  tedge.dx/tedge.dist;
  MY(tedge.junc2,i) =  tedge.dy/tedge.dist; 
end
toc

disp(['Iteration over CELL number (CELL_NUMBER = ' num2str(CELL_NUMBER) ')...']);
tic
for i=1:length(cell)
  pn = cell(i).jnum;
  ij = cell(i).junc;
  if length(ij) ~= pn; error('not consistent polygon class'); end  % check
  if ~ismember(ij(1),RndJ)
      MX(ij(1),E_NUM+i) = 0.5*(y(ij(2))-y(ij(pn))); 
      MY(ij(1),E_NUM+i) = 0.5*(x(ij(pn))-x(ij(2))); 
  end

  for j=2:pn-1
    if ~ismember(ij(j),RndJ)
      MX(ij(j),E_NUM+i) = 0.5*(y(ij(j+1))-y(ij(j-1))); 
      MY(ij(j),E_NUM+i) = 0.5*(x(ij(j-1))-x(ij(j+1))); 
    end
  end

  if ~ismember(ij(pn),RndJ)
    MX(ij(pn),E_NUM+i) = 0.5*(y(ij(1))-y(ij(pn-1))); 
    MY(ij(pn),E_NUM+i) = 0.5*(x(ij(pn-1))-x(ij(1))); 
  end
end
toc


MX(RndJ,:)=[];
MY(RndJ,:)=[];
MM = [MX;MY];    % MM

if size(MM) ~= [C_NUM, X_NUM]
  fprintf('%d %d\n',size(MM));
  error('Not Valid Martix: incorrect size');
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%%   Check the validity of Matrix MM
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp('Checking validity of matrix MM...');
ze= [1:E_NUM];
ze(RndE)=[];
zc=[1:CELL_NUMBER];
zc(RndC)=[];

CM = sum(MX);
cc = [CM(ze), CM(zc)];
err_x = abs(sum(cc));

CM = sum(MY);  
cc = [CM(ze), CM(zc)];
err_y = abs(sum(cc));

% not boundary vertces 
ix=x;  ix(RndJ)=[];
iy=y;  iy(RndJ)=[];
cx = [iy, -ix];
ccx=cx*MM;
ccx(RndE)=[];
ccx(RndC)=[];
err_ang = abs(sum(ccx));

ce = [ zeros(E_NUM,1); ones(CELL_NUMBER,1) ];
err_iso=abs(sum(MM*ce));
% err_iso=sum(abs(MM*ce));


fprintf('\n## Either err_ang or err_iso should be zero ( >ERR_MAX= %.2e ) \n',ERR_MAX);
fprintf('## err_x= %e   err_y= %e   err_ang=  %e  err_iso= %e\n',err_x,err_y,err_ang,err_iso);
if max([err_x err_y err_ang err_iso]/C_NUM) > ERR_MAX; 
  fprintf('%e %e %e %e\n',err_x,err_y,err_ang,err_iso);
  error('Not Valid Martix: too large error');
end;    
fprintf('\n');

%% History %%

% 12/11/2012: correction of the sum(abs) mistake in err_iso
