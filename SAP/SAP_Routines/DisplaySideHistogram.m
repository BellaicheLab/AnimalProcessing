function nDisplay = DisplaySideHistogram(quantityDisplay, quantityRange, quantityBin, colormap)
%
% nDisplay = DisplaySideHistogram(quantityDisplay, quantityRange, quantityBin, colormap)
%
% Function to plot lengths of chords and sides in a 3-colored histogram:
% - blue: above "quantity_range" highest value
% - green: within "quantity_range"
% - red: below "quantity_range" lowest value
%
% Version 1.1
% Boris Guirao

%% Code %%

% Checks quantity_range (1.1):
if isempty(quantityRange)
    quantity_display_nonan = quantityDisplay(~isnan(quantityDisplay));   % removes NaNs
    mean_quantity_display = mean(quantity_display_nonan);
    quantityRange = [mean_quantity_display  mean_quantity_display];
end


fig = figure('PaperPositionMode','auto');
set(fig, 'color', 'white');
nDisplay = length(quantityDisplay);
X_quantity = 0:quantityBin:ceil(max(quantityDisplay));

% bin data in 3 groups: Above, below and within thresholds:
approx_Max_quantity = round(max(quantityRange)/quantityBin) * quantityBin;
approx_Min_quantity = round(min(quantityRange)/quantityBin) * quantityBin;
quantity_display_Above = quantityDisplay(quantityDisplay >= approx_Max_quantity + quantityBin/2);
quantity_display_Below = quantityDisplay(quantityDisplay <= approx_Min_quantity - quantityBin/2);
quantity_display_Middle = quantityDisplay(quantityDisplay < approx_Max_quantity + quantityBin/2 & ...
    quantityDisplay > approx_Min_quantity - quantityBin/2);
n_values_Above = hist(quantity_display_Above,X_quantity);
n_values_Below = hist(quantity_display_Below,X_quantity);
n_values_Middle = hist(quantity_display_Middle,X_quantity);
part_I = bar(X_quantity,n_values_Above/nDisplay);
set(part_I,'FaceColor', colormap(63,:))
hold on
bar(X_quantity,n_values_Below/nDisplay, 'r');
part_II = bar(X_quantity,n_values_Middle/nDisplay);
set(part_II,'FaceColor', Color_Fade([0 1 0],0.7))

% chord count check:
n_check = length(quantity_display_Above) + length(quantity_display_Middle) + length(quantity_display_Below);
if nDisplay ~= n_check
    disp('Warning: "n_display" and "n_check" are different!')
    return
end


%% History %%

% 01/12/2010: 1.1
% - bug fix: error when quantity_range = [].

% 01/10/2010: 1.0 creation
