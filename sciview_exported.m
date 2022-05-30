classdef sciview_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        SciViewUIFigure             matlab.ui.Figure
        TabGroup                    matlab.ui.container.TabGroup
        RecordingsTab               matlab.ui.container.Tab
        RecordingsListBox           matlab.ui.control.ListBox
        ProcessedRecordingsTab      matlab.ui.container.Tab
        ProcessedListBox            matlab.ui.control.ListBox
        ReferenceImagesTab          matlab.ui.container.Tab
        ReferenceImagesListBox      matlab.ui.control.ListBox
        RootPathEditFieldLabel      matlab.ui.control.Label
        RootPathEditField           matlab.ui.control.EditField
        BrowseDirButton             matlab.ui.control.Button
        UpdateDirButton             matlab.ui.control.Button
        ViewZStackButton            matlab.ui.control.Button
        FindPlaneButton             matlab.ui.control.Button
        FindRotationCenterButton    matlab.ui.control.Button
        DestretchImagesSwitchLabel  matlab.ui.control.Label
        DestretchImagesSwitch       matlab.ui.control.Switch
        SelectbyMouseDropDownLabel  matlab.ui.control.Label
        SelectbyMouseDropDown       matlab.ui.control.DropDown
        SelectbyDateDropDownLabel   matlab.ui.control.Label
        SelectbyDateDropDown        matlab.ui.control.DropDown
        RigidAlignmentSwitchLabel   matlab.ui.control.Label
        RigidAlignmentSwitch        matlab.ui.control.Switch
        ViewRecordingButton         matlab.ui.control.Button
        MessageWindowListBoxLabel   matlab.ui.control.Label
        MessageWindowListBox        matlab.ui.control.ListBox
        CreateReferenceButton       matlab.ui.control.Button
        ViewReferenceButton         matlab.ui.control.Button
        CheckDriftButton            matlab.ui.control.Button
        AlignSampleButton           matlab.ui.control.Button
        DeleteDirButton             matlab.ui.control.Button
        OpenDirButton               matlab.ui.control.Button
        MoreActionsDropDownLabel    matlab.ui.control.Label
        MoreActionsDropDown         matlab.ui.control.DropDown
    end

    
    properties (Access = private)
        RootPath                    % Root path containing data
        Recordings                  % Struct Array. Contains info about recordings
        Processed                   % Struct Array. Contains info about processed recordings
        Reference                   % Struct Array. Contains info about reference images
        FileDeletion = struct('InitMessageDisplayed', false, 'FilesInTrash', false)
    end
    
    
    methods (Access = private)
        
        function listRootDir(app)
        % listRootDir List and organize contents of root directory into
        
            % First look for SciScan Recordings. Folders should always
            % start with the numbers of the year.
            dateListing = dir(fullfile(app.RootPath, '20*')); % Only works in the 21st century-.-
            
            % Make cell arrays for recording directory paths, experiment
            % names and dates
            recordingPaths = {};
            experimentNames = {};
            recordingDates = {};
            
            for i = 1:numel(dateListing)
                dateFolderName =  dateListing(i).name;
                recListing = dir(fullfile(app.RootPath, dateFolderName, strcat(dateFolderName(1:4), '*'))); 
                newPaths = fullfile(app.RootPath, dateFolderName, {recListing(:).name});
                recordingPaths = cat(1, recordingPaths, newPaths');
                newExpNames = cellfun(@(str) str(1:end), {recListing.name}, 'uni', 0)';
                experimentNames = cat(1, experimentNames, newExpNames);
                recordingDates = cat(1, recordingDates, repmat({dateFolderName(1:10)}, [numel(newPaths), 1]));
            end
            
            % Find mouse numbers for each recording.
            mouseNumbers = regexp(experimentNames, 'm\d{4}', 'match');
            emptyCells = cellfun(@(cel) isempty(cel), mouseNumbers, 'uni', 1);
            mouseNumbers(emptyCells) = {{'n/a'}};
            mouseNumbers = cellfun(@(cel) cel{1}, mouseNumbers, 'uni', 0);
            
            app.Recordings = struct('Path', recordingPaths, ...
                                    'Name', experimentNames, ...
                                    'Date', recordingDates, ...
                                    'Mnum', mouseNumbers);
           
            % List contents of Reference Image Folder
            subDirs = {'FOV Images', 'Dura Images', 'Brain Surface'};
            refType = {'FOV', 'Dura Images', 'Brain Surface'};
            fnameExpr = {'*fov_image_8bit.tif', '*image_8bit.tif', '*.jpg'};
            
            app.Reference = struct( 'Name', {}, 'Path', {}, 'Date', {}, ...
                        'Mnum', {}, 'Type', {} );

            fovImPath = fullfile(app.RootPath, 'Reference Images', subDirs);

            for i = 1:numel(fovImPath)
            
                imListing = dir(fullfile(fovImPath{i}, fnameExpr{i}));
                fileNames = {imListing(:).name};
            
                % Find mouse numbers for each recording.
                mouseNumbers = regexp(fileNames, 'm\d{4}', 'match', 'once');
                emptyCells = cellfun(@(cel) isempty(cel), mouseNumbers, 'uni', 1);
                mouseNumbers(emptyCells) = {'n/a'};
                    
                dateExpr = '\d{8}|\d{4}_\d{2}_\d{2}|\d{4}-\d{2}-\d{2}';
                dates = regexp(fileNames, dateExpr, 'match', 'once');
                
                emptyCells = isempty(dates);
                dates(emptyCells) = {'n/a'};
            
                for j = 1:numel(dates)
                    if numel(dates{j})==8
                        dates{j} = strcat(dates{j}(1:4), '_', dates{j}(5:6), '_', dates{j}(7:8));
                    elseif numel(dates{j})==10
                        dates{j} = strrep(dates{j}, '-', '_');
                    else
                        dates{j} = 'n/a';
                    end
                end
            
                app.Reference = cat(1, app.Reference, struct('Name', fileNames, ...
                                            'Path', fullfile(fovImPath{i}, fileNames), ...
                                            'Date', dates, ...
                                            'Mnum', mouseNumbers, ...
                                            'Type', refType{i} )');
            end
            
            % Todo; Get Processed

                              
            app.updateSelectionPopup();                  
            app.updateListbox();
            
        end
        
    
        function updateSelectionPopup(app)
            % Update mouse listbox
            
            mouseNumbers = unique(cat(2, {app.Recordings(:).Mnum}, {app.Reference(:).Mnum}));
            mouseNumbers = setdiff(mouseNumbers, {'m', 'n/a'});
            
%             currentValue = app.SelectbyMouseDropDown.Value;
%             app.SelectbyMouseDropDown.Items = setdiff(app.SelectbyMouseDropDown.Items, {'Show All', 'n/a'});
            if isempty(mouseNumbers)
                app.SelectbyMouseDropDown.Items = {'Show All'};
            else
                app.SelectbyMouseDropDown.Items = cat(2, {'Show All'}, mouseNumbers);
            end
%             app.SelectbyMouseDropDown.Items = setdiff(app.SelectbyMouseDropDown.Items, {'m', 'n/a'});

            dates = unique(cat(2, {app.Recordings(:).Date}, {app.Reference(:).Date}));
            if isempty(dates)
                app.SelectbyDateDropDown.Items = {'Show All'};
            else
                app.SelectbyDateDropDown.Items = cat(2, {'Show All'}, dates);
            end
            
%             
%             
% %             currentValue = app.SelectbyDateDropDown.Value;     
%             app.SelectbyDateDropDown.Items = setdiff(app.SelectbyDateDropDown.Items, 'Show All');
%             app.SelectbyDateDropDown.Items = cat(2, 'Show All', ...
%                 union(app.SelectbyDateDropDown.Items, dates));
            
            % Todo: It value is not part of items, reset value to select
            if ~contains(app.SelectbyMouseDropDown.Items, app.SelectbyMouseDropDown.Value)
                app.SelectbyMouseDropDown.Value = 'Show All';
            end
            
            if ~contains(app.SelectbyDateDropDown.Items, app.SelectbyDateDropDown.Value)
                app.SelectbyDateDropDown.Value = 'Show All';
            end
            
        end
        
    
        function updateListbox(app)
        %updateListbox Updates listboxes based on popup selection    
            
            % Numbers for all recordings
            ind1 = 1:numel(app.Recordings);
            ind2 = 1:numel(app.Reference);
            
            % Filter numbers if a mouse number is selected
            if ~isequal(app.SelectbyMouseDropDown.Value, 'Show All')
                ind1 = ind1 & contains({app.Recordings(:).Mnum}, app.SelectbyMouseDropDown.Value);
                ind2 = ind2 & contains({app.Reference(:).Mnum}, app.SelectbyMouseDropDown.Value);
            end
            
            % Filter numbers if a date is selected
            if ~isequal(app.SelectbyDateDropDown.Value, 'Show All')
                ind1 = ind1 & contains({app.Recordings(:).Date}, app.SelectbyDateDropDown.Value);
                ind2 = ind2 & contains({app.Reference(:).Date}, app.SelectbyDateDropDown.Value);

            end
            
            app.RecordingsListBox.Items = {app.Recordings(ind1).Name};
            app.ReferenceImagesListBox.Items = {app.Reference(ind2).Name};
        end

    
        
        function regOpt = getRegOpt(app)
            
            regOpt = struct;
            
            switch app.RigidAlignmentSwitch.Value
                case 'on'
                    regOpt.doRegister = true;
                case 'off'
                    regOpt.doRegister = false;
            end
            
            switch app.DestretchImagesSwitch.Value
                case 'on'
                    regOpt.doDestretch = true;
                case 'off'
                    regOpt.doDestretch = false;
            end
            
            regOpt.doNonrigid = false;
            regOpt.doParallel = true;
            
        end

    end
    
    methods (Access = public)
        
       function printMessage(app, msg, mode)
       %printMessage Print a message in the app's message window
       %
       %    app.printMessage(msgString, mode) where msgString is a string containing a message
       %    and mode is 'normal', 'append' or 'replace'.      
       
            switch mode
                case 'append'
                    app.MessageWindowListBox.Items{end} = strcat(app.MessageWindowListBox.Items{end}, ' ', msg);
                case 'normal'
                    app.MessageWindowListBox.Items{end+1} = msg;
                case 'replace'
                    app.MessageWindowListBox.Items{end} = msg;
            end
            drawnow
            scroll(app.MessageWindowListBox,'bottom')
            drawnow
       end
   
       function  hideGui(app)
           app.SciViewUIFigure.Visible = 'off';
       end
    
       function showGui(app)
          app.SciViewUIFigure.Visible = 'on';
       end
   
        function rootPath = getRootPath(app)
            rootPath = app.RootPath;
        end
   
   
    end
    

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            screenSize = get(0, 'ScreenSize');
            figSize = app.SciViewUIFigure.Position(3:4);
            app.SciViewUIFigure.Position(1) = screenSize(3) - figSize(1) - 10;
            app.SciViewUIFigure.Position(2) = 50;
%             app.MessageWindowListBox.Scrollable = 'on';
        end

        % Button pushed function: BrowseDirButton
        function BrowseDirButtonPushed(app, event)
            if ispc
                switch getenv('username')
                    case 'labuser'  %OS2
                        initPath = 'E:\';
                    case 'Tekla'    %OS1
                        initPath = 'D:\';
                    otherwise
                        initPath = '';
                end
            else
                initPath = '';
            end
            
            % Open dialog to select folder
            selectedPath = uigetdir(initPath);
            
            if ~isequal(selectedPath, 0) % Folder was selected
                % Assign selected folder to RootDir property and refresh folder lsit
                app.RootPath = selectedPath;
                app.RootPathEditField.Value = app.RootPath;
                app.listRootDir()
            end % Else: User canceled (nothing todo)

            figure(app.SciViewUIFigure)
        end

        % Button pushed function: ViewRecordingButton
        function ViewRecordingButtonPushed(app, event)
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            pathStr = app.Recordings(listInd).Path;
            imListing = dir(fullfile(pathStr, '*.raw'));
            pathStr = fullfile(pathStr, imListing(1).name);
            
            ivObj = imviewer(pathStr);
            ivObj.fig.Name = sprintf('%s', app.Recordings(listInd).Name);
            
            dispMsg = sprintf('Opened %s \n',  app.RecordingsListBox.Value{1});
            
            app.MessageWindowListBox.Items{end+1} = dispMsg;
            drawnow
            scroll(app.MessageWindowListBox,'bottom')
            drawnow

        end

        % Button pushed function: UpdateDirButton
        function UpdateDirButtonPushed(app, event)
             app.listRootDir()
        end

        % Value changed function: SelectbyMouseDropDown
        function SelectbyMouseDropDownValueChanged(app, event)
            app.updateListbox()
        end

        % Value changed function: SelectbyDateDropDown
        function SelectbyDateDropDownValueChanged(app, event)
            app.updateListbox()
        end

        % Button pushed function: FindRotationCenterButton
        function FindRotationCenterButtonPushed(app, event)
            
            regOpt = app.getRegOpt();
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            recordingFolder = app.Recordings(listInd).Path;
            
            findStageCenterPosition(recordingFolder, regOpt, app);

        end

        % Button pushed function: FindPlaneButton
        function FindPlaneButtonPushed(app, event)
            refImInd = contains({app.Reference(:).Name}, app.ReferenceImagesListBox.Value);
            refImPath = app.Reference(refImInd).Path;
            refImPath = strrep(refImPath, 'fov_image_8bit.tif', 'fov_image.tif'); % The 8bit image is just for viewing, use original 16bit for comparison with zstack
            referenceImage = imread(refImPath);
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            recordingFolder = app.Recordings(listInd).Path;
            
            [x, y, z] = findMatchingPlane(recordingFolder, referenceImage, app);
            
            dispMsg = sprintf('\nNew X Position: %.1f \nNew Y Position: %.1f \nNew Z Position: %.1f \n', x, y, z);
            app.MessageWindowListBox.Items{end+1} = dispMsg;
            drawnow
            scroll(app.MessageWindowListBox,'bottom')
            drawnow
        end

        % Button pushed function: CreateReferenceButton
        function CreateReferenceButtonPushed(app, event)
%           regOpt = app.getRegOpt;
            % Use default regopt for this function, register and destretch
             
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            recordingFolder = {app.Recordings(listInd).Path};
            
            for i = 1:numel(recordingFolder)
                currentFolder = recordingFolder{i};
                if any(contains(currentFolder, {'dura', 'zero'}))
                    createDuraImage(currentFolder, [], app)
                else
                    createFovImage(currentFolder, [], app)
                end
            end
            
        end

        % Button pushed function: ViewReferenceButton
        function ViewReferenceButtonPushed(app, event)
            listInd = find(contains({app.Reference(:).Name}, app.ReferenceImagesListBox.Value));

            % Sort indices according to ref image type
            imTypes = {app.Reference(listInd).Type};
            listInd = cat(2, listInd(contains(imTypes, 'Brain Surface')), ...
                listInd(contains(imTypes, 'Dura')), ...
                listInd(contains(imTypes, 'FOV')));
            
            nImages = numel(listInd);
           
            % Load ref images into array.
            ReferenceImages = zeros(512,512, nImages, 'uint8');
            
            for i = 1:nImages
                im = uint8(imread(app.Reference(listInd(i)).Path));
                maxsize = max(size(im));
                resizeFactor = 512/maxsize;
                im = imresize(im(:,:,1), resizeFactor);
                
                imCenter = size(im)/2;
                indX = (1:size(im,2)) - round(imCenter(2)) + 256;
                indY = (1:size(im,1)) - round(imCenter(1)) + 256;
                ReferenceImages(indY, indX, i) = im;
            end
            
            ivObj = imviewer(ReferenceImages);
            ivObj.fig.Position(1:2) = [1060, 43];

        end

        % Button pushed function: ViewZStackButton
        function ViewZStackButtonPushed(app, event)
            
            regOpt = app.getRegOpt();
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            pathStr = app.Recordings(listInd).Path;
    
            zStack = makeZstack(pathStr, regOpt, app);
            if ~isempty(zStack);  ivObj = imviewer(zStack); end
            ivObj.fig.Name = sprintf('Z Stack: %s', app.Recordings(listInd).Name);
            
        end

        % Button pushed function: CheckDriftButton
        function CheckDriftButtonPushed(app, event)
            
            regOpt = app.getRegOpt();
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            pathStr = app.Recordings(listInd).Path;
            
            minuttForMinutt(pathStr, regOpt.doRegister)
        end

        % Button pushed function: AlignSampleButton
        function AlignSampleButtonPushed(app, event)
            regOpt = app.getRegOpt();
            
            listInd = contains({app.Recordings(:).Name}, app.RecordingsListBox.Value);
            recordingFolder = app.Recordings(listInd).Path;
            
            answer = inputdlg({'Enter First Frame', 'Enter Number of Frames'});
            
            if isempty(answer)
                return
            else
                vsss = virtualSciScanStack(recordingFolder);
                vsss.channel = 2;
                
                nFrames = min([size(vsss, 3), str2double(answer{2})]);
                frameInd = (str2double(answer{1})-1) + (1:nFrames);
                imArray = vsss(:,:,frameInd);
                
                app.printMessage('Destretching images...', 'normal')
                % Correct Resonance Stretch
                if regOpt.doDestretch
                    scanParam = getSciScanVariables(recordingFolder, {'ZOOM', 'x.correct'});
                    imArray = correctResonanceStretch(imArray, scanParam, 'imwarp');
                end
                app.printMessage('finished.', 'append')
                
                app.printMessage('Correcting bidir offset...', 'normal')
                [~, imArray] = correct_bidirectional_offset(imArray, size(imArray, 3), 10);
                app.printMessage('finished.', 'append')
                
                app.printMessage('Aligning images...', 'normal')
                imArray = rigid(imArray);
                app.printMessage('finished.', 'append')
                
                imviewer(imArray);
                                
            end
            
        end

        % Button pushed function: DeleteDirButton
        function DeleteDirButtonPushed(app, event)
            listInd = find(contains({app.Recordings(:).Name}, app.RecordingsListBox.Value));
            
            if isempty(listInd)
                return
            end
            
            if ~app.FileDeletion.InitMessageDisplayed
               msg = 'This will move the selected folder(s) to the trashbin. This message will not be displayed again.';
               app.FileDeletion.InitMessageDisplayed = true;
               app.hideGui()
               answer = questdlg(msg, 'File Removal Disclaimer', 'Confirm', 'Cancel', 'Confirm');
               app.showGui()
               if strcmpi(answer, 'cancel')
                   return
               end
            end
            
%             if strcmp(app.SciViewUIFigure.CurrentCharacter, 'shift')
%                 oldState = recycle('off');
%             else
                oldState = recycle('on');
                app.FileDeletion.FilesInTrash = true;
%             end

            for i = listInd
                recordingFolder = app.Recordings(i).Path;
                L = dir(recordingFolder);
                
                for j = 1:numel(L)
    
                    if strcmp(L(j).name, '.') || strcmp(L(j).name, '..') 
                        continue
                    elseif L(j).isdir
                        rmdir(fullfile(recordingFolder, L(j).name))
                    else
                        delete(fullfile(recordingFolder, L(j).name))
                    end
                end
                app.printMessage('Moved folder content to recycling bin', 'normal')
                rmdir(recordingFolder)
            end
            
            recycle(oldState)
            
            app.listRootDir()
        end

        % Close request function: SciViewUIFigure
        function SciViewUIFigureCloseRequest(app, event)
            
            if app.FileDeletion.FilesInTrash
               msgbox('Files were moved to the trash during this session. Please be a good citizen and clean up after yourself.', 'Kind Reminder') 
            end
            delete(app)

        end

        % Button pushed function: OpenDirButton
        function OpenDirButtonPushed(app, event)
            listInd = find(contains({app.Recordings(:).Name}, app.RecordingsListBox.Value));
            
            if isempty(listInd)
                return
            end
            
            for i = listInd
                recordingFolder = app.Recordings(i).Path;
                if isunix
                    [status, ~] = unix(sprintf('open -a finder ''%s''', recordingFolder));
                elseif ispc
                    winopen(recordingFolder)
                end
            end
            

            
        end

        % Value changed function: MoreActionsDropDown
        function MoreActionsDropDownValueChanged(app, event)
            value = app.MoreActionsDropDown.Value;
           
            listInd = find(contains({app.Recordings(:).Name}, app.RecordingsListBox.Value));

            app.MoreActionsDropDown.Value = 'Select...';
            
            for i = listInd
            
                switch value
                    case {'Rename Experiment', 'Change Experiment Type'}
                        app.hideGui()
                        try
                            renameSciScanExperiment(app.Recordings(i).Path, value)
                        catch ME
                            app.showGui
                            error(ME.message)
                        end
                        app.showGui
                        
                        
                    case 'Open Ini File'
                        L = dir(fullfile(app.Recordings(i).Path, '*.ini'));
                        winopen(fullfile(app.Recordings(i).Path, L(1).name))
                    case 'Align Recording Eivind'
                        alignRecordingEivind(app.Recordings(i).Path)
                    case 'Monitor Z-Drift'
                        monitorZDrift(app.Recordings(i).Path, app)
                    case 'Join Raw-files'
                        joinRawFiles(app.Recordings(i).Path, app)
                    case 'Save Surface Image'
                        saveSurfaceImage(app.Recordings(i).Path, app)
                end
                
            end
            
            app.listRootDir()
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create SciViewUIFigure
            app.SciViewUIFigure = uifigure;
            app.SciViewUIFigure.Position = [55 55 1040 270];
            app.SciViewUIFigure.Name = 'SciView';
            app.SciViewUIFigure.CloseRequestFcn = createCallbackFcn(app, @SciViewUIFigureCloseRequest, true);

            % Create TabGroup
            app.TabGroup = uitabgroup(app.SciViewUIFigure);
            app.TabGroup.Position = [10 10 400 205];

            % Create RecordingsTab
            app.RecordingsTab = uitab(app.TabGroup);
            app.RecordingsTab.Title = 'Recordings';

            % Create RecordingsListBox
            app.RecordingsListBox = uilistbox(app.RecordingsTab);
            app.RecordingsListBox.Items = {};
            app.RecordingsListBox.Multiselect = 'on';
            app.RecordingsListBox.Position = [0 0 400 179];
            app.RecordingsListBox.Value = {};

            % Create ProcessedRecordingsTab
            app.ProcessedRecordingsTab = uitab(app.TabGroup);
            app.ProcessedRecordingsTab.Title = 'Processed Recordings';

            % Create ProcessedListBox
            app.ProcessedListBox = uilistbox(app.ProcessedRecordingsTab);
            app.ProcessedListBox.Items = {'Not Implemented Yet'};
            app.ProcessedListBox.Position = [0 0 400 179];
            app.ProcessedListBox.Value = 'Not Implemented Yet';

            % Create ReferenceImagesTab
            app.ReferenceImagesTab = uitab(app.TabGroup);
            app.ReferenceImagesTab.Title = 'Reference Images';

            % Create ReferenceImagesListBox
            app.ReferenceImagesListBox = uilistbox(app.ReferenceImagesTab);
            app.ReferenceImagesListBox.Items = {};
            app.ReferenceImagesListBox.Multiselect = 'on';
            app.ReferenceImagesListBox.Position = [0 0 400 179];
            app.ReferenceImagesListBox.Value = {};

            % Create RootPathEditFieldLabel
            app.RootPathEditFieldLabel = uilabel(app.SciViewUIFigure);
            app.RootPathEditFieldLabel.HorizontalAlignment = 'right';
            app.RootPathEditFieldLabel.Position = [42 234 59 22];
            app.RootPathEditFieldLabel.Text = 'Root Path';

            % Create RootPathEditField
            app.RootPathEditField = uieditfield(app.SciViewUIFigure, 'text');
            app.RootPathEditField.Position = [111 234 205 22];

            % Create BrowseDirButton
            app.BrowseDirButton = uibutton(app.SciViewUIFigure, 'push');
            app.BrowseDirButton.ButtonPushedFcn = createCallbackFcn(app, @BrowseDirButtonPushed, true);
            app.BrowseDirButton.Position = [325 234 22 22];
            app.BrowseDirButton.Text = '...';

            % Create UpdateDirButton
            app.UpdateDirButton = uibutton(app.SciViewUIFigure, 'push');
            app.UpdateDirButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateDirButtonPushed, true);
            app.UpdateDirButton.Icon = 'refresh_icon.jpg';
            app.UpdateDirButton.IconAlignment = 'center';
            app.UpdateDirButton.Position = [356 234 22 22];
            app.UpdateDirButton.Text = '';

            % Create ViewZStackButton
            app.ViewZStackButton = uibutton(app.SciViewUIFigure, 'push');
            app.ViewZStackButton.ButtonPushedFcn = createCallbackFcn(app, @ViewZStackButtonPushed, true);
            app.ViewZStackButton.Position = [802 234 100 22];
            app.ViewZStackButton.Text = 'View Z-Stack';

            % Create FindPlaneButton
            app.FindPlaneButton = uibutton(app.SciViewUIFigure, 'push');
            app.FindPlaneButton.ButtonPushedFcn = createCallbackFcn(app, @FindPlaneButtonPushed, true);
            app.FindPlaneButton.Position = [735 199 100 22];
            app.FindPlaneButton.Text = 'Find Plane';

            % Create FindRotationCenterButton
            app.FindRotationCenterButton = uibutton(app.SciViewUIFigure, 'push');
            app.FindRotationCenterButton.ButtonPushedFcn = createCallbackFcn(app, @FindRotationCenterButtonPushed, true);
            app.FindRotationCenterButton.Position = [870 199 126 22];
            app.FindRotationCenterButton.Text = 'Find Rotation Center';

            % Create DestretchImagesSwitchLabel
            app.DestretchImagesSwitchLabel = uilabel(app.SciViewUIFigure);
            app.DestretchImagesSwitchLabel.HorizontalAlignment = 'center';
            app.DestretchImagesSwitchLabel.Position = [904 100 100 22];
            app.DestretchImagesSwitchLabel.Text = 'Destretch Images';

            % Create DestretchImagesSwitch
            app.DestretchImagesSwitch = uiswitch(app.SciViewUIFigure, 'slider');
            app.DestretchImagesSwitch.Items = {'on', 'off'};
            app.DestretchImagesSwitch.Position = [928 76 52 23];
            app.DestretchImagesSwitch.Value = 'on';

            % Create SelectbyMouseDropDownLabel
            app.SelectbyMouseDropDownLabel = uilabel(app.SciViewUIFigure);
            app.SelectbyMouseDropDownLabel.HorizontalAlignment = 'right';
            app.SelectbyMouseDropDownLabel.Position = [452 234 94 22];
            app.SelectbyMouseDropDownLabel.Text = 'Select by Mouse';

            % Create SelectbyMouseDropDown
            app.SelectbyMouseDropDown = uidropdown(app.SciViewUIFigure);
            app.SelectbyMouseDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectbyMouseDropDownValueChanged, true);
            app.SelectbyMouseDropDown.Position = [551 234 82 22];

            % Create SelectbyDateDropDownLabel
            app.SelectbyDateDropDownLabel = uilabel(app.SciViewUIFigure);
            app.SelectbyDateDropDownLabel.HorizontalAlignment = 'right';
            app.SelectbyDateDropDownLabel.Position = [459 199 84 22];
            app.SelectbyDateDropDownLabel.Text = 'Select by Date';

            % Create SelectbyDateDropDown
            app.SelectbyDateDropDown = uidropdown(app.SciViewUIFigure);
            app.SelectbyDateDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectbyDateDropDownValueChanged, true);
            app.SelectbyDateDropDown.Position = [551 199 82 22];

            % Create RigidAlignmentSwitchLabel
            app.RigidAlignmentSwitchLabel = uilabel(app.SciViewUIFigure);
            app.RigidAlignmentSwitchLabel.HorizontalAlignment = 'center';
            app.RigidAlignmentSwitchLabel.Position = [906 34 90 22];
            app.RigidAlignmentSwitchLabel.Text = 'Rigid Alignment';

            % Create RigidAlignmentSwitch
            app.RigidAlignmentSwitch = uiswitch(app.SciViewUIFigure, 'slider');
            app.RigidAlignmentSwitch.Items = {'on', 'off'};
            app.RigidAlignmentSwitch.Position = [930 11 52 23];
            app.RigidAlignmentSwitch.Value = 'off';

            % Create ViewRecordingButton
            app.ViewRecordingButton = uibutton(app.SciViewUIFigure, 'push');
            app.ViewRecordingButton.ButtonPushedFcn = createCallbackFcn(app, @ViewRecordingButtonPushed, true);
            app.ViewRecordingButton.Position = [675 234 100 22];
            app.ViewRecordingButton.Text = 'View Recording';

            % Create MessageWindowListBoxLabel
            app.MessageWindowListBoxLabel = uilabel(app.SciViewUIFigure);
            app.MessageWindowListBoxLabel.HorizontalAlignment = 'right';
            app.MessageWindowListBoxLabel.Position = [417 129 100 22];
            app.MessageWindowListBoxLabel.Text = 'Message Window';

            % Create MessageWindowListBox
            app.MessageWindowListBox = uilistbox(app.SciViewUIFigure);
            app.MessageWindowListBox.Items = {};
            app.MessageWindowListBox.Position = [427 10 464 117];
            app.MessageWindowListBox.Value = {};

            % Create CreateReferenceButton
            app.CreateReferenceButton = uibutton(app.SciViewUIFigure, 'push');
            app.CreateReferenceButton.ButtonPushedFcn = createCallbackFcn(app, @CreateReferenceButtonPushed, true);
            app.CreateReferenceButton.Position = [670 162 110 22];
            app.CreateReferenceButton.Text = 'Create Reference';

            % Create ViewReferenceButton
            app.ViewReferenceButton = uibutton(app.SciViewUIFigure, 'push');
            app.ViewReferenceButton.ButtonPushedFcn = createCallbackFcn(app, @ViewReferenceButtonPushed, true);
            app.ViewReferenceButton.Position = [928 234 100 22];
            app.ViewReferenceButton.Text = 'View Reference';

            % Create CheckDriftButton
            app.CheckDriftButton = uibutton(app.SciViewUIFigure, 'push');
            app.CheckDriftButton.ButtonPushedFcn = createCallbackFcn(app, @CheckDriftButtonPushed, true);
            app.CheckDriftButton.Position = [802 162 100 22];
            app.CheckDriftButton.Text = 'Check Drift';

            % Create AlignSampleButton
            app.AlignSampleButton = uibutton(app.SciViewUIFigure, 'push');
            app.AlignSampleButton.ButtonPushedFcn = createCallbackFcn(app, @AlignSampleButtonPushed, true);
            app.AlignSampleButton.Position = [928 162 100 22];
            app.AlignSampleButton.Text = 'Align Sample';

            % Create DeleteDirButton
            app.DeleteDirButton = uibutton(app.SciViewUIFigure, 'push');
            app.DeleteDirButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteDirButtonPushed, true);
            app.DeleteDirButton.Icon = 'trash_icon.jpg';
            app.DeleteDirButton.IconAlignment = 'center';
            app.DeleteDirButton.Position = [10 234 22 22];
            app.DeleteDirButton.Text = '';

            % Create OpenDirButton
            app.OpenDirButton = uibutton(app.SciViewUIFigure, 'push');
            app.OpenDirButton.ButtonPushedFcn = createCallbackFcn(app, @OpenDirButtonPushed, true);
            app.OpenDirButton.Icon = 'open_icon.png';
            app.OpenDirButton.IconAlignment = 'center';
            app.OpenDirButton.Position = [387 234 22 22];
            app.OpenDirButton.Text = '';

            % Create MoreActionsDropDownLabel
            app.MoreActionsDropDownLabel = uilabel(app.SciViewUIFigure);
            app.MoreActionsDropDownLabel.HorizontalAlignment = 'right';
            app.MoreActionsDropDownLabel.Position = [460 162 76 22];
            app.MoreActionsDropDownLabel.Text = 'More Actions';

            % Create MoreActionsDropDown
            app.MoreActionsDropDown = uidropdown(app.SciViewUIFigure);
            app.MoreActionsDropDown.Items = {'Select...', 'Rename Experiment', 'Change Experiment Type', 'Open Ini File', 'Align Recording Eivind', 'Monitor Z-Drift', 'Join Raw-files', 'Save Surface Image'};
            app.MoreActionsDropDown.ValueChangedFcn = createCallbackFcn(app, @MoreActionsDropDownValueChanged, true);
            app.MoreActionsDropDown.Position = [551 162 82 22];
            app.MoreActionsDropDown.Value = 'Select...';
        end
    end

    methods (Access = public)

        % Construct app
        function app = sciview_exported

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.SciViewUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.SciViewUIFigure)
        end
    end
end