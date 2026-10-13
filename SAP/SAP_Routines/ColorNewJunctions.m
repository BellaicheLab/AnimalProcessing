
function CTimage = ColorNewJunctions(CTimage, cnjARG)
%
% CTimage = ColorNewJunctions(CTimage, cnjARG)
%
% In "CTimage", will color new junctions according to:
% 1) what created them (T1s or Divisions)
% 2) developmental time and parameter "newJuncDisplayTimes"
%
% Version 1.1
% Boris Guirao



%% Code %%

%#ok<*NODEF>

ExtractData(cnjARG,'','caller');
% NB: now direclty loads newDivCouplesTF, newDelCouplesTF, newT1CouplesTF
% stored in "cnjARG"

nNewJuncDisplayFrames = length(newJuncDisplayFrames) - 1; % number of indicated frames ranges to switch colors of diplayed new junctions.

for t = 1:nNewJuncDisplayFrames 
    
    %%%% T1s
    %-----------------------------------------------------------------------------------------------------
    if displayNewT1Junctions
        
        % Cropping "allNewCoupleANs" and "allNewFrames"
        newT1CoupleANs = allNewCoupleANs(newT1CouplesTF,:);  %#ok<*IDISVAR>
        newT1Frames = allNewFrames(newT1CouplesTF);
        % Determining "sideOfT1CouplesPixels" from "allNewT1CoupleANs" and "allNewT1Frames"
        selectedNewT1RowsTF = newT1Frames >= newJuncDisplayFrames(t) & newT1Frames < newJuncDisplayFrames(t+1);
        selectedNewT1CoupleANs = newT1CoupleANs(selectedNewT1RowsTF,:);
        selectedNewT1CoupleRNs = coupleANs2coupleRNs(selectedNewT1CoupleANs, Correspondence);
        % Pixels of new junctions created by T1s
        sideOfT1CouplesTF = ismember(sideCoupleRNs, selectedNewT1CoupleRNs,'rows'); % using now "newT1CoupleRNs" rather than "newNeighborCoupleRNs"
        sideOfT1CouplesPixels = sideDilatedIndices(sideOfT1CouplesTF);
        sideOfT1CouplesPixels = cell2mat(sideOfT1CouplesPixels')';
        sideOfT1CouplesPixels = unique(sideOfT1CouplesPixels);
        % Coloring pixels
        CTimage = Paint(CTimage, sideOfT1CouplesPixels, colorNewT1Junctions(t,:));
    end
    %-----------------------------------------------------------------------------------------------------
    
    %%%% Divisions
    %-----------------------------------------------------------------------------------------------------
    if displayNewDivJunctions

        % Cropping "allNewCoupleANs" and "allNewFrames"
        newDivCoupleANs = allNewCoupleANs(newDivCouplesTF,:);
        newDivFrames = allNewFrames(newDivCouplesTF);
        % Determining "sideOfT1CouplesPixels" from "allNewT1CoupleANs" and "allNewT1Frames"
        selectedNewDivRowsTF = newDivFrames >= newJuncDisplayFrames(t) & newDivFrames < newJuncDisplayFrames(t+1);
        selectedNewDivCoupleANs = newDivCoupleANs(selectedNewDivRowsTF,:);
        selectedNewDivCoupleRNs = coupleANs2coupleRNs(selectedNewDivCoupleANs, Correspondence);
        % Pixels of new junctions created by Divisions (between sisters and cousins)
        sideOfDivCouplesTF = ismember(sideCoupleRNs, selectedNewDivCoupleRNs,'rows');
        sideOfDivCouplesPixels = sideDilatedIndices(sideOfDivCouplesTF);            % using dilated version of sides
        sideOfDivCouplesPixels = cell2mat(sideOfDivCouplesPixels')';
        sideOfDivCouplesPixels = unique(sideOfDivCouplesPixels);
        % Coloring pixels
        CTimage = Paint(CTimage, sideOfDivCouplesPixels, colorNewDivJunctions(t,:));
    end
    %-----------------------------------------------------------------------------------------------------
    
    %%%% Delaminations (1.1)
    %-----------------------------------------------------------------------------------------------------
    if displayNewDelJunctions

        % Cropping "allNewCoupleANs" and "allNewFrames"
        newDelCoupleANs = allNewCoupleANs(newDelCouplesTF,:);
        newDelFrames = allNewFrames(newDelCouplesTF);
        % Determining "sideOfT1CouplesPixels" from "allNewT1CoupleANs" and "allNewT1Frames"
        selectedNewDelRowsTF = newDelFrames >= newJuncDisplayFrames(t) & newDelFrames < newJuncDisplayFrames(t+1);
        selectedNewDelCoupleANs = newDelCoupleANs(selectedNewDelRowsTF,:);
        selectedNewDelCoupleRNs = coupleANs2coupleRNs(selectedNewDelCoupleANs, Correspondence);
        % Pixels of new junctions created by Delisions (between sisters and cousins)
        sideOfDelCouplesTF = ismember(sideCoupleRNs, selectedNewDelCoupleRNs,'rows');
        sideOfDelCouplesPixels = sideDilatedIndices(sideOfDelCouplesTF);            % using dilated version of sides
        sideOfDelCouplesPixels = cell2mat(sideOfDelCouplesPixels')';
        sideOfDelCouplesPixels = unique(sideOfDelCouplesPixels);
        % Coloring pixels
        CTimage = Paint(CTimage, sideOfDelCouplesPixels, colorNewDelJunctions(t,:));
    end
    %-----------------------------------------------------------------------------------------------------
end

%% History %%

% 29/03:2018: 1.1
% - now loading "newDivCouplesTF", "newDelCouplesTF", "newT1CouplesTF"
% directly from structure "cnjARG"

% 08/12/2017: creation
