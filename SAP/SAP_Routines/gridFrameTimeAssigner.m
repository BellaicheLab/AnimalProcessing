function [gridFrame, gridTime] = gridFrameTimeAssigner(gridTime, timeRef, frameRef, dt, startFrame, finalFrame)
%
% [gridFrame gridTime] = gridFrameTimeAssigner(gridTime,timeRef,frameRef,dt,format)
%
% In addition to an actual time, 'gridTime' can be 'start' or 'final' => this small routine will assign the actual corresponding gridTime in
% 'HHhMM' format, and gridFrame.
%
% version 1.0
% Boris Guirao

%% Code %%

gridFrame = startFrame; % default
if ~isempty(gridTime)
    if strcmp(gridTime,'start')
        gridTime = frame2time(startFrame,timeRef,frameRef,dt,'str');
        gridFrame = startFrame;
    elseif strcmp(gridTime,'final')
        gridTime = frame2time(finalFrame,timeRef,frameRef,dt,'str');
        gridFrame = finalFrame;
    else
        gridFrame = round(time2frame(gridTime, timeRef, frameRef, dt));
    end
end

%% History %%

% 20/01/2017: creation