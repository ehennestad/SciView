function recordingPath = getNewestRecordingFolder(rootPath)
% getNewestRecordingFolder Return the lastest sciscan recording directory
%
%   recordingPath = getNewestRecordingFolder(rootPath)


    % Use folder from today by default
    thisDateStr = datestr(now, 'yyyy_mm_dd');
%     thisDateStr = '2020_06_04'; %NB: Be very careful when hardcoding this line
    
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