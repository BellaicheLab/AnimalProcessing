function L = GaborTextureBinarization(I, f)
% L = GaborTextureBinarization(I, f) take an input gray image and a downscaling factor f
% and return a binary image L
%

originalSize = size(I);
A = imresize(I, f);
A = adapthisteq(A);
[numRows, numCols] = size(A);

% visualisation
% figure;imshow(A)

%% designe gabor filter

wavelengthMin = 4/sqrt(2);
wavelengthMax = hypot(numRows, numCols);
n = floor(log2(wavelengthMax/wavelengthMin));
wavelength = 2.^(0:(n-2)) * wavelengthMin;

deltaTheta = 45;
orientation = 0:deltaTheta:(180-deltaTheta);

g = gabor(wavelength,orientation);
gabormag = imgaborfilt(A, g);


%% gabor post process

for i = 1:length(g)
    sigma = 0.5*g(i).Wavelength;
    K = 3;
    gabormag(:,:,i) = imgaussfilt(gabormag(:,:,i), K*sigma); 
end

X = 1:numCols;
Y = 1:numRows;
[X,Y] = meshgrid(X, Y);
featureSet = cat(3, gabormag, X);
featureSet = cat(3, featureSet, Y);

X = reshape(featureSet,numRows*numCols,[]);
X = bsxfun(@minus, X, mean(X));
X = bsxfun(@rdivide, X, std(X));

% visualisation
% coeff = pca(X);
% feature2DImage = reshape(X*coeff(:,1),numRows,numCols);
% figure;imshow(feature2DImage,[])

%% features classif

L = kmeans(X, 2, 'Replicates', 5);
L = reshape(L, [numRows numCols]);


rp = regionprops(L, 'Area', 'PixelIdxList');
[~, ind] = sort([rp.Area], 'descend');
rp = rp(ind);
bw = false(size(L));
bw(rp(1).PixelIdxList) = true;

L = imresize(bw, originalSize);
% L = imbinarize(L, 0.1);

% visualisation
% figure; imshow(L,[])

end