function Mborder = MakeBorderFrame(image)
%
% Mborder = MakeBorderFrame(image)
%
% Version 1.0
% Boris Guirao


% Creates border frame matrix "M_border" with 1s on image borders and 0s elsewhere.

%% Code

image_size = size(image);
Nimage_lines = image_size(:,1);
Nimage_columns = image_size(:,2);
Mborder = zeros(Nimage_lines,Nimage_columns); % creates a zero matrix same size as image
One_line = ones(1,Nimage_columns);             % creates a one-line vector of size Nimage_columns
One_column = ones(Nimage_lines,1);             % creates a one-column vector of size Nimage_lines
Mborder(1,:) = One_line;
Mborder(Nimage_lines,:) = One_line;
Mborder(:,1) = One_column;
Mborder(:,Nimage_columns) = One_column;       % M_border is created

%% History

% 02/06/2010: creation