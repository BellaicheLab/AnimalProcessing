function allVertexCATEGORIES = SortVertices(VERTICES, SIDES, sideCATEGORIES)
%
% allVertexCATEGORIES = SortVertices(VERTICES, SIDES, sideCATEGORIES)
%
% NB: need to remove possible NaN values from list for sides without vertices (circle cells)
%
% Version 1.2
% Boris Guirao

%% Code %%

%%% Extraction of "side" and "allVertex" CATEGORIES:
ExtractData(sideCATEGORIES,'','caller')
% ExtractData(allVertexCATEGORIES,'','caller')
allVertexNumbers = VERTICES.Numbers; % 1.2
allVertexnCells = VERTICES.nCells; % 1.2

sideVertices = SIDES.Vertices; % 1.2
sideNumbers = SIDES.Numbers;

%%% Determining "bulk", "edge", "three" and "fourVertices" from "allVertexnCells" (1.2)
edgeVerticesTF = allVertexnCells <= 2;
threeVerticesTF = allVertexnCells == 3;
fourVerticesTF = allVertexnCells == 4;
% getting corresponding vertex numbers (NOT just rows, actual numbers!)
edgeVertices = allVertexNumbers(edgeVerticesTF);
threeVertices = allVertexNumbers(threeVerticesTF);
fourVertices = allVertexNumbers(fourVerticesTF);
% bulk (vs edge)
bulkVertices = setdiff(allVertexNumbers,edgeVertices);

%%% Finding rows corresponding to side numbers for each side category (1.2)
% NB: required because in C++SIA, side numbers no longer correspond to side rows!!
[~,coreFLSideRows] = ismember(coreFLSides,sideNumbers);
[~,borderFLSideRows] = ismember(borderFLSides,sideNumbers);
[~,allCoreSideRows] = ismember(allCoreSides,sideNumbers);
[~,allFLSideRows] = ismember(allFLSides,sideNumbers);
[~,allBorderSideRows] = ismember(allBorderSides,sideNumbers);

%%% Interface vertices:
coreFLVertices = RemoveNaNs(unique(sideVertices(coreFLSideRows,:)));
borderFLVertices = RemoveNaNs(unique(sideVertices(borderFLSideRows,:)));

%%% Other bulk vertices:
% Core:
allCoreVertices = RemoveNaNs(unique(sideVertices(allCoreSideRows,:)));
coreVertices = setdiff(allCoreVertices, coreFLVertices);                                    % vertices ONLY involving core cells
% Fist layer:
allFLVertices = RemoveNaNs(unique(sideVertices(allFLSideRows,:)));
FLVertices = setdiff(allFLVertices, union(coreFLVertices,borderFLVertices));              % vertices ONLY involving FL cells (NB: often empty on full image)
% Border (NOT EDGES):
allBorderVerticesTemp = RemoveNaNs(unique(sideVertices(allBorderSideRows,:)));
allBorderVertices = setdiff(allBorderVerticesTemp, edgeVertices);                          % removes edge vertices
borderVertices = setdiff(allBorderVertices, borderFLVertices);                              % vertices ONLY involving Border cells (NB: often empty on full image)
% Non Core:
allNonCoreVertices = setdiff(bulkVertices, coreVertices);                                   % includes Core_FL_vertices
nonCoreVerticies = setdiff(allNonCoreVertices, coreFLVertices);                            % vertices ONLY involving Non Core cells

%%% Storing quantities in "allVertexCATEGORIES":
% "bulk", "edge", "three" and "fourVertices" (1.2)
allVertexCATEGORIES.edgeVertices = edgeVertices;
allVertexCATEGORIES.threeVertices = threeVertices;
allVertexCATEGORIES.fourVertices = fourVertices;
allVertexCATEGORIES.bulkVertices = bulkVertices;

% Parition of bulk vertices:
allVertexCATEGORIES.coreVertices = coreVertices;
allVertexCATEGORIES.coreFLVertices = coreFLVertices;
allVertexCATEGORIES.FLVertices = FLVertices;
allVertexCATEGORIES.borderFLVertices = borderFLVertices;
allVertexCATEGORIES.borderVertices = borderVertices;
% partition Core, Core-FL, Non_Core:
allVertexCATEGORIES.nonCoreVerticies = nonCoreVerticies;

% Combined categories:
allVertexCATEGORIES.allCoreVertices = allCoreVertices;
allVertexCATEGORIES.allFLVertices = allFLVertices;
allVertexCATEGORIES.allBorderVertices = allBorderVertices;
allVertexCATEGORIES.allNonCoreVertices = allNonCoreVertices;

% NB: Core_vertices U Core_FL_vertices U Non_Core_vertices = allVertexNumbers
% NB: Border_vertices U Border_FL_vertices U Non_Border_vertices = Bulk_vertices


%% History %%

% 04/05/2018: 1.2
% - changes to adapt to new C++SIA, in particular now need to find the rows
% corresponding to each side number
% - added the determination and storage of "bulk", "edge", "three" and
% "fourVertices" from "allVertexnCells"
% - now directly takes SIDES and VERTICES as input arguments

% 18/01/2018: 1.1
% - changed names stored in "allVertexCATEGORIES"

% 25/11/2010: creation

