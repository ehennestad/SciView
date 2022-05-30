function compareStartAndEndOfRecording(recordingFolder, doRegister)

if nargin < 1 || isempty(recordingFolder)
    recordingFolder = uigetdir('D:\');
    if recordingFolder == 0; return; end
end

if nargin < 2
    doRegister = false;
end

nImages = 200;

% Create a virtual sciscan stack object
vsss = virtualSciScanStack(recordingFolder);
vsss.channel = 2;

meta2p = getSciScanMetaData(recordingFolder);

% Check if file exist with image angular positions
tdmsListing = dir( fullfile(recordingFolder, '*theta_frame.tdms'));
if ~isempty(tdmsListing)
    tdmsPathStr = fullfile(recordingFolder, tdmsListing(1).name);
    tdmsData = loadTDMSdata(tdmsPathStr, {'Theta_Frame'});
    frameInd = find(mod(tdmsData.ThetaFrame(1:meta2p.nFrames), 360) == 0);
else
    frameInd = 1:meta2p.nFrames;
end

firstFrames = frameInd(1:200);
lastFrames = frameInd(end-200:end);

IM1 = vsss(:,:,firstFrames);
IM2 = vsss(:,:,lastFrames);

if doRegister
    IM1 = rigid(IM1);
    IM2 = rigid(IM2);
end


firstImage = mean(IM1, 3);
lastImage = mean(IM2, 3);

imviewer(cat(3,firstImage, lastImage));

end