function STATISTICS = BasicCircularStatistics(Qvalues, Qweights, Qname, categoryName, STATISTICS)
%
% STATISTICS = BasicCircularStatistics(Qvalues, Qweights, Qname, categoryName, STATISTICS)
%
%
% NB: ANGLES MUST BE IN INTERVAL [-90, 90]
%
% This will calculate basic circular statistics (circ_mean, circ_std, R,
% min, max) over "Q_values" (DEGREES) using weights "Q_weights" (default = 1) and
% store everything within structure "STATISTICS".
% NB: if "STATISTICS" is among arguments, it will be completed (not
% overwritten). If not, "STATISTICS" will be created or will overwrite the
% variable with same name in the workspace
%
% Version 1.3
% Boris Guirao

%% Defines "category_weights" %%

if isempty(Qweights)
    Qweights = ones(size(Qvalues,1),1);                                         % equal weights if "Q_weights" left empty
end

%% Statistics computation %%

% Removing NaN values:
Q_values_no_NaN = Qvalues(~isnan(Qvalues));                                     % removes NaN values from "Q_values" (1.1)
Q_weights_no_NaN = Qweights(~isnan(Qvalues));                                   % removes weights corresponding to NaN values (1.1)

mean_Q = 1/2*circ_mean(2*Q_values_no_NaN * pi/180, Q_weights_no_NaN) * 180/pi;          % CIRCULAR MEAN WEIGHTED WITH "Q_weights_no_NaN" VALUES (*2 and *1/2 in 1.3)
R_Q = circ_r(2*Q_values_no_NaN * pi/180, Q_weights_no_NaN);                             % R MEAN WEIGHTED WITH "Q_weights_no_NaN" VALUES (*2 in 1.3)
std_Q = 1/2*circ_std(2*Q_values_no_NaN * pi/180, Q_weights_no_NaN) * 180/pi;            % CIRCULAR STD WEIGHTED WITH "Q_weights_no_NaN" VALUES: std_Q = sqrt(2*(1-R_Q))(*2 and *1/2 in 1.3)
% NB: sqrt(2*(1-R)) is in [0 sqrt(2)] when working in radians, so here, since working in DEGREES, *180/pi, and to go back between [-90, 90], *1/2
min_Q = min(Q_values_no_NaN);
max_Q = max(Q_values_no_NaN);


%% Name attributions %%

Q_values_name = [Qname '_' categoryName];

mean_Q_name = ['mean_' Q_values_name];
std_Q_name = ['std_' Q_values_name];
R_Q_name = ['R_' Q_values_name];
min_Q_name = ['min_' Q_values_name];
max_Q_name = ['max_' Q_values_name];


%% Saving within structure STATISTICS %%

STATISTICS.(Q_values_name) = Qvalues;
STATISTICS.(mean_Q_name) = mean_Q;
STATISTICS.(std_Q_name) = std_Q;
STATISTICS.(R_Q_name) = R_Q;
STATISTICS.(min_Q_name) = min_Q;
STATISTICS.(max_Q_name) = max_Q;

%% History %%

% 08/02/2011: 1.3
% - fixed factors *2 and *1/2 required for angles in [-90, 90].

% 03/08/2010: 1.2
% - Now DIRECTLY takes the list of data over which statistics should be
% calculated, i.e. does not crop the list anymore (has to be done before)

% 19/07/2010: 1.1
% - removes possible NaN values before statistics calculations.

% 17/07/2010: creation