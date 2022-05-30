function monitorZDrift(zStackPath, app, recordingPath)

% Todo: Add buttons to click if position was corrected.
%   Save those as boolean/vector together with drift values.


screenSize = get(0, 'ScreenSize');

% Set options for zstack processing
zStackOpt.doRegister    = true;
zStackOpt.doDestretch   = true;
zStackOpt.doNonrigid    = false;
zStackOpt.doParallel    = true;
% todo: set regOpt.nonrigid in sciview

% Set options for drift calculation
driftOpt.nFramesPerFile = 2000;
driftOpt.nFramesPerAvg = 200;
driftOpt.nObservations = 100;
driftOpt.refreshRate = 2; % Look for new file every n seconds

imageOpt.rangeForAvg = [0.25, 0.75];
% app = [];

% Create a processed zstack
[zStack, cLims] = makeZstack(zStackPath, zStackOpt, app);
if ~isempty(zStack)
    ivZ = imviewer(zStack); 
    ivZ.resizeWindow([], [], 'down')
    
    fH1 = ivZ.fig;
    fH1.Position(1:2) = screenSize(3:4) - fH1.OuterPosition(3:4)+1;             % Position the figure
end

% Get metadata from zstack
zVars = {'x.pixel.sz', 'y.pixel.sz', 'z.spacing'};
scanParamZ = getSciScanVariables(zStackPath, zVars);
nPlanes = size(zStack, 3);


% These are necessary for destretching of images. % Todo: get from zstack
% % scanParam.zoom = 2;
% % scanParam.xcorrect = -32;
scanParam = getSciScanVariables(zStackPath, {'ZOOM', 'x.correct'});

imageSizeOrig = [512, 512]; % Todo: get from user input or zstack
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
ivR.resizeWindow([], [], 'down')

fH2 = ivR.fig;
fH2.Position(1) = fH1.Position(1) - fH2.Position(3);
fH2.Position(2) = fH1.Position(2);

% Open figure to display drift results. 

fH3 = openfig('driftMonitorFigureLayout_2.fig');
fH3.Name = 'Estimated Drift';
fH3.Units = 'pixel';
fH3.Position(3) = fH1.OuterPosition(3) + fH2.OuterPosition(3);
fH3.Position(1) = screenSize(3) - fH3.Position(3) + 1;
fH3.Position(2) = fH1.Position(2) - fH3.OuterPosition(4);
fH3.CloseRequestFcn = @(src, event) closeFigures(src, event, fH1, fH2);

try
    jframeF3 = fmutilities.getjframe(fH3);
    set(jframeF3, 'WindowActivatedCallback', @(s, e) giveFocus(fH1, fH2))
catch
    % Nothing is needed to be done here
end

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
l.Position(1:2) = l.Position(1:2) + [0.03, 0.1];
set( AX(4:6), 'YTick', [] )



% % % % Functions only used in online version
if nargin < 3 || ~exist('recordingPath', 'var') || isempty(recordingPath)
    
    app.hideGui()
    proceed = waitForRecordingStarted();
    app.showGui()

    if ~proceed; return; end
    recordingPath = getNewestRecordingFolder(app.getRootPath());
    
end


% Create Finish Button
btnFinish = uicontrol('Style', 'togglebutton', 'Parent', fH3);
btnFinish.Units = 'normalized';
btnFinish.Position =  [0.91, 0.92, 0.06, 0.065];
btnFinish.String = 'Finish';

btnNewRecording = uicontrol('Style', 'togglebutton', 'Parent', fH3);
btnNewRecording.Units = 'normalized';
btnNewRecording.Position =  [0.74, 0.92, 0.15, 0.065];
btnNewRecording.String = 'Started New Recording';

btnCheckReference = uicontrol('Style', 'togglebutton', 'Parent', fH3);
btnCheckReference.Units = 'normalized';
btnCheckReference.Position =  [0.6, 0.92, 0.12, 0.065];
btnCheckReference.String = 'Check Reference';


% Start looping through files
checkAngularPosition = false; 


finished = false;
currentFile = 0;
currentImage = 0;

while ~finished
    
    if ~isvalid(fH1) || ~isvalid(fH2) || ~isvalid(fH3)
        finished = true;
    end
    
    pause(driftOpt.refreshRate) % Wait n seconds before looking for new file
    
    
    if btnNewRecording.Value
        recordingPath = getNewestRecordingFolder(app.getRootPath());
        % Reset file counter
        currentFile = 0;
        % Reset button
        btnNewRecording.Value = false;
        memmapFormatSpecImage{2}(3) = driftOpt.nFramesPerFile;
        nFramesPerFile = driftOpt.nFramesPerFile;

    end
    
    
    if btnCheckReference.Value
        recordingPath = getNewestRecordingFolder(app.getRootPath());
        % Reset file counter
        currentFile = 0;
        btnCheckReference.Enable = 'off';
        memmapFormatSpecImage{2}(3)=200;
        nFramesPerFile = 200;
    end
    
    
    %Todo: Take care of cases when sciscan mistakenly records as XYTZ
    if currentFile == 0
        L = dir(fullfile(recordingPath, '*.raw'));
        
        if ~isempty(L)
            if contains(L(1).name, 'XYTZ')
                expType = 'XYTZ';
                printmsg('NB: Experiment type XYTZ detected.', app)
            else
                expType = 'XYT';
            end
        end

    end    
    
    % Look for new files.
    imageFiles = dir(fullfile(recordingPath, sprintf('*%s_part*', expType)));
    thetaFiles = dir(fullfile(recordingPath, sprintf('*%s_theta_frame_part*', expType)));
    
    if ~isempty(thetaFiles)
       checkAngularPosition = true; 
    end
    
    numFiles = numel(imageFiles);
    
    if btnFinish.Value
        finished = true;
    end
    
    if (numFiles < 2 || numFiles == (currentFile+1)) && ~btnCheckReference.Value
        continue
    end
    
    currentFile = currentFile+1;
    currentImage = currentImage+1;
    ivR.displayMessage('Please Wait. Processing new image...')
    
    
    % Create a memory mapped file for images
    imageFilePath = fullfile(recordingPath, imageFiles(currentFile).name);
    imageMMap = memmapfile(imageFilePath, 'Format', memmapFormatSpecImage);

    % Load stage positions
    if checkAngularPosition
        try
            thetaFilePath = fullfile(recordingPath, thetaFiles(currentFile).name);
            thetaMMap = memmapfile(thetaFilePath, 'Format', memmapFormatSpecTheta);
            theta = swapbytes(thetaMMap.Data.t);
            clear thetaMMap
        catch
            theta = zeros(nFramesPerFile, 1);
        end
        %     figure; plot(theta)
        
    else
        theta = zeros(nFramesPerFile, 1);
    end
    
    isZerosDeg = mod(round(theta), 360) == 0;
    frameInd = find(isZerosDeg);
    
    nGoodFrames = numel(frameInd);
    
    if nGoodFrames == 0
        continue
    else
        frameInd = frameInd((end-(min([nGoodFrames, nFramesPerAvg]))+1):end );
    end
    
    % Load images taken at 0 degrees
    imArray = imageMMap.Data.xyt(:, :, frameInd);
    imArray = permute(swapbytes(imArray), [2,1,3]);
    clear imageMMap
    
    [imArray, ~, ~] = correctLineOffsets(imArray, 200);
    imArray = correctLineByLineBrightnessDifference(imArray);

    % Align and create reference image.
    imArray = rigid(imArray);
    
    % Create a reference image from data in the interquartile range
    Y = sort(imArray, 3, 'MissingPlacement', 'last');
    nFirst = 1;%round(numel(frameInd)*0.25);
    nLasst = round(numel(frameInd)*0.75);

    Y = Y(:,:,nFirst:nLasst);
    newRef = mean(Y, 3);

%     [~, newRef] = correct_bidirectional_offset(meanIm, 1, 10);
%     newRef = correctLineByLineBrightnessDifference(newRef);

    % Adjust images to the same limits. Most important to baseline them at
    % 0...
    newRef = correctResonanceStretch(newRef, scanParam, 'imwarp');
    newRef = makeuint8(newRef, cLims);
    
    if btnCheckReference.Value
        newRef = insertText(newRef, [10, 10], 'Reference Image', 'FontSize', 22, 'BoxColor', ones(1,3).*0.8, 'TextColor', 'w');
        newRef = uint8(mean(newRef, 3));
        btnCheckReference.Value = false;
        btnCheckReference.Enable = 'on';
    end
    
    % Add image to imviewer
    ivR.imArray(:, :, currentImage) = newRef;
    ivR.nFrames = currentImage;
    ivR.changeFrame(struct('String', num2str(currentImage)), [], 'jumptoframe');
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

    xCorrZ(:, currentImage) = Yhat;
    hIm.CData(:, currentImage) = Yhat;
    hIm.AlphaData(:, :) = 1;
    
    [~, bestFit] = max(Yhat);
    
    offsetZ(currentImage) = bestFit - ceil(nPlanes/2);
    
    shiftsBestPlane = shifts(bestFit).shifts;
    offsetX(currentImage) = shiftsBestPlane(2) * scanParamZ.xpixelsz * 1e6;
    offsetY(currentImage) = shiftsBestPlane(1) * scanParamZ.ypixelsz * 1e6;
    
    hLineZ.YData(currentImage) = offsetZ(currentImage);
    hLineX.YData(currentImage) = offsetX(currentImage);
    hLineY.YData(currentImage) = offsetY(currentImage);
    
    
    % Expand the x limits of the plots to anticipate incoming data
    if currentImage + 5 > AX(2).XLim(1)
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

% Save Figure
if btnFinish.Value
    delete(btnFinish)
    
    [~, fileName] = fileparts(recordingPath);
    savePath = fullfile(recordingPath, sprintf('%s_driftSummaryFigure.png', fileName));
    im = frame2im(getframe(fH3));
    imwrite(im, savePath, 'PNG')

    % Save Data
    S = struct;
    S.offsetX = offsetX;
    S.offsetY = offsetY;
    S.offsetZ = offsetZ;
    save(fullfile(recordingPath, sprintf('%s_driftSummaryData.mat', fileName)), 'S')

    % Todo: Save summary stack...

    % Join raw files
%     joinRawFiles(recordingPath)
end

end

function giveFocus(fH1, fH2)
    if isvalid(fH1) 
        figure(fH1)
    end
    
    if isvalid(fH2)
        figure(fH2)
    end
end

function closeFigures(src, ~, fH1, fH2)
    delete(src)
    if isvalid(fH1) 
        close(fH1)
    end
    
    if isvalid(fH2)
        close(fH2)
    end
end

