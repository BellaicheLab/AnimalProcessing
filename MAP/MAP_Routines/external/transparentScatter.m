function scatterPoints = transparentScatter(x,y,PtSize,color,opacity,scale_factor)
%
% 1.1
%
% scatterPoints = transparentScatter(x,y,sizeOfCirlce,color,opacity)
%
% x,y = coordinates of point centers
% PtSize = size of circle
% color = sets patch FaceColor property
% opacity = value or vector of values defining opacity. MUST BE IN [0 1]
% NB: "opacity" can be a vector of same size as x y, but "color" must be a single color
%
% example:
% scatterPoints = transparentScatter(randn(5000,1),randn(5000,1),0.1,'b',0.05);
% set(scatterPoints,'FaceColor',[1,0,0]); % sets points color to red


    %defaultColors = get(0,'DefaultAxesColorOrder');
    assert(size(x,2)  == 1 && size(y,2)  == 1 && size(opacity,2)  == 1, 'x,y and opacity should be column vectors'); % 1.0
    
    %scale_factor = max(y)/max(x); % modified version
    
    t= 0:pi/10:2*pi;
    rep_x = repmat(x',[size(t,2),1]);
    rep_y = repmat(y',[size(t,2),1]);
    rep_t = repmat(t',[ 1, size(x,1)]);

%     scatterPoints = patch((PtSize*sin(rep_t)+ rep_x),(PtSize*scale_factor*cos(rep_t)+rep_y),color,'edgecolor','none'); % modified version 1.1
 scatterPoints = patch((PtSize*sin(rep_t)+ rep_x),(PtSize*cos(rep_t)+rep_y),color,'edgecolor','none'); 
  alpha(scatterPoints,opacity);
    
    alim([0 1]); %1.0
end

%% History %%

% 1.1 : modified version, scale_factor added
%
% 29/01/2014: 1.0
% - added "color" as argument and removed defaultColors = get(0,'DefaultAxesColorOrder');
% - added defintion of arguments
% - set transparency (alpha) scale to be [0 1]: alim([0 1])



