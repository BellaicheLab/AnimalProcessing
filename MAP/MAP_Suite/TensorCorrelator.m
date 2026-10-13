function [Eta, Slope, err] = Tensor_Correlator(TENSORS,FIT,PLOT,path_out)
% Tensor_Correlator
% Plot correlations between two tensors 2x2 (I, M, V...), vectors or scalar
%
% version 3.4
% Anais Bailles & Stephane Rigaud
%


dir = [path_out '\Plots\'];
if ~exist(dir,'dir')
    mkdir(dir);
end

plot_extension = ['.' PLOT.extension];

%% Estimate the objects to be correlated
format = iscell(TENSORS.in_x_axis); % test format of input data
if ~format
    % NOTE: To improve in order to remove the use of Index and time_scale    
    delta_t = 5;
    temp = 25;
    startFrame = (TENSORS.in_x_axis.FrameArray(1,1) + TENSORS.in_x_axis.FrameArray(1,2))   ./ 2;
    endFrame   = (TENSORS.in_x_axis.FrameArray(end,1) + TENSORS.in_x_axis.FrameArray(end,2)) ./ 2;
    startAPF   = round( frame2time(startFrame,TENSORS.in_x_axis.TimeArray{1,1},TENSORS.in_x_axis.FrameArray(1,1),delta_t,'dec') );
    endAPF     = round( frame2time(endFrame,TENSORS.in_x_axis.TimeArray{1,1},TENSORS.in_x_axis.FrameArray(1,1),delta_t,'dec') );

    Time = [startAPF:endAPF];
    N = length(TENSORS.in_x_axis.FrameArray);
    Index = [1:N];
    
%     N = length(Index) ; % number of pictures
    eval(['dim = size( TENSORS.in_x_axis.' TENSORS.in_x_axis_data ',3);']);
    if dim ~= 2 && dim ~= 4
        dim = 1;
    end
else
    disp('input are cell array, this does not work');
    return
end

if dim==1 && FIT.tf_T_dev == 1;
    disp('Object is a scalar : only one value will be plotted.')
    FIT.tf_T_iso = 1;
    FIT.tf_T_dev = 0;
end
if dim==2 && FIT.tf_T_dev == 1;
    isp('Object is a vector : only two values will be plotted.')
    FIT.tf_T_iso = 0;
    FIT.tf_T_dev = 1;
end
if FIT.tf_T_iso == 0 && FIT.tf_T_dev == 0
    disp ( 'You are asking for an empy plot !')
    return %break
end


%% Storing data

% Initiate memory array
X_red = cell(1,N);       % Defined as X_xx + X_yy , i.e. trace(X)
Y_red = cell(1,N);       % Defined as Y_xx + Y_yy , i.e. trace(Y)
X_green = cell(1,N);     % Defined as X_xx - X_yy , i.e. deviatoric part of X #1
Y_green = cell(1,N);     % Defined as Y_xx - Y_yy , i.e. deviatoric part of Y #1
X_blue = cell(1,N);      % Defined as X_xy , i.e. deviatoric of X #2
Y_blue = cell(1,N);      % Defined as Y_xy , i.e. deviatoric part of Y #2
% Weight = cell(1,N); % Defined as ratio of cells total area over grid element area
DEVweight = cell(1,N); % Defined as ratio of cells total area over grid element area
ISOweight = cell(1,N); % Defined as ratio of cells total area over grid element area

X_XYs = eval(['TENSORS.in_x_axis.' TENSORS.in_x_axis_data]);
Y_XYs = eval(['TENSORS.in_y_axis.' TENSORS.in_y_axis_data]);

if PLOT.significance % (3.5)
    [~,marker1] = ismember('_',TENSORS.in_x_axis_data);
    [~,marker2] = ismember('_',TENSORS.in_y_axis_data);
    if isfield(TENSORS.in_x_axis,[ TENSORS.in_x_axis_data(1:marker1-1) '_Smap' ] ) && ...
            isfield(TENSORS.in_y_axis,[ TENSORS.in_y_axis_data(1:marker2-1) '_Smap' ] )
        stdX_XYs = eval(['TENSORS.in_x_axis.' TENSORS.in_x_axis_data(1:marker1-1) '_Smap']);
        stdY_XYs = eval(['TENSORS.in_y_axis.' TENSORS.in_y_axis_data(1:marker2-1) '_Smap']);
    else
        PLOT.significance = 0;
        disp('No std field provided in TENSORS for one of the value to compare ...');
    end
end


[~,marker1] = ismember('c',TENSORS.in_x_axis_data);
[~,marker2] = ismember('_',TENSORS.in_x_axis_data);
if marker1 > 0
    TQname1 = TENSORS.in_x_axis_data(1:marker1-1);
    TQname2 = TENSORS.in_x_axis_data(marker1+1:marker2-1);
    [TPname1,~] = GetPname(TQname1);
    [TPname2,~] = GetPname(TQname2);
    Areas_ratio_x = min( eval(['TENSORS.in_x_axis.AreaRatios_' TPname1 ';']), eval(['TENSORS.in_x_axis.AreaRatios_' TPname2 ';']) );
    if strcmp(TPname1,'TA') || strcmp(TPname2,'TA')
        Areas_ratio_x = Areas_ratio_x .* TENSORS.in_x_axis.RConds;
    end
else
    [TPname,~] = GetPname(TENSORS.in_x_axis_data);
    if isempty(TPname)
        TPname = 'AOS';
    end
    
    Areas_ratio_x = eval(['TENSORS.in_x_axis.AreaRatios;']);  % Remove empty elements in areas ratio values and shape as a vector
%     if strcmp(TPname,'TA')
        Areas_ratio_x = Areas_ratio_x .* TENSORS.in_x_axis.RConds;
%     end
end
Areas_ratio_x = Areas_ratio_x .^ 2;
        

[~,marker1] = ismember('c',TENSORS.in_y_axis_data);
[~,marker2] = ismember('_',TENSORS.in_y_axis_data);
if marker1 > 0
    TQname1 = TENSORS.in_y_axis_data(1:marker1-1);
    TQname2 = TENSORS.in_y_axis_data(marker1+1:marker2-1);
    [TPname1,~] = GetPname(TQname1);
    [TPname2,~] = GetPname(TQname2);
    Areas_ratio_y = min( eval(['TENSORS.in_y_axis.AreaRatios_' TPname1 ';']), eval(['TENSORS.in_y_axis.AreaRatios_' TPname2 ';']) );
    if strcmp(TPname1,'TA') || strcmp(TPname2,'TA')
        Areas_ratio_y = Areas_ratio_y .* TENSORS.in_y_axis.RConds;
    end
else
    
    
    
    [TPname,~] = GetPname(TENSORS.in_y_axis_data);
    if isempty(TPname)
        TPname = 'AOS';
    end
    
    Areas_ratio_y = eval(['TENSORS.in_y_axis.AreaRatios;']);  % Remove empty elements in areas ratio values and shape as a vector
%     if strcmp(TPname,'TA')
        Areas_ratio_y = Areas_ratio_y .* TENSORS.in_y_axis.RConds;
%     end
end
Areas_ratio_y = Areas_ratio_y .^ 2;






nbElements = TENSORS.in_x_axis.size(1) * TENSORS.in_x_axis.size(2);
epsilon = TENSORS.epsilon;

% Devide data by its norm if asked
if isfield(TENSORS,'norm_axis')
    if sum(TENSORS.norm_axis) > 0
        for t=1:size(Y_XYs,4)
            for x=1:size(Y_XYs,2)
                for y=1:size(Y_XYs,1)
                    if TENSORS.norm_axis(1)
                        X_XYs(y,x,:,t) = X_XYs(y,x,:,t) ./ TensorNorm(Vec2Mat(X_XYs(y,x,:,t)));
                    end
                    if TENSORS.norm_axis(2)
                        Y_XYs(y,x,:,t) = Y_XYs(y,x,:,t) ./ TensorNorm(Vec2Mat(Y_XYs(y,x,:,t)));
                    end
                end
            end
        end
    end
end

% Data reshape, normalisation, and storage for each time
for h = 1:N
    
    ind = Index(h);
    
    % Reshape, remove 0 weighted values, and store in cell array
    Weight{1,h} = reshape( ( Areas_ratio_x(:,:,ind) .* Areas_ratio_y(:,:,ind) ).^2 , [nbElements, 1] );

    % split data
    if dim == 4 % tensor
        % Mxx+Myy vs Ixx+Iyy (red) i.e. Trace
        X_red{1,h} = reshape(X_XYs(:,:,1,ind) +  X_XYs(:,:,4,ind), [nbElements,1] );
        Y_red{1,h} = reshape(epsilon(1)*Y_XYs(:,:,1,ind) +  epsilon(4)*Y_XYs(:,:,4,ind), [nbElements,1] );
        
        % Mxx-Myy vs Ixx-Iyy (green) i.e deviatoric part #1
        X_green{1,h} = reshape(X_XYs(:,:,1,ind) - X_XYs(:,:,4,ind), [nbElements,1] );
        Y_green{1,h} = reshape(epsilon(1)*Y_XYs(:,:,1,ind) - epsilon(4)*Y_XYs(:,:,4,ind), [nbElements,1] );
        
        % Mxy vs Ixy (blue) i.e deviatoric part #2
        X_blue{1,h} = reshape(X_XYs(:,:,2,ind), [nbElements,1] );
        Y_blue{1,h} = reshape(epsilon(2)*Y_XYs(:,:,2,ind), [nbElements,1] );
        
        
        if PLOT.significance % (3.5)
            isoSignificance = and( reshape(stdX_XYs(:,:,1,ind), [nbElements,1] ), reshape(stdY_XYs(:,:,1,ind), [nbElements,1] ));
            devSignificance = and( reshape(stdX_XYs(:,:,2,ind), [nbElements,1] ), reshape(stdY_XYs(:,:,2,ind), [nbElements,1] ));
        else
            isoSignificance = ones(size(Weight{1,h}));
            devSignificance = ones(size(Weight{1,h}));
        end
        
        keepISO = and( (Weight{1,h} > 0), isoSignificance );
        keepDEV = and( (Weight{1,h} > 0), devSignificance );
        ISOweight{1,h} = Weight{1,h}( keepISO );
        DEVweight{1,h} = Weight{1,h}( keepDEV );
        
        X_red{1,h} = X_red{1,h}(keepISO);
        Y_red{1,h} = Y_red{1,h}(keepISO);
        X_green{1,h} = X_green{1,h}(keepDEV);
        Y_green{1,h} = Y_green{1,h}(keepDEV);
        X_blue{1,h} = X_blue{1,h}(keepDEV);
        Y_blue{1,h} = Y_blue{1,h}(keepDEV);
        
        
        if PLOT.normalise
            % STD computation (3.4)
            XisoSTDnorm = UWStd(X_red{1,h},ISOweight{1,h});
            YisoSTDnorm = UWStd(Y_red{1,h},ISOweight{1,h});
            XdevSTDnorm = sqrt(UWStd(X_green{1,h},DEVweight{1,h}).^2 + (UWStd(X_blue{1,h},DEVweight{1,h}).^2).*4);
            YdevSTDnorm = sqrt(UWStd(Y_green{1,h},DEVweight{1,h}).^2 + (UWStd(Y_blue{1,h},DEVweight{1,h}).^2).*4);
            % Normalisation [ X - mean(X) ] / std(X) (3.4)
            X_red{1,h}   = (X_red{1,h}   - mean(X_red{1,h}))   ./ XisoSTDnorm;
            Y_red{1,h}   = (Y_red{1,h}   - mean(Y_red{1,h}))   ./ YisoSTDnorm;
            X_green{1,h} = (X_green{1,h} - mean(X_green{1,h})) ./ XdevSTDnorm;
            Y_green{1,h} = (Y_green{1,h} - mean(Y_green{1,h})) ./ YdevSTDnorm;
            X_blue{1,h}  = (X_blue{1,h}  - mean(X_blue{1,h}))  ./ XdevSTDnorm;
            Y_blue{1,h}  = (Y_blue{1,h}  - mean(Y_blue{1,h}))  ./ YdevSTDnorm;
        end
        
    elseif dim == 1 % scalar
        % Mxx+Myy vs Ixx+Iyy (red) i.e. Trace
        X_red{1,h} =  reshape(X_XYs(:,:,1,ind), [nbElements,1] );
        Y_red{1,h} =  reshape(epsilon(1)*Y_XYs(:,:,1,ind), [nbElements,1] );
        
        if PLOT.significance % (3.5)
            isoSignificance = and( reshape(stdX_XYs(:,:,1,ind), [nbElements,1] ), reshape(stdY_XYs(:,:,1,ind), [nbElements,1] ));
        else
            isoSignificance = ones(size(Weight{1,h}));
        end
        
        keepISO = and( (Weight{1,h} > 0), isoSignificance );
        ISOweight{1,h} = Weight{1,h}( keepISO );
        
        X_red{1,h} = X_red{1,h}(keepISO);
        Y_red{1,h} = Y_red{1,h}(keepISO);
        
        if PLOT.normalise
            % STD computation (3.4)
            XisoSTDnorm = UWStd(X_red{1,h},ISOweight{1,h});
            YisoSTDnorm = UWStd(Y_red{1,h},ISOweight{1,h});
            % Normalisation [ X - mean(X) ] / std(X) (3.4)
            X_red{1,h} = (X_red{1,h} - mean(X_red{1,h})) ./ XisoSTDnorm;
            Y_red{1,h} = (Y_red{1,h} - mean(Y_red{1,h})) ./ YisoSTDnorm;
        end
        
    elseif dim == 2 % vector
        % Mxx-Myy vs Ixx-Iyy (green) i.e deviatoric part #1
        X_green{1,h} = reshape(X_XYs(:,:,1,ind), [nbElements,1] );
        X_green{1,h} =  X_green{1,h}( keep );
        Y_green{1,h} = reshape(epsilon(1)*Y_XYs(:,:,1,ind), [nbElements,1] );
        Y_green{1,h} =  Y_green{1,h}( keep );
        
        % Mxy vs Ixy (blue) i.e deviatoric part #2
        X_blue{1,h} = reshape(X_XYs(:,:,2,ind), [nbElements,1] );
        X_blue{1,h} =  X_blue{1,h}( keep );
        Y_blue{1,h} = reshape(epsilon(2)*Y_XYs(:,:,2,ind), [nbElements,1] );
        Y_blue{1,h} =  Y_blue{1,h}( keep );
        
        if PLOT.significance % (3.5)
            devSignificance = and( reshape(stdX_XYs(:,:,2,ind), [nbElements,1] ), reshape(stdY_XYs(:,:,2,ind), [nbElements,1] ));
        else
            devSignificance = ones(size(Weight{1,h}));
        end
        
        keepDEV = and( (Weight{1,h} > 0), devSignificance );
        DEVweight{1,h} = Weight{1,h}( keepDEV );
        
        X_green{1,h} = X_green{1,h}(keepDEV);
        Y_green{1,h} = Y_green{1,h}(keepDEV);
        X_blue{1,h} = X_blue{1,h}(keepDEV);
        Y_blue{1,h} = Y_blue{1,h}(keepDEV);
        
        if PLOT.normalise
            % STD computation (3.4)
            XdevSTDnorm = sqrt(UWStd(X_green{1,h},DEVweight{1,h}).^2 + (UWStd(X_blue{1,h},DEVweight{1,h}).^2).*4);
            YdevSTDnorm = sqrt(UWStd(Y_green{1,h},DEVweight{1,h}).^2 + (UWStd(Y_blue{1,h},DEVweight{1,h}).^2).*4);
            % Normalisation [ X - mean(X) ] / std(X) (3.4)
            X_green{1,h} = (X_green{1,h} - mean(X_green{1,h})) ./ XdevSTDnorm;
            Y_green{1,h} = (Y_green{1,h} - mean(Y_green{1,h})) ./ YdevSTDnorm;
            X_blue{1,h}  = (X_blue{1,h}  - mean(X_blue{1,h}))  ./ XdevSTDnorm;
            Y_blue{1,h}  = (Y_blue{1,h}  - mean(Y_blue{1,h}))  ./ YdevSTDnorm;
        end
    end
    
end

if PLOT.eachTime
    t_tot = N;
else
    t_tot = 1;
end

for t=1:t_tot
    
    
    %% Test and reshape data
    % Reshape X and Y values
    if FIT.tf_T_iso
        if PLOT.eachTime
            x_red = X_red{:,t};
            y_red = Y_red{:,t};
        else
            x_red = cell2mat(X_red.');
            y_red = cell2mat(Y_red.');
        end
    else
        x_red = [];
        y_red = [];
    end
    
    if FIT.tf_T_dev
        if PLOT.eachTime
            
            x_green = X_green{:,t};
            y_green = Y_green{:,t};
            x_blue = X_blue{:,t};
            y_blue = Y_blue{:,t};
        else
            x_green = cell2mat(X_green.');
            y_green = cell2mat(Y_green.');
            x_blue = cell2mat(X_blue.');
            y_blue = cell2mat(Y_blue.');
        end
    else
        x_green = [];
        y_green = [];
        x_blue = [];
        y_blue = [];
    end
    
    x_tot = [x_red ; x_green ; x_blue]; % vector containing all x values
    y_tot = [y_red ; y_green ; y_blue]; % vector containing all y values
    
    % Reshape areas_ration values
    if PLOT.eachTime
        ISOweight_temp = ISOweight{:,t};
        DEVweight_temp = DEVweight{:,t};
    else
        ISOweight_temp = cell2mat(ISOweight.');
        DEVweight_temp = cell2mat(DEVweight.');
    end
    
    if FIT.tf_T_dev && FIT.tf_T_iso
        weight_tot = [ISOweight_temp ; DEVweight_temp ; DEVweight_temp]; % Vector containing all areas_ratio values
    elseif FIT.tf_T_dev
        weight_tot = [DEVweight_temp ; DEVweight_temp]; % Vector containing all areas_ratio values
    else
        weight_tot = ISOweight_temp; % Vector containing all areas_ratio values
    end
    
    
    
    
    %% Linear Fit
    % best fit with Matlab function
    % k = polyfit(x_tot, y_tot , FIT.degree);
    
    % best fit constrained to pass through (0,0) (Matlab Central)
    % k_0 = polyfitZero(x_tot, y_tot, FIT.degree);
    
    % polynomial fit A (X,Y)
    % best fit constrained to pass through (0,0) with FIT.points weighted by the surfaces ratio (Matlab Central)
    if isempty(FIT.slope) && isempty(FIT.point)
        k_0_weighted_A = mmpolyfit(x_tot, y_tot, FIT.degree, 'Weight', weight_tot);
    elseif isempty(FIT.slope)
        k_0_weighted_A = mmpolyfit(x_tot, y_tot, FIT.degree, 'Weight', weight_tot ,'Point', FIT.point);
    elseif isempty(FIT.point)
        k_0_weighted_A = mmpolyfit(x_tot, y_tot, FIT.degree, 'Weight', weight_tot ,'Slope', FIT.slope);
    else
        k_0_weighted_A = mmpolyfit(x_tot, y_tot, FIT.degree, 'Weight', weight_tot ,'Point', FIT.point,'Slope', FIT.slope);
    end
    % Confidence for each value of k
    rsq_0_weighted_A = R2_value(x_tot, y_tot, k_0_weighted_A, weight_tot); % coefficient of determination R squared constrained to (0,0) and weighted
    % r_xy Bravais Pearson
    r_xy_A = sum(weight_tot.*(x_tot - mean(x_tot)).*(y_tot - mean(y_tot)))/sqrt(sum(weight_tot.*(x_tot- mean(x_tot)).^2) * sum(weight_tot.*(y_tot- mean(y_tot)).^2) );
    
    % polynomial fit B (Y,X) (3.4)
    % best fit constrained to pass through (0,0) with FIT.points weighted by the surfaces ratio (Matlab Central)
    if isempty(FIT.slope) && isempty(FIT.point)
        k_0_weighted_B = mmpolyfit(y_tot, x_tot, FIT.degree, 'Weight', weight_tot);
    elseif isempty(FIT.slope)
        k_0_weighted_B = mmpolyfit(y_tot, x_tot, FIT.degree, 'Weight', weight_tot ,'Point', FIT.point);
    elseif isempty(FIT.point)
        k_0_weighted_B = mmpolyfit(y_tot, x_tot, FIT.degree, 'Weight', weight_tot ,'Slope', FIT.slope);
    else
        k_0_weighted_B = mmpolyfit(y_tot, x_tot, FIT.degree, 'Weight', weight_tot ,'Point', FIT.point,'Slope', FIT.slope);
    end
    % Confidence for each value of k
    rsq_0_weighted_B = R2_value(y_tot, x_tot, k_0_weighted_B, weight_tot); % coefficient of determination R squared constrained to (0,0) and weighted
    % r_xy Bravais Pearson
    r_xy_B = sum(weight_tot.*(y_tot - mean(y_tot)).*(x_tot - mean(x_tot)))/sqrt(sum(weight_tot.*(y_tot- mean(y_tot)).^2) * sum(weight_tot.*(x_tot- mean(x_tot)).^2) );
    
    
    %% Inertia matrix
    I = zeros(1,4);
    x_center_of_mass = mean(x_tot .* weight_tot);
    y_center_of_mass = mean(y_tot .* weight_tot);
    
    % Fills inertia matrix
    if sum(weight_tot) ~= 0
        I(1,1) = sum( ((x_tot - x_center_of_mass).^2) .* weight_tot) / sum(weight_tot);
        I(1,2) = sum( ((x_tot - x_center_of_mass) .* (y_tot - y_center_of_mass)) .* weight_tot) / sum(weight_tot);
        I(1,3) = I(2);
        I(1,4) = sum( ((y_tot - y_center_of_mass).^2) .* weight_tot) / sum(weight_tot);
    end
    % Determines eigen values & vectors and sort them
    TD = TensorData(I);
    % Computation of inertia anisotropy
    eta = 1 - sqrt( TD.Es(2) / TD.Es(1) );
    % Computation of the ellipse major axis slope (3.4)
    ellipse_angle = tan( degtorad(TD.Angles(1)) );
    
    
    %% Error
    reference = (x_tot + y_tot) ./ 2;
    error = (x_tot - y_tot) ./ 2;
    var_error = var(error, weight_tot); % renormaliser par somme des poids ?
    err = sqrt(sum((error.^2).*weight_tot)/sum(weight_tot)) / sqrt(sum((reference.^2).*weight_tot)/sum(weight_tot));
    
    
    %% Plot
    if PLOT.plot
        
        figure(1)
        % Define axes (3.4)
        if isfield(PLOT,'axesRange') && ~isempty(PLOT.axesRange)
            axis(PLOT.axesRange * 1.1);
            leg_position_x = PLOT.axesRange(2)*0.5;
            leg_position_y = PLOT.axesRange(3)*0.5;
            xmin = PLOT.axesRange(1);
            xmax = PLOT.axesRange(2);
            ymin = PLOT.axesRange(3);
            ymax = PLOT.axesRange(4);
            axis square;
        else
%             axis equal;
            axis normal;

            leg_position_x = max(x_tot)*0.5;
            leg_position_y = min(y_tot)*0.5;
            xmin = min(x_tot) * 1.2;
            xmax = max(x_tot)* 1.2;
            ymin = min(y_tot)* 1.2;
            ymax = max(y_tot)* 1.2;
        end
        hold on
        
        % Plot all tensor parts
        scale_factor = (max(y_tot)-min(y_tot)) / (max(x_tot)-min(x_tot));
        if FIT.tf_T_iso == 1
            scatter_patches(x_red,y_red,PLOT.pointSize, [1,0,0],'FaceAlpha',ISOweight_temp*PLOT.opacityMax,'EdgeColor','none');
%             transparentScatter( x_red, y_red, PLOT.pointSize, [1,0,0], ISOweight_temp*PLOT.opacityMax, scale_factor); % plot data cloud in red
        end
        if FIT.tf_T_dev == 1
            scatter_patches(x_green,y_green,PLOT.pointSize, [0,1,0],'FaceAlpha',DEVweight_temp*PLOT.opacityMax,'EdgeColor','none');
            scatter_patches(x_blue,y_blue,PLOT.pointSize, [0,0,1],'FaceAlpha',DEVweight_temp*PLOT.opacityMax,'EdgeColor','none');
%             transparentScatter( x_green, y_green, PLOT.pointSize, [0,1,0], DEVweight_temp*PLOT.opacityMax, scale_factor); % plot data cloud in green
%             transparentScatter( x_blue, y_blue, PLOT.pointSize, [0,0,1], DEVweight_temp*PLOT.opacityMax, scale_factor); % plot data cloud in blue
        end
        
        % Plot data fit
        x = xmin:(xmax-xmin)/10:xmax;
        line( x, polyval(k_0_weighted_A, x), 'Color', [0.45 0.45 0.45], 'LineWidth', 0.75 )
        y = ymin:(ymax-ymin)/10:ymax;
        line( polyval(k_0_weighted_B, y),y, 'Color', [0.65 0.65 0.65], 'LineWidth', 0.75 )
        
        % Plot data inertia matrix
        TDISPLAY.PlotType = 'merged';
        TDISPLAY.Qsr = 1;
        TDISPLAY.LineWidth = 1.5;
        TDISPLAY.SignOpacities = 1;                 % goes to 0 (100% transparency) when weight = 0 (1.4)
        TDISPLAY.LineOpacity = 1;
        TDISPLAY.LineColor = [0.9 0.9 0.9];
        TDISPLAY.LineWidth = 0.75;
        TDISPLAY.EVStyles = {'-' '-'};
        %         cat, space_x, scale_ratio, color, line_width, point_size, font_size, EV_styles, sign_opacities, plot_type)
        %         'none', [], 1, [0.9 0.9 0.9], 1.5, 1, 1, {'-' '-'}, [0.5 0.5], 'merged'
        TensorPlotter(sqrt(TD.Es), [x_center_of_mass y_center_of_mass], TD.Angles, TDISPLAY);
        
        % Display
        if dim == 4
            if FIT.tf_T_iso == 1 && FIT.tf_T_dev == 1
                leg = legend( [ num2str(TENSORS.epsilon(1)) '*' TENSORS.str_y_axis '_{xx} + ' num2str(TENSORS.epsilon(4)) '*' TENSORS.str_y_axis '_{yy} vs ' TENSORS.str_x_axis '_{xx} + ' TENSORS.str_x_axis '_{yy}'], ...
                              [ num2str(TENSORS.epsilon(1)) '*' TENSORS.str_y_axis '_{xx} - ' num2str(TENSORS.epsilon(4)) '*' TENSORS.str_y_axis '_{yy} vs ' TENSORS.str_x_axis '_{xx} - ' TENSORS.str_x_axis '_{yy}'], ...
                              [ num2str(TENSORS.epsilon(2)) '*' TENSORS.str_y_axis '_{xy} vs ' TENSORS.str_x_axis '_{xy}']);
            elseif FIT.tf_T_iso == 1
                leg = legend( [ num2str(TENSORS.epsilon(1)) '*' TENSORS.str_y_axis '_{xx} + ' num2str(TENSORS.epsilon(4)) '*' TENSORS.str_y_axis '_{yy} vs ' TENSORS.str_x_axis '_{xx} + ' TENSORS.str_x_axis '_{yy}'] );
            else
                leg = legend( [ num2str(TENSORS.epsilon(1)) '*' TENSORS.str_y_axis '_{xx} - ' num2str(TENSORS.epsilon(4)) '*' TENSORS.str_y_axis '_{yy} vs ' TENSORS.str_x_axis '_{xx} - ' TENSORS.str_x_axis '_{yy}'], ...                                          
            [ num2str(TENSORS.epsilon(2)) '*' TENSORS.str_y_axis '_{xy} vs ' TENSORS.str_x_axis '_{xy}']);
            end
        elseif dim == 1
            leg = legend( [num2str(TENSORS.epsilon) '*' TENSORS.str_y_axis ' vs ' TENSORS.str_x_axis] );
        elseif dim == 2
            leg = legend( [ num2str(TENSORS.epsilon(1)) '*' TENSORS.str_y_axis '_{x} vs ' TENSORS.str_x_axis '_{x}'], ...
                          [ num2str(TENSORS.epsilon(2)) '*' TENSORS.str_y_axis '_{y} vs ' TENSORS.str_x_axis '_{y}']);
        end
        set(leg,'Location','Northoutside');
        klabel = {['Polynomial : ' num2str(k_0_weighted_A(1),3) ' ; ' num2str(1/k_0_weighted_B(1),3)] ; ...
            ['R^2 : ' num2str(rsq_0_weighted_A,3) ' ; ' num2str(rsq_0_weighted_B,3) ] ; ...
            ['r_{xy}^2 : ' num2str(r_xy_A^2,3) ' ; ' num2str(r_xy_B^2,3)] ; ...
            ['\eta_{I} : ' num2str(eta,3)] ; ...
            ['sqrt(EVs) : ' num2str(sqrt(TD.Es),3)] ; ...
            ['E_{slope} : ' num2str(ellipse_angle,3) ] ; ...
            ['CoM : ' num2str([x_center_of_mass y_center_of_mass],3)] ; ...
            ['Std_{error} : ' num2str(sqrt(var_error),3)]};
        text(leg_position_x, leg_position_y, klabel);
        if PLOT.eachTime
            title(['Correlations between ' TENSORS.str_y_axis ' and ' TENSORS.str_x_axis ' : ' PLOT.app_filename ' at time ' num2str(Time(t))], 'Interpreter', 'none');
        else
            title(['Correlations between ' TENSORS.str_y_axis ' and ' TENSORS.str_x_axis ' : ' PLOT.app_filename ], 'Interpreter', 'none');
        end
        ylabel([TENSORS.str_y_axis ' (' TENSORS.str_unit_y ')']); %' (µm^2)' for mM etc
        xlabel([TENSORS.str_x_axis ' (' TENSORS.str_unit_x ')']); %' (µm^2)'
        main_h = figure(1);
        set(main_h, 'color', 'white');
        
        hold off
        
        % Print
        if PLOT.print
            disp ( 'Printing...'  )
            %             pdf_filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(Index(1),'%04d') '_to_' num2str(Index(N),'%04d') '_' PLOT.app_filename '.pdf'];
            if PLOT.eachTime
                filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(t,'%04d') '_' PLOT.app_filename];
            else
                filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(Index(1),'%04d') '_to_' num2str(Index(N),'%04d') '_' PLOT.app_filename];
            end
            if exist ([filename '.png'], 'file') == 2
                button = questdlg('File already exists. Overwrite ?','Warning', 'Yes', 'No', 'No');
                if strcmp(button,'Yes')
                    print('-dpng','-r400',[filename '.png']);
                elseif strcmp(button,'No')
                    return
                end
            else
                
                if strcmp(plot_extension,'.svg')
                    plot2svg([filename '.svg'], figure(1), 'png');
                else
                    print('-dpng', '-r500', [filename '.png']);
                end
                
            end
            %             export_fig(pdf_filename, '-pdf','-append'); % overwrites existing file (if any) on computer for first FRAME...
        end
        close all
    end
    
end


%% Other plots (3.4)
% Plot correlations as a function of time
if PLOT.plot && PLOT.plotCoef
    
    eta_val = zeros(1,N);
    ellipse_angle_val = zeros(1,N);
    eta_val = zeros(1,N);
    k_val = zeros(1,N);
    x_center_of_mass_val = zeros(1,N);
    y_center_of_mass_val = zeros(1,N);
    
    for n=1:N
        
        if FIT.tf_T_iso && FIT.tf_T_dev
            x_val = [ X_red{:,n} ; X_green{:,n} ; X_blue{:,n}];
            y_val = [ Y_red{:,n} ; Y_green{:,n} ; Y_blue{:,n}];
            weight_val = [ISOweight{:,n} ; DEVweight{:,n} ; DEVweight{:,n}];
        elseif FIT.tf_T_iso
            x_val = [ X_red{:,n} ];
            y_val = [ Y_red{:,n} ];
            weight_val = [ISOweight{:,n} ];
        else
            x_val = [ X_green{:,n} ; X_blue{:,n}];
            y_val = [ Y_green{:,n} ; Y_blue{:,n}];
            weight_val = [DEVweight{:,n} ; DEVweight{:,n}];
        end
        
        I_val = zeros(1,4);
        x_center_of_mass_val(n) = mean(x_val .* weight_val);
        y_center_of_mass_val(n) = mean(y_val .* weight_val);
        
        % Fills inertia matrix
        if sum(weight_val) ~= 0
            I_val(1,1) = sum( ((x_val - x_center_of_mass_val(n)).^2) .* weight_val) ./ sum(weight_val);
            I_val(1,2) = sum( ((x_val - x_center_of_mass_val(n)) .* (y_val - y_center_of_mass_val(n))) .* weight_val) ./ sum(weight_val);
            I_val(1,3) = I_val(2);
            I_val(1,4) = sum( ((y_val - y_center_of_mass_val(n)).^2) .* weight_val) ./ sum(weight_val);
        end
        % Determines eigen values & vectors and sort them
        TD_val = TensorData(I_val);
        % Computation of inertia anisotropy
        eta_val(n) = 1 - sqrt( TD_val.Es(2) / TD_val.Es(1) );
        % Computation of the ellipse major axis slope (3.4)
        ellipse_angle_val(n) = tan( degtorad(TD_val.Angles(1)) );
        
        % Calculation of k
        if isempty(FIT.point)==1
            temp = mmpolyfit(x_val, y_val , 1, 'Weight', weight_val);
        else
            temp = mmpolyfit(x_val,  y_val , 1, 'Weight', weight_val,'Point',FIT.point);
        end
        k_val(n) = R2_value(x_val, y_val, temp, weight_val);
        
    end
    
    %     % plot of eta and r2 over time
    %     figure(2)
    %     hold on
    %     axis([Time(1)*0.9 Time(end)*1.1 0 1* 1.1] );
    %     plot(Time, eta_val, 'g.-', 'MarkerSize', 20)
    %     plot(Time, k_val,'k.-','MarkerSize',20)
    %     title(['Evolution of \eta_{I} | ' TENSORS.str_y_axis ' vs ' TENSORS.str_x_axis ' | along time']);
    %     leg = legend('\eta_{I}' , 'R^2' );
    %     set(leg,'Location','NorthWest');
    %     xlabel('Time (APF)');
    %     % ylabel('\eta_{I}');
    %     fh = figure(2);
    %     set(fh, 'color', 'white');
    %     hold off
    %
    %     % Print
    %     if PLOT.print
    %         disp ( 'Printing...')
    %         filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(Index(1),'%04d') '_to_' num2str(Index(N),'%04d') '_' PLOT.app_filename '_etaI.png'];
    %         print('-dpng', '-r500', filename);
    %         export_fig(pdf_filename, '-pdf', '-append'); % ... then appends contributions of following frames as extra sheets.
    %     end
    
    
    
    % plot of ellipse slope over time
    relevant = eta_val > PLOT.threshold;
    figure(3)
    hold on
    plot( [Time(1)*0.9 Time(end)*1.1],[0 0], 'k', ...
        [Time(1)*0.9 Time(end)*1.1], [1 1], '-.k', ...
        [Time(1)*0.9 Time(end)*1.1],  [-1 -1], '-.k' );
    
    [hAx,hLine1,hLine2] = plotyy(Time, ellipse_angle_val, Time, eta_val);
    
    plot( Time(relevant), ellipse_angle_val(relevant), 'ok' );
    
    set(hLine1,'Color',[0.8 0 0]); set(hLine1,'MarkerSize',10); set(hLine1,'Marker','.');
    set(hAx(1),'YColor',[0.8 0 0]);
    if min(eta_val) > PLOT.threshold
        axis(hAx(1),[Time(1)*0.9 Time(end)*1.1 -2*1.1 2*1.1]);
        set(hAx(1),'YLim',[-2*1.1 2*1.1])
    else
        axis(hAx(1),[Time(1)*0.9 Time(end)*1.1 min(min(ellipse_angle_val),-2)*1.1 max(max(ellipse_angle_val),2)*1.1]);
        set(hAx(1),'YLim',[min(min(ellipse_angle_val),-2)*1.1 max(max(ellipse_angle_val),2)*1.1])
    end
    set(hLine2,'Color',[0 0.8 0]); set(hLine2,'MarkerSize',10); set(hLine2,'Marker','.');
    set(hAx(2),'YColor',[0 0.8 0]);
    axis(hAx(2),[Time(1)*0.9 Time(end)*1.1 0 1*1.1]);
    set(hAx(2),'YLim',[0 1*1.1])
    set(hAx(2),'YTick',[0:0.1:1*1.1])
    
    %     scale_factor = (max(ellipse_angle_val)-min(ellipse_angle_val)) / (max([1:length(ellipse_angle_val)])-min([1:length(ellipse_angle_val)]));
    %     transparentScatter( Time',  ellipse_angle_val', 0.20, [1,0,0], max(eta_val',0.15), scale_factor); % plot data cloud in red
    %     patchline(Time,ellipse_angle_val, 'linestyle','-','linewidth',0.5,'edgecolor',[1 0 0],'linewidth',3,'edgealpha',max(min(eta_val),0.15));
    
    title(['Evolution of ellispe slope and \eta_{I} along time | ' TENSORS.str_y_axis ' vs ' TENSORS.str_x_axis ]);
    xlabel('Time (APF)');
    ylabel(hAx(1),'E_{slope}') % left y-axis
    ylabel(hAx(2),'\eta_{I}') % right y-axis
    
    fh = figure(3);
    set(fh, 'color', 'white');
    hold off
    
    % Print
    if PLOT.print
        disp ( 'Printing...'   )
        filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(Index(1),'%04d') '_to_' num2str(Index(N),'%04d') '_' PLOT.app_filename '_EtaI_E(slope)' plot_extension];
        
        if strcmp(plot_extension,'.svg')
            plot2svg(filename, figure(1), 'png');
        else
            print('-dpng', '-r500', filename);
        end
        
        %         export_fig(pdf_filename, '-pdf', '-append'); % ... then appends contributions of following frames as extra sheets.
    end
    
    
    
    %     % plot of CoM over time
    %     figure(4)
    %     hold on
    %     plot(Time,x_center_of_mass_val, 'r.-', Time, y_center_of_mass_val , 'b.-')
    %     title(['Evolution of CoM | ' TENSORS.str_y_axis ' vs ' TENSORS.str_x_axis ' | along time']);
    %     xlabel('Time (APF)');
    %     ylabel('position');
    %     leg = legend('CoMx' , 'CoMy' );
    %     set(leg,'Location','NorthWest');
    %     fh = figure(4);
    %     set(fh, 'color', 'white');
    %     hold off
    %
    %     % Print
    %     if PLOT.print
    %         disp ( 'Printing...')
    %         filename = [dir TENSORS.str_y_axis 'vs' TENSORS.str_x_axis '_' num2str(Index(1),'%04d') '_to_' num2str(Index(N),'%04d') '_' PLOT.app_filename '_CoM.png'];
    %         print('-dpng', '-r500', filename);
    %         export_fig(pdf_filename, '-pdf', '-append'); % ... then appends contributions of following frames as extra sheets.
    %     end
    
    close all
end


if ~PLOT.eachTime
    
    Eta = eta;
    Slope = ellipse_angle;
    
else
    
    Eta = mean(eta_val);
    Slope = mean(ellipse_angle_val);
    
end

% R2 = [rsq_0_weighted_A rsq_0_weighted_B];
% r2 = [r_xy_A^2 r_xy_B^2];


end


%% History

% 13/03/2015 : 3.5
% - remove non significance values using std determined during AOA and DOA (not available for CM)
% - change return value to return etaI and Eslope instead of R2 and r2
% - remove print in pdf

% 03/03/2015 : 3.4
% - add plotyy with eta and slope
% - normalisation of the data
% - add opposite polynomial fit
% - change ellipse angle by ellispe major axis slope
% - add option PLOT.axesRange to specify [xmin xmax ymin ymax] of the plot

% 19/02/2015 : 3.3
% - Code cleaning
% - modification for 4D tensor matrix input
% - modification to correlate values generated after animal average

% 10/10/2014 : 3.2
% 03/09/2014 : 3.1 adapted to AIA_parameters
% 25/03/2014 : 3.0 function
% 28/02/2014 : 2.6 different input formats
% 31/01/2014 : 2.5 choice isotropic part or not
% 30/01/2014 : 2.4 cleaned version and new name of the script
%              2.3 transparency plot and weighted fit
% 27/01/2014 : 2.2 matlab fit
% 24/01/2014 : 2.1 extended statistics
% 23/01/2014 : 2.0 new data set : no more loop
% 17/01/2014 : 1.1 pre declared arrays, several data set possible, replot mode
% 16/01/2014 : 1.0 creation



