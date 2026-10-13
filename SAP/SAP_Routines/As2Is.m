function  Is = As2Is(As)
%
% INPUT: As = [A0 A1 B1 A2 B2 ; A0' A1' B1' A2' B2' ; ...]
% OUTPUT: [I0 I1 Ph1 I2 Phi2 ; I0' I1' Ph1' I2' Phi2' ; ...], wih Phi angles in DEGREES
%
% Converts Fourier transform coefficients [A0 A1 B1 A2 B2] calculated over
% cell contour intensity into [I0 I1 Ph1 I2 Phi2] (see below for
% definition), for each line (each cell) in the array.
%
% NB: Convention used:
%     I(a) = A0 + A1 cos(a) + B1 sin(a) + A2 cos(2a) + B2 sin(2a) +...
%          = I0 + I1 cos(a + Phi1) + I2 cos(2a + Phi2) + ...
%
% then, theta_star1,2 , angle of max intensity for modes 1,2 are given by:
%       theta_star1 = -Phi1
%       theta_star2 = -Phi2/2
%
% WARNING: in SIA, a +30 angle ellipse points DOWNWARD ('ij' axis convention)!
%
% Version 1.2
% Boris Guirao, adapted from "edge_cell_detection_v6" and "acedic" by I.Bonnet and F.Serman
%


%% Extraction from As %%

% Extracts each column (1.2):
A0s = As(:,1);
A1s = As(:,2);
B1s = As(:,3);
A2s = As(:,4);
B2s = As(:,5);


%% Conversion into Is %%

% Calculation of intensity I and angles Phi of mode 0, 1 and 2:

I0s = A0s;

I1s = sqrt(A1s.^2 + B1s.^2);
Phi1s = -radtodeg(angle(A1s + 1i*B1s));

I2s = sqrt(A2s.^2 + B2s.^2 );
Phi2s = -radtodeg(angle(A2s + 1i*B2s));

% NB: Phi2 is in [-pi, pi], which implies theta_star2 in [-pi/2, pi/2]


%% Merging into Is %%

Is = [I0s I1s Phi1s I2s Phi2s];


%% History %%

% 02/02/2011: 1.2
% - can now take an array as input and return an array.
% - use of "radtodeg" newer version of "rad2deg".

% 01/02/2011: 1.1
% - now uses angle (argument) that gives an angle in radian in [-pi; pi] instead of acos etc..
% - does not add 180° anymore to Phi1,2

% 31/01/2011: creation 1.0