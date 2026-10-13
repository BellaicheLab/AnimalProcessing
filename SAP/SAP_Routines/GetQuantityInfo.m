function Qinfo = GetQuantityInfo(Qname,info)
%
% Qinfo = GetQuantityInfo(Qname,info)
%
% For a quantity "Qname" ('EG', 'S', 'Rho'...) listed in AllQsColorsUnits, either retrieves the units, color and origin
% (AOS, TA, SM, VM). "info" = 'color', 'units' or 'origin'
%
% Version 1.0
% Boris Guirao


%% Code %%

AllQsColorsUnits;

QnameInTAtf = ismember(allQsTA, Qname);
QnameInAOStf = ismember(allQsAOS, Qname);
QnameInSMtf = ismember(allQsSM, Qname);
QnameInVMtf = ismember(allQsVM, Qname);


if any(QnameInAOStf)
    Qorigin = 'AOS';
    Qcolor = allColorsAOS{QnameInAOStf};
    Qunits = allUnitsAOS{QnameInAOStf};
    
elseif any(QnameInTAtf)
    Qorigin = 'TA';
    Qcolor = allColorsTA{QnameInTAtf}; %#ok<*USENS>
    Qunits = allUnitsTA{QnameInTAtf};
    
elseif any(QnameInSMtf)
    Qorigin = 'SM';
    Qcolor = allColorsSM{QnameInSMtf};
    Qunits = allUnitsSM{QnameInSMtf};
    
elseif any(QnameInVMtf)
    Qorigin = 'VM';
    Qcolor = allColorsVM{QnameInVMtf};
    Qunits = allUnitsVM{QnameInVMtf};
end

% Defining "Qinfo"
if strcmp(info,'color')
    Qinfo = Qcolor;
    
elseif strcmp(info,'units')
    Qinfo = Qunits;
    
elseif strcmp(info,'origin')
    Qinfo = Qorigin;
    
else
    disp('GetQuantityInfo ERROR: "info" can only be "color", "units", "origin"!')
    return
end


%% History %%

% 29/09/2017: