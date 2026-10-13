function ManagePdf(output_filename, path_output)
    dirnow = pwd;
    cd(path_output);

    % Check the operating system
    if ismac  % If on macOS
        exec_Terminal = ['! "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py" -o ', output_filename, ' ', 'fig*.pdf'];
    elseif isunix && ~ismac  % If on Linux
        exec_Terminal = ['pdftk fig*.pdf cat output ' output_filename];
        system(exec_Terminal);  % Combine PDF files using pdftk
        %movefile('temp_combined.pdf', output_filename);  % Rename the combined file
    else
        error('Unsupported operating system.');
    end

    % Remove individual PDF files
    exec_Terminal = 'rm fig*.pdf';
    system(exec_Terminal);

    cd(dirnow);
    clear dirnow;
end