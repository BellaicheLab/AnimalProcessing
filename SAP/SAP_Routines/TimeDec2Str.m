function timeStr = TimeDec2Str(timeDec,separator)
%
% timeStr = TimeDec2Str(timeDec,separator)
%
% Returns time as sting 'HHhMM' (default) or 'HH:MM' from decimal time.
% "separator" can only be ':' or 'h'.
%
% version 1.2
% Boris Guirao


%% check %%

% defining default separator or overriding wrong ones:
if nargin == 1 || ~ischar(separator)||~ismember(separator,[':', 'h'])
    separator = 'h'; 
end

if isempty(timeDec) || ~isnumeric(timeDec)
    disp('Error in "TimeDec2Str": argument must be a number')
    timeStr = [];
    return
end

%% conversion to string format %%

HH = floor(timeDec);
MM = round((timeDec - HH)*60);

% case where MM rounding up yields exactly 60 (1.2):
if MM == 60
    HH = HH + 1;
    MM = 0;   
end

timeStr = [num2str(HH,'%02d') separator num2str(MM,'%02d')];


%% History %%

% 01/03/2016: 1.2
% - fixed case where MM rounding yields 60 and strings like 35h60 => now 36h00

% 18/09/2014: 1.1
% - added optional argument "separator" that can be 'h' or ':'
% - changed default separator to 'h' from ':' since the latter creates many
% problems in the code or when naming files.

% 16/07/2013: creation