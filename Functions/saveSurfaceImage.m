function saveSurfaceImage(recordingDir, app)

    regOpt = struct;
    regOpt.doDestretch = true;
    regOpt.doRegister = true;
    regOpt.doNonrigid = false;
    regOpt.doParallel = true;
    
    [~, fileName] = fileparts(recordingDir);
    nChar = numel('20191114_13_51_14_m0121-20191114-1311');
    
    fileName = fileName(1:nChar);
    fileName = sprintf('%s_surface_fov.tif', fileName);
    
    if nargin < 2; app = []; end
    
    % Create a processed zstack
    [zStack, ~] = makeZstack(recordingDir, regOpt, app);
    
    if ~isempty(zStack)
        ivZ = imviewer(zStack);
        ivZ.stackname = fileName;
        ivZ.filePath = fullfile(recordingDir, fileName);
        ivZ.displayMessage('Press s to save the displayed image to the recording folder')
        pause(2)
        ivZ.clearMessage()
    end
    
end