function anglesOut = FixAnglesRAD(anglesIn)
%
% Program to fix angles of bars for which angles are only relevant between [-pi/2 pi/2] (unlike vectors).
% From angles in [-pi pi] will return angles between [-pi/2 pi/2] by adding or subtracting pi. 
% NB: in RADIANS!!!
%
% version 1.0
% Boris Guirao
%

%% Code %%

anglesOut = anglesIn;

anglesInAboveTF = anglesIn >  pi/2;
anglesInBelowTF = anglesIn < -pi/2;

anglesOut(anglesInAboveTF) = anglesOut(anglesInAboveTF) - pi;
anglesOut(anglesInBelowTF) = anglesOut(anglesInBelowTF) + pi;


%% History %%

% 25/10/2017: creation
