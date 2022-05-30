function getZStack(recordingFolder, regOpt, logger) % todo: last input should be a logger

    % Let user select recording folder if none are provided
    if nargin < 1 || isempty(recordingFolder)
        recordingFolder = uigetdir('D:\');
        if recordingFolder == 0; return; end
    end
    
    if nargin < 3
        logger = CommandlineLogger();
    end

    % Get default registration options
    
    isZStack = sciview.assert.isRecordingXYTZ(recordingFolder);
    logger.error('This is not a Z Stack recording')
    
    
end