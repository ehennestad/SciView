function monitorZDriftOffline(zStackPath, app, recordingPath)

screenSize = get(0, 'ScreenSize');

% Set options for zstack processing
zStackOpt.doRegister    = true;
zStackOpt.doDestretch   = false;
zStackOpt.doNonrigid    = true;
zStackOpt.doParallel = true;

% Set options for drift calculation
driftOpt.nFramesPerFile = 2000;
driftOpt.nFramesPerAvg = 200;
driftOpt.nObservations = 100;

imageOpt.rangeForAvg = [0.25, 0.75];
app = [];

% Create a processed zstack
[zStack, cLims] = makeZstack(zStackPath, zStackOpt);
if ~isempty(zStack)
    ivZ = imviewer(zStack); 
    fH1 = ivZ.fig;
    fH1.Position(1:2) = screenSize(3:4) - fH1.Position(3:4)+1;             % Position the figure
end

% Get metadata from zstack
zVars = {'x.pixel.sz', 'y.pixel.sz', 'z.spacing'};
scanParamZ = getSciScanVariables(zStackPath, zVars);
nPlanes = size(zStack, 3);


% These are necessary for destretching of images.
scanParam.zoom = 2;
scanParam.xcorrect = -32;

imageSizeOrig = [512, 512];
imageSize = size(zStack); imageSize = imageSize(1:2);


% Unpack options variables. 
% structvars(driftOpt) %FEX function. Running it yields the following:
nFramesPerFile = driftOpt.nFramesPerFile;     
nFramesPerAvg = driftOpt.nFramesPerAvg;       
nObservations = driftOpt.nObservations; 

memmapFormatSpecImage = {'uint16', [imageSizeOrig, nFramesPerFile], 'xyt'};
memmapFormatSpecTheta = {'double', [nFramesPerFile, 1], 't'};

% Preallocate data.

% Create an image array:
imArrayRef = ones([imageSize, nObservations], 'uint8');                    % if uint16: .* 31500; % Typically darkest level of recording.
imArrayRef(1) = 255;                                                       % cLims(2); % Imviewer will use this as the max brightness value

% Show crosscorrelation errors as heat map.
xCorrZ = nan(nPlanes, nObservations);

offsetX = nan(1, nObservations); % Shifts detected from rigid alignment
offsetY = nan(1, nObservations); % Shifts detected from rigid alignment
offsetZ = nan(1, nObservations); % Best fit of xcorr with ref vs zstack



% Open imviewer instance to display reference images as they become avail.

ivR = imviewer(imArrayRef);
ivR.nFrames = 1;
ivR.changeFrame(struct('String', '1'), [], 'jumptoframe');

fH2 = ivR.fig;
fH2.Position(1) = fH1.Position(1) - fH2.Position(3);
fH2.Position(2) = fH1.Position(2);

% Open figure to display drift results. 

fH3 = openfig('driftMonitorFigureLayout.fig');
fH3.Name = 'Estimated Drift';
fH3.Units = 'pixel';
fH3.Position(3) = fH1.OuterPosition(3) + fH2.OuterPosition(3);
fH3.Position(1) = screenSize(3) - fH3.Position(3) + 1;
fH3.Position(2) = fH1.Position(2) - fH3.OuterPosition(4);

AX = findobj(fH3, 'type', 'axes');

% Plot drift in two axes, one for x/y drift and one for z drift

% Plot "target" lines for each of the plot
plot(AX(1), [0, nObservations+1], [0,0], '--', 'Color', ones(1,3)*0.5);
plot(AX(2), [0, nObservations+1], [0,0], '--', 'Color', ones(1,3)*0.5);
arrayfun(@(ax) hold(ax, 'on'), AX(1:2))

title(AX(1), 'XY - Drift')
title(AX(2), 'Z - Drift')

set( AX(1:2), 'XLim', [1,10] - 0.5);
set( [AX(1:2).XLabel], 'String', 'Observations per 2000 frames')

% AX(1).YLim = [-10, 10];
AX(2).YLim = [-nPlanes/2, nPlanes/2];
AX(2).YTickLabel = AX(2).YTick .* scanParamZ.zspacing;
AX(1).YLabel.String = 'Est. X-Y Drift (um)';
AX(2).YLabel.String = 'Est. Z Position (um)';


hIm = imagesc(xCorrZ, 'XData', [1, nObservations], 'YData', [-1,1]*nPlanes/2);
hIm.AlphaData = zeros(size(xCorrZ));
hIm.Parent = AX(2);
uistack(hIm, 'down') % Place it under the "target" line

cmap = cbrewer('div', 'PuOr', 7);

hLineX = plot(AX(1), 1:nObservations, offsetX, '-o', 'Color', cmap(1,:));
hLineY = plot(AX(1), 1:nObservations, offsetY, '-o', 'Color', cmap(7,:));
hLineZ = plot(AX(2), 1:nObservations, offsetZ, '*', 'Color', 'w');

legend(AX(1), [hLineX, hLineY], {'X-Drift', 'Y-Drift'}, 'AutoUpdate', 'off')

% Prepare axes on bottom
hErr = gobjects(4,1);
hFit = gobjects(4,1);
hBest = gobjects(4,1);
for j = 1:4
    hErr(j) = plot(AX(j+2), 1:nPlanes, nan(nPlanes,1), '*');
    hold(AX(j+2), 'on')
    hFit(j) = plot(AX(j+2), 1:nPlanes, nan(nPlanes,1), '-');
    hBest(j) = plot(AX(j+2), [nan,nan], [0.6,1], '--', 'Color', 'k');

    AX(j+2).XLim = [1,nPlanes];
    AX(j+2).YLim = [0.6,1];
    AX(j+2).XTick = linspace(1,nPlanes, 5);
    AX(j+2).XTickLabel = (AX(j+2).XTick - ceil(nPlanes/2)) .* scanParamZ.zspacing;
    text(AX(j+2), 2, 0.95, sprintf('Current Frame -%d', 4-j))
    
end
l = legend(AX(6), [hErr(1), hFit(1)], {'Actual Values', 'Fitted Values'}, 'AutoUpdate', 'off');
l.Position(1:2) = l.Position(1:2) + [0.025, 0.1];
set( AX(4:6), 'YTick', [] )




% % % % used in offline version:
imageFiles = dir(fullfile(recordingPath, '*XYT.raw'));
thetaFiles = dir(fullfile(recordingPath, '*XYT_theta_frame.tdms'));

vsss = virtualSciScanStack(fullfile(recordingPath, imageFiles(1).name));
tdmsData = loadTDMSdata(fullfile(recordingPath, thetaFiles(1).name), 'ThetaFrame');
thetaFull = tdmsData.ThetaFrame;
    

% % % % Functions only used in online version
if nargin < 3 || ~exist('recordingPath', 'var') || isempty(recordingPath) 
    proceed = waitForRecordingStarted();
    if ~proceed; return; end

    error('Need to make this method on sciview') %app.getRootPath()
    recordingPath = getNewestRecordingFolder(app.getRootPath());
    
end


% Start looping through files
finished = false;
currentFile = 0;

while ~finished
    
    if ~isvalid(fH1)
        finished = true;
    end
    
% % %     pause(10) % Check for new file every 10 seconds
% % %     
% % %     % Look for new files.
% % %     imageFiles = dir(fullfile(recordingPath, '*XYT_part*'));
% % %     thetaFiles = dir(fullfile(recordingPath, '*XYT_theta_frame_part*'));
% % %     
% % %     numFiles = numel(imageFiles);
% % %     
% % %     if numFiles < 2 || numFiles == (currentFile+1)
% % %         continue
% % %     end
    
    currentFile = currentFile+1;
    ivR.displayMessage('Please Wait. Processing new image...')
    
    
% % %     % Create a memory mapped file for images
% % %     imageFilePath = fullfile(recordingPath, imageFiles(currentFile).name);
% % %     imageMMap = memmapfile(imageFilePath, 'Format', memmapFormatSpecImage);
% % % 
% % %     % Load stage positions
% % %     thetaFilePath = fullfile(recordingPath, thetaFiles(currentFile).name);
% % %     thetaMMap = memmapfile(thetaFilePath, 'Format', memmapFormatSpecTheta);
% % %     theta = swapbytes(thetaMMap.Data.t);
% % % %     figure; plot(theta)
       

    ff = (currentFile-1) * nFramesPerFile + 1;
    lf = ff + nFramesPerFile - 1;
    
    theta = thetaFull(ff:lf);

    isZerosDeg = mod(theta, 360) == 0;
    frameInd = find(isZerosDeg);
    
    nGoodFrames = numel(frameInd);
    
    if nGoodFrames == 0
        continue
    else
        frameInd = frameInd(1:min([nGoodFrames, nFramesPerAvg]));
    end
    
% % %     % Load images taken at 0 degrees
% % %     imData = imageMMap.Data.xyt(:, :, frameInd);
% % %     imData = permute(swapbytes(imData), [2,1,3]);
% % %     fclose('all');

    imArray = vsss(:, :, (ff-1) + frameInd);

% %     imArray = correctLineByLineBrightnessDifference(imArray);

    
    % Align and create reference image.
    imArray = rigid(imArray);
    
    % Create a reference image from data in the interquartile range
    Y = sort(imArray, 3, 'MissingPlacement', 'last');
    nFirst = 1;%round(numel(frameInd)*0.25);
    nLasst = round(numel(frameInd)*0.75);

    Y = Y(:,:,nFirst:nLasst);
    meanIm = mean(Y, 3);

    [~, newRef] = correct_bidirectional_offset(meanIm, 1, 10);
    
%     newRef = correctLineByLineBrightnessDifference(newRef);

    % Adjust images to the same limits. Most important to baseline them at
    % 0...
%     newRef = correctResonanceStretch(newRef, scanParam, 'imwarp');
    newRef = makeuint8(newRef, cLims);
    
    
    
    % Add image to imviewer
    ivR.imArray(:, :, currentFile) = newRef;
    ivR.nFrames = currentFile;
    ivR.changeFrame(struct('String', num2str(currentFile)), [], 'jumptoframe');
    ivR.clearMessage()
    
    
    
    % Align each plane of the zstack to the new ref
    [zStackAligned, ~, shifts] = rigid(zStack, newRef);

    % Compare reference with zstack (calculate image correlations)
    err1 = zeros(nPlanes, 1);
    
    cropfun = @(im) imcropcenter(im, [450,450]);
    
    for i = 1:nPlanes
       plane =  zStackAligned(:,:,i);
       err1(i) = corr_err(single(cropfun(plane)), single(cropfun(newRef)));
    end

    % Fit a 2nd order polynomial to the observed errors
    P = polyfit((1:nPlanes)', err1, 2);
    Yhat = polyval(P, 1:numel(err1));

    xCorrZ(:, currentFile) = Yhat;
    hIm.CData(:, currentFile) = Yhat;
    hIm.AlphaData(:, :) = 1;
    
    [~, bestFit] = max(Yhat);
    
    offsetZ(currentFile) = bestFit - ceil(nPlanes/2);
    
    shiftsBestPlane = shifts(bestFit).shifts;
    offsetX(currentFile) = shiftsBestPlane(2) * scanParamZ.xpixelsz * 1e6;
    offsetY(currentFile) = shiftsBestPlane(1) * scanParamZ.ypixelsz * 1e6;
    
    hLineZ.YData(currentFile) = offsetZ(currentFile);
    hLineX.YData(currentFile) = offsetX(currentFile);
    hLineY.YData(currentFile) = offsetY(currentFile);
    
    
    % Expand the x limits of the plots to anticipate incoming data
    if currentFile + 5 > AX(2).XLim(1)
        AX(1).XLim(2) = AX(1).XLim(2) + 1;
        AX(2).XLim(2) = AX(2).XLim(2) + 1;
    end


    for j = 1:3
        hErr(j).YData = hErr(j+1).YData;
        hFit(j).YData = hFit(j+1).YData;
        hBest(j).XData = hBest(j+1).XData;

    end
    
    hErr(4).YData = err1;
    hFit(4).YData = Yhat;        
    hBest(4).XData = [bestFit, bestFit];

    
end