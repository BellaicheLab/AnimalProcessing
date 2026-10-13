% version 2.0

function [thetaMap] = GetAngleMap(X)

[by,bx,~,bt,ba] = size(X);
thetaMap = zeros([by bx 1 bt ba]);
for a=1:ba
    for t=1:bt
        for x=1:bx
            for y=1:by
                TData = TensorData(X(y,x,:,t,a));
                thetaMap(y,x,1,t,a) = deg2rad( TData.Angles(1) );
            end
        end
    end
end

end

%% History

% 13/06/2018
% - add a fifth dimension for animal, in case of MAP usage