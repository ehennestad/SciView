function tf = isRecordingXYTZ(recordingFolder)
    
    scanParam = sciscan.getRecordingParameters(recordingFolder, {'experiment.type'});
    tf = isequal(scanParam.experimenttype, 'XYTZ');
end