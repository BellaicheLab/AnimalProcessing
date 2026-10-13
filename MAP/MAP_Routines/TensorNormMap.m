% Stephane Rigaud
% 2016-03-15

% for a given 4D tensor map (x,y,4,t,a), return its corresponding
% 4D tensor norm map (x,y,1,t,a)

function [normA] = TensorNormMap(A)

[h, w, l, t,a] = size(A);
normA = NaN(h,w,1,t,a);
for la = 1:a
for lt = 1:t
    for lx = 1:w
        for ly = 1:h
            if l == 2
                value = [A(ly, lx, 1, lt, la) A(ly, lx, 2, lt, la)];
                vectorNorm = norm(value);
                normA(ly, lx, 1, lt, la) = vectorNorm;
            else
                value = Vec2Mat( A(ly, lx, :, lt, la) );
                tensorNorm = TensorNorm( value );
                % normA(ly, lx, 1, lt) = tensorNorm .* sqrt(2) .^ 2;
                % normA(ly, lx, 1, lt) = tensorNorm .* sqrt(2);
                normA(ly, lx, 1, lt, la) = tensorNorm;
            end
        end
    end
end
end
end

%% History

% 13/06/2018
% - add a fifth dimension for multiple animal stacked up