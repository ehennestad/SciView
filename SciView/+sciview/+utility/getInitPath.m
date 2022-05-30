function initPath = getInitPath()
%getInitPath Get init path for uigetdir. 
%
%   This function gets the path depending on a computer. Should be replaced
%   with a preference where user sets this once.

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
    
end