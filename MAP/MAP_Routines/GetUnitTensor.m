function uTensor = GetUnitTensor(uTensorName)
%
% Version 1.0
% Boris Guirao

%% Code %%

if strcmp(uTensorName,'u0')
    
    uTensor = eye(2);   % identity matrix (0th Pauli matrix)
    
elseif strcmp(uTensorName,'u1')
    
    uTensor = [0  1;    % 1st Pauli matrix
               1  0];
    
elseif strcmp(uTensorName,'u3')
    
    uTensor = [1  0;     % 3rd Pauli matrix
               0 -1];
           
elseif strcmp(uTensorName,'xx')
    
    uTensor = [1  0;     
               0  0];
    uTensor = 2*uTensor;    % NOT unitary, but will give xx component (T.uTensor = Txx)
%     uTensor = sqrt(2)*uTensor; % to make it unitary: uxx.uxx = 1; (BUT T.uTensor = 1/sqrt(2)*Txx)
    
elseif strcmp(uTensorName,'yy')
    
    uTensor = [0  0;     
               0  1];
    uTensor = 2*uTensor;    % NOT unitary, but will give yy component (T.uTensor = Tyy)
%     uTensor = sqrt(2)*uTensor; % to make it unitary: uyy.uyy = 1; (BUT T.uTensor = 1/sqrt(2)*Tyy)
    
elseif strcmp(uTensorName,'xy')
    
    uTensor = [0  1;     
               0  0];
    uTensor = 2*uTensor;    % NOT unitary, but will give xy component (T.uTensor = Txy)
%     uTensor = sqrt(2)*uTensor; % to make it unitary (BUT T.uTensor = 1/sqrt(2)*Txy)
    
elseif strcmp(uTensorName,'yx')
    
    uTensor = [0  0;     
               1  0];
    uTensor = 2*uTensor;    % NOT unitary, but will give yx component (T.uTensor = Tyx)
%     uTensor = sqrt(2)*uTensor; % to make it unitary (BUT T.uTensor = 1/sqrt(2)*Tyx)
    
else
    uTensor = [];
end


%% History %%

% 03/07/2019: creation