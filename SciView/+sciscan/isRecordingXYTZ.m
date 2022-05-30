function tf = isRecordingXYTZ(recordingFolder)
%isRecordingXYTZ Check if sciscan recording is a zstack (XYTZ)
    scanParam = sciscan.getRecordingParameters(recordingFolder, {'experiment.type'});
    tf = isequal(scanParam.experimenttype, 'XYTZ');
end