function macroANs = FindMacroANs(pathFolderCTD)
%
% macroANs = FindMacroANs(pathFolderCTD)
%
% version 1.0
% Boris Guirao

%% Code %%

macroCellsBackup = [pathFolderCTD filesep 'macroCells.mat'];

if exist(macroCellsBackup,'file')
    
    fprintf('Loading ANs of macrochaetes...');
    load(macroCellsBackup, 'macroANs');
    fprintf('Done\n');
else
    fprintf('No macrochaetae file found.\n');
    macroANs = [];
end


%% History %%

% 13/10/2017: 1.0