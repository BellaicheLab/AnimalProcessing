%% SR clicking over the second protein cohort (protein_round2).
% Run INTERACTIVELY (MATLAB GUI, NOT -batch) from this folder so this
% folder's SAP_parameters.m (SR=1, GEP=0) wins by cwd precedence:
%   cd /path/to/AnimalProcessing/GEP_atlas/round2_SR
%   addpath(genpath('/path/to/AnimalProcessing'))
%   step_1_round2
% Per animal: click up to 8 macrochaetae (right-click = NaN for invisible, >=4
% needed), press F, then midline (2 clicks) and neck (2 clicks). Animals with an
% existing All_clicked_landmarks png are skipped -> interrupt/resume freely.

% MATLAB launched via nohup/-r starts in userpath, so cwd precedence cannot be
% relied on: cd here and prepend this folder so ITS SAP_parameters (SR=1) wins.
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
    clearvars -except listdir ixfile path_SAP_to_use
    run(fullfile(path_SAP_to_use, listdir.name{ixfile}));
end

rmpath(path_SAP_to_use);
