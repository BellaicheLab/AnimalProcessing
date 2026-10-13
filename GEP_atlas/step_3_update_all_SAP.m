% modify the values obtained from

%{
% lister les fichiers SAP (path_SAP_before) et les genes qui ont deja fait MAP 1 fois
% pour chaque SAP
  -  faire une copie de SAP dans un nouveau repertoire (path_SAP_after)
  -  recuperer les parametres de transformation associes au gene (rescalingOutput.mat)

  - remplaced une ligne
%}
clear All

% fichier pour r?cup?rer param?tres transform?s

f = 'fish_RNAi';


path_SAP_before = {
    '/path/to/data/GEPs/24hAPF/SAP_infos/protein/resol40um/', 
    '/path/to/data/GEPs/24hAPF/SAP_infos/validation_fish/resol40um/', 
    '/path/to/data/GEPs/24hAPF/SAP_infos/validation_protein/resol40um/' % Add as many paths as needed
};


% Construct corresponding path_SAP_after for each path in path_SAP_before
path_SAP_after = cell(size(path_SAP_before));
for i = 1:length(path_SAP_before)
    path_SAP_after{i} = strrep(path_SAP_before{i}, '/resol40um/', '/40um_after_rescaling/');
end

% File for rescaling output
rescaling_output_path = '/path/to/data/GEPs/24hAPF/results/Gene_40um_rescaled_24h00_nMacroUsed=4/rescalingOutput.mat'
load(rescaling_output_path);

rescalingOutput = cell2table(rescalingOutput(2:end,2:end)','RowNames',rescalingOutput(1,2:end),...
    'VariableNames',{'Ox','Oy','xFactor','yFactor','yML','xNK','scale1D'});


% Determine the operating system for sed command compatibility
if ismac
    sed_inplace = 'sed -i '''' '; % for macOS
else
    sed_inplace = 'sed -i '; % for Linux
end

for idx = 1:length(path_SAP_before)
    current_SAP_before = path_SAP_before{idx};
    current_SAP_after = path_SAP_after{idx};

    % Create the after rescaling directory if it doesn't exist
    if ~exist(current_SAP_after, 'dir')
        mkdir(current_SAP_after);
    end

% List all files in the current SAP_before directory
    files_in_dir = dir(fullfile(current_SAP_before, 'SAP_info_*.m'));
    files_in_dir = {files_in_dir.name};

    % Extract gene names from file names
    genes_in_dir = regexp(files_in_dir, 'SAP_info_(.*)\.m', 'tokens');
    genes_in_dir = [genes_in_dir{:}];  % Flatten the cell array
    genes_in_dir = cellfun(@(x) x{1}, genes_in_dir, 'UniformOutput', false);  % Extract gene names

    % Find intersection with the genes in rescalingOutput
    list_gene = intersect(rescalingOutput.Properties.RowNames, genes_in_dir);

    for g = 1:length(list_gene)
        gene = list_gene{g};

        old_file = ['"', current_SAP_before, 'SAP_info_', gene, '.m', '"'];
        new_file = ['"', current_SAP_after, 'SAP_info_', gene, '.m', '"'];

        % Copy the original file to the new location
        copy_command = ['cp ', old_file, ' ', new_file];
        [status, result] = system(copy_command);
        if status ~= 0, error(result); end

        % Modify commands to account for OS-specific sed behavior
        command1 = [sed_inplace, '-e "s/^xFactor=.*/xFactor=', num2str(round(rescalingOutput.xFactor(gene), 3)), ';/" ', new_file];
        command2 = [sed_inplace, '"s/^yFactor=.*/yFactor=', num2str(round(rescalingOutput.yFactor(gene), 3)), ';/" ', new_file];
        command3 = [sed_inplace, '"s/^yMid=.*/yMid=', num2str(rescalingOutput.yML(gene)), ';/" ', new_file];
        command4 = [sed_inplace, '"s/^xyStart=.*/xyStart=\\[', num2str(rescalingOutput.Ox(gene)), ',', num2str(rescalingOutput.Oy(gene)), '\\];/" ', new_file];

        % Execute the commands
        [status, result] = system(command1);
        if status ~= 0, error(result); end
        [status, result] = system(command2);
        if status ~= 0, error(result); end
        [status, result] = system(command3);
        if status ~= 0, error(result); end
        [status, result] = system(command4);
        if status ~= 0, error(result); end
    end
end