function [frameMin, frameMax] = MakeFrameIntervals(firstFrame, lastFrame, averageWidth, overlap)
%
% [frameMin, frameMax] = MakeFrameIntervals(firstFrame, lastFrame, averageWidth, overlap)
%
% Returns 2 n-columns vectors "frameMin/Max" containing actual frame numbers (integers) that define n intervals for averaging of width
% "averageWidth" in INTERFRAMES, and the spacing of which is determined by "overlap". Both lowest and highest frame numbers listed
% lie within interval [frame_start frame_stop] when "averageWidth" is an integer (movies at 25) and [frame_start-1 frame_stop+1] when it is
% not (movies at 29) (as of v1.3).
% NB: "first/last_frame" and "averageWidth" can be NON-integer numbers!! ONLY "frame_min/max" have to be integers corresponding to ACTUAL
% frame numbers.
%
% Version 1.8
% Boris Guirao
% Anais Bailles


%% Code %%

totalInterframeWidth = lastFrame - firstFrame; % NOT frame width, but interframe width: ex: frame range = [1 3], interframe width = 3-1 = 2, frame width = 3-1 +1

% Tests on "averageWidth" (mod 1.5,1.7):
if averageWidth == 0    % case of NO averaging (1.7)
    disp(['"FrameIntervalMaker" WARNING: averaging parameter "averageWidth" (' num2str(averageWidth) ') corresponds to NO averaging!']);
    frameMin = (firstFrame:lastFrame)';
    frameMax = frameMin;
    return
    
elseif averageWidth < 0
    disp(['"FrameIntervalMaker" ERROR: averaging parameter "averageWidth" (' num2str(averageWidth) ') is negative!']);
    disp('Please select a larger time width for averaging.');
    return   
    
elseif averageWidth == 1
    disp(['"FrameIntervalMaker" WARNING: averaging parameter "averageWidth" (' num2str(averageWidth)...
        ') corresponds to one interframe!'])
    
elseif averageWidth > totalInterframeWidth*1.0000001 % 1.8
    disp(['"FrameIntervalMaker" ERROR: averaging parameter "averageWidth" (' num2str(averageWidth) ') is larger than the specified frame range (' num2str(firstFrame) '-' num2str(lastFrame) ' = ' num2str(totalInterframeWidth)  ' interframes)!']);
    disp('Either decrease "averageWidth" or increase the frame range.');
    return
end

% Determining frame numbers for average (mod 1.3):
Lmax = totalInterframeWidth;                    % maximal possible length of frame interval
W = averageWidth;                          % average width in INTERFRAMES
S = W*(1-overlap);                          % distance between 2 "framepoints" (step)

% Determining number of segments to plot (1.3):
ndec = 1+(Lmax-W)/S;                            % DECIMAL number of segments of length S that can fit in Lmax.
nr = round(ndec);                               % NEAREST number of segments of length S that can fit in Lmax.
nf = floor(ndec);                               % MAXIMAL number of COMPLETE segments of length S that can fit in Lmax. NB: nmax >=1 since W <= interframe_width
n = nr;
L = W+(n-1)*S;                                  % ACTUAL interframe length covered by nr segments of length S
R = Lmax - L;                                   % remainder, namely length NOT covered. NB: could be negative when nr > ndec!
if R < -2 || isintegerBo(averageWidth)         % IF offset is larger than 2 frames OR "averageWidth" is integer, ie processing movie @25�
    n = nf;                                     % => using nf instead of nr
    L = W+(n-1)*S;                              % ACTUAL length covered by nf segments of length S
    R = Lmax - L;                               % R becomces > 0
elseif R < 0                                    % overrun smaller than 2 frames is accepted
    disp(['FrameIntervalMaker WARNING: frame ranges go beyond specified range [' num2str(firstFrame) ' ' num2str(lastFrame) '] by less than 2 frames to avoid loosing the average on an almost full segment!']);
end

% OLD:
%---------------------------------------------------------------------------------------------------------------------
% Lmax = frame_range;                         % maximal possible length of frame interval
% W = interframe_width;                       % interframe width
% S = interframe_width*(1-overlap);           % distance between 2 "framepoints" (step)
% nmax = 1 + floor((Lmax-W)/S);               % MAXIMAL number of complete segment of length S that can fit in Lmax
% L =  W + (nmax-1)*S;                        % ACTUAL length covered
% R = Lmax - L;                               % remainder, namely length NOT covered         

% Going back to frame nubmers:
Vframepoint_start = firstFrame + R/2;                                  % first virtual frame point
Vframepoints = Vframepoint_start: S : Vframepoint_start + (n-1)*S;      % all virtual frame points

frameMin = round(Vframepoints)';                               % rounding up values so they correspond to  actual frame numbers
frameMax = frameMin + round(averageWidth);                   % defines corresponding "frame_max" vector accordingly

% Commented in 1.6
% -----------------------------------------------------------------------
% if frame_max(n) > last_frame                              % checks that rounding to nearest integer did not pushed frame_max beyon limit
%     frame_min = floor(Vframepoints)';                     % if it did, reround all values to lowest integers
%     frame_max = frame_min + round(averageWidth);         % updates frame_max accordingly
% end
% 
% % if frame_min(1) dropped to 0, putting it back to 1 (1.3)
% if frame_min(1)<1
%     frame_min(1) = 1;
% end
% -----------------------------------------------------------------------

%% Explanation %%

% Let's call
% F = frame range: total range available to calculate average
% L = total length of coverage in interframes
% W = average width, number of INTERframes over which average is calculated
% S = step between two "framepoints" at which area is calculated
% n = number of complete segment that can fit
%
% One has: L = W/2 + (n-1)*S + W/2 = W + (n-1)*S
% Indeed, around each step, the average is done over W, so there is +/-W/2 reach aroud each step, hence the two W/2 terms
% Check that when n=1, one indeed has: L = W
% To determine the largest number of segment that can fit, take:
% L = Lmax = F => nmax = 1 + floor((Lmax-W)/S)
% Actual length covered: L = = W + (nmax-1)*S
% Remainder : R = Lmax - L


end

%% History %%

% 15/06/2018: 1.8
% - added "*1.0000001" factor to fix bug with "wt29c4" movie (1.8)

% 02/03/2018: 1.7
% - support cases where "averageWidth" = 0, namely no time averging is
% being made

% 23/05/2016: 1.6 
% - allowing negative and beyond limit frame values => commented parts recalulating "frame_min" when beyond "last_frame" and putting
% frame_min back to 1 if was <1

% 01/04/2015: 1.5
% - now allows averages over 1 interframe and display a warning rather than an error

% ??/2015: 1.4

% 22/01/2015: 1.3
% - fixed bug that was removing a segment of average even though the specified range was exaclty corresponding (Ex: TRBL4 average over 4h between 14h and 26h)
% - when "averageWidth" is not an integer (29� movies), now allowing the program to select up to one frame before and after the specified range

% 12/10/2014: 1.2
% - finally wrote proper code to best cover the available frame range without going beyond

% 22/09/2014: 1.1
% - minor changes: renamed some variables, added comments

% 19/09/2014: creation
% NB: total overhaul of first version since Anais restarted it from her own function ("Time_Point_Dealer")