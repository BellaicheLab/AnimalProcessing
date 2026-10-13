function ExtractData(STRUCT, nameAddon, ws)
%
% ExtractData(STRUCT, nameAddon, ws)
%
% Extracts ALL fields present in structure "STRUCT" to make them available in Matlab workspace "ws" (= 'base' (default)
% or 'caller', optional), KEEPING THEIR ORIGINAL NAMES or possibly adding the string 'name_addon' (optional) at the
% beginning of every original names.
%
% NB: only one level of extraction
%
% Version 1.2
% Boris Guirao

%% Code

if ~isempty(STRUCT)
    if nargin == 1                                                             % changed in 1.1
        nameAddon = '';
        ws = 'base';
    elseif nargin == 2
        ws = 'base';
    end
    
    STRUCT_names = fieldnames(STRUCT);
    n_fields = size(STRUCT_names,1);
    
    for i = 1:n_fields
        this_field = STRUCT.(STRUCT_names{i});                                 % extracts variable STRUCT_names{i} from STRUCT
        this_name = [nameAddon STRUCT_names{i}];                              % adds prefix
        assignin(ws, this_name, this_field);                               % assigns name "this_name" to variable "this_field" in the main workspace
    end
end

%% History

% 19/12/2010: 1.2
% - checks STRUCT is not empty before action

% 17/07/2010: 1.1
% - added possibility to specify the workspace "ws" = 'base' or 'caller'

% 08/07/2010: creation