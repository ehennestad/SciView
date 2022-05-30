function imageStack = getStackFromImageReference(imageRef)

    if (ischar(imageRef) || isstring(imageRef)) && isfolder(imageRef)
        filePath = ophys.twophoton.sciscan.util.findrawfile(imageRef);
        imageStack = nansen.stack.ImageStack(filePath);
        
    elseif (ischar(imageRef) || isstring(imageRef)) && isfile(imageRef)
        imageStack = nansen.stack.ImageStack(imageRef);
        
    elseif isa(imageRef, 'nansen.stack.ImageStack')
        imageStack = imageRef;
        
    else
        error('Unsupported image reference')
        
    end
    
end