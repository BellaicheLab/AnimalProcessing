function [p1, p2, Pks] = ComparePolarPlots(anglesRAD1, anglesRAD2, color1, color2, binWidth, titleText)
%
% [p1, p2, Pks] = ComparePolarPlots(anglesRAD1, anglesRAD2, color1, color2, binWidth, titleText)
%
% Compares 2 distribution of angles in [-pi/2, pi/2].
%
% Version 1.3
% Boris Guirao

%% Code %%

% taking absolute values of angles
absAnglesRAD1 = abs(anglesRAD1);
absAnglesRAD2 = abs(anglesRAD2);
% Define custom Tick labels
ThetaLabels = {'0'; '30'; '60'; '90'; '60'; '30'; '0'; '-30'; '-60'; '-90'; '-60';'-30'} ;
% Using color fading (rather than transparency) for pdf generation (1.2)
fadingLow = 0.3;
fadingHigh = 0.65;

% Plotting "anglesRAD1" (color1)
absAnglesRAD1 = RemoveNaNs(absAnglesRAD1);  % removes NaNs: crucial to make sure the bin percentages add up to 100% for both animals (1.3)
p1 = polarhistogram(absAnglesRAD1,'BinWidth',binWidth,'Normalization','probability','FaceAlpha',1,'FaceColor', FadeColor(color1,fadingLow)); % 1.2
set(gca, 'ThetaTicklabel', ThetaLabels);
set(gcf, 'color', 'white');                 % 1.3
hold on
polarhistogram(-absAnglesRAD1,'BinWidth',binWidth,'Normalization','probability','FaceAlpha',1,'FaceColor', FadeColor(color1,fadingHigh)); % 1.2

% Plotting "anglesRAD2" (color2)
absAnglesRAD2 = RemoveNaNs(absAnglesRAD2); % removes NaNs: crucial to make sure the bin percentages add up to 100% for both animals (1.3)
p2 = polarhistogram(pi - absAnglesRAD2,'BinWidth',binWidth,'Normalization','probability','FaceAlpha',1,'FaceColor', FadeColor(color2,fadingLow)); % 1.2
polarhistogram(pi + absAnglesRAD2,'BinWidth',binWidth,'Normalization','probability','FaceAlpha',1,'FaceColor', FadeColor(color2,fadingHigh)); % 1.2

nAngles1 = length(absAnglesRAD1); % only using "length" now that there is no nan anymore (1.3)
nAngles2 = length(absAnglesRAD2); % 1.1

% Defining "nTex"t (1.1)
nText = ['n = ' num2str(nAngles1)];
if nAngles1 ~= nAngles2
    nText = ['n = ' num2str(nAngles1) ' & ' num2str(nAngles2)];
end

% Performing statistical test (mod 1.3):
[~,Pks] = kstest2(absAnglesRAD1, absAnglesRAD2);               % Kolmogorov-Smirnov 2-sample test (done in Nature paper)

titleFull = [titleText ' ' nText  ' (P_{ks} = ' num2str(Pks,'%.1e') ')' ]; % using "nText"
title(titleFull)

%% History %%

% 05/04/2018: 1.3
% - now removes NaNs in list of angles: crucial to make sure the bin
% percentages add up to 100% for both animals.
% - removed Kuipert's test
% - now make plot background white

% 15/03/2018: 1.2
% - Using color fading (using "FadeColor") rather than transparency for pdf
% generation that does NOT support transparency.
% - accordingly removed argument "opacity"

% 05/02/2018: 1.1
% - fixed bug where "kuiText" was not defined in regular cases
% - now displays the two values of number of data points "n" when they're
% NOT equal
% - shortened writing of "Pkui"

% 02/02/2018:
% - Not going through "circ_kuipertest" when a dataset has less than 10
% points to avoid crash in "kuiperlookup".

% 10/01/2018: creation