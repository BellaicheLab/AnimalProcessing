function [res] = InputParserPTE(Q)

if isempty(Q)
    % GUI
    res = 'GUI';
else
    switch class(Q)
        case {'char';'string'}
            % KeyWord
            res = 'key';
        case 'cell'
            % multiple boxes or areas
            if isequal(size(Q{1}), [1 2])
                % list of grid compartments
                res = 'LoGC';
            elseif isequal(size(Q{1}), [1 4])
                % rectangle selection of grid comparments
                res = 'RSoGC';
            else
                res = 'invalid';
            end
        otherwise
            res = 'invalid';
    end
end

if strcmp(res,'invalid')
    msg = sprintf(['Wrong input area format, please use folowing :\n' ...
        'Qarea = [ ]                     : Start GUI\n' ...
        'Qarea = keyword                 : Analyse a predifined area\n' ...
        'Qarea = {[x y];[x y];...}       : Analyse corresponding grid box\n' ...
        'Qarea = {[xmin ymin xmax ymax]} : Analyse corresponding area\n']);
    f = errordlg(msg,'LTA Input Error', 'modal');
end

end

%% History %%

% 18/02/2020:
% changed some "res" to more explicit strings

