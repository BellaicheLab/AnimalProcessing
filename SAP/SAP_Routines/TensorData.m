 function Tdata = TensorData(T)
%
% Tdata = TensorData(T)
%
% from tensor T cartesian coordinates T = [Txx Txy Tyx Tyy], calculates eigen-values/vectors and stores everything in
% structure "Tdata" that so far contains:
%
% * Es = EIGENVALUES [E1 E2] sorted in ASCENDING order OF *** DEVIATORIC PART OF T, NOT THEIR MODULES ***, (1x2 vector)
%        (Ex: [+2 -2] if T is deviatoric (Eiso =0), [1 -3] if same dev part (namely (1+3)/2*[1 -1] = [+2 -2]) but with Eiso = -1)
%       => the first listed angle always indicates the direction of the + bar (in circle-bar plots)
%
% * Angles = angles (in [-90, 90]) made by each eigenvector with x axis (1x2 vector)
%
% Version 3.1
% Boris Guirao
%

%% Code %%

if ~any(isnan(T)) && ~any(isinf(T))        % checks there are no NaN or Inf (2.1)
    
    Tmat = Vec2Mat(T);                     % reshapes [Txx Txy Tyx Tyy] into 2X2 matrix [Txx Txy ; Tyx Tyy] (2.0)
    
    % Calculation and sorting will be made on Tdev (3.0):
    Eiso = trace(Tmat)/2;                    % part that will be added back to eigenvalues of dev part
    Tiso = Eiso*eye(2);
    Tdev = Tmat - Tiso;  
    [Vs, Edevs] = eig(Tdev);                  % computes eigenvectors Vs and eigenvalues ON DEV PART OF T: Edevs
    % NB: Es are NOW equal and opposite since taken on Tdev: Es(2) = -Es(1) (3.0)
    
    % Reformatting:
    E1 = Edevs(1,1); E2 = Edevs(2,2);
    V1 = Vs(:,1); V2 = Vs(:,2);
    Z1 = V1(1) + 1i*V1(2);
    Z2 = V2(1) + 1i*V2(2);
    Edevs = [E1 ; E2];
    Zs = [Z1 ; Z2];
    
    % Resorting putting POSITIVE eigenvalue FIRST (3.0, 3.1)
    mat = [Edevs [1;2]];                % 3.1
    matSorted = sortrows(mat,-1);       % puts rows with highest value in col 1 on top (put -1 in 3.1)
    Edevs = matSorted(:,1);             % now sorted as follows: Es(1) > 0 > Es(2) = -Es(1)
    ZsLoc = matSorted(:,2);              % 3.1
    Zs = Zs(ZsLoc);                      % 3.1
    
    % COMMENTED 3.1
%     mat = [Edevs Zs];
%     matSorted = (sortrows(mat,1));      % sort rows in ASCENDING ORDER with respect to column 1
%     Edevs = matSorted(:,1);             % now sorted as follows: Es(1) > 0 > Es(2) = -Es(1)
%     Zs = matSorted(:,2);
    
    % Adding back isotropic part (3.0)
    Es = Edevs + Eiso;                  % Full eigenvalues of tensor T
    
    % OLD: RE-sorting puting values corresponding to HIGHEST "AEs" FIRST:
%     mat = [AEs ; Es ; Zs ];
%     matSorted = (sortrows(mat',-1))';     % sort rows in DESCENDING ORDER with respect to column 1
%     Es = matSorted(2,:);                  % now sorted as follows: AEs(1) > AEs(2)
%     Zs = matSorted(3,:);
    
    % Calculating angles "Angles": angles of each eigenvalues with x axis
    Angles = rad2deg(angle(Zs));
    Thetas_high_TF = Angles > 90;
    Thetas_low_TF =  Angles < -90;
    % Resetting angles in [-90, 90]:
    Angles(Thetas_high_TF) = Angles(Thetas_high_TF) - 180;
    Angles(Thetas_low_TF) = Angles(Thetas_low_TF) + 180;
    
else
    Es = [NaN ; NaN];         % 2.1, 3.0
    Angles = [NaN ; NaN];     % 2.1, 3.0
end



%% Writing in "Tdata" %%

Tdata.Es = Es';         % transpose to store as before (2.1-) a 1x2 row vector [Es(1) Es(2)]
Tdata.Angles = Angles';



%% History %%

% 08/04/2016: 3.1
% - fixed issue with "mat" becoming a complex matrix becaue of Zs and yielding inaccurate sorting

% 06/08/2015: 3.0
% - now sorts eigenvalues and eigenvectors according to asending eigenvalues of DEVIATORIC PART OF T, namelely
% Edevs(1) > 0 > Edevs(2) = - Edevs(1).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAJOR CHANGES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 25/02/2015: 2.1 (became TensorData)
% - support of tensors containing NaN of Inf

% 17/02/2015: 2.0: started implementation of new framework
% - use of Vec2Mat
% - removed "minAEV" argument setting a threshold: now angles are ALWAYS calculated, even when meaningless.
% NB: with the "split" representation, it doesn't matter if the angles are ill defined since the bar has nearly 0 length

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NEW FRAMEWORK RENORMALIZATION (TA 2.0+)%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 05/12/2013: 1.3
% - fixed bug when AEs(1)=AEs(2)=0 then ratio = NaN, which was causing a
% bug in "if (1 - rAEs > minAEV) || E1*E2 < 0" since the output was not logical

% 23/07/2013: 1.2
% - changed criterion to assess meaningful angles: now ALWAYS caculate angle when eigenvalues have differents signs (+1 and -1 are very different, although anisotropy = 0)!
% - when angles deemed not meaningful, replaced Angles = [NaN NaN] by [0 90] so that ellipses STILL get displayed

% 19/07/2013: 1.1
% - changed criterion to calculate angle: now using "minAEV" with a RELATIVE criterion (anisotropy between
% eigenvalues) instead of ABSOLUTE criterion on largest eigenvalue.

% 26/11/2011: creation