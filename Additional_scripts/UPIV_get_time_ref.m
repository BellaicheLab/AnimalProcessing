function [avg_animals, list_time_ref,list_frame_ref] =UPIV_get_time_ref(path_Mat,path_animals)
% UPIV_get_time_ref  finds the 2/3 of rotation peaks.

% Loading backup
load(path_Mat)

% Assessing number of movies
[~,~,nb_movie]=size(value);

% Assessing the names of the animals 
avg_animals = split(legendQname, '.');
avg_animals = avg_animals(2:end, 1);

% Will contain the time refs and frame refs
list_time_ref=[];
list_frame_ref=[];

% For each movie
for i=1:(nb_movie-1)
    
    % We get the name of the animal
    animal = string(avg_animals(i));
    
    % We set the path for the SAPparameters.mat backup in the SAP_folder
    path_animal_complete = strcat(path_animals,sprintf('/%s',animal));
    path_animal_complete = strcat(path_animal_complete,sprintf('/SAP_%s',animal));
    path_animal_complete =strcat(path_animal_complete,sprintf('/SAPparameters.mat'));
    
    % We load the SAP backup
    load(path_animal_complete,'timeRef','frameRef','dt','nFrames')
    
    % We fetch the minimum value and its frame
    [X,timepoint_start]=min(value(:,1:nFrames/2,i+1));
    
    % We fetch the match value and its frame
    [n,l]=max(value(:,timepoint_start:end,i+1));
    
    % We fetch the frame value for witch it is equal to 3/4 of the
    % migration peaks
    n=n*3/4;
    [~,l2]=min(abs(value(:,timepoint_start:l+timepoint_start,i+1)-n));
    
    time_ref=TimeDecArray(l2+timepoint_start);
    list_time_ref=[list_time_ref ; time_ref];
    list_frame_ref=[list_frame_ref ; round(time2frame(time_ref,timeRef,frameRef,dt))]

end
end