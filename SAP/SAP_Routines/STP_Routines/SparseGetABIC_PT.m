function [ABIC, vertex_mistake] = SparseGetABIC_PT(SMM,SB,SG,Mu,ParameterNumber,E_NUM,qrMethod) 
%
% [ABIC, vertex_mistake] = SparseGetABIC_PT(SMM,SB,SG,Mu,ParameterNumber,E_NUM,qrMethod) 
%
% Solve MM*ep=0 and B*ep=G with constraint.
% MM  C_NUM x X_NUM 
% B   [ARBITRARY NUMBER] x X_NUN 
%
% Version 2.4
% Shuji Ishihara
% Boris Guirao: changes to only involve sparse matrices

%% Code %%

C_NUM=size(SMM,1); % condition number
X_NUM=size(SMM,2); % unknown vaiable number

smu = sqrt(Mu);
K=1;              % number of zero-eigen values of A

UN = E_NUM;
%UN = sum(any(B));   % = E_NUM !!! (1.3)

M0 = X_NUM-UN;    % Number of zero-eigen values of B
NKM = C_NUM+K-M0; 

fprintf(['\nMu = ' num2str(Mu) '\n']);

S0 = sparse(zeros(C_NUM,1));
SS = [SMM S0; smu*SB smu*SG]; %#ok<NASGU>

cmd = ['SR = ' qrMethod '(SS);'];
fprintf(['QR decomposition of S using SPARSE MATRICES [' cmd ']...'])
tic
eval(cmd);
fprintf('done\n');
clear SS;
toc

% Cropping R to its square part (2.3):
SR = SR(1:X_NUM+1,1:X_NUM+1);                                                                                           %#ok<NODEF>
SdR = diag(SR);                                                                                                         % matrix R being upper triangular, its eigenvalues lie on its diagonal

% Extracts and display local R structure (2.3)
SR_local = full(SR(X_NUM-1:X_NUM+1,X_NUM-1:X_NUM+1));                                                                   % extracting 3x3 matrix ending at location (m+1,m+1) in R
disp('Displaying local R structure:')
disp(num2str(SR_local));

% Extracting h value in R matrix according to last two eigenvalues (2.3)                                                                                           
if SdR(X_NUM) == 0 && SdR(X_NUM+1) == 0 
    SF = SR(X_NUM,X_NUM+1);             % regular case with sparse matrices: removal of zero-eigenvalue (Phs) line
    vertex_mistake = 0;
    disp('Taking "h" value at location (m,m+1) in R matrix (regular case)');
else                                    
    SF = SR(X_NUM+1,X_NUM+1);           % special case: the Phs line is back, taking F at same location than full matrix
    vertex_mistake = 1;                 % corresponds to mistake in vertex ordering resulting in last diagonal coeff |Hm|>0 in matrix H (instead of 0) 
    disp('WARNING: taking "h" value at location (m+1,m+1) in R matrix (special case)');
    disp('         => vertex ordering mistake in Cs!');
end
F = full(SF*SF);
clear SR

% OLD:
%------------------------------------------------------------------------------------------------------------------
% % Building sparse H and F (1.6):
% SH = SR(1:X_NUM-1,1:X_NUM);
% S0 = sparse(zeros(1,X_NUM));
% SH = [SH ; S0];
% SF = SR(X_NUM,X_NUM+1);
% F = full(SF*SF);

% Sdh = diag(SH);
%clear SR SH Sh
% 
% Sdh(end) = []; % removes 0 eigenvalue corresponding to Ph
%------------------------------------------------------------------------------------------------------------------

Sdh = SdR(1:X_NUM-1); % crops list of R eigenvalues by removing the last two to get H eigenvalues
Sdh = abs(Sdh);
Slogdh = log(Sdh);

detlA = full(2*sum(Slogdh));
detlB = UN*log(Mu);

ABIC = NKM+NKM*log(2.0*pi*F/(NKM))+detlA-detlB+2*ParameterNumber;

% displaying values of each term (2.1):
disp(['h = ' num2str(SF)]);
% disp(['F = ' num2str(F)]);
% disp(['detlA = ' num2str(detlA)]);
% disp(['detlB = ' num2str(detlB)]);
disp(['ABIC(' num2str(Mu) ') = ' num2str(ABIC)]);


%% History %%

% 20/09/2013: 2.4
% - addition of output "vertex_mistake" to indicate the "special case" that stems from a
% mistake in vertex ordering in CJs (in Cs) that impacts matrix SMM

% 09/09/2013: 2.3 
% - checking local structure of R matrix to make sure the right number is assigned to scalar h
% - displaying R local structure in workspace, removed display of F, NKM, detlA, detlB
% - removed matrix SR from outputs again

% 03/09/2013: 2.2
% - added matrix SR in outputs for debug purpose
% - removed weird "~" second input

% 13/11/2012: 2.1
% - display of all terms contributing to ABIC value
% - now keeps dh sparse unitl detlA computation

% 11/11/2012: 2.0
% - display of ABIC value

% 08/11/2012: 1.7
% - added 'qr_method' as input ('qr' or 'spqr')

% 31/10/2012: 1.6
% - THOROUGHLY USES SPARSE MATRICES
% - changed name to SparseGet_ABIC

% 30/10/2012: 1.5
% - adjustment to ONLY take sparse matrices as input
% - stopped displaying F and ABIC in workspace
% - added E_NUM as input

% 01/10/2012: 1.4
% - use of SPARSE MATRICES for QR decomposition
% - clearing biggest matrices after their last use

% 28/09/2012: 1.3: 
% - stopped calculating UN = rank(B'*B) (not needed): UN = sum(any(B));


