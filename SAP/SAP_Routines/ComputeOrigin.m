function [Ox,Oy] = ComputeOrigin(oType, macroX, macroY, midLin, neck, nMacroMin, halfNotum, flag)

nMovies = size(macroX,2);

for n = 1:nMovies
    
    switch oType
        case 1
            % first macrochaete X coordinate and midline Y coordinate
            Ox(n) = min(macroX(:,n));
            Oy(n) = midLin(3,n);
            
        case 2
            % average coordinate of the Nth first macrochaete requested by the user
            landmarkX = macroX(1:nMacroMin,n); % take the nth first macro X coord
            landmarkY = macroY(1:nMacroMin,n); % take the nth first macro X coord
            if strcmp(halfNotum,'b')
                % if both side, we need to find the Nth macrochaete on each side
                landmarkXl = macroX(9:9+nMacroMin-1,n);
                landmarkYl = macroY(9:9+nMacroMin-1,n);
                landmarkX  = [landmarkX ; landmarkXl];
                landmarkY  = [landmarkY ; landmarkYl];
            end
            if flag
                landmarkX = [landmarkX ; neck(3,n)];
                landmarkY = [landmarkY ; midLin(3,n)];
            end
            Ox(n) = mean(landmarkX(:));
            Oy(n) = mean(landmarkY(:));
        otherwise
            % first macrochaete coordinate
            Ox(n) = macroX(1,n);
            Oy(n) = macroY(1,n);
    end
    
    % we verify if we have all the necessary macrochaete requested
    if sum(isnan([Ox(n) Oy(n)])) ~= 0
        warndlg(['The first ' num2str(nMacroMin) ' macrochaetes are NOT available on ' halfNotum ' sides for all animals!'...
            ' Please enter a smaller value for "nLandmarksMin" or go back and reclick the incomplete animals.'],'WARNING!')
        return
    end
end

end