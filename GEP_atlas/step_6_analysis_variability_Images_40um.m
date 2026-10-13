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

%% SELECT DATA

%
%main_path = '/path/to/data/data/Processing17h00/'

%root_path = [main_path,'17APF_All_ImagesRescld/']
%path_AOA    = [root_path,'AOA_',num2str(resol),'um_olap',num2str(gridOverlap),'/'];


%path_output = [root_path,'analysis/',num2str(resol),'um_olap',num2str(gridOverlap),'/'];
%}

%path_AOA= '/path/to/data/projects/FISH/image_analysis/results/rescaled/SAPfish_RNAi/data_rescaled/AOA_40um_olap0.5/';
%path_output ='/path/to/data/projects/FISH/image_analysis/results/rescaled/SAPfish_RNAi/data_rescaled/Analysis_AOA_40um_olap0.5/';
%path_AOA='/path/to/data/projects/FISH/FISH_quantifier/results/rescaled/SAPfish_RNAi/data_rescaled/AOA_40um_olap0.5/';
%path_AOA=    '/path/to/data/projects/FISH/results/rescaled/SAPfish_RNAi/data_rescaled/AOA_15um_olap0/';
%path_output ='/path/to/data/projects/FISH/results/rescaled/SAPfish_RNAi/data_rescaled/analysis_no_satur_pctl005/15um_olap0/';

path_AOA   = "/path/to/data/data/Processing17h00/17APF_All_ImagesRescld/3_data_rescaled/AOA_40um_olap0.5/";
path_output   = "/path/to/data/data/Processing17h00/17APF_All_ImagesRescld/analysis/40um_olap0.5/";


%path_AOA    ='/path/to/data/projects/FISH/results/rescaled/SAPfish_RNAi/data_rescaled/AOA_40um_olap0.5/'
%path_output ='/path/to/data/projects/FISH/results/rescaled/SAPfish_RNAi/data_rescaled/analysis_230215/';

mkdir(path_output)

% List of genes processed by AOA
listdir = struct2table( dir(path_AOA) );
listdir( ismember(listdir.name,{'.','..','.DS_Store'}) ,: ) =[]; % remove first 2 rows
listdir = listdir(contains(listdir.name,'_0h_0olap'),:);
listdir( ismember(listdir.name,{'yrt','Mnt','emc','msn','yrt'}) ,: ) =[]; % remove first 2 rows

%list_to_excl = {''}



%% make list of nota for selection
%
list_full_notum={};
for f= 1:length(listdir.name)
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    list_full_notum = union(list_full_notum,list_notum);
end


%}

%REVOIR PVR:
%% save data normalized
%

mkdir(strcat(path_output,'image_nrmlized/'))
ix=0;

for f= 1:length(listdir.name)
    clear Gene* Cad
    load(strcat(path_AOA,listdir.name{f},'/AOA_backup.mat')) %AOA data
    clearvars -except gridOverlap main_path prctl list_to_excl isfish f resol gridOverlap ix n_animal_gene Gene* AreaRatios Cad REG mask_holes list_name mapAnimal path_output path_AOA listdir subplot
    clear *Smap
    
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    ncol =3;
    
    macrocheats = array2table( (1/(1-gridOverlap))*REG.MacrocaetesMCU ) ;
    macrocheats.Properties.VariableNames = {'m1','m2','m3','m4','m5','m6','m7','m8'};
    
    [nr,nc,~,~,nimage] = size(AreaRatios);
    i=1;
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
    ix_ar                 = AreaRatios<0.9 ; %if less than 0.9 I say it is background
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
        Gene_dotseg_Studentized  = normalizeStdz5D( Gene_dotseg,AreaRatios);
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
    
    
end
n_animal_gene = cell2table(n_animal_gene);
n_animal_gene.Properties.VariableNames = {'gene','nb_nota','nb_sq_smallest_notum'};
writetable(n_animal_gene,strcat(path_output,'nb_notum_per_mean_after_selection.xlsx'));
%%%
%{
for f= 1:length(listdir.name)
    clear Gene*
    load([path_AOA,listdir.name{f},'/name_notum.mat']) %names of the notums used to make AOA
    load([path_output,'image_nrmlized/',mapAnimal])
    
    clearvars -except Gene* REG AreaRatios Cad list_name mapAnimal path_output path_AOA listdir subplot gridOverlap
    ncol =3;
    [nx,ny,~,~,nnotum_plus_one] =size(Gene);
    %
    %MEAN IMAGE
    Gene_Prctl=Gene_Prctl(:,:,1,1,1);
    ix_notNaN     = ~isnan(Gene_Prctl);
    ix_col_notNaN = sum(ix_notNaN,1)>0; % at least one pixel not nan
    ix_row_notNaN = sum(ix_notNaN,2)>0;
    im  = mat2gray(Gene_Prctl(:,:));
    mkdir(strcat(path_output,'mean_image/'))
    imwrite(im,strcat(path_output,'mean_image/',mapAnimal,'_prctl.tif'))
    
end

%}
%% for each gene : RAW - calculate the mean intensity my-self
%

for f= 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene);
        Make_Image_Gene(Gene,REG,AreaRatios,nnotum_plus_one,list_notum,path_output,mapAnimal,'',gridOverlap)
    end
end
ManagePdf('Image_raw.pdf',path_output)
%

for f= 1:length(listdir.name)
    clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Gene_bg'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_bg);
        Make_Image_Gene(Gene_bg,REG,AreaRatios,nnotum_plus_one,list_notum,path_output,mapAnimal,'',gridOverlap)
    elseif(exist('Gene_bg50'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Gene_bg50);
        Make_Image_Gene(Gene_bg50,REG,AreaRatios,nnotum_plus_one,list_notum,path_output,mapAnimal,'',gridOverlap)
    end
end
ManagePdf('Image_bg.pdf',path_output)


%}
%% plot nrmlized image with percentile (prclt calculated on area corresponding to smallest fly : AR =1 on all notums)
% prctlie value calculated on area where all the notum =1
%
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

for f= 1:length(listdir.name)
     clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat'),'mapAnimal') %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    if(exist('Cad_Prctl'))
        ncol =3;
        [nx,ny,~,~,nnotum_plus_one] =size(Cad_Prctl);
        Make_Image_Gene(Cad_Prctl,REG,AreaRatios,nnotum_plus_one,...
            list_notum,path_output,mapAnimal,'Mean- Nrmlz Prctl ',gridOverlap)
    end
end
ManagePdf('Image_Cad_Percentile.pdf',path_output)

%}

%% Make mean pdf
%{
for f= 1:length(listdir.name)
    clear macrocheats
    load([path_AOA,listdir.name{f},'/name_notum.mat']) %names of the notums used to make AOA
    load([path_output,'image_nrmlized/',mapAnimal])
    macrocheats = array2table( (1/(1-gridOverlap))*REG.MacrocaetesMCU ) ;
    macrocheats.Properties.VariableNames = {'m1','m2','m3','m4','m5','m6','m7','m8'};
  
    
    ncol =3;
    [nx,ny,~,~,nnotum_plus_one] =size(Gene);
    AR_Mean               = squeeze(AreaRatios(:,:,1,1,1));
    Gene_bg_Mean_Prctl       = squeeze(Gene_bg_Prctl(:,:,1,1,1));
    
    %MEAN IMAGE
    figure('visible','off');
    
    %ix_notNaN     = ~isnan(Gene_Mean_Prctl);
    %ix_col_notNaN = sum(ix_notNaN,1)>0;
    %ix_row_notNaN = sum(ix_notNaN,2)>0;
    %h=imagesc( Gene_Mean_Prctl(ix_row_notNaN,ix_col_notNaN) );
    
    h=imagesc( Gene_bg_Mean_Prctl(1:20,1:45) );
    set(h,'AlphaData',AR_Mean(1:20,1:45)>min(0.8,3/(nnotum_plus_one-1))  ) % if AreaRation < 0.5 ==> background
    
    title([mapAnimal,' - Percentiles 1.5-98.5'], 'Interpreter', 'none') % interpreter set at none to avoid interpretation underscore
    axis('off');   
    axis image ;colormap(jet)
    hold on
        scatter(macrocheats{1,:},macrocheats{2,:},'xm','LineWidth',3)
    hold off
    daspect auto
    print(strcat(path_output,'fig_',mapAnimal,'1'),'-dpdf')
    
    close
    
end
ManagePdf('Image_bg_Prctl_Mean.pdf',path_output)
%}
%% compare Mean image mean raw / prctl / mean std-
%
for f= 1:length(listdir.name)
     clear Gene*
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    ncol =3;
    if(exist('Gene'))
        
        [nx,ny,~,~,nnotum_plus_one] =size(Gene);
        
        Gene_Mean_Raw         = squeeze(Gene(:,:,1,1,1));
        Gene_Mean_Studentized = squeeze(Gene_Studentized(:,:,1,1,1));
        Gene_Mean_Prctl       = squeeze(Gene_Prctl(:,:,1,1,1));
        AR_Mean               = squeeze(AreaRatios(:,:,1,1,1));
        MakeCompareMean(Gene_Mean_Studentized,Gene_Mean_Raw,Gene_Mean_Prctl,REG,AR_Mean,mapAnimal,path_output,gridOverlap,prctl)
    end
end
ManagePdf('Cmpr_Nrmlztn_calculs_on_smallest_notum.pdf',path_output)


%}
%% image : plot image available and calculate average - NOT SAVED
%{
f=1;
load([path_AOA,listdir.name{f},'/AOA_backup.mat'])
load([path_AOA,listdir.name{f},'/name_notum.mat'])
clearvars -except Gene AreaRatios Cad REG list_name mapAnimal path_output gridOverlap
path_AOA listdir gridOverlap

[nx,ny,~,~,nim] =size(Gene);

for n=1:(nim)
    
   
    ncol =3;
    
    subplot = @(m,n,p) subtightplot(m,n,p);
    subplot(ceil(nim/ncol),ncol,n)
    h=imagesc( Gene(:,:,1,1,n));

    set(h,'AlphaData',AreaRatios(:,:,1,1,n)>0.5) % if AreaRation < 0.5 ==> background
    title(list_name(n), 'Interpreter', 'none') % interpreter set at none to avoid interpretation underscore
    axis('off')
    
    
    
end
%}

%% BOX PLOT : comparison distribution values for each notum and normalization
%{
    for f=1:height(listdir)
        load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
        load(strcat(path_output,'image_nrmlized/',mapAnimal))
      
        [nx,ny,~,~,nim] =size(Gene);
        X      = squeeze(Gene(:,:,1,1,1);X=X(:);
        Xprctl = Gene_Prctl(:,:,1,1,1);Xprctl=Xprctl(:);
        Xstd   = Gene_Studentized(:);Xstd=Xstd(:);
        AR_smallest_notum = AreaRatios(:,:,:,:,1)==1;
        
        for n=2:(nim)
            temp = Gene(:,:,1,1,n);
            X=[X,temp(:)];
            Xprctl = [Xprctl,normalizePrctl(temp(:), AR_smallest_notum(:),prctl)];
            Xstd   = [Xstd,normalizeStdz(temp(:),    AR_smallest_notum(:))];
            
        end
        subplot = @(m,n,p) subtightplot(m,n,p,0.06);
        
        figure('visible','off');
        
        
        subplot(1,3,1)
        boxplot(X,list_name)
        title([mapAnimal,' raw'])
        set(gca,'FontSize',10,'XTickLabelRotation',90)
        
        subplot(1,3,2)
        boxplot(Xprctl,list_name)
        title([mapAnimal,' prctl ',num2str(prctl)])
        set(gca,'FontSize',10,'XTickLabelRotation',90)
        
        subplot(1,3,3)
        boxplot(Xstd,list_name)
        title([mapAnimal,' Mean std'])
        set(gca,'FontSize',10,'XTickLabelRotation',90)
        
        print(strcat(path_output,'fig',mapAnimal),'-dpdf')
        close
    end
    ManagePdf('BoxPlot_Nrmlz_Intensity.pdf',path_output)
end

%}

%%  Get descriptive statistics for each image
%{
stat_des  = cell2table(cell(0,10), 'VariableNames', {'short_name','name','nrmlztn','min', 'p1', 'median', 'p99', 'max','mean','std'});

% pour chaque image reagrder les valeur descriptives
for f=1:height(listdir)
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    
    [nx,ny,~,~,nim] =size(Gene);
    
    
    
    X      = Gene_Mean_Raw(:);
    Xprctl = Gene_Mean_Prctl(:);
    Xstd   = Gene_Mean_Studentized(:);
    
    d        = Gene_Mean_Raw(:);
    stat_des = [stat_des;{mapAnimal,'mean expression','raw',nanmin(d),prctile(d,1),...
        nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
    
    d        = Gene_Mean_Prctl(:);
    stat_des = [stat_des;{mapAnimal,'mean expression','prctl',nanmin(d),prctile(d,1),...
        nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
    
    d        = Gene_Mean_Studentized(:);
    stat_des = [stat_des;{mapAnimal,'mean expression','mean-std',nanmin(d),prctile(d,1),...
        nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
    
    AR_smallest_notum = AreaRatios(:,:,:,:,1)==1;
    
    for n=2:(nim)
        temp   = Gene(:,:,1,1,n);
        X      = [X,temp(:)];
        Xprctl = [Xprctl,normalizePrctl(temp(:),AR_smallest_notum(:),prctl(:))];
        Xstd   = [Xstd,normalizeStdz(temp(:),AR_smallest_notum(:))];
        
        d        = temp(:);
        stat_des = [stat_des;{mapAnimal,list_name{n},'raw',nanmin(d),prctile(d,1),...
            nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
        
        d        = normalizePrctl(temp(:),AR_smallest_notum(:),prctl);
        stat_des = [stat_des;{mapAnimal,list_name{n},'prctl',nanmin(d),prctile(d,1),...
            nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
        
        d        = normalizeStdz(temp(:),AR_smallest_notum(:));
        stat_des = [stat_des;{mapAnimal,list_name{n},'mean-std',nanmin(d),prctile(d,1),...
            nanmedian(d),prctile(d,99),nanmax(d),nanmean(d),nanstd(d)}];
        
        
    end
end

save(strcat(path_output,'stat_descriptive'),'stat_des')

%}


%% save image for fiji
%
for f= 1:length(listdir.name)
    load(strcat(path_AOA,listdir.name{f},'/name_notum.mat')) %names of the notums used to make AOA
    load(strcat(path_output,'image_nrmlized/',mapAnimal))
    
    clearvars -except Gene* AreaRatios Cad REG list_name mapAnimal path_output path_AOA listdir subplot gridOverlap
    ncol =3;
    [nx,ny,~,~,nnotum_plus_one] =size(Gene);
    %
    %MEAN IMAGE
    Gene_Prctl=Gene_Prctl(:,:,1,1,1);
    ix_notNaN     = ~isnan(Gene_Prctl);
    ix_col_notNaN = sum(ix_notNaN,1)>0; % at least one pixel not nan
    ix_row_notNaN = sum(ix_notNaN,2)>0;
    im  = mat2gray(Gene_Prctl(:,:));
    mkdir(strcat(path_output,'mean_image/'))
    imwrite(im,strcat(path_output,'mean_image/',mapAnimal,'_prctl.tif'))
end

%}
%% compare grid sze
%{
f= 1;
load(strcat(path_AOA,listdir.name{f},'/AOA_backup.mat')) %AOA data
figure
imagesc( Gene(:,:,1) );
title(num2str(igrid))
axis('off')
colormap(jet)
colorbar

end
%}



%%
function ManagePdf(output_filename,path_output)

dirnow=pwd;
cd(path_output);
exec_Terminal=['! "/System/Library/Automator/Combine PDF Pages.action/Contents/Resources/join.py" -o ',output_filename,' ','fig*.pdf'];
eval(exec_Terminal);
exec_Terminal=['! rm fig*.pdf'];
eval(exec_Terminal);
cd(dirnow);
clear dirnow exec_Terminal
end


function mat5d_min_max = normalizeMinMax5D(mat5d,AR)
[~,~,~,~,nanimal] = size(mat5d);
for i=1:nanimal
    temp = mat5d(:,:,:,:,i);
    temp = temp(:);%on vectorise
    % on calcule min/max sur r?gion ou AR =1 partout (Smallest fly)
    ix_AR1 = AR(:,:,:,:,1)==1;
    ix_AR1 = ix_AR1(:);
    mini = nanmin(temp(ix_AR1==1));
    maxi = nanmax(temp(ix_AR1==1));
    mat5d_min_max(:,:,:,:,i) = (mat5d(:,:,:,:,i) - mini)./(maxi-mini);
end
end


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


function mat5d_median = normalizeMedian5D(mat5d,AR)
[~,~,~,~,nanimal] = size(mat5d);
for i=1:nanimal
    temp = mat5d(:,:,:,:,i);
    temp = temp(:);%on vectorise
    
    % on calcule mediane sur r?gion ou AR =1 partout
    ix_AR1 = AR(:,:,:,:,1)==1;
    ix_AR1 = ix_AR1(:);
    med =  nanmedian(temp(ix_AR1==1));
    mat5d_median(:,:,:,:,i) = mat5d(:,:,:,:,i) - med;
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

function tn = normalizeMinMax(t,AR)
ix = AR==1;
ts = t(ix==1);
tn = (t-min(ts(:)))./(max(ts(:))- min(ts(:)));
end

function tn = normalizePrctl(t,AR,prct)
ix       = AR==1;
ts       = t(ix==1);
tn       = ( t-prctile(ts,prct) )./( prctile(ts,100-prct) - prctile(ts,prct) );
%tn(tn>1) = 1;
tn(tn<0) = 0 ;
end

function tn = normalizeMedian(t,AR)
ix = AR==1;
ts = t(ix==1);
tn = (t-nanmedian(ts));
end

function tn = normalizeStdz(t,AR)
ix = AR==1;
ts = t(ix==1);
tn = (t-nanmean(ts))./nanstd(ts);
end


function h=make_image(Gene_Mean_Raw,AR_Mean,ix_row_notNaN,ix_col_notNaN)

h=imagesc( Gene_Mean_Raw(ix_row_notNaN,ix_col_notNaN) );
set(h,'AlphaData',AR_Mean(ix_row_notNaN,ix_col_notNaN)>0.8) % if AreaRation < 0.5 ==> background
title('\color{magenta}My mean', 'FontSize',8) % interpreter set at none to avoid interpretation underscore
axis('off')
axis image
colormap(jet)
% colorbar
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
subplot(ceil((nnotum_plus_one)/ncol),ncol,1)
% si je met macrocheat je ne peux pas enlever les nan sinon positions macrocheatssont fausses
% h=imagesc( Gene(ix_row_notNaN,ix_col_notNaN,1,1,1) ); 
%set(h,'AlphaData',AreaRatios(ix_row_notNaN,ix_col_notNaN,1,1,1)>= min(0.8,4/(nnotum_plus_one-1)))  % need at least 4 animals to see signal

h=imagesc( Gene(min_x:max_x,min_y:max_y,1,1,1) )
mytitle = ['\color{magenta} ',text_title];
set(h,'AlphaData',AreaRatios(min_x:max_x,min_y:max_y,1,1,1)>= min(0.8,3.5/(nnotum_plus_one-1)))  % need at least 4 animals to see signal

title(mytitle, 'FontSize',8) % interpreter set at none to avoid interpretation underscore
axis('off')
axis image

colormap(jet)
hold on
scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
hold off
daspect auto
% colorbar
for n= 2:nnotum_plus_one
    
    subplot(ceil((nnotum_plus_one)/ncol),ncol,n)
    
    %h= imagesc( Gene(ix_row_notNaN,ix_col_notNaN,1,1,n));
    %set(h,'AlphaData',AreaRatios(ix_row_notNaN,ix_col_notNaN,1,1,n)>=min(0.5,4/(nnotum_plus_one-1))) % if AreaRation < 0.5 ==> background

    h= imagesc( Gene(min_x:max_x,min_y:max_y,1,1,n));
    set(h,'AlphaData',AreaRatios(min_x:max_x,min_y:max_y,1,1,n)> 0.5) % if AreaRation < 0.5 ==> background
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


function MakeCompareMean(Gene_Mean_Studentized,Gene_Mean_Raw,Gene_Mean_Prctl,REG,AR_Mean,mapAnimal,path_output,gridOverlap,prctl)
macrocheats = array2table( (1/(1-gridOverlap))*REG.MacrocaetesMCU ) ;
macrocheats.Properties.VariableNames = {'m1','m2','m3','m4','m5','m6','m7','m8'};


min_y = find(sum(AR_Mean(:,:),1)>0);
min_y = min_y(1) -1 ;
% pour eviter que min_y =0
min_y = max(min_y,1) ;
max_y = find(sum(AR_Mean(:,:),1)==0);
max_y = max_y(max_y>min_y) ;
max_y = max_y(1)+ 1;

min_x = find(sum(AR_Mean(:,:),2)>0);
min_x = min_x(1) -1 ;
min_x = max(min_x,1);
max_x = find(sum(AR_Mean(:,:),2)==0);
max_x = max_x(max_x>min_x) ;
max_x = max_x(1)+ 1;


figure('visible','off');

subplot(3,1,1)
h=imagesc( Gene_Mean_Raw(min_x:max_x,min_y:max_y) );
set(h,'AlphaData',AR_Mean(min_x:max_x,min_y:max_y))%>0.8) % if AreaRation < 0.5 ==> background
title([mapAnimal,' -  raw'], 'Interpreter', 'none') % interpreter set at none to avoid interpretation underscore
axis('off');  axis image; colormap(jet)
daspect([1 1 1])% auto
hold on
scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
hold off

subplot(3,1,2)
%h=imagesc( Gene_Mean_Prctl(ix_row_notNaN,ix_col_notNaN) );
h=imagesc( Gene_Mean_Prctl(min_x:max_x,min_y:max_y) );
set(h,'AlphaData',AR_Mean(min_x:max_x,min_y:max_y))%>0.8) % if AreaRation < 0.5 ==> background

title([mapAnimal,' - Percentiles ',num2str(prctl),'-',num2str(100-prctl)], 'Interpreter', 'none') % interpreter set at none to avoid interpretation underscore
axis('off');    axis image; colormap(jet)
daspect([1 1 1])% auto
hold on
scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
hold off

subplot(3,1,3)
h=imagesc( Gene_Mean_Studentized(min_x:max_x,min_y:max_y) );
set(h,'AlphaData',AR_Mean(min_x:max_x,min_y:max_y))%>0.8) % if AreaRation < 0.5 ==> background
title([mapAnimal,' - Mean Std'], 'Interpreter', 'none') % interpreter set at none to avoid interpretation underscore
axis('off');    axis image;    colormap(jet)
daspect([1 1 1])% auto
hold on
scatter(macrocheats{1,:}-min_y,macrocheats{2,:}-min_x,'xm','linewidth',2)
hold off

print(strcat(path_output,'fig_',mapAnimal,'1'),'-dpdf')
close
end