function pixs = GetPixelsFromBorderTracking(binfo, rown, imageSize)
    pixs = binfo(rown, 12:end);
    pixs = pixs(pixs > 0); % remove trailing zeros
    [yt,xt] = ind2sub([imageSize(2) imageSize(1)], pixs);
    pixs = sub2ind(imageSize, xt, yt);
end