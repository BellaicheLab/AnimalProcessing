clear all
restoredefaultpath
path(pathdef); clc;

%% DON"T FORGET TO MODIFY SAP_PARAMETER BEFORE !!!

resol='40um';
gridOverlap = 0.5;

main_path = '/path/to/data/GEPs/24hAPF/results'

f = 'fish_RNAi';
%path to SAP
path_SAP_to_use = {'/path/to/data/GEPs/24hAPF/SAP_infos/validation_protein/resol40um/',...
                    '/path/to/data/GEPs/24hAPF/SAP_infos/protein/resol40um/',... 
                    '/path/to/data/GEPs/24hAPF/SAP_infos/validation_fish/resol40um/',...
                   }; %Path sap_info
               
% Adding the paths to the MATLAB path
for p = 1:length(path_SAP_to_use)
    addpath(path_SAP_to_use{p});
end

% adding the path to the SAP parameters
addpath('/path/to/data/GEPs/scripts/')
%% List of SAP to treat

%listdir   =struct2table(dir(path_SAP_to_use)); % list directory from
%listdir(ismember(listdir.name,{'.';'..';'.DS_Store'}),:) =[]; % remove first 2 rows

% fichier err
T_err = array2table(nan(0,4));
T_err.Properties.VariableNames = {'idx','filename','gene','grid'};

for p = 1:length(path_SAP_to_use)
    current_path = path_SAP_to_use{p};
    listdir = struct2table(dir(current_path)); % List directory from
    listdir(ismember(listdir.name, {'.', '..', '.DS_Store'}), :) = []; % Remove unwanted entries

    for ixfile = 1:height(listdir)
        disp(ixfile)
        display(['************', num2str(ixfile), '*------*', listdir.name{ixfile}, '****************'])
        clearvars -except path_SAP_to_use listdir ixfile gridOverlap main_path T_err resol f current_path SAP_parameters
        %try
        run(fullfile(current_path, listdir.name{ixfile}));
        %{
        catch
            Err.idx      = ixfile;
            namefile     = listdir.name{ixfile};
            Err.filename = {namefile};
            Err.gene     = {namefile(10:length(namefile)-2)};
            Err.grid     = resol;
            T_err        = [T_err; struct2table(Err)];
        end
        %}
    end
end

display(T_err)

if (height(T_err) > 0 )
     save( strcat(main_path,'/file_to_modify_manually_',num2str(resol),'_resol','.mat'),'T_err')

end



