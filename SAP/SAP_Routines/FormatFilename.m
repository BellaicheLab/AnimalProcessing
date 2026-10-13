function filenameOut = FormatFilename(filenameIn)
%
% filenameOut = FormatFilename(filenameIn)
%
% first removes last '_' of "filename_in"
% NB: stopped cropping it to its first nmax_char = 15 characters.
%
% NB: "nmax_char" SHOULD NOT BE CHANGED SO AS TO BE ABLE TO USE PREVIOUS BACKUP FILES!!
%
% Version 1.3
% Boris Guirao


%% Code %%

%%% maximal number of characters kept:
% nmaxChar = 15;        

%%% Crops name at its first "nmax_char" characters:
filenameOut = filenameIn; 
% filename_out = substr(filename_in, 0, nmaxChar);  

%%% Removes last character, most likely "_" (1.1), AFTER checking it ACTUALLY ends with "_" (1.2)
if strcmp(filenameOut(end),'_')
    filenameOut = substr(filenameOut,  0, -1);
end


%% History %%

% 13/04/2015: 1.2
% - simplified code

% 07/09/2011: 1.1
% - prevents name cut ending with '_'. It so, removes it.

% 12/08/2011: creation