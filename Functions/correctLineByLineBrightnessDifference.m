function imOut = correctLineByLineBrightnessDifference(imIn)
% A percentile image will show the difference in brightness between two
% lines.

% So does the mean
% imIn = imIn(7:end,:,:);
meanIm = mean(imIn, 3);

[imHeight, imWidth, nFrames] = size(imIn);

meanImA = meanIm(1:2:end, :);
meanImB = meanIm(2:2:end, :);

corrIm = mean(cat(3, meanImA, meanImB), 3);
% figure; imagesc(corrIm)

diffImA = imgaussfilt(corrIm-meanImA, 10);
diffImB = imgaussfilt(corrIm-meanImB, 10);

% figure; imagesc(diffImA)
% figure; imagesc(diffImB)
% diffIm = imgaussfilt(meanImA-meanImB, 10);
% figure; imagesc(diffIm)

imOut = imIn;

if ~isa(imIn, 'single') || ~isa(imIn, 'double')
    imOut = single(imOut);
end

imOut(1:2:end, :, :) = imOut(1:2:end, :, :) + repmat(diffImA, 1, 1, nFrames);
imOut(2:2:end, :, :) = imOut(2:2:end, :, :) + repmat(diffImB, 1, 1, nFrames);

imOut = cast(imOut, 'like', imIn);

end