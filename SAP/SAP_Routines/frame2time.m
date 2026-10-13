function time = frame2time(frame, timeRef, frameRef, dt, format)
%
% time = frame2time(frame, timeRef, frameRef, dt, format)
%
% Returns "time" (decimal or string format hh:mm) corresponding to "frame".
% NB: "frame" can be matrix, format is forced to "dec" in that case
%
% frame = current frame number to be turned into time
% timeRef = reference time (can be decimal or string ('HH:MM' format))
% frameRef = reference frame corresponding to time_ref
% dt = CORRECTED time between two frames IN MINUTES, namely ADJUSTED ACCORDING TO TEMPERATURE
% format = OUTPUT format: 'dec' or 'str'
%
% version 1.2
% Boris Guirao
% Mathieu Riviere


%% Code %%


% turns "time_ref" into decimal format if needed
if ischar(timeRef)
    timeRef = TimeStr2Dec(timeRef);
end

% determines "time" in decimal format:
time = timeRef + (frame - frameRef)*(dt/60);

% converts "time" in string format if requested:
if strcmp(format,'str') && length(frame) == 1 
    time = TimeDec2Str(time);
elseif strcmp(format,'str') && length(frame) > 1 
    disp('WARNING in frame2time: output format "str" is only possible when "frame" is scalar and was overridden to "dec"!'); % 1.1
elseif ~strcmp(format,'dec')
    disp(['ERROR in frame2time: output format (here "' num2str(format) '")  can only be "str" or "dec"!'])
    time = [];
    return
end


%% History %%

% 28/04/2016: 1.2
% - removed argument "temp" since dt is now corrected at "AIA_parameter" stage

% 16/07/2013: creation
