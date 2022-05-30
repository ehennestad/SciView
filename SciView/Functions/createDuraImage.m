function targetImage = createDuraImage(recordingFolder, regOpt, app)

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

% Print progress message
[recPath, recordingName] = fileparts(recordingFolder);
msg = sprintf('Creating dura reference image for recording \n"%s"', recordingName);
printmsg(msg, app, 'normal')


nImages = 100;

% Create a virtual sciscan stack object
vsss = virtualSciScanStack(recordingFolder);
vsss.channel = 2;

% Check if file exist with image angular positions
tdmsListing = dir( fullfile(recordingFolder, '*theta_frame.tdms'));
if ~isempty(tdmsListing)
    tdmsPathStr = fullfile(recordingFolder, tdmsListing(1).name);
    tdmsData = loadTDMSdata(tdmsPathStr, {'Theta_Frame'});
    isZeroDeg = find(mod(tdmsData.ThetaFrame, 360) == 0);
    frameInd = isZeroDeg(1:nImages);
else
    frameInd = 1:nImages;
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
scanParam = getSciScanVariables(recordingFolder, {'root.path'});
if exist(scanParam.rootpath, 'dir')
    savePath = fullfile(scanParam.rootpath, 'Reference Images', 'Dura Images');
else
    [rootPath, ~] = fileparts(recPath);
    savePath = fullfile(rootPath, 'Reference Images', 'FOV Images');
end

if ~exist(savePath, 'dir'); mkdir(savePath); end

% fileName = strcat(recordingName, 'dura_image.tif');
% imwrite(uint16(targetImage), fullfile(savePath, fileName))

% Create a version which can open in windows photos
targetImage = single(targetImage);
targetImage = (targetImage - minVal) ./ (maxVal - minVal) .* 255;
fileName = strcat(recordingName, '_dura_image_8bit.tif');

imCenter = round(size(targetImage) ./ 2);
targetImage(imCenter(1), :) = 200;
targetImage(:, imCenter(2)) = 200;
imwrite(uint8(targetImage), fullfile(savePath, fileName))

% Print progress message
msg = sprintf('Saved dura reference image.');
printmsg(msg, app, 'normal')

if ~nargout
    clearvars
end

end