function ABIC = GetABIC_PT(MM,B,G,Mu,ParameterNumber, E_NUM)
%
% ABIC = GetABIC_PT(MM,B,G,Mu,ParameterNumber, E_NUM)
%
% Solve MM*ep=0 and B*ep=G with constraint.
% MM  C_NUM x X_NUM 
% B   [ARBITRARY NUMBER] x X_NUN 
%
% Version 1.3
% Shuji Ishihara
% adjustments Boris Guirao

%% Code %%

C_NUM=size(MM,1); % condition number
X_NUM=size(MM,2); % unknown vaiable number


smu = sqrt(Mu);
K=1;              % number of zero-eigen values of A

UN = E_NUM; % 1.1
%UN = rank(B'*B)

M0 = X_NUM-UN;    % Number of zero-eigen values of B
NKM = C_NUM+K-M0; 

fprintf(['\nMu = ' num2str(Mu) '\n']);

S = [MM, zeros(C_NUM,1); smu*B, smu*G];
clear MM
fprintf('QR decomposition of S [R = triu(qr(S))]...')
tic
R = triu(qr(S));                            % X = qr(A) and X = qr(A,0) return a matrix X such that triu(X) is the upper triangular factor R.
% assignin('base','S',S);                    % USED TO UNDERSTAND THE DISCREPANCY BETWEEN R AND R FROM SR (SPARSE VERSION OF R)
% assignin('base','R',R);                    % USED TO UNDERSTAND THE DISCREPANCY BETWEEN R AND R FROM SR (SPARSE VERSION OF R)
fprintf('done\n');
toc
clear S


H = R(1:X_NUM,1:X_NUM);
%h = R(1:X_NUM,end);
F = R(X_NUM+1,X_NUM+1);
F = F*F;
clear R     % (1.3)


dh = diag(H);
dh(end) = [];
dh=abs(dh);
detlA = 2*sum(log(dh));
detlB = UN*log(Mu);

ABIC = NKM+NKM*log(2.0*pi*F/(NKM))+detlA-detlB+2*ParameterNumber;

% displaying values of each term (2.1):
disp(['NKM = ' num2str(NKM)]);
disp(['F = ' num2str(F)]);
disp(['detlA = ' num2str(detlA)]);
disp(['detlB = ' num2str(detlB)]);
disp(['ABIC(' num2str(Mu) ') = ' num2str(ABIC)]);


%% History %%

% 20/09/2013: 1.3
% - removed matrix R from outputs, clear R added

% 03/09/2013: 1.2
% - added matrix R in outputs for debug purpose
% - removed weird "~" second input

% 13/11/2012:
% - display of ABIC value and all terms contributing to it;

% 31/10/2012: 1.1
% - adjusted a working version WITHOUT using sparse matrices AT ALL
% - added E_NUM as input
% - display of ABIC value

% 28/09/2012: 1.0.5: 
% - stopped calculating UN = rank(B'*B) (not needed): UN = sum(any(B));

