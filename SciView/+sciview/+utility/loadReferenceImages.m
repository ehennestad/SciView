function referenceImageArray = loadReferenceImages(referenceImagePathList)
%loadReferenceImages Load reference images and place in 512 x 512 array
    
    % todo:
    % [ ] Support for multi channel images
    % [ ] Keep original image size and pad or crop imaegs instead of resizing 
    
    numImages = numel(referenceImagePathList);
    
    % Load ref images into array.
    referenceImageArray = zeros(512, 512, numImages, 'uint8');

    for i = 1:numImages
        im = uint8(imread(referenceImagePathList{i}));
        
        if ndims(im) == 3 % merge channels
            im = mean(im, 3);
        end
        
        maxsize = max(size(im));
        resizeFactor = 512/maxsize;
        im = imresize(im(:,:,1), resizeFactor);

        imCenter = size(im)/2;
        indX = (1:size(im,2)) - round(imCenter(2)) + 256;
        indY = (1:size(im,1)) - round(imCenter(1)) + 256;
        referenceImageArray(indY, indX, i) = im;
    end
end