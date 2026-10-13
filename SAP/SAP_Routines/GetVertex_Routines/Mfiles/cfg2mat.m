function M=cfg2mat(c)
% displays the configuration corresponding to the binary configuration
% GOYA Yûki
% v0.1 (last update: 2012-12-11)

    M=false(3);
    % center middle
    M(2,2)=1;
    % upper left
    M(1,1)= c(8)=='1';
    % upper middle
    M(1,2)= c(7)=='1';
    % upper right
    M(1,3)= c(6)=='1';
    % center left
    M(2,1)= c(5)=='1';
    % center right
    M(2,3)= c(4)=='1';
    % upper left
    M(3,1)= c(3)=='1';
    % upper middle
    M(3,2)= c(2)=='1';
    % upper right
    M(3,3)= c(1)=='1';
end

% end of file