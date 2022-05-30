function rawFilePath = getRawFilePath(recordingFolder)
%getRawFilePath Get path to raw file from recording folder

    % Todo: 
    %   [ ] Warn if multiple files are found?
    %   [ ] Add option to get tiff files?
    
    L = dir(fullfile(folderPathStr, '*.raw'));
    keep = ~ strncmp(L, '.', 1);
    L = L(keep);
    
    rawFilePath = fullfile(recordingFolder, L(1).name);
end