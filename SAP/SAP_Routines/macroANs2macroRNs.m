function macroRNs = macroANs2macroRNs(macroANs, Correspondence, excludeRNs)
%
% macroRNs = macroANs2macroRNs(macroANs, Correspondence, excludeRNs)
%
% Determines "macroANs" matching "macroRNs" in the current frame. When some "macroANs" are not found, or have
% corresponding RNs being borderRNs or coalescedRNs in the frame, then found RNs are replaced by NaN in macroRNs.
%
% NB: this requires a specific function (in addition to ANs2RNs) to support cases where macro are lost or fused with the
% border region (that would become all yellow if just using ANs2RNs).
%
% Version 2.0
% Boris Guirao

%% Code %%

% Determining this frame RNs

if ~isempty(macroANs)

    % Finds existing macro ANs and their corresponding RNs:
    [foundMacroRNs, foundMacroANs] = ANs2RNs(macroANs, Correspondence);    % some macro ANs may NOT exist in the beginning or may be lost later
    [~, foundMacroANsLoc] = ismember(foundMacroANs, macroANs,'rows');      % finding rows in "macroANs" where "foundMacroANs" are
    
    % Filling macroRNs, matching macroANs
    nMacro = size(macroANs,1);
    macroRNs = NaN(nMacro,1);
    macroRNs(foundMacroANsLoc) = foundMacroRNs;                            % storing RNs at the right location in table
    
    % Finding RNs being either borderRNs or coalescedRNs:
    foundMacroRNs2excludeTF = ismember(foundMacroRNs, excludeRNs);          % finding RNs involved
    foundMacroANsLoc2exclude = foundMacroANsLoc(foundMacroRNs2excludeTF);   % getting their rows in "macroANs"
    
    % Updating macroRNs by replacing stored RNs with NaNs
    macroRNs(foundMacroANsLoc2exclude) = NaN;
    
else
    macroRNs = []; 
end


%% History %%

% 25/10/2017: 2.0
% - complete overhaul
% - now replacing RNs by NaNs when a macro RNs belongs to coalesced RNs.

% 12/10/2017: 1.0