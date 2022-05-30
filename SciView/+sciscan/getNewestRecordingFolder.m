function recordingPath = getNewestRecordingFolder(rootPath)
% getNewestRecordingFolder Return the lastest sciscan recording directory
%
%   recordingPath = getNewestRecordingFolder(rootPath)


    % Use folder from today by default
    thisDateStr = datestr(now, 'yyyy_mm_dd');
    
    % Combine rootPath with datefolder
    todayDir = fullfile(rootPath, thisDateStr);
    
    % Select the last folder in the list. Hopefully it is the newest.
    recDirs = dir(fullfile(todayDir, '*'));
    
    % Remove listing result that is not a folder
    isDir = [recDirs.isdir];
    recDirs = recDirs(isDir);
        
    % Remove listing result that does not contain the date in the
    % beginning of the name
    isRecDir = strncmp({recDirs.name}, strrep(thisDateStr, '_', ''), 8);
    recDirs = recDirs(isRecDir);

    recordingPath = fullfile(todayDir, recDirs(end).name);
    
end