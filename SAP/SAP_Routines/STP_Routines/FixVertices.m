function [Cs, vertexFixLog]= FixVertices(Cs,Es,Js)
%
% [Cs, vertexFixLog]= FixVertices(Cs,Es,Js)
%
% Will check consistency between edges entailed by vertex ordering in CJs
% and actual edges listed in Es ([EJ1s EJ2s]). Then, in cells for which inconsistency is
% found, it will rebuild the proper vertex list, ensuring cell area is
% positive, namely ordering vertices counter-clockwise.
%
% Version 1.1
% Boris Guirao


%% Extracting %%

CJs = Cs.CJs;
CExts = Cs.CExts;
EJ1s = Es.EJ1s;
EJ2s = Es.EJ2s;
JXs = Js.JXs;
JYs = Js.JYs;

EJs = [EJ1s EJ2s];      % build full list of actual edges = vertex couples
n_CExts = max(CExts);   % NB: all external cells are numbered from 1 to n_CExts in a row

vertexFixLog = [];    % will store changes made and for which cell (1.1) 

%% Iteration over non border cells %%

ncols = size(CJs,2);
nrows = size(CJs,1); 
cmin = n_CExts + 1;             % removes Ext (Border) cells from the iteration by starting at first non-border cell
for c = cmin:nrows
   cjs = RemoveNaNs(CJs(c,:)); % this cell vertices (line vector)
   ces = MakeEdges(cjs);       % yields this cell vertex couples, for each couple SMALLER VERTEX NUMBER ON THE LEFT
   cjs_TF = ismember(EJs,cjs);  % finds locations of this cell vertices in EJs
   aces_TF = all(cjs_TF,2);     % finds lines in EJs where BOTH vertices belong to this cell
   aces = EJs(aces_TF,:);       % gets ACTUAL cell edges (from EJs) for this cell NOT SORTED
   aces = sort(aces,2);         % for each vertex couple PUTS THE SMALLEST NUMBER IN LEFT COLUMN
   
   % comparing cell edges from CJs to actual cell edges from EJs:
   CvsE_TF = ismember(ces, aces,'rows'); % compare the list of edges obtained from Cs (cells) and Es (edges)
   
   % if at least one 0 is found in "CvsE_TF" starts the fixing procedure of CJs correction:
   if any(~CvsE_TF)
       disp(['Vertex_Fixer WARNING: found inconsistency between Cs and Es for cell # ' num2str(c) '(Shuji numbering)!!!. Fixing Cs...' ])
       text_OLD = ['OLD vertex list: [' num2str(cjs) '] (A = ' num2str(PolygonArea(cjs, JXs, JYs)) ')'];
       disp(text_OLD);
       
       n_new_cjs = length(unique(aces));                % get the number of vertices for this cell = number of edges
       new_cjs = NaN(1,n_new_cjs);                      % initialize line vector of cell c vertices WITH NEW ORDERING
       new_ces = NaN(n_new_cjs,2);                      % initialize matrix of cell c edges WITH NEW ORDERING
       new_ces(1,:) = aces(1,:);                        % picks first vertex couple to rebuild vertex list from on that.
       new_cjs(1:2) = new_ces(1,:)';                    % the first two vertices are set here, thereby initiating an ARBITRARY ordering
       aces_left = aces;                                % initialization or remaining edges to look for
       aces_left = setdiff(aces_left, new_ces, 'rows'); % updates remaining edges
       
       % iteration over vertices: 
       last_j = new_cjs(2);                             % initialization of "next_j"
       for j = 2:n_new_cjs
           new_cjs(j) = last_j;                         % storing new vertex in new_cjs
           last_j_TF = ismember(aces_left,last_j);      % finds location of last vertex in aces_left
           line_last_j = find(any(last_j_TF,2));        % line with last_j SHOULD BE ONLY ONE INDEX HERE IF NO SMALL CELLS INSERTED BETWEEN 2 BIG ONES (Get_Vertex shouldn't run on such skeletons)
           if length(line_last_j)~=1
               disp(['Vertex_Fixer ERROR: vertex # ' num2str(last_j) ' in cell ' num2str(c) '(Shuji numbering) was found with 0 or 1+ companion vertex!!']);
               return
           end
           next_j_TF = ~last_j_TF(line_last_j,:);               % [0 1] or [1 0], 1 where last_j's partner vertex is
           next_j = aces_left(line_last_j,next_j_TF);           % gets next vertex number, namely last_j vertex companion
           new_ces(j,:) = sort([last_j next_j]);                % MUST BE SORTED IN CRESCENT ORDER!
           aces_left = setdiff(aces_left, new_ces, 'rows');     % update list of remaining edges
           last_j = next_j;                                     % updates of last vertex number to look for
       end
       
       % Checks "aces_left" is empty:
       if ~isempty(aces_left)
           disp(['Vertex_Fixer ERROR: edge [' num2str(aces_left) '] was not used for vertex redetermination in Cs!!']);
           return
       end
       
       % Determining area sign and defining new_cjs accordingly:
        A = PolygonArea(new_cjs, JXs, JYs);

       % list vertices in inverse order if A found negative:
       if A<0
           new_cjs = fliplr(new_cjs);
           A = PolygonArea(new_cjs, JXs, JYs);
       end
       text_NEW = ['NEW vertex list: [' num2str(new_cjs) '] (A = ' num2str(A) ')'];
       disp(text_NEW);
       
       % formatting new_cjs and storage in CJs:
       new_cjsF = NaN(1,ncols);
       new_cjsF(1:n_new_cjs) = new_cjs;
       CJs(c,:) = new_cjsF;
       
       % storing cell# and old/new vertex list in "vertex_fix_log" (1.1):
       text_cell = ['cell # ' num2str(c)];
       text_full = {text_cell ; text_OLD ; text_NEW ; {}};
       vertexFixLog = [vertexFixLog ; text_full];       %#ok<AGROW>
   end
end


%% Update of Cs %%

Cs.CJs = CJs;


%% History %%

% 20/09/2013: 1.1
% - addition of output "vertex_fix_log" (cell array) of log of all cells and vertices fixed in the frame

% 16-18/09/2013: creation