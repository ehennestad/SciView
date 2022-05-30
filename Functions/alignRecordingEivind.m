function alignRecordingEivind(recordingFolder)

options = struct;
PROCESSED = 'D:\EH\PROCESSED\';

try
    
    registerImagesRotation(recordingFolder, options)
    sid = strfindsid(recordingFolder);
    proPath = fullfile(PROCESSED, strrep(sid(1:5), 'm', 'mouse'), strcat('session-', sid));
    imregPostProcess(proPath, 'saveFiles', true, 'saveFormat', 'raw')
        
catch ME
    crashDump(ME, recordingFolder(end-22:end), 'regrot', 'D:\EH\error_report')
end

end