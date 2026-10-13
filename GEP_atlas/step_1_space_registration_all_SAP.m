%% Modify the path of SAP_info each time
% path to images
main_path = '/path/to/data/GEPs/24hAPF/data/protein/';

% paths to SAP
paths_SAP_to_use = {
    '/path/to/data/GEPs/24hAPF/SAP_infos/validation_protein/resol40um/',...
    '/path/to/data/GEPs/24hAPF/SAP_infos/protein/resol40um/',...
    '/path/to/data/GEPs/24hAPF/SAP_infos/validation_fish/resol40um/',...
    % Add as many paths as needed
};

path_SAP_parameters = '/path/to/data/GEPs/scripts/';

addpath(path_SAP_parameters);

%% Execute all the .m files for all the paths in the list
for ixPath = 1:length(paths_SAP_to_use)
    
    progressionStr = sprintf('%d/%d', ixPath, length(paths_SAP_to_use));
    % Display the progression
    disp(progressionStr);
    path_SAP_to_use = paths_SAP_to_use{ixPath};
    addpath(path_SAP_to_use);

    listdir = struct2table(dir(fullfile(path_SAP_to_use, '*.m'))); % list only .m files
    listdir(ismember(listdir.name, {'.', '..', '.DS_Store'}), :) = []; % remove unwanted entries

    listdir = ExcludeSomeNotum(listdir);
    %

    for ixfile = 1:height(listdir)
        disp(ixfile);
        display(['************', num2str(ixfile), '*------*', listdir.name{ixfile}, '****************']);
        clearvars -except paths_SAP_to_use listdir ixfile main_path ixPath path_SAP_parameters path_SAP_to_use gridOverlap
        gridOverlap = 0.5; % If this is a parameter for each file, it might need to be redefined within the file scope
        display(fullfile(path_SAP_to_use, listdir.name{ixfile}));
        run(fullfile(path_SAP_to_use, listdir.name{ixfile}));
    end

    rmpath(path_SAP_to_use); % Remove the path after processing all files in it
end
%}

function listdir = ExcludeSomeNotum(listdir)
    % remove half notum
    list_remove_half = {}; % populate as needed
    for g = 1:length(list_remove_half)
        listdir(contains(listdir.name, list_remove_half{g}), :) = [];
    end

    % remove full notum
    list_remove_all = {}; % populate as needed
    for g = 1:length(list_remove_all)
        listdir(contains(listdir.name, list_remove_all{g}), :) = [];
    end
end
