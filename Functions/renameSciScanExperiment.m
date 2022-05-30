function renameSciScanExperiment(recordingFolder, varargin)
%renameSciScanExperiment Change experiment name in file names and metadata
%
%   renameSciScanExperiment(recordingFolder) Opens a dialog for entering a
%   new experiment name. File names and metadata fields containing the
%   experiment name will be renamed.
%
%   renameSciScanExperiment(recordingFolder, keyword) can be used to
%   specify whether to change experiment type instead of experiment name.
%   Sometimes SciScan records an XYT experiment as an XYTZ. 
%   
%   Keyword can be 'experiment_type'. Note other variations of keyword used
%   when this function is called from SciView.


if nargin < 2 || isempty(varargin)
    inFix = 'experiment_name';
end

if ~isempty(varargin)
    if contains(varargin, 'experiment_type')
        inFix = 'experiment_type';
    elseif contains(varargin, 'Change Experiment Type')
        inFix = 'experiment_type';
    elseif contains(varargin, 'Rename Experiment')
        inFix = 'experiment_name';
    end
end


L = dir(recordingFolder);

switch inFix

    case 'experiment_name'
    
        % Get file list
        meta = getSciScanVariables(recordingFolder, 'experiment.name');
        oldName = meta.experimentname;

        newName = inputdlg('Please enter new experiment name', 'Change Experiment Name', 1, {oldName});
        if isempty(newName) || strcmp(newName, oldName)
            return
        end
        
    case 'experiment_type'
        meta = getSciScanVariables(recordingFolder, 'experiment.type');
        oldName = meta.experimenttype;
        
        newName = inputdlg('Please enter new experiment type', 'Change Experiment Type', 1, {oldName});
        if isempty(newName) || strcmp(newName, oldName)
            return
        end
        
end
        

% Rename all files

for i = 1:numel(L)
    
    if strcmp(L(i).name, '.') || strcmp(L(i).name, '..')
        continue
    end
    
    if contains(L(i).name, oldName)
        newFileName = regexprep(L(i).name, oldName, newName);
        movefile(   fullfile(recordingFolder, L(i).name), ...
                    fullfile(recordingFolder, newFileName) )
    end
            
end

% Update file list
L = dir(recordingFolder);

% Rename experimentname in inifile
isIni = contains({L.name}, '.ini');

% Open file and read text.
[fid, ~] = fopen(fullfile(recordingFolder, L(isIni).name));
inistring = fread(fid, '*char')';
fclose(fid);

% Replace the experimentname and overwrite the data in the ini file
inistring = regexprep(inistring, oldName, newName);
[fid, ~] = fopen(fullfile(recordingFolder, L(isIni).name), 'w');
fwrite(fid, inistring, 'char');
fclose(fid);

% Find the folder name
fileSepInd = regexp(recordingFolder, filesep);
oldFolderName = recordingFolder(fileSepInd(end)+1:numel(recordingFolder));
newFolderName = regexprep(oldFolderName, oldName, newName);

% Change this name in imj.txt file and the notes.txt file
filePatterns = {'IJmacro', 'notes', 'OME'};
for i = 1:numel(filePatterns)
    isTxt = contains({L.name}, filePatterns{i});
    [fid, ~] = fopen(fullfile(recordingFolder, L(isTxt).name));
    txtstring = fread(fid, '*char')';
    fclose(fid);

    % Replace the foldername and overwrite the data in the ijm file
    txtstring = regexprep(txtstring, oldFolderName, newFolderName);
    
    if strcmp(inFix, 'experiment_type')
        txtstring = regexprep(txtstring, oldName, newName);
    end
    
    [fid, ~] = fopen(fullfile(recordingFolder, L(isTxt).name), 'w');
    fwrite(fid, txtstring, 'char');
    fclose(fid);
end


% Rename the folder last
if strcmp(inFix, 'experiment_name')
    movefile(recordingFolder, regexprep(recordingFolder, oldFolderName, newFolderName))
end

end




