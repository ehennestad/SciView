function tf = waitForRecordingStarted()
%waitForRecordingStarted Lets user decide to wait or go ahead
% 
%   tf = waitForRecordingStarted() Return true if recording was started, or
%   false if user aborted.

    % Ask user if recording was started
    answer = questdlg('Did you start the recording?');
    if isempty(answer); tf = false; return; end
    
    switch lower(answer)
        case 'yes'
            tf = true;
        case 'no'
            h = msgbox('Press OK when recording has been started', 'Waiting box... ');
            uiwait(h)
            tf = true;
        case 'cancel'
            tf = false;
            return
    end
    
end


