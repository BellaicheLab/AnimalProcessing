function value = GetLocalIntensityValue(I, y, x, kernel)
% value = GetLocalIntensityValue(I, y, x, kernel)
% on a image I, compute the intensity mean around the pixel (x,y) using the
% provided kernel for both neighbor and ponderation effect
%

imageSize = size(I);
[shift_h, shift_w] = size(kernel);
shift_h = floor(shift_h/2);
shift_w = floor(shift_w/2);

% based on the kernel size, define the list of pixel indices to process
yl = repmat(         [y-shift_h:y+shift_h],[1,3,1]);
xl = reshape(repmat( [x-shift_w:x+shift_w],[3,1,1]),[1 length(yl)]);

% border management
yl(yl>imageSize(1)) = imageSize(1);
xl(xl>imageSize(2)) = imageSize(2);
yl(yl<=0) = 1;
xl(xl<=0) = 1;

% stack all pixel
junctionPixelIndices = sub2ind(imageSize, yl, xl);
v = [];
for p = 1:length(junctionPixelIndices)
    [y, x] = ind2sub(imageSize, junctionPixelIndices(p));
    v = [v I(y, x)];
end

% v = I(junctionPixelIndices);

% apply weight
weight = reshape(kernel,[1 numel(kernel) 1]);
value = nansum( double(v) .* weight ) ./ nansum( weight );

end