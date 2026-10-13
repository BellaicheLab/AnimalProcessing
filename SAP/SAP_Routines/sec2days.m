function time_str = sec2days(time_seconds) 
%
% time_str = sec2days(time_seconds) 
% 
% Converts time given in seconds into a string: Job done in Nd days Nh hours and Nm minutes.
%
% Version 1.0
% Boris Guirao

%% Code %%

% Days
time_days = time_seconds/(3600*24);
time_days_cut = floor(time_days);
remainder_days = time_days - time_days_cut;

% Hours:
time_hours = remainder_days*24;
time_hours_cut = floor(time_hours);
remainder_hours = time_hours - time_hours_cut;

% Minutes:
time_minutes = remainder_hours*60;
time_minutes_cut = round(time_minutes);

% Creates string:
time_str = ['Job done in ' num2str(time_days_cut) ' day(s) ' num2str(time_hours_cut) ' hour(s) and ' num2str(time_minutes_cut) ' minute(s).'];

%% History %%

% 27/02/2015: creation