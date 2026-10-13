function varargout = fourpixelblockdetector(I)
%
% version 0.3
% GOYA Yûki & Boris Guirao
%
% detects four pixel blocks

filter=[0 0 0 0 ;
        0 1 1 0 ;
        0 1 1 0 ;
        0 0 0 0];
% NB: only pattern made up by 1s is looked for, 0s above can have any values in the skeleton

% finds upper left corner (ULC) pixel coordinates of 4-pixel blocks:
[ULCy ULCx] = find(bwhitmiss(I,filter));
ULCyx = [ULCy ULCx];

% removes wrong detections on image borders (0.3):
ULCy_TF = ismember(ULCy, size(I,1)); % 1s where size(I,1) are found
ULCx_TF = ismember(ULCx, size(I,2)); % 1s where size(I,2) are found
% NB1: has to be done along x and y separately
% NB2: not looking for upper and left borders of image, i.e. 1 in ULCy,x that shouldn't occur

ULCyx_TF = any([ULCy_TF ULCx_TF],2);    % 1s where 1 was found in either column
ULCyx = ULCyx(~ULCyx_TF,:);             % removes lines where a border pixel was found
ULCy = ULCyx(:,1);
ULCx = ULCyx(:,2);
ULCind = sub2ind(size(I),ULCy,ULCx);    % linear indices

% replacing "Empty matrix: 0-by-1" by "[]":
if isempty(ULCind)
    ULCy = [];
    ULCx = [];
    ULCind = [];
end

% assigning outputs:
varargout{1}= ULCind;
if nargout==2
    varargout{1} = ULCy;
    varargout{2} = ULCx;
end


%% History %%

% 15/05/2013: 0.2, 0.3
% improved detection of filter by preventing fake detection on image borders:
% - removing bottom right pixel of image I (that is always found when it is 1) from varagout (0.2)
% - removing border pixels (right and bottom borders) of image I from varagout (0.3)
% - changed name to "fourpixelblocKdetector"

% 11/01/2013: creation