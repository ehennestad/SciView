function targetImage = createFovImage(recordingFolder, regOpt, app)

if nargin < 1 || isempty(recordingFolder)
    recordingFolder = uigetdir('D:\');
    if recordingFolder == 0; return; end
end

if nargin < 2 || isempty(regOpt)
    regOpt = struct;
    regOpt.doRegister = true;
    regOpt.doDestretch = true;
end

if nargin < 3
    app=[];
end

[recPath, recordingName] = fileparts(recordingFolder);

% Assemble savepath and filename for image
scanParam = getSciScanVariables(recordingFolder, {'root.path'});
if exist(scanParam.rootpath, 'dir')
    savePath = fullfile(scanParam.rootpath, 'Reference Images', 'FOV Images');
else
    [rootPath, ~] = fileparts(recPath);
    savePath = fullfile(rootPath, 'Reference Images', 'FOV Images');
end

fileName = strcat(recordingName, '_fov_image.tif');

% Check if image already exists
if exist(fullfile(savePath, fileName), 'file')
    msg = sprintf('Reference image already exists for recording \n"%s", skipping...', recordingName);
    printmsg(msg, app, 'normal')
    if nargout
        targetImage = imread(fullfile(savePath, fileName));
    end
    return
end

% Print progress message
msg = sprintf('Creating reference image for recording \n"%s"', recordingName);
printmsg(msg, app, 'normal')

nImages = 200;

% Create a virtual sciscan stack object
vsss = virtualSciScanStack(recordingFolder);
vsss.channel = 2;


%rawFilepath = getImageFilepath(recordingFolder); % Local function
%vsss = nansen.stack.ImageStack(rawFilepath);


nImages = min([nImages, size(vsss,3)]);

% Check if file exist with image angular positions
tdmsListing = dir( fullfile(recordingFolder, '*theta_frame.tdms'));
if ~isempty(tdmsListing)
    tdmsPathStr = fullfile(recordingFolder, tdmsListing(1).name);
    tdmsData = loadTDMSdata(tdmsPathStr, {'Theta_Frame'});
    if ~isfield(tdmsData, 'ThetaFrame')
        frameInd = 1:nImages; % Hope for the best
    else
        isZeroDeg = find(mod(round(tdmsData.ThetaFrame), 360) == 0);
        frameInd = isZeroDeg(1:nImages);
    end
else
    frameInd = 1:nImages;
end

% Find number of frames from metadata and check that there are enough frames.
S = getSciScanVariables(recordingFolder, {'no.of.frames.acquired'});
if frameInd(end) > S.noofframesacquired
    frameInd(frameInd < S.noofframesacquired) = [];
end

% Load Images
imArray = vsss(:,:,frameInd);

% Correct Resonance Stretch
if regOpt.doDestretch
    scanParam = getSciScanVariables(recordingFolder, {'ZOOM', 'x.correct'});
    imArray = correctResonanceStretch(imArray, scanParam, 'imwarp');
end 

% Get min and max value for scaling to 8 bit later
targetImage = single(mean(imArray, 3));
minVal = min(targetImage(:));
maxVal = max(targetImage(:));

if regOpt.doRegister
    imArray = rigid(imArray);
end

targetImage = mean(imArray, 3);


[~, targetImage] = correct_bidirectional_offset(targetImage, 1, 10);

targetImage = uint16(targetImage);

% Save image
if ~exist(savePath, 'dir'); mkdir(savePath); end

imwrite(uint16(targetImage), fullfile(savePath, fileName))

% Create a version which can open in windows photos
targetImage = single(targetImage);
targetImage = (targetImage - minVal) ./ (maxVal - minVal) .* 255;
fileName = strcat(recordingName, '_fov_image_8bit.tif');

imCenter = round(size(targetImage) ./ 2);
targetImage(imCenter(1), :) = 200;
targetImage(:, imCenter(2)) = 200;
imwrite(uint8(targetImage), fullfile(savePath, fileName))

% Print progress message
msg = sprintf('Saved FOV reference image.');
printmsg(msg, app, 'normal')

if ~nargout
    clearvars
end

end


function imFilepath = getImageFilepath(recordingFolder)
    
    [~, recName, ~] = fileparts(recordingFolder);
    L = dir(fullfile(recordingFolder, '*.raw'));
    
    if numel(L) > 1
        warning('Multiple files detected for recording "%s", selected first one...', recName)
    elseif isempty(L)
        error('No file was detected for recording "%s", recName')
    end
    
    imFilepath = fullfile(recordingFolder, L(1).name);
    
end
