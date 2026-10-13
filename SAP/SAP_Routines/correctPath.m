function correctedPath = correctPath(rawPath)
    % Escape the parentheses
    escapedPath = strrep(rawPath, '(', '\(');
    escapedPath = strrep(escapedPath, ')', '\)');
    escapedPath = strrep(escapedPath, ' ', '\ ');

    % Enclose the path in quotes
    correctedPath = escapedPath;
end
