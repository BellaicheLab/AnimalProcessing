function D=readBordersNei(filefullpath)
%READBORDERSNEI read bordersNeighbours file
% D=readBordersNei(FILEFULLPATH) reads & extracts the information contained
% in FILEFULLPATH.
% 
% D structure is: 
% [Nx1 int32]    [Nx1 int32]    [Nx1 int32]    {Nx1 cell}    {Nx1 cell}
% ID, 1st Neighbour(R), 2nd Neighbour(R), 1st Neighbour(A), 2nd Neighbour(A)
%
% /!\ Delimiter in FILEFULLPATH MUST ',' /!\
%
% GOYA Yûki
% v0.3, last update: 2012-11-19
% 
   fid=fopen(filefullpath);
   % open failed
   if fid==-1
       disp(['ERROR: unable to open ' filefullpath]);
       D=[];
       return;
   end
   %                1  2  3  4  5
   D=textscan(fid,'%d %d %d %s %s','Delimiter',',');
   
   % DO NOT FORGET TO CLOSE !
   fclose(fid);
end

%% history %%
%
% 0.3: 2012-11-19
% * opening check added. 
%
% 0.2: 2011-12-09
% * fclose added.
%
% 0.1: 2011-12-07
% * creation.
%
