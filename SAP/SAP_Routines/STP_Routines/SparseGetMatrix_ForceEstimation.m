function [SMM,C_NUM,X_NUM]  = SparseGetMatrix_ForceEstimation(Js,Es,Cs,E_NUM,CELL_NUMBER,R_NUM,INV_NUM,ERR_MAX)
%
%
% Version 2.0
% Shuji Ishihara
% changes by Boris Guirao


%% Initializations %%

C_NUM = 2*(INV_NUM);            % �?�件数
X_NUM = E_NUM + CELL_NUMBER;    % 未知変数

% Extracting data:
ExtractData(Js,'','caller');
ExtractData(Es,'','caller');
ExtractData(Cs,'','caller');

% OLD:
% MX = zeros(INV_NUM+R_NUM,X_NUM);  % V_NUM = INV_NUM+R_NUM
% MY = zeros(INV_NUM+R_NUM,X_NUM);


%% Iteration over edges %%

% % To avoid loop:
% Elist = (1:E_NUM)';
% Ns_odd = (1:2:2*E_NUM)';
% Ns_even = (2:2:2*E_NUM)';

disp('Initialization of edge vectors...');
% is & js:
edgeXY_is = NaN(2*E_NUM,1);
edgeXY_js = NaN(2*E_NUM,1);
% ss:
edgeX_ss = NaN(2*E_NUM,1);
edgeY_ss = NaN(2*E_NUM,1);
n=0;

disp(['Iteration over edge number (E_NUM = ' num2str(E_NUM) ')...']);
tic
for i=1:E_NUM
        n=n+1;
        edgeXY_is(n) = EJ1s(i);
        edgeXY_js(n) = i;
        edgeX_ss(n) = -EdXs(i)/EDs(i);
        edgeY_ss(n) = -EdYs(i)/EDs(i);
        n=n+1;
        edgeXY_is(n) = EJ2s(i);
        edgeXY_js(n) = i;
        edgeX_ss(n) = EdXs(i)/EDs(i);
        edgeY_ss(n) = EdYs(i)/EDs(i); 
    
%     % OLD:  
%         tedge = edge(i);
%         n=n+1;
%         edgeXY_is(n) = tedge.junc1;
%         edgeXY_js(n) = i;
%         edgeX_ss(n) = -tedge.dx/tedge.dist;
%         edgeY_ss(n) = -tedge.dy/tedge.dist;
%         n=n+1;
%         edgeXY_is(n) = tedge.junc2;
%         edgeXY_js(n) = i;
%         edgeX_ss(n) = tedge.dx/tedge.dist;
%         edgeY_ss(n) = tedge.dy/tedge.dist;
        
%     % OLDER
%     tedge = edge(i);
%     MX(tedge.junc1,i) = -tedge.dx/tedge.dist;
%     MY(tedge.junc1,i) = -tedge.dy/tedge.dist;
%     MX(tedge.junc2,i) =  tedge.dx/tedge.dist;
%     MY(tedge.junc2,i) =  tedge.dy/tedge.dist;
end
toc


%% Iteration over cells %%

disp('Initialization of cell vectors...');

% is & js:
cellXY_is = NaN(7*CELL_NUMBER,1); % 4 instead of 3 to have some leeway Or 6 ???
cellXY_js = NaN(7*CELL_NUMBER,1);
% ss:
cellX_ss = NaN(7*CELL_NUMBER,1);
cellY_ss = NaN(7*CELL_NUMBER,1);
n=0;

disp(['Iteration over CELL number (CELL_NUMBER = ' num2str(CELL_NUMBER) ')...']);
tic
for i=1:CELL_NUMBER
    pn = CnJs(i);
    i_CJs = CJs(i,:);
    i_CJs_TF = ~isnan(i_CJs);
    ij = i_CJs(i_CJs_TF);
%     % OLD
%     pn = cell(i).jnum;
%     ij = cell(i).junc;

    if length(ij) ~= pn; error('not consistent polygon class'); end  % check
    
    if ij(1) > R_NUM
%     if ~ismember(ij(1),JExts)
        n = n+1;
        cellXY_is(n) = ij(1);
        cellXY_js(n) = E_NUM+i;
        cellX_ss(n) = 0.5*(JYs(ij(2))-JYs(ij(pn)));
        cellY_ss(n) = 0.5*(JXs(ij(pn))-JXs(ij(2)));
%         % OLD
%         cellX_ss(n) = 0.5*(y(ij(2))-y(ij(pn)));
%         cellY_ss(n) = 0.5*(x(ij(pn))-x(ij(2)));
        %       % OLDER:
        %       MX(ij(1),E_NUM+i) = 0.5*(y(ij(2))-y(ij(pn)));
        %       MY(ij(1),E_NUM+i) = 0.5*(x(ij(pn))-x(ij(2)));
    end
    
    for j=2:pn-1
        if ij(j) > R_NUM
%         if ~ismember(ij(j),JExts)
            n = n+1;
            cellXY_is(n) = ij(j);
            cellXY_js(n) = E_NUM+i;
            cellX_ss(n) = 0.5*(JYs(ij(j+1))-JYs(ij(j-1)));
            cellY_ss(n) = 0.5*(JXs(ij(j-1))-JXs(ij(j+1)));
%             % OLD
%             cellX_ss(n) = 0.5*(y(ij(j+1))-y(ij(j-1)));
%             cellY_ss(n) = 0.5*(x(ij(j-1))-x(ij(j+1)));
            %         % OLDER
            %         MX(ij(j),E_NUM+i) = 0.5*(y(ij(j+1))-y(ij(j-1)));
            %         MY(ij(j),E_NUM+i) = 0.5*(x(ij(j-1))-x(ij(j+1)));
        end
    end
    
    if ij(pn) > R_NUM
%     if ~ismember(ij(pn),JExts)
        n = n+1;
        cellXY_is(n) = ij(pn);
        cellXY_js(n) = E_NUM+i;
        cellX_ss(n) = 0.5*(JYs(ij(1))-JYs(ij(pn-1)));
        cellY_ss(n) = 0.5*(JXs(ij(pn-1))-JXs(ij(1)));
%         % OLD
%         cellX_ss(n) = 0.5*(y(ij(1))-y(ij(pn-1)));
%         cellY_ss(n) = 0.5*(x(ij(pn-1))-x(ij(1)));
        %       % OLDER
        %       MX(ij(pn),E_NUM+i) = 0.5*(y(ij(1))-y(ij(pn-1)));
        %       MY(ij(pn),E_NUM+i) = 0.5*(x(ij(pn-1))-x(ij(1)));
    end
end
% Cropping vectors to non-NaN values:
noNaN_TF = ~isnan(cellXY_is);
cellXY_is = cellXY_is(noNaN_TF);
cellXY_js = cellXY_js(noNaN_TF);
cellX_ss = cellX_ss(noNaN_TF);
cellY_ss = cellY_ss(noNaN_TF);
toc


%%  Building matrix SMM %%

noExt_TF = edgeXY_is > R_NUM;                       % gets lines corresponding to non-Ext edges (see OLD part below)
% SMX:
XIs = [edgeXY_is(noExt_TF) ; cellXY_is] - R_NUM;    % removes these from list of lines of sparse matrix AND reset indices to start from 1 (and not R_NUM+1)
XJs = [edgeXY_js(noExt_TF) ; cellXY_js];            % removes associated j values
XSs = [edgeX_ss(noExt_TF) ; cellX_ss];              % removes associated s values
SMX = sparse(XIs,XJs,XSs);

% SMY:
YIs = [edgeXY_is(noExt_TF) ; cellXY_is]- R_NUM;     % removes these from list of lines of sparse matrix AND reset indices to start from 1 (and not R_NUM+1)
YJs = [edgeXY_js(noExt_TF) ; cellXY_js];            % removes associated j values
YSs = [edgeY_ss(noExt_TF) ; cellY_ss];              % removes associated s values
SMY = sparse(YIs,YJs,YSs);

% SMM (1.1,1.2):
SMM = [SMX ; SMY];

% NB: removing R_NUM from lines values (is) assumes that all Ext edges have been listed CONSECUTIVELY and that non-Ext
% edges start at R_NUM+1

% % OLD:
% MX(RndJ,:)=[];
% MY(RndJ,:)=[];
% MM = [MX;MY];    % MM


%% Checking SMM size %%

fprintf('Checking size of SMM...');
if any(size(SMM) - [C_NUM, X_NUM])
    fprintf('%d %d\n',size(SMM));
    error('Not Valid Martix: incorrect size');
else
    fprintf('SMM size OK.\n');
end

% % OLD:
% if size(MM) ~= [C_NUM, X_NUM]
%   fprintf('%d %d\n',size(MM));
%   error('Not Valid Martix: incorrect size');
% end


%% Checking validity of matrix MM %%

Exts = (1:R_NUM)'; % 2.0

disp('Checking validity of matrix SMM...');
ze= 1:E_NUM;
ze(Exts)=[];
% ze(RndE)=[];
zc=1:CELL_NUMBER;
zc(Exts)=[];
%zc(RndC)=[];

disp('Computing "err_x"...');
SCM = sum(SMX);
CM = full(SCM);
%CM = sum(MX);
cc = [CM(ze), CM(zc)];
err_x = abs(sum(cc));

disp('Computing "err_y"...');
SCM = sum(SMY);
CM = full(SCM);
%CM = sum(MY);  
cc = [CM(ze), CM(zc)];
err_y = abs(sum(cc));

disp('Computing "err_ang"...');
% not boundary vertices 
ix=JXs';  ix(Exts)=[];
iy=JYs';  iy(Exts)=[];
% ix=x;  ix(RndJ)=[];
% iy=y;  iy(RndJ)=[];
cx = [iy, -ix];
Scx = sparse(cx);
Sccx = Scx*SMM;
ccx = full(Sccx);
%ccx=cx*MM;
ccx(Exts)=[];
ccx(Exts)=[];
% ccx(RndE)=[];
% ccx(RndC)=[];
err_ang = abs(sum(ccx));

disp('Computing "err_iso"...');
ce = [ zeros(E_NUM,1); ones(CELL_NUMBER,1) ];
Sce = sparse(ce);
Scce = SMM*Sce;
cce = full(Scce);
err_iso = abs(sum(cce));          % 1.2
% err_iso=sum(abs(cce));
%err_iso=sum(abs(MM*ce));


fprintf('\n## Either err_ang or err_iso should be zero ( >ERR_MAX= %.2e ) \n',ERR_MAX);
fprintf('## err_x= %e   err_y= %e   err_ang=  %e  err_iso= %e\n',err_x,err_y,err_ang,err_iso);
if max([err_x err_y err_ang err_iso]/C_NUM) > ERR_MAX; 
  fprintf('%e %e %e %e\n',err_x,err_y,err_ang,err_iso);
  error('Not Valid Matrix: too large error');
end;    
fprintf('\n');

%% History %%

% 11/11/2012: 2.0
% - adjusments to work with new "FastGetData" outputs

% 31/10/2012: 1.2
% - corrected mistake (I think) in "err_iso" computation (inversion of sum and abs)
% - further simplified building of SMM directly using concanetation of sparse matrices

% 30/10/2012: 1.1
% - changed name to "SparseGetMatrix..."
% - only uses sparse matrices to avoid requiring to much RAM. In particular now returns SMM, sparse version of MM

