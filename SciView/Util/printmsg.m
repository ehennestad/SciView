function printmsg(msg, app, mode)

    if nargin < 3 % Only for app.
        mode = 'normal';
    end

    if isempty(app)
        if isequal(msg, 'done.'); msg = sprintf(' done.\n'); end
        fprintf('%s', msg)
    elseif isa(app, 'sciview') || isa(app, 'sciview_exported')
        app.printMessage(msg, mode)
    else
        error('Provided app is not compatible with the current function')
    end

end
