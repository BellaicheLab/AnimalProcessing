function frame = time2frame(time, timeRef, frameRef, dt)
%
% frame = time2frame(time, timeRef, frameRef, dt)
%
% Returns "frame" (rounded to nearest tenth if non-integer) corresponding to "time".
%
% time = current time to be turned into frame number (can be decimal or string ('HH:MM' format))
% timeRef = reference time (can be decimal or string ('HH:MM' format))
% frameRef = reference frame corresponding to time_ref
% dt = CORRECTED time between two frames IN MINUTES, namely ADJUSTED ACCORDING TO TEMPERATURE
%
% version 1.1
% Boris Guirao
% Mathieu Riviere


%% Code %%


% Turns "time" into decimal format if needed:
if ischar(time)
    time = TimeStr2Dec(time);
end

% Turns "time_ref" into decimal format if needed
if ischar(timeRef)
    timeRef = TimeStr2Dec(timeRef);
end

% Determines "frame":
frame = frameRef + (time - timeRef)*(60/dt);
frame = roundn(frame,-1);                         % rounds up to 1 digit

% Inverse formula used in "frame2time":
% time = time_ref + (frame - frame_ref)*(delta_t/60);



%% History %%

% 28/04/2016: 1.1
% - removed argument "temp" since dt is now corrected at "AIA_parameter" stage

% 16/09/2014: creation
