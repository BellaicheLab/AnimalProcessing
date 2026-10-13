function anglesOut = FixAnglesDEG(anglesIn)
%
% Program to fix angles of bars for which angles are only relevant between [-90 90] (unlike vectors).
% From angles in [-180 180] will return angles between [-90 90] by adding or subtracting 180. 
% NB: in DEGREES!!!
%
% version 1.0
% Boris Guirao
%

%% Code %%

anglesOut = anglesIn;

anglesInAboveTF = anglesIn >  90;
anglesInBelowTF = anglesIn < -90;

anglesOut(anglesInAboveTF) = anglesOut(anglesInAboveTF) - 180;
anglesOut(anglesInBelowTF) = anglesOut(anglesInBelowTF) + 180;


%% History %%

% 10/01/2018: creation from "FixAnglesRAD"
