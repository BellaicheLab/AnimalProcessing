function [Js,Es,Cs,Rnd,CELL_NUMBER,E_NUM,V_NUM,INV_NUM,R_NUM, result] = FastGetData(filename)
%
% [Js,Es,Cs,Rnd,CELL_NUMBER,E_NUM,V_NUM,INV_NUM,R_NUM] = FastGetData(filename)
% 
% Version 1.2
% Boris Guirao
%
% Replaces Shuji Ishiara's function "GetData" that is too slow on large images. Basically uses function "readtext" to
% import data in txt file "filename" into a cell array, then work on cell array to dermine vertex, edge and cell
% quantities listed in structures Js, Es and Cs, respectively.
%
% NB1: "scale" is not an output anymore and is NOT expected in "filename" but should be entered in "run_Force_Estimate".
% NB2: not checking for polygonal area positivity anymore (never encountered such a case even when processing Full
% Thorax + error message at getVertex level)


%% Reading and extracting txt data %%

fprintf('Reading "dat.txt" file using "readtext"...');

[data, result] = readtext(filename,' ','','','empty2NaN');
ncol = size(data,2);                                                                                                    % 1.1

% Checking "dat" file is not empty (1.2)
if ncol == 0
    fprintf('Empty "dat.txt" file!!\n');
    Js = []; Es = []; Cs = []; Rnd = []; CELL_NUMBER = []; E_NUM = []; V_NUM = []; INV_NUM = []; R_NUM= []; result = [];
    return
end

%ncol = result.max; % max not reliable !!!
empty_TF = result.emptyMask;
full_TF = ~empty_TF;

% Building data_header:
data_header = cell(9,3);
for r=1:9
    data_line = data(r,:);
    full_TF_line = full_TF(r,:);
    data_header(r,:) = data_line(full_TF_line);
end
disp(data_header)

%%  Defining scalar outputs %%

C_NUM = data_header{1,3};
CELL_NUMBER = C_NUM;                                                                                                    % at this stage, they're equal
EX_CNUM = data_header{3,3}; 
E_NUM = data_header{4,3};
V_NUM = data_header{7,3};
INV_NUM = data_header{8,3};
R_NUM = EX_CNUM;                                                                                                        % defined like this in "GetData"


%% J (vertices) related: JXs,JYs and JExts %%

Jstart = 10;
Jend = Jstart+V_NUM-1;                                                                                                  % last line of Js
Jrange = Jstart:Jend;
JXs = cell2mat(data(Jrange,2));
JYs = cell2mat(data(Jrange,3));
JExts_TF = full_TF(Jrange,4);                                                                                           % 1 when 'Ext', 0 otherwise
Jlist = (1:V_NUM)';
JExts = Jlist(JExts_TF);
nJExts = length(JExts);

% Storage Js:
Js.JXs = JXs;
Js.JYs = JYs;
Js.JExts = JExts;


%% E (edges) related %%

Estart = Jend + 2;                                                                                                      % existence of a NaN line after Js
Eend = Estart + E_NUM-1;
Erange = Estart:Eend;
EJ1s = cell2mat(data(Erange,2))+1;                                                                                      % +1 because numbering or junction (vertices) started at 0
EJ2s = cell2mat(data(Erange,3))+1;
EExts_TF = full_TF(Erange,4);
Elist = (1:E_NUM)';
EExts = Elist(EExts_TF);
nEExts = length(EExts);
% Additional quantities that could be NOT stored:
EX1s = JXs(EJ1s);   EX2s = JXs(EJ2s);
EY1s = JYs(EJ1s);   EY2s = JYs(EJ2s);
EdXs = EX1s-EX2s;   EdYs = EY1s-EY2s;
EZs = EdXs + 1i*EdYs;
EDs = abs(EZs);
%EAngles = angle(EZs);
%nEIns = E_NUM - nEExts;
%EInOuts = [repmat('o',nEExts,1) ; repmat('i',nEIns,1)];                                                                % ASSUMES ALL "Ext" ARE CONSECUTIVE AND LISTED AT THE BEGINNING

% Storage in Es:
Es.EJ1s = EJ1s;
Es.EJ2s = EJ2s;
Es.EX1s = EX1s; Es.EX2s = EX2s;
Es.EY1s = EY1s; Es.EY2s = EY2s;
Es.EdXs = EdXs;
Es.EdYs = EdYs;
Es.EDs = EDs;
Es.EExts = EExts;


%% C (cell) related %%

Cstart = Eend + 2;
Cend = Cstart + C_NUM-1;
Crange = Cstart:Cend;
CnJs = cell2mat(data(Crange,2));
CJs = data(Crange,4:ncol);
CJs = [CJs num2cell(NaN(C_NUM,1))];                                                                                     % adding NaN column => EVERY cell number is followed by NaN (1.1)
% Determining 'Ext' cells:
CJs_TF = full_TF(Crange,4:ncol);                                                                                        % 1 where there is a junction number OR Ext, 0 elsewhere
CJs_TF = logical([CJs_TF zeros(C_NUM,1)]);                                                                              % adds column of 0s to match CJs modification (1.1)
Ext_cols = sum(CJs_TF,2);                                                                                               % gets number of 1s in each row of CJs_TF
Ext_cols = Ext_cols+1;                                                                                                  % now indicates col number of 'Ext', when exist, OR NaN
Ext_rows = (1:C_NUM)';
CJs_TF_size = size(CJs_TF);
Ext_inds = sub2ind(CJs_TF_size,Ext_rows,Ext_cols);                                                                      % turning I,J into linear indices
CExts_TF = CJs_TF(Ext_inds);                                                                                            % 1 when Ext, 0 otherwise
Clist = (1:C_NUM)';
CExts = Clist(CExts_TF);
nCExts = length(CExts);
% REFormatting CJs:
CJs(Ext_inds) = {NaN};                                                                                                  % replaces all 'Ext' with NaN
CJs = cell2mat(CJs);                                                                                                    % now CJs can be turned into a matrix
nCJcol = CJs_TF_size(2);
CJs = CJs(:,1:nCJcol-1);                                                                                                % removing last column that contains NaNs and maybe some 'Ext'
CJs = CJs + 1;                                                                                                          % adds 1 to all J numbers (used to start a 0)
%nCIns = C_NUM - nCExts;
%CInOuts = [repmat('o',nCExts,1) ; repmat('i',nCIns,1)];                                                                % ASSUMES ALL "Ext" ARE CONSECUTIVE AND LISTED AT THE BEGINNING

% Storage in Cs:
Cs.CnJs = CnJs;
Cs.CJs = CJs;
Cs.CExts = CExts;


%% Checking number of "Exts" for each category %

% Checking numbers in each category are the same: 
nExts = [nJExts nEExts nCExts] - R_NUM;
if any(nExts)
    disp('Error: mismatch between "R_NUM" and one of nJ/nE/nCExts!!!');
    return
end

% Checking that all Exts are listed consecutively:
Rnd = (1:R_NUM)';
deltaExts = [JExts EExts CExts] - [Rnd Rnd Rnd];
if any(any(deltaExts))
    disp('Error: all "Ext" in Js/Es/Cs are not consecutive!!!');
    return
end

% NB: after these checks one knows that number of Exts are the same in Js,Es,Cs AND that all are listed consecutively
% from 1:R_NUM, namely: old quantities RndJ = RndE = RndC = Rnd;


%% History %%

% 29/06/2017: 1.2
% - Checking "dat" file is not empty

% 12/11/2012: 1.1
% - fixed bug where CJ size was set by a non-Ext cell and that a number was stored. Added a column of NaN to solve it.
% - accordingly removing only one column from CJs at the end.

% 11/11/2012: creation
