function tableOutput = update_list_name_fish(path_dir, varargin)
%UPDATE_LIST_NAME Generates a table of the experiments for averaging GEPs
%   Takes a Directory path as input and creates a table containing the list
%   of all experiments. Can also remove specified suffixes and specify
%   experiment type if the corresponding options are given.
%   The last argument can be 'old' or 'new' to determine the splitting method.

% Define default experiment type and suffixes to remove
defaultType = 'protein';
validTypes = ['protein', 'RNA'];
defaultMethod = 'old';
defaultIndexGene = 1;
suffixesToRemove = {'GfpcadRfp','KateCnoYfp','KateCno', '3M1Gfp', '3K2Gfp','AB555', 'AGFP','Che','Gfp' , 'GFP','YFP', 'Yfp','rQF', 'QF'};

% Check for optional arguments
remove_suffixes = false;
experimentType = defaultType;
splitMethod = defaultMethod;
indexGene = defaultIndexGene;
if ~isempty(varargin)
    if length(varargin) >= 1
        remove_suffixes = varargin{1};
    end
    if length(varargin) >= 2
        experimentType = varargin{2};
        % Ensure experimentType is a string, not a cell
        if iscell(experimentType)
            experimentType = experimentType{1};
        end
        if ~ismember(experimentType, validTypes)
            error('Invalid experiment type. Valid types are: %s and %s.', validTypes{:});
        end
    end
    if length(varargin) >= 3
        splitMethod = varargin{3};
        if ~ismember(splitMethod, {'old', 'new'})
            error('Invalid split method. Valid methods are: "old" and "new".');
        end
    end
    if length(varargin) >=4
        indexGene = varargin{4};
    end
end

searchPattern = fullfile(path_dir, 'SAP_info_*');
files = struct2table(dir(searchPattern));
% Remove every directory
files = files(~files.isdir,:);
files(ismember(files.name,{'.','..','.DS_Store'}),:) = [];

short = strings(height(files),1);
long = strings(height(files),1);
type = strings(height(files),1);
%repmat(experimentType, height(files), 1);

for i = 1:height(files)
    name = files{i,1}{1}([length('SAP_info_')+1:end-2]);
    
    if strcmp(splitMethod, 'old')
        splitted_name = split(name, "_");
        short{i} = splitted_name{indexGene};
        short{i} = strcat(short{i}, '_', experimentType);
    else  % New method
        splitted_name = split(name, "__");
        short{i} = strcat(splitted_name{2}, '_', experimentType);
    end

    if remove_suffixes
        for j = 1:length(suffixesToRemove)
            short{i} = strrep(short{i}, suffixesToRemove{j}, '');
        end
    end

    long{i} = name;
    type{i} = experimentType;
    
end

tableOutput = table(long, short, type);
end
