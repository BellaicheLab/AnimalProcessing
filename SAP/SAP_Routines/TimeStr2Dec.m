function timeDec = TimeStr2Dec(timeStr)
%
% timeDec = TimeStr2Dec(timeStr)
%
% Returns decimal time from string time.
% NB: "timeStr" must begin with 'HH:MM' (or 'HHhMM') and can be followed by anything ('HH:MM hAPF',...) 
%
% version 1.1
% Boris Guirao


%% check %%

if isempty(timeStr) || ~ischar(timeStr)                       % 1.1
    disp('Error in "TimeStr2Dec": argument must be a string!')
    timeDec = [];
    return
end


%% extracting time and checking format %%

% extracts:
HH = substr(timeStr,0,2);          %#ok<*ST2NM> % takes first 2 characters in time_str, namely 'HH', and turn them into a number
separator = substr(timeStr,2,1);   % takes 3rd character
MM = substr(timeStr,3,2);          % takes 4th and 5th characters in time_str (offset 3), namely 'MM', and turn them into a number

% checks format follows "HH:MM":
HH1 = str2num(substr(HH,0,1));     % empty if string cannot be converted to number
HH2 = str2num(substr(HH,1,1));
MM1 = str2num(substr(MM,0,1));
MM2 = str2num(substr(MM,1,1));

vector_check = [HH1 HH2 MM1 MM2];

% checks the string format follows HH:MM:
if ~ismember(separator,[':', 'h']) || length(vector_check) < 4
    disp('Error in "TimeStr2Dec": time must follow "HH:MM" format!')
    timeDec = [];
    return
end


%% conversion to decimal format %%

HH = str2num(HH);
MM = str2num(MM)/60;                          % fraction of hours

timeDec = HH + MM;

%% History %%

% 25/02/2014: 1.1
% - now also checks "isempty(time_str)" right at beginning (similarly to "Time_dec2str")

% 16/07/2013: creation


