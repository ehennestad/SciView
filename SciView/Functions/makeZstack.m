function [zStack, cLims] = makeZstack(recordingFolder, regOpt, app)

zStack = [];
cLims = []; 

if nargin < 1 || isempty(recordingFolder)
    recordingFolder = uigetdir('D:\');
    if recordingFolder == 0; return; end
end

if nargin < 2
    regOpt = struct;
    regOpt.doDestretch = false;
    regOpt.doRegister = false;
    regOpt.doNonrigid = false;
    regOpt.doParallel = false;
end

regOpt.batchSize = 1000;

if nargin < 3
    app = [];
end

% Check if recording is a zstack
scanParam = getSciScanVariables(recordingFolder, {'experiment.type'});
if ~isequal(scanParam.experimenttype, 'XYTZ')
    if isempty(app)
        error('This is not a zstack recording')
    else
        errordlg('This is not a Z Stack recording')
    end
end

% Check if data already exists
dirs = strsplit(recordingFolder, filesep);
dirs(end:end+1) = dirs(end-1:end);
dirs{end-2} = 'PROCESSED';
if ismac && isempty(dirs{1})
    savedirPath = fullfile(filesep, dirs{:});
else
    savedirPath = fullfile(dirs{:});
end

fileNames = {'plane_avg_zstack_nonrigid.tif', 'plane_avg_zstack_rigid.tif', 'plane_avg_zstack_uncorr.tif'};
filePaths = fullfile(savedirPath, 'avg_image_stacks', fileNames);
existFile = cellfun(@(fp) exist(fp, 'file'), filePaths);

if regOpt.doRegister && regOpt.doNonrigid
    fileInd = 1; 
elseif regOpt.doRegister && ~regOpt.doNonrigid
    fileInd = 1:2;
else
    fileInd = 1:3;
end

if any(existFile(fileInd))
    fileInd = find(existFile(fileInd)~=0, 1, 'first');
    zStack = stack2mat(filePaths{fileInd});
    S = load( strrep(filePaths{fileInd}, '.tif', '_clims.mat'), 'cLims' );
    cLims = S.cLims;
    
    printmsg('Loaded Z-Stack from disk.', app)
else
    printmsg('Processing Z-stack...', app)

    % Create a virtual sciscan stack object
    vsss = virtualSciScanStack(recordingFolder);
    imSize = size(vsss);

    % Load all the images
    printmsg('Loading images...', app)
    imArray = vsss(:, :, 1:imSize(3));
    
    imArray = correctLineByLineBrightnessDifference(imArray);

    
    printmsg('done.', app, 'append')
    
    % Correct Resonance Stretch. Do in batched because it is memory
    % expensive
% %     if regOpt.doDestretch
% %         printmsg('Destretching images...', app)
% %         scanParam = getSciScanVariables(recordingFolder, {'ZOOM', 'x.correct'});
% %         
% %         for tmpFirst = 1:regOpt.batchSize:imSize(3)
% %             if tmpFirst + regOpt.batchSize > imSize(3)
% %                 tmpLast = imSize(3);
% %             else
% %                 tmpLast = tmpFirst + regOpt.batchSize - 1;
% %             end
% %             subArrayDs = correctResonanceStretch(imArray(:,:,tmpFirst:tmpLast), scanParam, 'imwarp');
% %             if tmpFirst == 1
% %                 imArrayDs = zeros(size(subArrayDs,1), size(subArrayDs,2), imSize(3), 'like', imArray);
% %             end
% %             imArrayDs(:, :, tmpFirst:tmpLast) = subArrayDs;
% %             
% %             printmsg(sprintf('Destretching images... %d%%', round(tmpLast/imSize(3)*100)), app, 'replace')
% %             
% %         end
% %         
% %         imArray = imArrayDs;
% %         clearvars imArrayDs subArrayDs
% %         
% %         imSize = size(imArray);
% %         printmsg('Destretching images...done.', app, 'replace')
% %     end

    % Get scan parameters for zstack.
    scanParam = getSciScanVariables(recordingFolder, {...
        'x.pixel.sz', 'y.pixel.sz', 'z.spacing', 'no.of.planes', ...
        'frames.per.plane', 'setX', 'setY', 'setZ', 'x.pixels', 'y.pixels'} );

    nPlanes = scanParam.noofplanes;
    planeInd = repmat(1:nPlanes, [scanParam.framesperplane, 1]);

    printmsg('Creating average image for each plane...', app)
    zStack = zeros([imSize(1:2), nPlanes], 'single');
    % Go through planes and load each plane
    
    if regOpt.doRegister
        cLims(1) = prctile(imArray(:), 0.05);
        cLims(2) = prctile(imArray(:), 99.95);
    else
        cLims = [];
    end
    
    if regOpt.doParallel
        imArray = arrayfun(@(i) imArray(:,:,planeInd==i), 1:nPlanes, 'uni', 0 );
        nWorkers = 6;
    else
        nWorkers = 1;
    end

    
    parfor (i = 1:nPlanes, nWorkers)
%     for i = 1:nPlanes  
        if regOpt.doParallel
            Ytmp = imArray{i};
        else
            Ytmp = imArray(:,:,planeInd==i);
        end
        if regOpt.doRegister
            
            if ~regOpt.doParallel
                printmsg(sprintf('Aligning plane %d/%d...', i, nPlanes), app, 'replace')
            end
            
%             options_rigid = NoRMCorreSetParms( ...
%                 'd1', size(Y,1), 'd2', size(Y,2), 'max_shift', 15, ...
%                 'bin_width', scanParam.framesperplane, 'us_fac', 50, );
% 
%             [Y, ~, ~] = normcorre(Y, options_rigid);
            
            if regOpt.doNonrigid
                Ytmp = nonrigid(Ytmp, [], '4x1');
            else
                Ytmp = rigid(Ytmp, [], 'fft');
            end
            
            Ytmp = sort(Ytmp, 3, 'MissingPlacement', 'last');
            
            Ytmp = Ytmp(:, :, 1:round(scanParam.framesperplane*0.75));
            
            meanIm = nanmean(Ytmp, 3);
            meanIm(isnan(meanIm))= cLims(1);
        else
            meanIm = median(Ytmp, 3);
        end

        [~, M] = correct_bidirectional_offset(meanIm, 1, 10);

        zStack(:, :, i) = M;

    end
    printmsg('done.', app, 'append')
    
    if regOpt.doDestretch
        % Destretch after alignment (Assuming that motion is not dramatic)
        scanParam = getSciScanVariables(recordingFolder, {'ZOOM', 'x.correct'});
        zStack = correctResonanceStretch(zStack, scanParam, 'imwarp');
    end 
    
    zStack = makeuint8(zStack, cLims);

    % Save zstack
    fileName =  fileNames{fileInd(end)};
    savedirPath = fullfile(savedirPath, 'avg_image_stacks');
    if ~exist(savedirPath, 'dir'); mkdir(savedirPath); end
    mat2stack(uint8(zStack), fullfile(savedirPath, fileName))
    
    save( strrep(fullfile(savedirPath, fileName), '.tif', '_clims.mat'), 'cLims' )
end

if nargout == 1
    clear cLims
end



end