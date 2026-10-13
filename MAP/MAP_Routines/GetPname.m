% Based on AllQsColorsUnits script.
% determine the Process Name (Pname) associated with the Quantity Name (Qname)
% and its index (idx) in the Qname list
% Example: the Qname EG sould return the Pname TA
% If the Qname is unknown, the function return an empty string '' and an idx = 0.
%
% version 1.2
% Stephane Rigaud

function [ Pname, idx ] = GetPname( Qname )

CustomColors;
AllQsColorsUnits;

for t=1:length(allQsVM)
    allQsVMPIV{t} = [allQsVM{t} 'PIV'];
    allQsVMCT{t} = [allQsVM{t} 'CT'];
end

switch Qname
    case allQsAOS
        Pname = 'AOS';
        [~,idx] = ismember(Qname, allQsAOS);
    case allQsVM
        Pname = 'VM';
        %idx = find(cellfun(@(x)( ~isempty(x) ), regexpi(allQsVM, Qname)));
        [~,idx] = ismember(Qname, allQsVM);
    case allQsVMCT
        Pname = 'VM';
        %idx = find(cellfun(@(x)( ~isempty(x) ), regexpi(allQsVM, Qname)));
        [~,idx] = ismember(Qname, allQsVMCT);
    case allQsVMPIV
        Pname = 'VM';
        %idx = find(cellfun(@(x)( ~isempty(x) ), regexpi(allQsVM, Qname)));
        [~,idx] = ismember(Qname, allQsVMPIV);
    case allQsSM
        Pname = 'SM';
        [~,idx] = ismember(Qname, allQsSM);
    case allQsGEP
        Pname = 'GEP';
        [~,idx] = ismember(Qname, allQsGEP);
    case allQsTA
        Pname = 'TA';
        [~,idx] = ismember(Qname, allQsTA);
    otherwise
        Pname = 'RND';
        idx = 1;
        % [Pname, idx] = GetPname(Qname(1:2));
end

end

