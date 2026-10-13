%% look at the average
% - compare various normalization ==> Prctl better
% - remove saturationn (keep values <0 and >1)
% v3
% 6 mars : added patch to look at dot segmented images (only done on some
% genes)
% Previous version (v2)
% 1) patch for AR: it is better to exclude area ratio <1 to avoid border
%    ==> borders tend to have artifially high expression of genes (caused by projection)
%         by excludding border I solved partly the problem
%    Notes: - when I did the mask I tried to exclude border but was not enough
%           - I am not sure how big of a problem it is because I focus on the intersection of notums
% 2) for some reason one animal is not flipped for yrt igrid 48
% ==> I excluded that animal (otherwise would need to reproject all)

clear all ;close all; clc
prctl = 0.5; % for normalization pixel intensity

resol=40;
gridOverlap = 0.5;

%% Setting paths

path_AOA   = "/path/to/data/GEPs/17hAPF/results/AOA_40um_olap0.5/";
path_output   = "/path/to/data/GEPs/17hAPF/results/final_images/";

% Folder creation
mkdir(path_output)
mkdir(strcat(path_output,'image_nrmlized/'))

%% Fetching of genes

% List of genes processed by AOA
listdir = struct2table( dir(path_AOA) );
listdir( ismember(listdir.name,{'.','..','.DS_Store'}) ,: ) =[]; % remove first 2 rows
listdir = listdir(contains(listdir.name,'_0h_0olap'),:);
listdir( ismember(listdir.name,{'yrt','Mnt','emc','msn','yrt'}) ,: ) =[]; % remove first 2 rows
% Normalize only the 9 Actvi 96h control genes (per-gene normalization, so the
% other genes are unaffected).
% Second protein cohort: normalize only its 8 protein reporter genes.
round2_dirs = {'AOA_dpy_protein_0h_0olap','AOA_emc_protein_0h_0olap',...
    'AOA_Lobe_protein_0h_0olap','AOA_Mnt_protein_0h_0olap',...
    'AOA_msn_protein_0h_0olap','AOA_stan_protein_0h_0olap',...
    'AOA_yrt_protein_0h_0olap','AOA_zip_protein_0h_0olap'};
listdir = listdir(ismember(listdir.name, round2_dirs),:);

% List of animals for each genes
list_full_notum={};
for f= 1:length(listdir.name)
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    list_full_notum = union(list_full_notum,list_notum);
end

%% Saving Normalized images
ix=0;

disp("Saving normalized images ")
gene_specific_area_ratio = {'AOA_slit_RNA_0h_0olap'}; % Replace with your specific gene names


for f= 1:length(listdir.name)
    clear Gene* Cad 
    load(strcat(path_AOA,listdir.name{f},'/AOA_backup.mat')) %AOA data
    clearvars -except gene_specific_area_ratio gridOverlap main_path prctl list_to_excl isfish f resol gridOverlap ix n_animal_gene Gene* AreaRatios Cad REG mask_holes list_name mapAnimal path_output path_AOA listdir subplot
    clear *Smap
    
    % Display which animal is being processed
    disp(['Processing animal: ', mapAnimal]);
    
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    ncol=3;
    
    macrocheats = array2table(REG.MacrocaetesMCU);
    macrocheats.Properties.VariableNames = {'m1','m2','m3','m4','m5','m6','m7','m8'};
    
    [nr,nc,~,~,nimage] = size(AreaRatios);
    i=1;
    %{
    for p=2:nimage
        
        subplot(3,2,i)
        imagesc(AreaRatios(:,:,1,1,p))
        hold on
        scatter(macrocheats{1,:},macrocheats{2,:},'xm','LineWidth',2)
        hold off
        i =i+1;
        if i==7
            i=1;
        end
    end
    %}
    

    
    %{
    % manually exclude some nota
    [~,ix_to_excl,~]   = intersect(list_notum,list_to_excl);
    list_notum = setdiff(list_notum,list_to_excl,'stable');
    ix_to_excl=ix_to_excl';
    
    AreaRatios(:,:,:,:,ix_to_excl)=[];
    if(exist('Gene'))
        Gene(:,:,:,:,ix_to_excl)=[];
    end
    if(exist('Gene_bg'))
        Gene_bg(:,:,:,:,ix_to_excl)=[];
    end
    if(exist('Gene_bg100'))
        Gene_bg100(:,:,:,:,ix_to_excl)=[];
    end
    if(exist('Gene_dotseg'))
        Gene_dotseg(:,:,:,:,ix_to_excl)=[];
    end
    %}
    
    
    
    % EXCLUDE the bin if AR too low to avoid border effects
%if less than 0.9 I say it is background
    if strmatch(listdir.name{f}, 'AOA_mirr_protein_0h_0olap')
        ix_ar = AreaRatios<0.4
    else
        ix_ar = AreaRatios<0.7 
    end
        
    % Let's try with a set number of animals instead, after all there is no
    % reason to be more stringent when we have a lot of animals no ?
    %{
    if ismember(listdir.name{f}, gene_specific_area_ratio)
        areaRatioThreshold = 0;
        disp(['found:',listdir.name{f}])
    
    else
        areaRatioThreshold = 3;
    end
    mean_AreaRatios = AreaRatios(:,:,:,:,1);
    field = size(AreaRatios);
    number_of_animals = field(length(size(AreaRatios))) - 1;
    mean_Area = mean_AreaRatios * number_of_animals;
    ix_ar = mean_Area < areaRatioThreshold;
    disp(areaRatioThreshold)
    %}
    AreaRatios(ix_ar)     = 0;

    
    %update the mean AR after selection nota ==> impact the smallest area
    [nx,ny,~,~,nnotum_plus_one] =size(AreaRatios);
    AreaRatios(:,:,:,:,1) = sum(AreaRatios(:,:,:,:,2:end),5)./(nnotum_plus_one-1);
    if(exist('Gene'))
        Gene_Prctl       = normalizePrctl5D(Gene,AreaRatios,prctl);
        Gene_Studentized = normalizeStdz5D(Gene,AreaRatios);
        Gene(:,:,:,:,1)              = nansum(       Gene(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_Prctl(:,:,:,:,1)        = nansum(Gene_Prctl(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_Studentized(:,:,:,:,1)  = nansum(Gene_Studentized(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        
    end
    if(exist('Gene_bg'))
        Gene_bg_Prctl        = normalizePrctl5D(Gene_bg,AreaRatios,prctl);
        Gene_bg_Studentized  = normalizeStdz5D(Gene_bg,AreaRatios);
        Gene_bg(:,:,:,:,1)             = nansum(Gene_bg(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_bg_Prctl(:,:,:,:,1)       = nansum(Gene_bg_Prctl(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_bg_Studentized(:,:,:,:,1) = nansum(Gene_bg_Studentized(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
    end
    
    if(exist('Gene_bg50'))
        Gene_bg_Prctl        = normalizePrctl5D(Gene_bg50,AreaRatios,prctl);
        Gene_bg_Studentized  = normalizeStdz5D(Gene_bg50,AreaRatios);
        Gene_bg50(:,:,:,:,1)             = nansum(Gene_bg50(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_bg_Prctl(:,:,:,:,1)       = nansum(Gene_bg_Prctl(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_bg_Studentized(:,:,:,:,1) = nansum(Gene_bg_Studentized(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
    end
    if(exist('Gene_dotseg'))
        Gene_dotseg_Prctl        = normalizePrctl5D(Gene_dotseg,AreaRatios,prctl);
        Gene_dotseg_Studentized  = nokrmalizeStdz5D( Gene_dotseg,AreaRatios);
        Gene_dotseg(:,:,:,:,1)             = nansum(Gene_dotseg(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_dotseg_Prctl(:,:,:,:,1)       = nansum(Gene_dotseg_Prctl(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Gene_dotseg_Studentized(:,:,:,:,1) = nansum(Gene_dotseg_Studentized(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
    end
    
    if(exist('Cad'))
        Cad_Prctl        = normalizePrctl5D(Cad,AreaRatios,prctl);
        Cad_Studentized  = normalizeStdz5D(Cad,AreaRatios);
        Cad_bg(:,:,:,:,1)             = nansum(Cad(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Cad_Prctl(:,:,:,:,1)       = nansum(Cad_Prctl(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
        Cad_Studentized(:,:,:,:,1) = nansum(Cad_Studentized(:,:,:,:,2:end).* AreaRatios(:,:,:,:,2:end) ,5)./sum(AreaRatios(:,:,:,:,2:end),5);
    end
    
    
    n_animal_AR_not_nan   = nansum(AreaRatios(:,:,1,1,2:end)>0,5);
    close all
    % SCATTER PLOT

    save(strcat(path_output,'image_nrmlized/',mapAnimal),'REG','Cad*','Gene*','mapAnimal','AreaRatios','n_animal_AR_not_nan','list_notum')
    
    %{
    % je sauvagarde aussi toutes les images au m�me endroit:
    path_all = [main_path,'17APF_All_ImagesRescld/',num2str(resol),'um_olap',num2str(gridOverlap),'/'];
    if ~exist(path_all,'dir')
        mkdir(path_all)
    end
    save([path_all,mapAnimal],'REG','Cad*','Gene*','mapAnimal','AreaRatios','n_animal_AR_not_nan','list_notum')
     %}

    ix =ix+1;
    n_animal_gene{ix,1} = {mapAnimal};
    n_animal_gene{ix,2} = max(n_animal_AR_not_nan(:));
    n_animal_gene{ix,3} = sum(n_animal_AR_not_nan(:)==n_animal_gene{ix,2});
    
    
    if strmatch(listdir.name{f}, 'AOA_mirr_protein_0h_0olap')
        imagesc(Gene_bg_Prctl(:,:,1,1,1))
    end
    
end

n_animal_gene = cell2table(n_animal_gene);
n_animal_gene.Properties.VariableNames = {'gene','nb_nota','nb_sq_smallest_notum'};
writetable(n_animal_gene,strcat(path_output,'nb_notum_per_mean_after_selection.xlsx'));

%% Generating PDFs of Raw Images
disp("Generating PDFs for raw images");
for f = 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA, listdir.name{f}, '/name_notum.mat'), 'mapAnimal') % names of the notums used to make AOA
    load(strcat(path_output, 'image_nrmlized/', mapAnimal))
    if (exist('Gene'))
        ncol = 3;
        [nx, ny, ~, ~, nnotum_plus_one] = size(Gene);
        % Display the name of the animal being processed
        disp(['Processing animal: ', mapAnimal]);
        Make_Image_Gene(Gene, REG, AreaRatios, nnotum_plus_one, list_notum, path_output, mapAnimal, '', gridOverlap)
    end
end
ManagePdf('Image_raw.pdf', path_output)

%% Generating PDFs of Images with background removal
disp("Generating PDFs for images with background removal");
for f = 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA, listdir.name{f}, '/name_notum.mat'), 'mapAnimal') % names of the notums used to make AOA
    load(strcat(path_output, 'image_nrmlized/', mapAnimal))
    if (exist('Gene_bg'))
        ncol = 3;
        [nx, ny, ~, ~, nnotum_plus_one] = size(Gene_bg);
        % Display the name of the animal being processed
        disp(['Processing animal: ', mapAnimal]);
        Make_Image_Gene(Gene_bg, REG, AreaRatios, nnotum_plus_one, list_notum, path_output, mapAnimal, '', gridOverlap)
    elseif (exist('Gene_bg50'))
        ncol = 3;
        [nx, ny, ~, ~, nnotum_plus_one] = size(Gene_bg50);
        % Display the name of the animal being processed
        disp(['Processing animal: ', mapAnimal]);
        Make_Image_Gene(Gene_bg50, REG, AreaRatios, nnotum_plus_one, list_notum, path_output, mapAnimal, '', gridOverlap)
    end
end
ManagePdf('Image_bg.pdf', path_output)

%% Generating PDFs Percentile normalized (prclt calculated on area corresponding to smallest fly : AR =1 on all notums)

% For raw images 
disp("Generating PDFs for images with percentile normalization");
for f= 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene_Prctl'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_Prctl);
        Make_Image_Gene(Gene_Prctl,REG,AreaRatios,nnotum_plus_one,...
            list_notum,path_output,mapAnimal,'Mean- Nrmlz Prctl ',gridOverlap)
    end
end
ManagePdf('Image_Percentile.pdf',path_output)

disp("Generating PDFs for images with student normalization");
for f= 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene_Studentized'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_Studentized);
        Make_Image_Gene(Gene_Studentized,REG,AreaRatios,nnotum_plus_one,...
            list_notum,path_output,mapAnimal,'Mean- Nrmlz STUDENT ',gridOverlap)
    end
end
ManagePdf('Image_Student.pdf',path_output)

% For background removal images
disp("Generating PDFs for images with percentile normalization (background removal)");
for f= 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene_bg_Prctl'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_bg_Prctl);
        Make_Image_Gene(Gene_bg_Prctl,REG,AreaRatios,nnotum_plus_one,...
            list_notum,path_output,mapAnimal,'Mean bg - Nrmlz Prctl ',gridOverlap)
     end
end
ManagePdf('Image_bg_Percentile.pdf',path_output)

disp("Generating PDFs for images with student normalization (background removal)");
for f= 1:length(listdir.name)
     clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene_bg_Studentized'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_bg_Studentized);
        Make_Image_Gene(Gene_bg_Studentized,REG,AreaRatios,nnotum_plus_one,...
            list_notum,path_output,mapAnimal,'Mean- Nrmlz STUDENT ',gridOverlap)
    end
end
ManagePdf('Image_bg_Student.pdf',path_output)


function mat5d_prct = normalizePrctl5D(mat5d,AR,pct)
[~,~,~,~,nanimal] = size(mat5d);
for i=1:nanimal
    temp = mat5d(:,:,:,:,i);
    temp = temp(:);%on vectorise
    % on calcule min/max sur region ou mean AR =1 partout (Smallest fly)
    % si j'ai fait de la selection d'image, il faut que cela ait été
    % calculé eavant
    ix_AR1 = AR(:,:,:,:,1)==1;
    ix_AR1 = ix_AR1(:);
    mini = prctile(temp(ix_AR1==1),pct);
    maxi = prctile(temp(ix_AR1==1),100-pct);
    mat5d_prct(:,:,:,:,i) = (mat5d(:,:,:,:,i) - mini)./(maxi-mini);
    temp= mat5d_prct(:,:,:,:,i);
    %saturation
    % temp(temp >1) = 1;
    temp(temp <0) = 0;
    mat5d_prct(:,:,:,:,i) = temp;
    
    
end
end

function mat5d_stdz = normalizeStdz5D(mat5d,AR)
[~,~,~,~,nanimal] = size(mat5d);
for i=1:nanimal
    temp = mat5d(:,:,:,:,i);
    temp = temp(:);%on vectorise
    
    % on calcule mediane sur r?gion ou AR =1 partout
    ix_AR1 = AR(:,:,:,:,1)==1;
    ix_AR1 = ix_AR1(:);
    temp = temp(ix_AR1==1);
    m    = nanmean(temp(:)); %moyenne sur AR =1
    s    = nanstd(temp(:));
    mat5d_stdz(:,:,:,:,i) = (mat5d(:,:,:,:,i) - m)/s;
end
end


function Make_Image_Gene(Gene,REG,AreaRatios,nnotum_plus_one,list_notum,path_output,mapAnimal,text_title,gridOverlap)
ix_notNaN     = ~isnan(Gene(:,:,1,1,1));
ix_col_notNaN = sum(ix_notNaN,1)>0;
ix_row_notNaN = sum(ix_notNaN,2)>0; 



ncol =3;
min_y = find(sum(AreaRatios(:,:,1,1,1),1)>0);
min_y = min_y(1) -1 ;
% pour eviter que min_y =0
min_y = max(min_y,1) ;
max_y = find(sum(AreaRatios(:,:,1,1,1),1)==0);
max_y = max_y(max_y>min_y) ;
max_y = max_y(1)+ 1;

min_x = find(sum(AreaRatios(:,:,1,1,1),2)>0);
min_x = min_x(1) -1 ;
% pour eviter que min_y =0
min_x = max(min_x,1) ; 
max_x = find(sum(AreaRatios(:,:,1,1,1),2)==0);
max_x = max_x(max_x>min_x) ;
max_x = max_x(1)+ 1;


macrocheats = array2table(REG.MacrocaetesMCU ) ;
macrocheats.Properties.VariableNames = {'m1','m2','m3','m4','m5','m6','m7','m8'};


figure('visible','off');
subplot(ceil((nnotum_plus_one)/ncol),ncol,1);
% si je met macrocheat je ne peux pas enlever les nan sinon positions macrocheatssont fausses
% h=imagesc( Gene(ix_row_notNaN,ix_col_notNaN,1,1,1) ); 
%set(h,'AlphaData',AreaRatios(ix_row_notNaN,ix_col_notNaN,1,1,1)>= min(0.8,4/(nnotum_plus_one-1)))  % need at least 4 animals to see signal

h=imagesc( Gene(min_x:max_x,min_y:max_y,1,1,1) );
mytitle = ['\color{magenta} ',text_title];
set(h,'AlphaData',AreaRatios(min_x:max_x,min_y:max_y,1,1,1)>= min(0.8,3.5/(nnotum_plus_one-1))) ; % need at least 4 animals to see signal

title(mytitle, 'FontSize',8) ;% interpreter set at none to avoid interpretation underscore
axis('off');
axis image

colormap(jet);
hold on
scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
hold off
daspect auto
% colorbar
for n= 2:nnotum_plus_one
    
    subplot(ceil((nnotum_plus_one)/ncol),ncol,n);
    
    %h= imagesc( Gene(ix_row_notNaN,ix_col_notNaN,1,1,n));
    %set(h,'AlphaData',AreaRatios(ix_row_notNaN,ix_col_notNaN,1,1,n)>=min(0.5,4/(nnotum_plus_one-1))) % if AreaRation < 0.5 ==> background

    h= imagesc( Gene(min_x:max_x,min_y:max_y,1,1,n));
    set(h,'AlphaData',AreaRatios(min_x:max_x,min_y:max_y,1,1,n)> 0.5); % if AreaRation < 0.5 ==> background
    title(list_notum(n), 'Interpreter', 'none','FontSize',8) % interpreter set at none to avoid interpretation underscore
    axis('off');  axis image; colormap(jet)
    hold on
    scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
    hold off
    daspect auto
    % colorbar()
end

print(strcat(path_output,'fig',mapAnimal),'-dpdf')
close
end



