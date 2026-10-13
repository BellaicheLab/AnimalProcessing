function PIV_pngmaker()
%% version 1.6 (last update: 2012-10-26)
% Formerly "PIV_Reformat" > "Stage1_0_PIV_txt_maker" (1.5)
% GOYA Yûki
%
% Generates PIV txt files required to perform C++ cell & side tracking from
% matlab PIV backup files. Use this program only when Matlab PIV backup files
% were properly generated, but NOT the corresponding png files.
%
   
    %% check current directory %%
    currentDirectory=pwd;
    if ~isdir([currentDirectory '/segmentation_routines'])
       wd=warndlg('segmentation_routines folder not found ! Please make sure to be in the right folder (Segmentation_Update_**).') ;
       waitfor(wd);
       return;
    end    
    
    %% parameters %%
    % load Stage1 parameters
    S1params=Stage1_0_Initial_info();    
    % digits_format
    digits_format =['%0' num2str(S1params.DIGITNUMBER) 'd'];
    % PIV backup folder
    PIVbackupsPath=[S1params.PATHFOLDER '/AIA_' S1params.ANIMAL '/PIV_' S1params.ANIMAL '/Grid_' S1params.PIV_GRID '/Backups'];
    % output folder
    outpath=[S1params.PATHFOLDER '/' S1params.OUTPUTNAME '_backup'];    
    % 2011-11-16: create output folder if not exists
    if ~exist(outpath,'dir'), mkdir(outpath); end
    
    % PIV backup file rootname
    PIVfileroot= ['PIV_' S1params.PIV_GRID  '_' S1params.ANIMAL '_Backup_'];
    % PIV output filename
    PIVfilerootTXT=['PIV_' S1params.PIV_GRID  '_' S1params.ANIMAL '_'];
    
    % 2011-07-06: load XY grid
    try
        XYGrid=load( [PIVbackupsPath '/PIV_' S1params.PIV_GRID  '_' S1params.ANIMAL '_Backup_XY_Grid.mat']);
        XYGrid_X=XYGrid.x; % sliced XYGrid for parfor loop
        XYGrid_Y=XYGrid.y;
    catch err
        if strcmp('MATLAB:load:couldNotReadFile',err.identifier)
            disp(['ERROR! Unable to read ' PIVbackupsPath '/PIV_' S1params.PIV_GRID  '_' S1params.ANIMAL '_Backup_XY_Grid.mat']);
        else
            disp('ERROR ! unable to load PIV grid !')        
            disp(err.identifier);
        end
        return
    end
    % 2011-07-06: image_size
    raw_seg_image=imread([S1params.PATHFOLDER '/' S1params.ROOTFILENAME num2str(S1params.FIRSTIMAGE,digits_format) '.' S1params.FILEEXTENSION]);
    image_size= size(raw_seg_image);

    % 2011-09-26 array of grid size
    PIV_Grid_t={'XS' 'S' 'M' 'L' 'XL'};    
    
    %% Reformat %%
    % 2011-11-16: matlabpool for parallel computing 
    if matlabpool('size')==0, matlabpool open; end
    % slice parameters for parallel run
    PIV_Grid=S1params.PIV_GRID;
    pathfolder=S1params.PATHFOLDER;
    Animal=S1params.ANIMAL;
    
    % parallel loop
    parfor n = S1params.FIRSTIMAGE:S1params.LASTIMAGE-1
        fprintf('processing file %d',n);
        % 2011-09-16: skip if already exist
        if exist([outpath '/' PIVfilerootTXT 't_v_' num2str(n,digits_format) '.png'], 'file' )
           fprintf('\tskipped!\n');
           continue;
        end
        % 2011-09-26: PIV mat file not found case
        filename=[PIVbackupsPath '/' PIVfileroot num2str(n,digits_format) '.mat'];        
        if ~exist(filename,'file')
            % regular grid size not found ! look for next grid ...
            indix=find(ismember(PIV_Grid_t,PIV_Grid)==1)+1;
            % loop on all remaining size
            while indix<=numel(PIV_Grid_t)                                          
                filename=[pathfolder '/AIA_' Animal '/PIV_' Animal '/Grid_' PIV_Grid_t{indix} '/Backups/PIV_' PIV_Grid_t{indix} '_' Animal '_Backup_' num2str(n,digits_format) '.mat'];
                if exist(filename,'file'), break; end
                indix=indix+1;
            end            
            if indix~=6
                % 2011-09-26: display grid size
                fprintf(' >>> %s ',PIV_Grid_t{indix});
                m=load(filename); % load PIV mat
                % load XY grid
                xy=load([pathfolder '/AIA_' Animal '/PIV_' Animal '/Grid_' PIV_Grid_t{indix} '/Backups/PIV_' PIV_Grid_t{indix} '_' Animal '_Backup_XY_Grid.mat']);
                u_image=m.u;
                v_image=m.v;
                % interpolate to fit to the image size
                [~,~,u_image,v_image]=PIV_Interpolate(image_size,xy.x,xy.y,u_image,v_image,'cubic',PIV_Grid_t(indix));
            else
                % every grid failed ... blank PIV ....
                u_image=zeros(image_size);
                v_image=u_image;
            end
        else % no problems here !
            % load PIV mat
            m=load(filename);
            u_image=m.u;
            v_image=m.v;
            % 2011-07-06: interpolate to fit to the image size
            [~,~,u_image,v_image]=PIV_Interpolate(image_size,XYGrid_X,XYGrid_Y,u_image,v_image,'cubic',PIV_Grid); % sliced XYGrid
        end
        % rount to uint8 & set 0 to 128
        u_image=uint8(round(u_image)+128);
        v_image=uint8(round(v_image)+128);        
        % write as an image
        % u_image
        imwrite(u_image,[outpath '/' PIVfilerootTXT 'o_u_' num2str(n,digits_format) '.png']);
        % v_image
        imwrite(v_image,[outpath '/' PIVfilerootTXT 'o_v_' num2str(n,digits_format) '.png']);
        % transpose u & v to be used in C++ tracking with Matlab compatibility
        u_image=u_image';
        v_image=v_image';
        % write as an image
        % u_image (u vector = v because of transposition)
        imwrite(v_image,[outpath '/' PIVfilerootTXT 't_u_' num2str(n,digits_format) '.png']);
        % v_image (v vector = u because of transposition)
        imwrite(u_image,[outpath '/' PIVfilerootTXT 't_v_' num2str(n,digits_format) '.png']); 
        % frame done
        fprintf('\tdone!\n');
    end
    matlabpool close % 2011-11-16
end

%% History %%

% 2012-10-26: 1.6
% - output files changed to PNG images.
% - parameters loading updated.

% 2011-11-16: 1.5
% - output folder existence check added.
% - txt files writing parallelized.

% 2011-09-26: 1.4
% - PIV txt files output folder changed.
% - PIV mat file not found cases added.
% - PIV txt files name changed.

% 2011-09-16: 1.3
% - process skip for existing files added.
% - input parameters loading adjusted.

% 2011-09-08:
% - changed name "PIV_Reformat" to "Stage1_0_PIV_txt_maker" to make it appear right after "Stage1_0_PIV_SRR"

% 2011-08-22: 1.2
% - PIV_SRR v1.1.2 cloned and truncated.

%% end of file %%