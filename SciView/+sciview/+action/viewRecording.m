function imviewerObj = viewRecording(filePathStr)

    imviewerObj = imviewer(filePathStr);
    
    if ~nargout
        clear imviewerObj
    end

end