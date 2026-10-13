function [chordLengths, chordAngles] = ChordGeometry(imageSize, indexCouples, scale1D)
%
% [chordLengths, chordAngles] = ChordGeometry(imageSize, indexCouples, scale1D)
%
% Returns vectors "chord_lengths" (scaled), "chord_angles" (degrees)
% calculated from the list of couples of indices "index_couples" (n_chords
% x 2 matrix) and the scale factor "scale_1D"
%
% NB1: chord(k) -> index_couples(k,:)
% NB2: since Y increases downwards, POSITIVE angles correspond to chords
% pointing DOWNWARDS
%
% Version 1.0
% Boris Guirao

%% Code

%%% Extracts columns of pixel indices:
index_couples_col_1 = indexCouples(:,1);
index_couples_col_2 = indexCouples(:,2);

%%% convertion index -> IJ coordinate:
[chord_ends_1_I, chord_ends_1_J] = ind2sub(imageSize, index_couples_col_1);
[chord_ends_2_I, chord_ends_2_J] = ind2sub(imageSize, index_couples_col_2);

%%% IJ -> XY:
chord_ends_1_XY = [chord_ends_1_J chord_ends_1_I];
chord_ends_2_XY = [chord_ends_2_J chord_ends_2_I];

%%% Rescaling:
chord_ends_1_XY_scaled = chord_ends_1_XY * scale1D;
chord_ends_2_XY_scaled = chord_ends_2_XY * scale1D;

%%% Chord lengths and angles calculation:
chord_vectors_XY = chord_ends_2_XY_scaled - chord_ends_1_XY_scaled;
chord_vectors_Z = chord_vectors_XY(:,1) + 1i * chord_vectors_XY(:,2);      % turns vectors into complex numbers Z = X + iY

chordLengths = abs(chord_vectors_Z);                                      % takes vector lengths
chordAngles = angle(chord_vectors_Z) * 180/pi;                            % takes vector angles

%%% Re-assign NaN to angles corresponding to 0 chord length (previously assigned to 0 by Matlab!):
ind_zero_length = chordLengths == 0;
chordAngles(ind_zero_length) = NaN;

%% History

% 09/06/2010: creation