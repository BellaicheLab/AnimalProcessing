%% Run GEP over the RA-filled protein_round2 SAP_infos.
% Lives in GEP_atlas/ (NOT round2_SR/) so THIS folder's SAP_parameters (SR=0,
% GEP=1, averageOverAll={'GEP'}) wins. Self-locating like step_1_round2:
thisDir = fileparts(mfilename('fullpath'));
cd(thisDir);
addpath(thisDir);
fprintf('SAP_parameters resolves to: %s\n', which('SAP_parameters'));

path_SAP_to_use = '/path/to/data/GEPs/17hAPF/SAP_infos/protein_round2/resol40um/';
addpath(path_SAP_to_use);

listdir = struct2table(dir(fullfile(path_SAP_to_use, 'SAP_info_*.m')));
listdir(ismember(listdir.name, {'.', '..', '.DS_Store'}), :) = [];

for ixfile = 1:height(listdir)
    display(['************', num2str(ixfile), '/', num2str(height(listdir)), '*------*', listdir.name{ixfile}, '****************']);
    clearvars -except listdir ixfile path_SAP_to_use thisDir
    run(fullfile(path_SAP_to_use, listdir.name{ixfile}));
end

rmpath(path_SAP_to_use);
