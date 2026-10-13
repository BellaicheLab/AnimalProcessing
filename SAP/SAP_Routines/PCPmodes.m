function [A0, A1, B1, A2, B2] = PCPmodes(rawImage, cellContourIndices, contourType, cellCentroid, dilatationValue, imageSize)
%
% [A0, A1, B1, A2, B2] = PCPmodes(rawImage, cellContourIndices, contourType, cellCentroid, dilatationValue, imageSize)
%
% INPUTS:
% rawImage = fluorescence image
% cellContourIndices = linear indices making up cell i contour. Can be real
% cell contour or dilated cell contour.
% contourType = 'normal' or 'dilated'. Specifies above contour type (1.3).
% cellCentroid = 1x2 matrix storing cell i centroid coordinates IN PIXELS
% dilatationValue = number of pixels added around contour for dilatation
% imageSize = size(rawImage)
%
% OUTPUTS:
% Polarity Fourier modes (cartesian): [A0 A1 B1 A2 B2]
%
% NB: with this calculation:
% A(w) = A0 + A1*cos(w)+ B1*sin(w) + A2*cos(2w)+ B2*sin(2w)
% (and NOT A0/2!) A0 being the average intensity around the cortex. Note
% that there is a binning effect as intensities are FIRST averaged for each
% angular sector and THEN averaged together, as opposed to direct averaging
% over the pixels.
%
% Version 2.2
% Boris Guirao


%% Parameters %%

% For calculating theta=f(intensity)
nSteps = 18;                % 20° arcs: nStep = 18; 10° arcs: nStep = 36 ;(initially 80!)


%% Initializations %%

thetaStep = 2*pi/nSteps;                    % removed "thetaRange" that was 2*pi (2.2)
thetaValues = (0:nSteps)'*thetaStep - pi;   % 2*pi cut into nStep parts ranging from -pi to pi
% NB: "thetaValues" has nStep+1 values since -pi and pi correspond to same angle (but convenient for the upcoming loop)

thetaMean = zeros(nSteps,1);
meanIntensity = zeros(nSteps,1);


%% Determination of cell dilated contour (changed 1.3) %%

if strcmp(contourType, 'dilated')
    dilatedCellContourIndices = cellContourIndices;                                                % input = indices of dilated cell contour. Nothing else to do.
elseif strcmp(contourType, 'normal')
    dilatedCellContourIndices = SideDilator(imageSize, cellContourIndices, dilatationValue);  % input = indices of normal cell contour: must be dilated
else
    disp('Error in PCPmodes: type of contour must either be "normal" or "dilated"!');
    return
end


%% Computation of intensity over contour %%

%%% calculates angle values corresponding to pixels making up cell i dilated contour (thoroughly changed in 1.4):
[Is,Js] = ind2sub(imageSize, dilatedCellContourIndices);
Xs = Js; Ys = Is;
deltaXs = Xs - cellCentroid(1);
deltaYs = Ys - cellCentroid(2);
cellThetaValues = cart2pol(deltaXs, deltaYs);                          % converts contour XY coordinates into polar: just using angle
% NB: yields angles in [-pi pi], positive angles pointing downwards if image convention (Y increases toward image bottom)

%%% Calculates intensity between theta and theta+d(theta) (changed 1.3)
for p = 1:nSteps
    cellThetaValuesTF = thetaValues(p) <= cellThetaValues & cellThetaValues <= thetaValues(p+1);         % logical vector: 1 when in range, 0 otherwise (1.3)
    pthPartcellIndices = dilatedCellContourIndices(cellThetaValuesTF);                                   % indices making up tth part of cell contour within range (1.3)
    pthPartpixelIntensities = rawImage(pthPartcellIndices);                                              % gets pixel intensities at these pixels (1.1)
    meanIntensity(p) = mean(pthPartpixelIntensities);                                                     % gets mean intensity
    thetaMean(p) = (thetaValues(p)+thetaValues(p+1))/2;                                                              % stores mean theta value (last = pi-theta_step/2)
end

%%% Sorting by ascending theta:
data = [thetaMean meanIntensity];
dataSorted = sortrows(data,1);
angle = dataSorted(:,1);
meanIntensity = dataSorted(:,2); % "meanIntensity" now sorted according to increasing theta

%%% checks whether sectors are not too straight (NaN in intensity):
pNaN = find(isnan(meanIntensity)==1);
if ~isempty(pNaN)
    dataNoInt = [angle(~isnan(meanIntensity)) meanIntensity(~isnan(meanIntensity))];
    nDataNoInt = size(dataNoInt,1); % 2.1
    if nDataNoInt > 2 % interp1 requires at least two data points
        intensityInt = interp1(dataNoInt(:,1),dataNoInt(:,2),angle(pNaN));
        dataNew = [dataNoInt; angle(pNaN) intensityInt];
        dataNewSorted = sortrows(dataNew,1);
        angle = dataNewSorted(:,1);
        meanIntensity = dataNewSorted(:,2);
    end
end


%% Mode calculation (2.0) %%

A0 = 1/2*thetaStep/pi*sum(meanIntensity);           % with 1/2 factor, then corresponds to the mean intensity as thetaStep/2pi = (2pi/nSteps)*1/2pi = 1/nSteps
A1 = thetaStep/pi*sum(meanIntensity.*cos(angle));
B1 = thetaStep/pi*sum(meanIntensity.*sin(angle));
A2 = thetaStep/pi*sum(meanIntensity.*cos(2*angle));
B2 = thetaStep/pi*sum(meanIntensity.*sin(2*angle));

% NB: "meanIntensity(k)" = mean intensity value calculated between theta_values(k) and theta_values(k+1) and corresponding
% to "angle(k)= (theta_values(k)+theta_values(k+1))/2.
% NB: see switch to version 2.0 to see comments on changes and corrections made in mode calculation

%% History %%

% 23/03/2018: 2.2
% - cleaned up code
% - removed "thetaRange" that was 2*pi 

% 28/06/2017: 2.1
% - checking "data_no_int" has at least two points before interpolating because "interp1" requires that

% 04/12/2012: 2.0
% - simplified A0...B2 calculation
% Fixed issues in old way of calculating A0,...B2:
% - "theta_mean" was not a mean between two angles but just the largest one
% - intensities and angles were averaged over 2 successive values EXCEPT FOR values 1 and "end"
% - related to wrong theta_mean, angle(end) was =pi and therefore, intensity(end) NEVER contributed to A0...B2!!

% 11/08/2011: 1.4
% - drastically decreased computation time: now cell contour angles are
% ONLY COMPUTED ON ACTUAL CELL CONTOUR INSTEAD OF FULL IMAGE BEFORE!!!
% - intensity_moy -> mean_intensity

% 03/02/2011: 1.3 CHECKED AND COMPARED WITH 1.2: SAME RESULTS!
% - new input: "contour_type" = 'normal' or 'dilated'
% - drastically improved code by looking for in range theta values only
% among pixels of cell i dilated contour (and not among all image pixels!),
% and extensively using linear indices and logical vectors.

% 03/02/2011: 1.2 
%- changed name from "Cell_Polarity_Modes" to "PCP_Modes" to avoid confusion
% with a variable

% 28-31/01/2011: creation 1.0, 1.1
% - use of linear indices instead of [indx, indy] and removal of loop over k=1:size(indx,1)
% - use of "intersect" to deterimine pixels of cell dilated contour that are within theta range
% - use of outputs [A0 A1 B1 A2 B2] instead of [I0 I1 Phi1 I2 Phi2].

