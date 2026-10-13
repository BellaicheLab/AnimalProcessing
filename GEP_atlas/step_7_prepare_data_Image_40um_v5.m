clear;close all;clc

% le nombre de nota par box est calcul� seulement sur la liste des g�nes de
% l'atlas

% A24hPour chaque image, on prend Gene_bg
% j'ai cr�e un r�pertoire

%% Setting parameters

prctl = 1.5;
resol = 40 ; unit ='um',gridOverlap = 0.5;
gridsize= [num2str(resol),unit,'_olap',num2str(gridOverlap)];
timing = '17hAPF'

list_atlas_17hAPF =  {'tsh','Diap1','Pax','sd','ara','ptc','h','rpr','hh', 'al','mirr','hid'	,...
    'usp','bi','wg','salm','esg','lgs','ush', 'sr','eyg','exd','BH1',...
    'puc','daw','kek5','cda4','CG10175','espl','frm','Kay','slf'};

list_atlas_24hAPF = {'ara', 'BH1', 'bi', 'caup', 'Delta', 'diap', 'esg', 'exd', 'eyg', 'fz', 'hh',...
    'Hid', 'h', 'hth', 'lgs', 'mirr', 'Pax', 'ptc', 'Rp', 'salm', 'sd', 'Sr', 'stan', 'tsh', 'Ush', 'usp', 'wg', 'zip'};

list_validation_24hAPF_fish = {'Wg', 'Hth', 'toe', 'QSox2', 'nw', 'dpp', 'Fj', 'nw', 'Robo1', 'slit', 'hbs', 'slow', 'crp', 'pdm3', 'Pvr'};
list_validation_24hAPF_protein = {'18w', 'Tollo', 'Wnt6', 'en', 'C15'};

%% Setting paths

path_AOA   =  '/path/to/data/GEPs/17hAPF/results/AOA_40um_olap0.5/';
path_data =  '/path/to/data/GEPs/17hAPF/results/final_images/image_nrmlized/';
path_out  =  strcat('/path/to/data/GEPs/17hAPF/results/atlas/',gridsize,'/');


fileout_macrochatea = ['17hAPF_wt_macrochaetae_', gridsize,'.csv'];
fileout_Image       = ['17hAPF_wt_Atlas_Validation_',gridsize,'.txt'];
fileout_nnota      = ['17hAPF_wt_nnota_per_position_per_gene_',gridsize,'.txt'];

if ~exist(path_out)
    mkdir(path_out)
end


%% Listing the genes in AOA

genes_to_remove_17hAPF = {'ds','emc','Mnt','neg_control','nls','msn','yrt','zip','stan'};
genes_to_remove_24hAPF = {};

list_nrmlz_genes= struct2table(dir(path_data));
list_nrmlz_genes( ismember(list_nrmlz_genes.name,{'.','..','.DS_Store','mean_image'}) ,: ) = []; % remove first 2 rows\


if (strmatch(timing, '24hAPF'))
    list_nrmlz_genes(contains(list_nrmlz_genes.name,genes_to_remove_24hAPF),:) = [];
    
elseif (strmatch(timing, '17hAPF'))
    list_nrmlz_genes(contains(list_nrmlz_genes.name,genes_to_remove_17hAPF),:) = [];
    list_nrmlz_genes(ismember(list_nrmlz_genes.name,'en_protein.mat'),:)=[]; %j'enleve en pour n'avoir que en_modif
    
end

list_nrmlz_genes(list_nrmlz_genes.isdir==1,:) = [];


%% Saving Macrochaete positions
% je prends les coordonnees moyennes des macrocheatae sur plusieurs animaux
% Pas top, je n'ai pas la meme struct a 17h et 24h
%
list_AOA = struct2table(dir(path_AOA)) ;
list_AOA(ismember(list_AOA.name,{'.','..','.DS_Store'}) ,: ) = []; % remove first 2 rows\
list_AOA(contains(list_AOA.name,'allTimeRanges'),:)=[];

if (strmatch(timing,'24hAPF'))
   list_AOA(contains(list_AOA.name,genes_to_remove_24hAPF),:)=[]; 
elseif (strmatch(timing,'17hAPF'))
   list_AOA(contains(list_AOA.name,genes_to_remove_17hAPF),:)=[]; 
end

ix=0;
macrocheatae = zeros(2,8);
n_gene=0;


for f= 1:length(list_AOA.name)
    load(strcat(path_AOA,list_AOA.name{f},'/AOA_backup.mat'),'REG') %AOA data
    if max(isnan(REG.MacrocaetesMCU(:)))==0
        macrocheatae = macrocheatae + REG.MacrocaetesMCU;
        n_gene = n_gene+1;
    end
end
macrocheatae = macrocheatae/n_gene;

%% Loading image Sizes

if (strmatch(timing, '17hAPF'))
    list_atlas = list_atlas_17hAPF+"_protein"
elseif (strmatch(timing, '24hAPF'))
    list_atlas = list_atlas_24hAPF+"_protein"
end

% get image dimension
load([path_data,list_nrmlz_genes.name{1}],'Gene')
[nr,nc,~,~,~] = size(Gene);

n_min_notum_atlas  = 999*ones(nr*nc,1);
table_n_notum      = zeros(nr*nc,height(list_nrmlz_genes));
list_gene = {};

%% Printing the maximum number of notum for each gene
for g=1:height(list_nrmlz_genes)
    clear Gene*
    gene_name   = list_nrmlz_genes.name{g}(1:end - 4);
    load([path_data,'/',gene_name],'n_animal_AR_not_nan','Gene*')
    
    %modify gene name
    gene_name   = ChangeGeneName(gene_name);
    % pour image Atlas : nb notum = nb notum atlas
    if max(ismember(gene_name,list_atlas))
        n_min_notum_atlas = min(n_min_notum_atlas,n_animal_AR_not_nan(:));
        display([gene_name,' : max notum ',num2str(max(n_min_notum_atlas))])

    end
end

%% (For 17hAPF only) Estimate missing values for 'en'
% il ne faut pas mettre 'en' dans les genes d'atlas � cette �tape
% j'ai besoin de l'exclure pour voir dans quelle r�gion l'estimer
if (strmatch(timing, '17hAPF'))
    clear Gene* n_animal_* Ar
    gene_name   =  'en_protein';
    % 10juillet 2023 j'ai modifi� : en_protein en en
    copyfile(strcat(path_data,'en.mat'),strcat(path_data,'en_modif.mat'))

    load(strcat(path_data,'/en_modif'),'n_animal_AR_not_nan','Gene*','REG','Area*')

    en = squeeze(Gene_bg_Prctl(:,:,1,1,1));

    % manually determined region to average
    % region does not make a big difference (values ~0.025)
    z = en(:,37:46);
    value_en_to_replace = nanmean(z(:));

    mask1notum = MakeMatrix(n_min_notum_atlas,nr,nc)>0;
    ix_anterior = zeros(nr,nc);
    ix_anterior(1:end,37:46) =1;
    ix_anterior = logical(ix_anterior);

    % where to replace the value
    ix_replace = logical((~isnan(en).* mask1notum).*ix_anterior);

    figure
    subplot(3,1,1)
    h=imagesc(en);colorbar;axis('off');
    set(h,'AlphaData',n_animal_AR_not_nan>0) % if AreaRation < 0.5 ==> background

    subplot(3,1,2)
    h=imagesc(ix_replace);colorbar;axis('off');
    set(h,'AlphaData',mask1notum) % if AreaRation < 0.5 ==> background

    subplot(3,1,3)
    en(ix_replace) = value_en_to_replace;
    Gene_bg_Prctl(:,:,1,1,1)=en;

    n_animal_AR_not_nan_modif = n_animal_AR_not_nan;
    n_animal_AR_not_nan_modif(ix_replace) = 1;
    hh=imagesc(Gene_bg_Prctl(:,:,1,1,1));colorbar;axis('off');
    set(hh,'AlphaData',n_animal_AR_not_nan_modif>0) % if AreaRation < 0.5 ==> background

    save([path_data,'en_modif'],'n_animal_AR_not_nan_modif','ix_replace','value_en_to_replace','Gene_bg_Prctl','-append')
end

%% Generate the actual images 

% Defining the list of genes to process
if (strmatch(timing, '17hAPF'))
    list_atlas = list_atlas_17hAPF
    % We add in en again
    list_atlas = union(list_atlas,'en_modif')
    
elseif (strmatch(timing, '24hAPF'))
    list_atlas = list_atlas_24hAPF
    
end

% Generating the atlas dataset
n_min_notum_atlas  = 999*ones(nr*nc,1);
table_n_notum      = zeros(nr*nc,height(list_nrmlz_genes));
list_gene = {};

for g=1:height(list_nrmlz_genes)
    clear Gene* n_animal_AR_not_nan
        
    gene_name   = list_nrmlz_genes.name{g}(1:end - 4);
    
    load([path_data,'/',gene_name],'n_animal_AR_not_nan*','Gene*')
    
    % First we rewrite the gene names based on conditions
    % Gene name modification
    if strcmp(timing, '17hAPF')
        gene_name = modifyGeneName17hAPF(gene_name);
    elseif strcmp(timing, '24hAPF')
        % Additional logic for 24hAPF if required
    end
    
    gene_name   = ChangeGeneName(gene_name);
    list_gene   = [list_gene,gene_name];
    
    % pour image Atlas : nb notum = nb notum atlas
    if max(ismember(gene_name,list_atlas))
        n_min_notum_atlas = min(n_min_notum_atlas,n_animal_AR_not_nan(:));
        display([gene_name,' : max notum ',num2str(max(n_min_notum_atlas))])
    end
    
    table_n_notum(:,g) = n_animal_AR_not_nan(:);
    
    if exist('Gene_dotseg_Prctl') % fish dpp,hbs,robo,slow,toe,neg_control
        Gene_Mean = squeeze(Gene_dotseg_Prctl(:,:,1,1,1));
    elseif  exist('Gene_bg_Prctl') %other fish and protein validation genes
        % inclus aussi Gene_bg
        Gene_Mean = squeeze(Gene_bg_Prctl(:,:,1,1,1));
    elseif  exist('Gene_bg50_Prctl') %other fish and protein validation genes
        % inclus aussi Gene_bg
        Gene_Mean = squeeze(Gene_bg50_Prctl(:,:,1,1,1));
    else % image maria: background correction included in Gene field
        Gene_Mean = squeeze(Gene_Prctl(:,:,1,1,1));
    end
    
    X(:,g) = Gene_Mean(:);
      
end


%nb de notum
figure
h=imagesc(MakeMatrix(n_min_notum_atlas,nr,nc));
set(h,'AlphaData',MakeMatrix(n_min_notum_atlas,nr,nc)>0) % if AreaRation < 0.5 ==> background
title('Minimum number of notum in each area');
colorbar; axis('off');

% If I add engrail (with few pixels estimated)
% onlly engrailed has a variable called n_animal_AR_not_nan_modif
if(strmatch(timing, '17hAPF'))
    n_min_notum_atlas = min(n_min_notum_atlas,n_animal_AR_not_nan_modif(:));
elseif (strmatch(timing, '24hAPF'))
    n_min_notum_atlas = min(n_min_notum_atlas,n_animal_AR_not_nan(:));
end

figure
h=imagesc(MakeMatrix(n_min_notum_atlas,nr,nc));
set(h,'AlphaData',MakeMatrix(n_min_notum_atlas,nr,nc)>0) % if AreaRation < 0.5 ==> background
title('Min notum with filling area for en');
colorbar; axis('off');

table_n_notum = array2table(table_n_notum);
table_n_notum.Properties.VariableNames = list_gene;

X              = array2table(X, 'VariableNames', list_gene);
X.n_nota_gene = n_min_notum_atlas;
coordX         = repmat([1:nr]',1,nc);
coordY         = repmat([1:nc],nr,1);
X.coordX       = coordX(:);
X.coordY       = coordY(:);
%

writetable(X,[path_out,fileout_Image])
%logmessage  = [logmessage, fileout_Image,' added, ']

writetable(table_n_notum,[path_out,fileout_nnota]);
%logmessage  = [logmessage, fileout_nnota,' added \n']

%{
fileID = fopen([path_out,logfile],'a');
fprintf(fileID,logmessage);
fclose(fileID);
%}


%% Separate atlas and geometry

% Merge and format validation lists
list_validation_24hAPF = [strcat(list_validation_24hAPF_fish, '_RNA'), ...
                          strcat(list_validation_24hAPF_protein, '_protein')];
list_atlas_24hAPF = strcat(list_atlas_24hAPF, '_protein');

% Check for missing genes in the table
all_genes = [list_atlas_24hAPF, list_validation_24hAPF];

if any(~ismember(all_genes, X.Properties.VariableNames))
    missing_genes = all_genes(~ismember(all_genes, X.Properties.VariableNames));
    error('Missing genes in the table: %s', strjoin(missing_genes, ', '));
end

% Separate the atlas and validation data
atlasData = X(:, ismember(X.Properties.VariableNames, list_atlas_24hAPF));
validationData = X(:, ismember(X.Properties.VariableNames, list_validation_24hAPF));

% Separate the gene expression data and coordinates
coords = X(:, {'n_nota_gene', 'coordX', 'coordY'});

% Define the output filenames
atlas_filename = fullfile(path_out, strcat(timing,'_wt_atlas_',gridsize,'.csv'));
validation_filename = fullfile(path_out, strcat(timing,'_wt_validation_',gridsize,'.csv'));
geometry_filename = fullfile(path_out, strcat(timing,'_wt_geometry_',gridsize,'.csv'));
macrochaete_filename = fullfile(path_out, strcat(timing, '_macrochaete_pos_', gridsize, '.csv'));
% Write the tables to CSV files
writetable(atlasData, atlas_filename);
writetable(validationData, validation_filename);
writetable(coords, geometry_filename);
csvwrite(macrochaete_filename, macrocheatae); % writematrix is R2019a+; kept R2018b-compatible

%% HELPER
function GetImageMaskNotum(path_data,mask_1nota , mask_3nota , mask_5nota)

fig = figure('visible','off')
imagesc(mask_1nota + mask_3nota + mask_5nota)
title(["mask 1, 3 or 5 nota in all genes ;",strcat(num2str(sum(mask_1nota(:)))," pixels with 1 nota "),....
    strcat(num2str(sum(mask_3nota(:)))," pixels with 3 nota "),...
    strcat(num2str(sum(mask_5nota(:)))," pixels with 5 nota ")])
%saveas(fig,[path_data,'data_for_mapping/Reports_for_mapping/Images1_mask_1_to_5_notum.pdf'])
%save([path_data,'data_for_mapping/mask_1_to_5_notum_genes'],'mask*','n_notum_gene*')
end

function mat = MakeMatrix(vect,nr,nc)

coordX = repmat([1:nr]',1,nc);
coordY = repmat([1:nc],nr,1);

mat = NaN(nr,nc);
for ii = 1:nr*nc
    mat(coordX(ii),coordY(ii))= vect(ii);
end
end

function gene_name = ChangeGeneName(gene_name)
    % I cannot change B-H1 but otherwise names should be standardized

    switch gene_name
        case 'Delta'
            gene_name = 'Dl';
        case 'Hid'
            gene_name = 'hid';
        case 'Rpr'
            gene_name = 'rpr';
        case 'Sr'
            gene_name = 'sr';
        case 'diap'
            gene_name = 'Diap1';
        case 'Ush'
            gene_name = 'ush';
        case 'Fj'
            gene_name = 'fj';
        case 'QSox2'
            gene_name = 'CG17843';
        case 'Ds'
            gene_name = 'ds';
        case '18w'
            gene_name = 'gene18w';
        % No case for 'B-H1' as it should not be changed
        otherwise
            % If none of the cases match, gene_name remains unchanged
    end
end

function modifiedGeneName = modifyGeneName17hAPF(gene_name)
    % GEP atlas: rename control FISH shorts 'Actvi_<N>h_<gene>_RNA' -> clean '<gene>'.
    tok = regexp(gene_name, '^Actvi_\d+h_(.+)_RNA$', 'tokens', 'once');
    if ~isempty(tok)
        modifiedGeneName = tok{1};
        return
    end
    % Gene name modification under '17hAPF' timing
    if strcmp(gene_name, 'wg')
        modifiedGeneName = 'wg_fish';
    elseif contains(gene_name, '_protein') && ~contains(gene_name, ["Pvr", "crp", "hth"])
        modifiedGeneName = extractBefore(gene_name, '_protein');
    elseif contains(gene_name, 'en_modif')
        modifiedGeneName = 'en';
    else
        modifiedGeneName = gene_name;  % No change for other cases
    end
end
