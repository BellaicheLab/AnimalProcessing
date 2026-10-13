function sideColor = AssignSideColor(Bocmap_sides, minThreshold, maxThreshold, lengthValue)
%
% sideColor = AssignSideColor(Bocmap_sides, minThreshold, maxThreshold, lengthValue)
%
% Use colormap "Bocmap_sides" corresponding to Matlab file
% "colormap_sides_Bo" (that must have been loaded previously)to
% attribute a color corresponding to "value".
%
% 1.0
% Boris Guirao

%% Code

if maxThreshold > minThreshold  
    if lengthValue > maxThreshold
        sideColor = Bocmap_sides(63,:);   
    elseif lengthValue < minThreshold
        sideColor = Bocmap_sides(1,:);    
    else
        % assigning a color index within [2 ; 62]:
        delta_thresholds = maxThreshold - minThreshold;
        color_index = 2 + round((lengthValue - minThreshold)/delta_thresholds * 60);
        sideColor = Bocmap_sides(color_index,:);
    end
elseif maxThreshold == minThreshold
    if lengthValue >= maxThreshold
        sideColor = Bocmap_sides(63,:);   
    elseif lengthValue < minThreshold
        sideColor = Bocmap_sides(1,:);      
    end
else
    disp('Error: max_threshold must be > or = min_threshold')
    return
end

%% History

% 11/02/2010:
% - if max_threshold == min_threshold, now side_color_RGB = Bocmap_sides(63,:);
% when length_value = max_threshold, and not the Bocmap_sides(32,:) middle value

% 10/02/2010: start