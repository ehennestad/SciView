function [newX, newY] = findStageCenterPosition(recordingFolder, regOpt, app)

if nargin < 1 || isempty(recordingFolder)
    recordingFolder = uigetdir();
end

if nargin < 2 || isempty(regOpt)
    regOpt = struct;
    regOpt.doDestretch = true;
    regOpt.doRegister = false;
end

if nargin < 3
    app=[];
end

newX = []; newY = [];

% if ~contains(recordingFolder, 'rotalign')
%     msg = 'Error: Recording does not have the right name for this operation';
%     printmsg(msg, app, 'normal')
%     return
% end

scanParam = getSciScanVariables(recordingFolder, {'external.start.trigger.enable'});
if contains(scanParam.externalstarttriggerenable, 'FALSE')
    msg = 'Error: You forgot the trigger tickbox';
    printmsg(msg, app, 'normal')
   return
end

% Create a virtual sciscan stack object
vsss = virtualSciScanStack(recordingFolder);

% Check if file exist with image angular positions
tdmsListing = dir( fullfile(recordingFolder, '*theta_frame.tdms'));
tdmsPathStr = fullfile(recordingFolder, tdmsListing(1).name);
tdmsData = loadTDMSdata(tdmsPathStr, {'Theta_Frame'});

nFrames = size(vsss, 3);
nAngles = numel(tdmsData.ThetaFrame);

if nAngles >= nFrames
    tdmsData.ThetaFrame = tdmsData.ThetaFrame(1:nFrames);
else
    tdmsData.ThetaFrame(end+1:nFrames) = tdmsData.ThetaFrame(end);
end

% Load images from each stack.
ind1 = mod(tdmsData.ThetaFrame, 360) == 0;
ind2 = mod(tdmsData.ThetaFrame, 360) == 180;

if sum(ind1)==0 || sum(ind2)==0
    msg = 'Error: Recording was not taken in the right stage positions';
    printmsg(msg, app, 'normal')
    return
end


targetIm1 = vsss(:, :, mod(tdmsData.ThetaFrame, 360) == 0);
targetIm2 = vsss(:, :, mod(tdmsData.ThetaFrame, 360) == 180);

scanParam = getSciScanVariables(recordingFolder, {'ZOOM', 'x.correct'});
targetIm1 = correctResonanceStretch(targetIm1, scanParam, 'imwarp');
targetIm2 = correctResonanceStretch(targetIm2, scanParam, 'imwarp');

if regOpt.doRegister
    targetIm1 = rigid(targetIm1);
    targetIm2 = rigid(targetIm2);
end

targetIm1 = mean(targetIm1, 3);
targetIm2 = mean(targetIm2, 3);

[~, targetIm1] = correct_bidirectional_offset(targetIm1, 1, 10);
[~, targetIm2] = correct_bidirectional_offset(targetIm2, 1, 10);

Y = imrotate(targetIm2, 180, 'bicubic', 'crop');

options_rigid = NoRMCorreSetParms( ...
    'd1', size(Y,1), 'd2', size(Y,2), 'max_shift', 100, ...
    'bin_width', 1, 'us_fac', 50 );

[regIm, nc_shifts] = normcorre(Y, options_rigid, targetIm1);
dx = arrayfun(@(row) row.shifts(2), nc_shifts);
dy = arrayfun(@(row) row.shifts(1), nc_shifts);

imviewer(cat(3,targetIm1, regIm))

% Get scan parameters for recording.
scanParam = getSciScanVariables(recordingFolder, {...
    'x.pixel.sz', 'y.pixel.sz', 'setX', 'setY', 'x.pixels', 'y.pixels'} );

imsize = size(targetIm1);
% xcorr = scanParam.xpixels / imsize(2);

newX = scanParam.setx + (dx/2 * scanParam.xpixelsz * 1e6); %* xcorr;
newY = scanParam.sety + (dy/2 * scanParam.ypixelsz * 1e6);

if ~nargout
    msg = sprintf('\nNew X Position: %.1f \nNew Y Position: %.1f', newX, newY);
    printmsg(msg, app, 'normal')
    clearvars;
end

end

