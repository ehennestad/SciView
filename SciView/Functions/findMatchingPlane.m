function [x, y, z] = findMatchingPlane(zStackPath, targetImage, app)

% Set options for zstack processing
zStackOpt.doDestretch   = true;
zStackOpt.doRegister    = false;
zStackOpt.doNonrigid    = false;
zStackOpt.doParallel    = false;

% Find the last recording folder
if nargin < 1 || isempty(zStackPath)
    zStackPath = uigetdir('D:\EH');
%     rootPath = 'D:\EH';
%     todayPath = fullfile(rootPath, datestr(now, 'yyyy_mm_dd'));
%     recListing = dir(fullfile(todayPath, strcat(todayPath(1:4), '*')));
%     recordingFolder = fullfile(todayPath, recListing(end).name);
end

if nargin < 2
    [filepath, folder] = uigetfile('*.tif', '', 'D:\EH');
    targetImage = imread(fullfile(folder, filepath));
end

if nargin < 3
    app = [];
end

% Create a virtual sciscan stack object
vsss = virtualSciScanStack(zStackPath);
imSize = size(vsss);


% Get scan parameters for zstack.
scanParam = getSciScanVariables(zStackPath, {...
    'x.pixel.sz', 'y.pixel.sz', 'z.spacing', 'no.of.planes', ...
    'frames.per.plane', 'setX', 'setY', 'setZ', 'x.pixels', 'y.pixels'} );

nPlanes = scanParam.noofplanes;
planeInd = repmat(1:nPlanes, [scanParam.framesperplane, 1]);

rawdata = struct;
rawdata.imdata = vsss;
rawdata.planeInd = planeInd;
rawdata.target = targetImage;
rawdata.scanParam = getSciScanVariables(zStackPath, {'ZOOM', 'x.correct'});

% Create a processed zstack
[zStack, cLims] = makeZstack(zStackPath, zStackOpt, app);

rawdata.min = cLims(1); rawdata.max = cLims(2);

targetImage = single(targetImage);
targetImage = makeuint8(targetImage, cLims);


% Make sure images are the same size...
if size(zStack, 2) > size(targetImage, 2)
    zStack = imcropcenter(zStack, [size(zStack, 1), size(targetImage, 2)]);
elseif size(zStack, 2) < size(targetImage, 2)
    targetImage = imcropcenter(targetImage, [size(targetImage, 1), size(zStack, 2)]);
end

% Register images and calculate error
printmsg('Aligning each plane to reference...', app)
zStackAligned = rigid(zStack, targetImage);
printmsg('done.', app, 'append')

printmsg('Calculating image correlations...', app)
err1 = zeros(nPlanes, 1);

for i = 1:nPlanes
   plane =  zStackAligned(:,:,i);
   err1(i) = corr_err(single(plane), single(targetImage));
end
printmsg('done.', app, 'append')

fig1=figure('MenuBar', 'none'); plot(err1); hold on
P = polyfit((1:nPlanes)', err1, 2);
errPolyfit = polyval(P, 1:numel(err1) );
plot(errPolyfit);
[yplot, xplot] = max(errPolyfit);
plot(xplot, yplot, 'o')
title('Image correlations per plane')
xlim([1, nPlanes])
text(xplot+0.5, yplot, sprintf('X: %d', xplot), 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'BackgroundColor', [0.9,0.9,0.7])

printmsg(sprintf('Press enter while viewing the best matching frame.\n'), app)
imviewerObj = imviewer(cat(2, zStack, repmat(targetImage, [1,1,nPlanes])));
imviewerObj.fig.KeyPressFcn = @quitImviewer;
imviewerObj.fig.WindowButtonDownFcn = {@mousePress, imviewerObj};
imviewerObj.fig.UserData = rawdata;
% This function should have been a class because this is turning messy!

if ~isempty(app)
    fig1.Position(1:2) = [  app.SciViewUIFigure.OuterPosition(1),...
                            sum(app.SciViewUIFigure.OuterPosition([2,4]))+45];
    fig1.Position(4) = imviewerObj.fig.Position(4);               
    imviewerObj.fig.Position(1:2) = [sum(fig1.Position([1,3]))+25, fig1.Position(2)];
    
    
    % Check that figures don't end up outside the screen...
    screenSize = get(0, 'ScreenSize');
    
    if imviewerObj.fig.Position(1) + imviewerObj.fig.Position(3) > screenSize(3)
        imviewerObj.fig.Position(1) = screenSize(3) - imviewerObj.fig.Position(3);
    end
    
    if imviewerObj.fig.Position(2) + imviewerObj.fig.Position(4) > screenSize(4)
        imviewerObj.fig.Position(2) = screenSize(4) - imviewerObj.fig.Position(4) - 40;
    end
    
    if fig1.Position(1) + fig1.Position(3) > screenSize(3)
        fig1.Position(1) = screenSize(3) - fig1.Position(3);
    end
    
    if fig1.Position(2) + fig1.Position(4) > screenSize(4)
        fig1.Position(2) = screenSize(4) - fig1.Position(4) - 40;
    end

end

uiwait(imviewerObj.fig)
frameNum = imviewerObj.currentFrameNo;

close(imviewerObj.fig)
close(fig1)

z = scanParam.setz - (nPlanes - frameNum) * scanParam.zspacing;

Y = zStack(:,:,frameNum);
options_rigid = NoRMCorreSetParms( ...
    'd1', size(Y,1), 'd2', size(Y,2), 'max_shift', 15, ...
    'bin_width', 1, 'us_fac', 50 );

[test, nc_shifts] = normcorre(Y, options_rigid, targetImage);
dx = arrayfun(@(row) row.shifts(2), nc_shifts);
dy = arrayfun(@(row) row.shifts(1), nc_shifts);

xcorr = imSize(2) / scanParam.xpixels;

x = scanParam.setx + (-dx * scanParam.xpixelsz * 1e6) * xcorr;
y = scanParam.sety + (-dy * scanParam.ypixelsz * 1e6);

if ~nargout
    fprintf('\nNew X Position: %.1f \nNew Y Position: %.1f \nNew Z Position: %.1f \n', x, y, z)
    clearvars;
end


end


function mousePress(src, event, imviewerObj)
    %debug
    switch src.SelectionType
        case 'alt'
            
            c = uicontextmenu;
            % Create child menu items for the uicontextmenu
            m1 = uimenu(c,'Label','Register Plane', 'Callback',{@registerPlane, src, imviewerObj});
            c.Position = src.CurrentPoint;
            c.Visible = 'on';
    end    
end

function registerPlane(~, ~, imviewerFig, imviewerObj)
%This kind of coding should not be allowed!
    planeNum = imviewerObj.currentFrameNo;
    
    newPlane = rigid(imviewerFig.UserData.imdata(:,:, imviewerFig.UserData.planeInd==planeNum));
    Y = single(mean(newPlane, 3));

    minVal = single(imviewerFig.UserData.min);
    maxVal = single(imviewerFig.UserData.max);
    
    Y = uint8((Y-minVal) ./ (maxVal-minVal) .* 255);
    Y = correctResonanceStretch(Y, imviewerFig.UserData.scanParam, 'imwarp');

	T = uint8((single(imviewerFig.UserData.target)-minVal) ./ (maxVal-minVal) .* 255);

    imviewerObj.imArray(:,:,planeNum) = cat(2, Y, T);
    imviewerObj.updateImageDisplay();
    
    
end


function quitImviewer(src, event)

switch event.Key
    case 'return'
        disp('pressed enter')
        uiresume(src)
end

end



