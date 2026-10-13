function STATISTICS = BasicStatistics(Qvalues, Qname, categoryName, STATISTICS)
%
% STATISTICS = BasicStatistics(Qvalues, Qname, categoryName, STATISTICS)
%
% This will calculate basic statistics (mean, std,min, max) over "Q_values"
% and store everything within structure "STATISTICS".
% Ex: Basic_Statistics(cell_areas_CC, 'area', 'CC', cell_STATISTICS)

% NB: if "STATISTICS" is among arguments, it will be completed (not
% overwritten). If not, "STATISTICS" will be created or will overwrite the
% variable with same name in the workspace
%
% Version 1.3
% Boris Guirao

%% Statistics computation %%

% Removing NaN values:
no_NaN_lines = all(~isnan(Qvalues), 2);                          % determines LINES without ANY NaN (1.2)
Q_values_no_NaN = Qvalues(no_NaN_lines,:);                       % removes NaN values from "Q_values" (1.1)

mean_Q = mean(Q_values_no_NaN, 1);                                % (mod 1.2)
std_Q = std(Q_values_no_NaN,0, 1);                                % specifies flag=0 (1.2)
min_Q = min(Q_values_no_NaN,[], 1);                               % (mod 1.2)
max_Q = max(Q_values_no_NaN,[], 1);                               % (mod 1.2)

%% Name attributions %%

Q_values_name = [Qname '_' categoryName];

mean_Q_name = ['mean_' Q_values_name];
std_Q_name = ['std_' Q_values_name];
min_Q_name = ['min_' Q_values_name];
max_Q_name = ['max_' Q_values_name];

%% Saving within structure STATISTICS %%

STATISTICS.(Q_values_name) = Qvalues;
STATISTICS.(mean_Q_name) = mean_Q;
STATISTICS.(std_Q_name) = std_Q;
STATISTICS.(min_Q_name) = min_Q;
STATISTICS.(max_Q_name) = max_Q;

%% History %%

% 03/08/2010: 1.3
% - Now DIRECTLY takes the list of data over which statistics should be
% calculated, i.e. does not crop the list anymore (has to be done before)

% 25/07/2010: 1.2
% - Q_all_values can have several columns now; mean, std... done for each
% columns over all rows.

% 19/07/2010: 1.1
% - removes possible NaN values before statistics calculations.

% 17/07/2010: creation