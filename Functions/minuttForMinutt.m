function minuttForMinutt(recordingFolder, doRegister)
%minuttForMinutt Make a minute-by-minute reference image stack.
%
%   minuttForMinutt(recordingFolderPath, register) where recordingFolderPath 
%   is a string containing the absolute path of the recording folder, and 
%   register can be set to true or false.


if nargin < 1 || isempty(recordingFolder)
    recordingFolder = uigetdir('D:\');
    if recordingFolder == 0; return; end
end

if nargin < 2
    doRegister = false;
end

displayResults = true;

% Check if data already exists
dirs = strsplit(recordingFolder, filesep);
dirs(end:end+1) = dirs(end-1:end);
dirs{end-2} = 'PROCESSED';
savedirPath = fullfile(dirs{:});

if doRegister
    fileName = 'minute_by_minute_rigid.tif';
else
    fileName = 'minute_by_minute_uncorr.tif';
end

if exist(fullfile(savedirPath, 'avg_image_stacks', fileName), 'file')
    imArray = stack2mat(fullfile(savedirPath, 'avg_image_stacks', fileName));
    S = load(fullfile(savedirPath, 'imreg_data', 'image_drift.mat'), 'imageDrift');
    imageDrift = S.imageDrift;
    
else
    % Create a virtual sciscan stack object
    vsss = virtualSciScanStack(recordingFolder);
    vsss.channel = 2;

    meta2p = getSciScanMetaData(recordingFolder);

    fps = meta2p.fps;

    framesPerMinute = fps*60;
    nChunksToGrab = floor(meta2p.nFrames ./ framesPerMinute);

    % Check if file exist with image angular positions
    tdmsListing = dir( fullfile(recordingFolder, '*theta_frame.tdms'));
    if ~isempty(tdmsListing)
        tdmsPathStr = fullfile(recordingFolder, tdmsListing(1).name);
        tdmsData = loadTDMSdata(tdmsPathStr, {'Theta_Frame'});
        nFrames = min([numel(tdmsData.ThetaFrame), meta2p.nFrames]);
        frameInd = find(mod(tdmsData.ThetaFrame(1:nFrames), 360) == 0);
    else
        frameInd = 1:meta2p.nFrames;
    end

    nFramesPerChunk = 150;
    startInd = floor(linspace(1, numel(frameInd)-nFramesPerChunk-1, nChunksToGrab));

    imArray = zeros([meta2p.ypixels, meta2p.xpixels, nChunksToGrab], 'uint16');

    for i = 1:nChunksToGrab
        tmpim = vsss(:,:, frameInd(startInd(i) + (0:nFramesPerChunk)) );
        
        [~, tmpim] = correct_bidirectional_offset(tmpim, 100, 10);       
        if doRegister
            tmpim = rigid(tmpim);
        end
        imArray(:,:,i) = mean(tmpim,3);
    end

    [Reg, ~, ncShifts] = rigid(imArray);
    
    imageDrift = fliplr(squeeze(cat(1, ncShifts.shifts)));

    savedirPath = fullfile(savedirPath, {'avg_image_stacks', 'imreg_data'});
    for i = 1:numel(savedirPath)
        if ~exist(savedirPath{i}, 'dir'); mkdir(savedirPath{i}); end
    end

    % Save results
    mat2stack(makeuint8(imArray), fullfile(savedirPath{1}, fileName))
    save(fullfile(savedirPath{2}, 'image_drift.mat'), 'imageDrift')
end




if displayResults
    
    imviewer(imArray)
    
    cmap = cbrewer('seq', 'YlGnBu', size(imageDrift, 1)-1);
    
    figure; ax = axes; hold on
    for i = 1:size(imageDrift, 1)-1
         plot(imageDrift(i:i+1, 1), imageDrift(i:i+1, 2), '-o', 'Color', cmap(i, :))
    end
         
    axis equal
    maxShift = ceil(max(abs(imageDrift(:))));
    xlim([-maxShift, maxShift])
    ylim([-maxShift, maxShift])
    ax.XTick = -maxShift:maxShift;
    xlabel('Pixels X')
    ax.YTick = -maxShift:maxShift;
    ylabel('Pixels Y')
    title('Minute by minute drift in recorded FOV')

end
